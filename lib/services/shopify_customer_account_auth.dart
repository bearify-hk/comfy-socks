// shopify_customer_account_auth.dart

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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

  // Secure storage keys
  static const String _accessTokenKey = 'shopify_access_token';
  static const String _refreshTokenKey = 'shopify_refresh_token';
  static const String _idTokenKey = 'shopify_id_token';
  static const String _tokenExpiresAtKey = 'shopify_token_expires_at';
  static const String _customerIdKey = 'shopify_customer_id';

  String? _codeVerifier;
  String? _state;
  String? _nonce;

  // Cached discovery endpoints
  Map<String, dynamic>? _authConfig;
  Map<String, dynamic>? _apiConfig;

  // Token storage (now persisted to secure storage)
  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
  DateTime? _tokenExpiresAt;
  String? _customerId;

  // Public getters
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get idToken => _idToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  String? get customerId => _customerId;

  /// Check if user is currently authenticated
  bool get isAuthenticated => _accessToken != null && !isTokenExpired;

  /// Check if we have tokens that might be refreshable
  bool get hasRefreshableSession => _refreshToken != null;

  ShopifyCustomerAccountAuth._({
    required this.shopDomain,
    required this.clientId,
    required this.redirectUri,
  });

  // ============ Initialization & Persistence ============

  /// Initialize the auth service and restore any saved session
  /// Call this when the app starts
  Future<bool> init() async {
    try {
      // Restore tokens from secure storage
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      _idToken = await _secureStorage.read(key: _idTokenKey);
      _customerId = await _secureStorage.read(key: _customerIdKey);

      final expiresAtStr = await _secureStorage.read(key: _tokenExpiresAtKey);
      if (expiresAtStr != null) {
        _tokenExpiresAt = DateTime.tryParse(expiresAtStr);
      }

      // If we have an access token, check if it's valid or needs refresh
      if (_accessToken != null) {
        if (isTokenExpired && _refreshToken != null) {
          // Try to refresh the token
          try {
            await refreshAccessToken();
            return true;
          } catch (e) {
            // Refresh failed, clear everything
            await _clearPersistedTokens();
            return false;
          }
        } else if (!isTokenExpired) {
          // Token is still valid
          return true;
        }
      }

      return false;
    } catch (e) {
      // Any error during init means we're not authenticated
      await _clearPersistedTokens();
      return false;
    }
  }

  /// Persist tokens to secure storage
  Future<void> _persistTokens() async {
    if (_accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
    }
    if (_refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);
    }
    if (_idToken != null) {
      await _secureStorage.write(key: _idTokenKey, value: _idToken);
    }
    if (_tokenExpiresAt != null) {
      await _secureStorage.write(
        key: _tokenExpiresAtKey,
        value: _tokenExpiresAt!.toIso8601String(),
      );
    }
    if (_customerId != null) {
      await _secureStorage.write(key: _customerIdKey, value: _customerId);
    }
  }

  /// Clear all persisted tokens
  Future<void> _clearPersistedTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _tokenExpiresAtKey);
    await _secureStorage.delete(key: _customerIdKey);

    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    _tokenExpiresAt = null;
    _customerId = null;
  }

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
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generate code challenge from verifier using SHA-256
  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
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
        if (locale != null) 'ui_locales': locale,
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
  Future<void> handleCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];
    final error = callbackUri.queryParameters['error'];
    final errorDescription = callbackUri.queryParameters['error_description'];

    if (error != null) {
      throw Exception('Authorization error: $error - $errorDescription');
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

    // Build the request body
    final bodyParams = {
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'code': code,
      'code_verifier': _codeVerifier!,
    };

    final response = await http.post(
      Uri.parse(config['token_endpoint']),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: bodyParams,
    );

    if (response.statusCode != 200) {
      throw Exception('Token exchange failed: ${response.body}');
    }

    final tokenData = jsonDecode(response.body);
    await _storeTokens(tokenData);

    // Verify nonce from id_token
    if (_nonce != null && tokenData['id_token'] != null) {
      final idTokenNonce = _extractNonceFromIdToken(tokenData['id_token']);
      if (idTokenNonce != _nonce) {
        throw Exception('Nonce mismatch - possible replay attack');
      }
    }

    // Extract customer ID from id_token
    _customerId = _extractCustomerIdFromIdToken(tokenData['id_token']);
    await _persistTokens();

    // Clear PKCE values
    _codeVerifier = null;
    _state = null;
    _nonce = null;
  }

  /// Store tokens from response and persist them
  Future<void> _storeTokens(Map<String, dynamic> tokenData) async {
    _accessToken = tokenData['access_token'];
    _refreshToken = tokenData['refresh_token'];
    _idToken = tokenData['id_token'];

    final expiresIn = tokenData['expires_in'] as int;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _persistTokens();
  }

  /// Extract nonce from id_token JWT
  String? _extractNonceFromIdToken(String token) {
    try {
      final claims = _decodeJwtPayload(token);
      return claims?['nonce'];
    } catch (e) {
      return null;
    }
  }

  /// Extract customer ID from id_token JWT
  String? _extractCustomerIdFromIdToken(String token) {
    try {
      final claims = _decodeJwtPayload(token);
      // The 'sub' claim contains the customer ID
      return claims?['sub'];
    } catch (e) {
      return null;
    }
  }

  /// Extract email from id_token JWT
  String? get customerEmail {
    if (_idToken == null) return null;
    try {
      final claims = _decodeJwtPayload(_idToken!);
      return claims?['email'];
    } catch (e) {
      return null;
    }
  }

  /// Decode JWT payload
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded);
    } catch (e) {
      return null;
    }
  }

  // ============ Token Refresh ============

  /// Check if access token is expired
  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    // Consider token expired 60 seconds before actual expiry for safety
    return DateTime.now().isAfter(
      _tokenExpiresAt!.subtract(const Duration(seconds: 60)),
    );
  }

  /// Refresh the access token
  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final config = await discoverAuthEndpoints();

    final response = await http.post(
      Uri.parse(config['token_endpoint']),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': _refreshToken!,
      },
    );

    if (response.statusCode != 200) {
      // Refresh token might be expired, clear everything
      await _clearPersistedTokens();
      throw Exception('Token refresh failed: ${response.body}');
    }

    final tokenData = jsonDecode(response.body);
    await _storeTokens(tokenData);
  }

  /// Get a valid access token, refreshing if necessary
  Future<String> getValidAccessToken() async {
    if (_accessToken == null) {
      throw Exception('Not authenticated');
    }

    if (isTokenExpired) {
      if (_refreshToken != null) {
        await refreshAccessToken();
      } else {
        await _clearPersistedTokens();
        throw Exception('Session expired - please login again');
      }
    }

    return _accessToken!;
  }

  // ============ Logout ============

  /// Log out the current customer
  Future<void> logout({String? postLogoutRedirectUri}) async {
    try {
      final config = await discoverAuthEndpoints();

      if (_idToken != null) {
        final logoutUrl = Uri.parse(config['end_session_endpoint']).replace(
          queryParameters: {
            'id_token_hint': _idToken!,
            if (postLogoutRedirectUri != null)
              'post_logout_redirect_uri': postLogoutRedirectUri,
          },
        );

        // For mobile, open the logout URL
        if (await canLaunchUrl(logoutUrl)) {
          await launchUrl(logoutUrl, mode: LaunchMode.externalApplication);
        }
      }
    } finally {
      // Always clear local tokens regardless of logout API result
      await _clearPersistedTokens();
    }
  }

  /// Silent logout - just clear local tokens without calling Shopify
  Future<void> silentLogout() async {
    await _clearPersistedTokens();
  }

  // ============ API Requests ============

  /// Make a GraphQL request to the Customer Account API
  Future<Map<String, dynamic>> query({
    required String graphqlQuery,
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    final apiConfig = await discoverApiEndpoints();
    final token = await getValidAccessToken();

    final response = await http.post(
      Uri.parse(apiConfig['graphql_api']),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode({
        'query': graphqlQuery,
        if (operationName != null) 'operationName': operationName,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode == 401) {
      // Token might be invalid, try refreshp
      try {
        await refreshAccessToken();
        // Retry the request
        return query(
          graphqlQuery: graphqlQuery,
          variables: variables,
          operationName: operationName,
        );
      } catch (e) {
        await _clearPersistedTokens();
        throw Exception('Session expired - please login again');
      }
    }

    if (response.statusCode != 200) {
      throw Exception('API request failed: ${response.body}');
    }

    final result = jsonDecode(response.body);

    // Check for GraphQL errors
    if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
      final errors = result['errors'] as List;
      throw Exception('GraphQL Error: ${errors.first['message']}');
    }

    return result;
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

    return query(graphqlQuery: customerQuery, operationName: 'GetCustomer');
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
      graphqlQuery: ordersQuery,
      operationName: 'GetOrders',
      variables: {'first': first},
    );
  }
}
