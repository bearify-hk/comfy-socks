import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart'; // For deep link handling
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shopify Customer Account API Authentication Service
///
/// This implements OAuth 2.0 with PKCE for public clients (mobile apps)
/// as specified in Shopify's Customer Account API documentation.
class ShopifyCustomerAccountAuth {


  static ShopifyCustomerAccountAuth? _instance;
  
  static ShopifyCustomerAccountAuth get instance {
    if (_instance == null) {
      throw Exception(
        'ShopifyCustomerAccountAuth not initialized. Call ShopifyCustomerAccountAuth.initialize() first.',
      );
    }
    return _instance!;
  }
  
  static void initialize({
    required String shopDomain,
    required String clientId,
    required String redirectUri,
  }) {
    _instance = ShopifyCustomerAccountAuth._(
      shopDomain: shopDomain,
      clientId: clientId,
      redirectUri: redirectUri,
    );
  }
  
  static bool get isInitialized => _instance != null;
  
  final String shopDomain; // e.g., 'your-store.myshopify.com'
  final String clientId;
  final String redirectUri; // e.g., 'shop.YOUR_SHOP_ID.app://callback'

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _codeVerifier;
  String? _state;
  String? _nonce;

  // Cached discovery endpoints
  Map<String, dynamic>? _authConfig;
  Map<String, dynamic>? _apiConfig;

  // Token storage (in production, use secure storage like flutter_secure_storage)
  String? accessToken;
  String? refreshToken;
  String? idToken;
  DateTime? tokenExpiresAt;

  ShopifyCustomerAccountAuth._({
    required this.shopDomain,
    required this.clientId,
    required this.redirectUri,
  });

  // ============ Discovery Endpoints ============

  /// Discover OpenID configuration endpoints
  Future<Map<String, dynamic>> discoverAuthEndpoints() async {
    if (_authConfig != null) return _authConfig!;

    final response = await http.get(
      Uri.parse('https://$shopDomain/.well-known/openid-configuration'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to discover auth endpoints: ${response.body}');
    }

    _authConfig = jsonDecode(response.body);
    return _authConfig!;
  }

  /// Discover Customer Account API endpoints
  Future<Map<String, dynamic>> discoverApiEndpoints() async {
    if (_apiConfig != null) return _apiConfig!;

    final response = await http.get(
      Uri.parse('https://$shopDomain/.well-known/customer-account-api'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to discover API endpoints: ${response.body}');
    }

    _apiConfig = jsonDecode(response.body);
    return _apiConfig!;
  }

  // ============ PKCE Helpers ============

  /// Generate a cryptographically secure code verifier
  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    // Directly base64url encode the bytes, not a string representation
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generate code challenge from verifier using SHA-256
  String _generateCodeChallenge(String verifier) {
    // Hash the raw ASCII/UTF-8 bytes of the verifier string
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    // Base64url encode the hash bytes
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generate state parameter for CSRF protection
  String _generateState() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure();
    final randomString = List.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return '$timestamp$randomString';
  }

  /// Generate nonce for replay attack prevention
  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ============ Authorization Flow ============

  /// Start the authorization flow - opens Shopify's login page
  ///
  /// For mobile apps, this will open an external browser or in-app browser.
  /// The user will authenticate via Shopify's hosted login (email + OTP, etc.)
  Future<Uri> getAuthorizationUrl({String? locale}) async {
    final config = await discoverAuthEndpoints();

    _codeVerifier = _generateCodeVerifier();
    _state = _generateState();
    _nonce = _generateNonce();

    final codeChallenge = _generateCodeChallenge(_codeVerifier!);

    final authUrl = Uri.parse(config['authorization_endpoint']).replace(
      queryParameters: {
        'scope': 'openid email customer-account-api:full',
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'state': _state,
        'nonce': _nonce,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        if (locale != null) 'locale': locale,
      },
    );

    return authUrl;
  }

  /// Launch the authorization URL in a browser
  Future<void> launchAuthorization({String? locale}) async {
    final authUrl = await getAuthorizationUrl(locale: locale);

    // Persist PKCE values before leaving the app
    await _secureStorage.write(key: 'code_verifier', value: _codeVerifier);
    await _secureStorage.write(key: 'auth_state', value: _state);
    await _secureStorage.write(key: 'auth_nonce', value: _nonce);

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch authorization URL');
    }
  }

  /// Handle the callback from the authorization redirect
  ///
  /// Call this when your app receives the deep link callback
  Future<void> handleCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];
    final error = callbackUri.queryParameters['error'];

    if (error != null) {
      throw Exception('Authorization error: $error');
    }

    if (code == null) {
      throw Exception('No authorization code received');
    }

    // Restore PKCE values if app was killed
    _codeVerifier ??= await _secureStorage.read(key: 'code_verifier');
    _state ??= await _secureStorage.read(key: 'auth_state');
    _nonce ??= await _secureStorage.read(key: 'auth_nonce');

    // Verify state to prevent CSRF
    if (returnedState != _state) {
      throw Exception('State mismatch - possible CSRF attack');
    }

    await _exchangeCodeForTokens(code);

    // Clean up stored PKCE values
    await _secureStorage.delete(key: 'code_verifier');
    await _secureStorage.delete(key: 'auth_state');
    await _secureStorage.delete(key: 'auth_nonce');
  }

  /// Exchange authorization code for access tokens
  Future<void> _exchangeCodeForTokens(String code) async {
    final config = await discoverAuthEndpoints();

    if (_codeVerifier == null) {
      throw Exception(
        'Code verifier not found - authorization flow not started',
      );
    }

    final response = await http.post(
      Uri.parse(config['token_endpoint']),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code': code,
        'code_verifier': _codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Token exchange failed: ${response.body}');
    }

    final tokenData = jsonDecode(response.body);
    _storeTokens(tokenData);

    // Verify nonce from id_token
    if (_nonce != null && tokenData['id_token'] != null) {
      final idTokenNonce = _extractNonceFromIdToken(tokenData['id_token']);
      if (idTokenNonce != _nonce) {
        throw Exception('Nonce mismatch - possible replay attack');
      }
    }

    // Clear PKCE values
    _codeVerifier = null;
    _state = null;
    _nonce = null;
  }

  /// Store tokens from response
  void _storeTokens(Map<String, dynamic> tokenData) {
    accessToken = tokenData['access_token'];
    refreshToken = tokenData['refresh_token'];
    idToken = tokenData['id_token'];

    final expiresIn = tokenData['expires_in'] as int;
    tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
  }

  /// Extract nonce from id_token JWT
  String? _extractNonceFromIdToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Add padding if needed
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(decoded);

      return claims['nonce'];
    } catch (e) {
      return null;
    }
  }

  // ============ Token Refresh ============

  /// Check if access token is expired
  bool get isTokenExpired {
    if (tokenExpiresAt == null) return true;
    // Consider token expired 30 seconds before actual expiry
    return DateTime.now().isAfter(
      tokenExpiresAt!.subtract(const Duration(seconds: 30)),
    );
  }

  /// Refresh the access token
  Future<void> refreshAccessToken() async {
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final config = await discoverAuthEndpoints();

    final response = await http.post(
      Uri.parse(config['token_endpoint']),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Token refresh failed: ${response.body}');
    }

    final tokenData = jsonDecode(response.body);
    _storeTokens(tokenData);
  }

  /// Get a valid access token, refreshing if necessary
  Future<String> getValidAccessToken() async {
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    if (isTokenExpired) {
      await refreshAccessToken();
    }

    return accessToken!;
  }

  // ============ Logout ============

  /// Log out the current customer
  Future<void> logout({String? postLogoutRedirectUri}) async {
    final config = await discoverAuthEndpoints();

    if (idToken == null) {
      // Just clear local tokens
      _clearTokens();
      return;
    }

    final logoutUrl = Uri.parse(config['end_session_endpoint']).replace(
      queryParameters: {
        'id_token_hint': idToken!,
        if (postLogoutRedirectUri != null)
          'post_logout_redirect_uri': postLogoutRedirectUri,
      },
    );

    // For mobile, call as API endpoint
    final response = await http.get(logoutUrl);

    if (response.statusCode != 200) {
      throw Exception('Logout failed: ${response.body}');
    }

    _clearTokens();
  }

  void _clearTokens() {
    accessToken = null;
    refreshToken = null;
    idToken = null;
    tokenExpiresAt = null;
  }

  // ============ API Requests ============

  /// Make a GraphQL request to the Customer Account API
  Future<Map<String, dynamic>> query({
    required String query,
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    final apiConfig = await discoverApiEndpoints();
    final token = await getValidAccessToken();

    final response = await http.post(
      Uri.parse(apiConfig['graphql_api']),
      headers: {'Content-Type': 'application/json', 'Authorization': token},
      body: jsonEncode({
        'query': query,
        if (operationName != null) 'operationName': operationName,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API request failed: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// Get current customer information
  Future<Map<String, dynamic>> getCurrentCustomer() async {
    const customerQuery = '''
      query GetCustomer {
        customer {
          id
          firstName
          lastName
          emailAddress {
            emailAddress
          }
          phoneNumber {
            phoneNumber
          }
          defaultAddress {
            id
            formatted
          }
        }
      }
    ''';

    return query(query: customerQuery, operationName: 'GetCustomer');
  }

  /// Get customer orders
  Future<Map<String, dynamic>> getOrders({int first = 10}) async {
    const ordersQuery = '''
      query GetOrders(\$first: Int!) {
        customer {
          orders(first: \$first) {
            edges {
              node {
                id
                number
                processedAt
                financialStatus
                fulfillments(first: 1) {
                  edges {
                    node {
                      status
                    }
                  }
                }
                totalPrice {
                  amount
                  currencyCode
                }
              }
            }
          }
        }
      }
    ''';

    return query(
      query: ordersQuery,
      operationName: 'GetOrders',
      variables: {'first': first},
    );
  }
}
