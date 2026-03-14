// services/shopify_customer_account_auth.dart

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shopify Service handling Authentication (Customer Account API)
/// and Shopping Cart (Storefront API).
class ShopifyCustomerAccountAuth extends ChangeNotifier {
  static ShopifyCustomerAccountAuth? _instance;

  static ShopifyCustomerAccountAuth get instance {
    if (_instance == null) {
      throw Exception(
        'ShopifyCustomerAccountAuth not initialized. Call ShopifyCustomerAccountAuth.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initialize the service.
  ///
  /// [storefrontAccessToken] is required for Cart operations.
  /// You can find this in Shopify Admin -> Headless -> Your Storefront -> API Credentials.
  static void initialize({
    required String shopDomain,
    required String clientId,
    required String redirectUri,
    required String storefrontAccessToken,
    String storefrontApiVersion = '2025-01',
  }) {
    if (_instance != null) return;

    _instance = ShopifyCustomerAccountAuth._(
      shopDomain: shopDomain,
      clientId: clientId,
      redirectUri: redirectUri,
      storefrontAccessToken: storefrontAccessToken,
      storefrontApiVersion: storefrontApiVersion,
    );
  }

  static bool get isInitialized => _instance != null;

  final String shopDomain;
  final String clientId;
  final String redirectUri;
  final String storefrontAccessToken;
  final String storefrontApiVersion;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Secure storage keys
  static const String _accessTokenKey = 'shopify_access_token';
  static const String _refreshTokenKey = 'shopify_refresh_token';
  static const String _idTokenKey = 'shopify_id_token';
  static const String _tokenExpiresAtKey = 'shopify_token_expires_at';
  static const String _customerIdKey = 'shopify_customer_id';
  static const String _cartIdKey =
      'shopify_cart_id'; // New key for persisting cart

  String? _codeVerifier;
  String? _state;
  String? _nonce;

  // Cached discovery endpoints
  Map<String, dynamic>? _authConfig;
  Map<String, dynamic>? _apiConfig;

  // Token storage
  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
  DateTime? _tokenExpiresAt;
  String? _customerId;

  // Cart storage
  String? _cartId;

  // Public getters
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get idToken => _idToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  String? get customerId => _customerId;
  String? get cartId => _cartId;

  bool get isAuthenticated => _accessToken != null && !isTokenExpired;

  ShopifyCustomerAccountAuth._({
    required this.shopDomain,
    required this.clientId,
    required this.redirectUri,
    required this.storefrontAccessToken,
    required this.storefrontApiVersion,
  });

  // ============ Initialization & Persistence ============

  Future<bool> init() async {
    try {
      // Restore auth tokens
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      _idToken = await _secureStorage.read(key: _idTokenKey);
      _customerId = await _secureStorage.read(key: _customerIdKey);

      // Restore cart ID
      _cartId = await _secureStorage.read(key: _cartIdKey);

      final expiresAtStr = await _secureStorage.read(key: _tokenExpiresAtKey);
      if (expiresAtStr != null) {
        _tokenExpiresAt = DateTime.tryParse(expiresAtStr);
      }

      if (_accessToken != null) {
        if (isTokenExpired && _refreshToken != null) {
          try {
            await refreshAccessToken();
            return true;
          } catch (e) {
            await _clearPersistedTokens();
            return false;
          }
        } else if (!isTokenExpired) {
          return true;
        }
      }

      return false;
    } catch (e) {
      await _clearPersistedTokens();
      return false;
    }
  }

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
    if (_customerId != null) {
      await _secureStorage.write(key: _customerIdKey, value: _customerId);
    }
    if (_tokenExpiresAt != null) {
      await _secureStorage.write(
        key: _tokenExpiresAtKey,
        value: _tokenExpiresAt!.toIso8601String(),
      );
    }
  }

  Future<void> _persistCartId() async {
    if (_cartId != null) {
      await _secureStorage.write(key: _cartIdKey, value: _cartId);
      notifyListeners(); // 2. Notify when cart ID is set
    }
  }

  Future<void> _clearPersistedTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _tokenExpiresAtKey);
    await _secureStorage.delete(key: _customerIdKey);
    // Note: We usually DO NOT clear the cart ID on logout, allowing guest checkout continuation

    await _secureStorage.delete(key: _cartIdKey);
    _cartId = null;

    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    _tokenExpiresAt = null;
    _customerId = null;

    notifyListeners(); // 2. Notify when cart ID is set
  }

  /// Clear the cart (e.g., after successful checkout)
  Future<void> clearCart() async {
    await _secureStorage.delete(key: _cartIdKey);
    _cartId = null;

    notifyListeners(); // 2. Notify when cart ID is set
  }

  // ============ Discovery Endpoints (Customer Account API) ============

  Future<Map<String, dynamic>> discoverAuthEndpoints() async {
    if (_authConfig != null) return _authConfig!;
    final response = await http.get(
      Uri.parse('https://$shopDomain/.well-known/openid-configuration'),
    );
    if (response.statusCode != 200)
      throw Exception('Failed to discover auth endpoints');
    _authConfig = jsonDecode(response.body);
    return _authConfig!;
  }

  Future<Map<String, dynamic>> discoverApiEndpoints() async {
    if (_apiConfig != null) return _apiConfig!;
    final response = await http.get(
      Uri.parse('https://$shopDomain/.well-known/customer-account-api'),
    );
    if (response.statusCode != 200)
      throw Exception('Failed to discover API endpoints');
    _apiConfig = jsonDecode(response.body);
    return _apiConfig!;
  }

  // ============ PKCE Helpers ============

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure();
    final randomString = List.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return '$timestamp$randomString';
  }

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

  Future<Uri> getAuthorizationUrl({String? locale}) async {
    final config = await discoverAuthEndpoints();
    _codeVerifier = _generateCodeVerifier();
    _state = _generateState();
    _nonce = _generateNonce();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);

    return Uri.parse(config['authorization_endpoint']).replace(
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
  }

  Future<void> launchAuthorization({String? locale}) async {
    final authUrl = await getAuthorizationUrl(locale: locale);
    await _secureStorage.write(key: 'code_verifier', value: _codeVerifier);
    await _secureStorage.write(key: 'auth_state', value: _state);
    await _secureStorage.write(key: 'auth_nonce', value: _nonce);

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch authorization URL');
    }
  }

  Future<void> handleCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];
    final error = callbackUri.queryParameters['error'];

    if (error != null) throw Exception('Authorization error: $error');
    if (code == null) throw Exception('No authorization code received');

    _codeVerifier ??= await _secureStorage.read(key: 'code_verifier');
    _state ??= await _secureStorage.read(key: 'auth_state');
    _nonce ??= await _secureStorage.read(key: 'auth_nonce');

    if (returnedState != _state) throw Exception('State mismatch');

    await _exchangeCodeForTokens(code);

    await _secureStorage.delete(key: 'code_verifier');
    await _secureStorage.delete(key: 'auth_state');
    await _secureStorage.delete(key: 'auth_nonce');
  }

  Future<void> _exchangeCodeForTokens(String code) async {
    final config = await discoverAuthEndpoints();
    if (_codeVerifier == null) throw Exception('Code verifier not found');

    final response = await http.post(
      Uri.parse(config['token_endpoint']),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code': code,
        'code_verifier': _codeVerifier!,
      },
    );

    if (response.statusCode != 200)
      throw Exception('Token exchange failed: ${response.body}');

    final tokenData = jsonDecode(response.body);
    await _storeTokens(tokenData);

    if (_nonce != null && tokenData['id_token'] != null) {
      final idTokenNonce = _extractNonceFromIdToken(tokenData['id_token']);
      if (idTokenNonce != _nonce) throw Exception('Nonce mismatch');
    }

    _customerId = _extractCustomerIdFromIdToken(tokenData['id_token']);
    await _persistTokens();
    _codeVerifier = null;
    _state = null;
    _nonce = null;
  }

  Future<void> _storeTokens(Map<String, dynamic> tokenData) async {
    _accessToken = tokenData['access_token'];
    _refreshToken = tokenData['refresh_token'];
    _idToken = tokenData['id_token'];
    final expiresIn = tokenData['expires_in'] as int;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _persistTokens();
  }

  String? _extractNonceFromIdToken(String token) {
    try {
      final claims = _decodeJwtPayload(token);
      return claims?['nonce'];
    } catch (e) {
      return null;
    }
  }

  String? _extractCustomerIdFromIdToken(String token) {
    try {
      final claims = _decodeJwtPayload(token);
      return claims?['sub'];
    } catch (e) {
      return null;
    }
  }

  String? get customerEmail {
    if (_idToken == null) return null;
    try {
      final claims = _decodeJwtPayload(_idToken!);
      return claims?['email'];
    } catch (e) {
      return null;
    }
  }

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

  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return DateTime.now().isAfter(
      _tokenExpiresAt!.subtract(const Duration(seconds: 60)),
    );
  }

  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) throw Exception('No refresh token available');
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
      await _clearPersistedTokens();
      throw Exception('Token refresh failed');
    }
    final tokenData = jsonDecode(response.body);
    await _storeTokens(tokenData);
  }

  Future<String> getValidAccessToken() async {
    if (_accessToken == null) throw Exception('Not authenticated');
    if (isTokenExpired) {
      if (_refreshToken != null) {
        await refreshAccessToken();
      } else {
        await _clearPersistedTokens();
        throw Exception('Session expired');
      }
    }
    return _accessToken!;
  }

  // ============ Logout ============

  Future<void> _disassociateCart() async {
    if (_cartId == null) return;

    const q = '''
      mutation CartBuyerIdentityUpdate(\$cartId: ID!, \$buyerIdentity: CartBuyerIdentityInput!) {
        cartBuyerIdentityUpdate(cartId: \$cartId, buyerIdentity: \$buyerIdentity) {
          cart {
            id
            checkoutUrl
            buyerIdentity { email }
          }
          userErrors { field message }
        }
      }
    ''';

    try {
      // Passing nulls removes the association
      final variables = {
        'cartId': _cartId,
        'buyerIdentity': {
          'email': null,
          'customerAccessToken': null,
          'deliveryAddressPreferences':
              [], // Optional: clear address prefs if needed
        },
      };

      final result = await storefrontQuery(
        graphqlQuery: q,
        variables: variables,
      );

      // Optionally update the local cart checkout URL if it changed
      // (Shopify might generate a new checkout URL for guest mode)
      // notifyListeners();
    } catch (e) {
      print('Failed to disassociate cart: $e');
      // If this fails, we should probably force delete the cart ID locally
      // to prevent the "logged in" glitch.
      await _secureStorage.delete(key: _cartIdKey);
      _cartId = null;
    }
  }

  Future<void> logout({String? postLogoutRedirectUri}) async {
    try {
      await _disassociateCart();

      final config = await discoverAuthEndpoints();
      if (_idToken == null) return;

      final logoutUri = Uri.parse(config['end_session_endpoint']).replace(
        queryParameters: {
          'id_token_hint': _idToken!,
          if (postLogoutRedirectUri != null)
            'post_logout_redirect_uri': postLogoutRedirectUri,
        },
      );
      await http.get(logoutUri);
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await _clearPersistedTokens();
    }
  }

  Future<void> silentLogout() async {
    await _clearPersistedTokens();
    await clearCart();
  }

  // ============ Customer Account API (Authenticated User Data) ============

  /// Query the Customer Account API (Requires Authentication)
  Future<Map<String, dynamic>> query({
    required String graphqlQuery,
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    final apiConfig = await discoverApiEndpoints();
    final token = await getValidAccessToken();

    final response = await http.post(
      Uri.parse(apiConfig['graphql_api']),
      headers: {'Content-Type': 'application/json', 'Authorization': token},
      body: jsonEncode({
        'query': graphqlQuery,
        if (operationName != null) 'operationName': operationName,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode == 401) {
      try {
        await refreshAccessToken();
        return query(
          graphqlQuery: graphqlQuery,
          variables: variables,
          operationName: operationName,
        );
      } catch (e) {
        await _clearPersistedTokens();
        throw Exception('Session expired');
      }
    }

    if (response.statusCode != 200)
      throw Exception('API request failed: ${response.body}');
    final result = jsonDecode(response.body);
    if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
      throw Exception('GraphQL Error: ${result['errors'][0]['message']}');
    }
    return result;
  }

  Future<Map<String, dynamic>> getCurrentCustomer() async {
    const q = '''
      query GetCustomer {
        customer {
          id
          firstName
          lastName
          emailAddress { emailAddress }
          defaultAddress { id formatted phoneNumber }
        }
      }
    ''';
    return query(graphqlQuery: q, operationName: 'GetCustomer');
  }

  Future<Map<String, dynamic>> getOrders({int first = 10}) async {
    const q = '''
      query GetOrders(\$first: Int!) {
        customer {
          orders(first: \$first) {
            edges {
              node {
                id number processedAt financialStatus
                totalPrice { amount currencyCode }
              }
            }
          }
        }
      }
    ''';
    return query(
      graphqlQuery: q,
      operationName: 'GetOrders',
      variables: {'first': first},
    );
  }

  // ============ Storefront API (Cart Functionality) ============

  /// Query the Storefront API (Used for Cart & Products)
  /// This uses the [storefrontAccessToken] and does not require user login,
  /// but helps power the shopping experience.
  Future<Map<String, dynamic>> storefrontQuery({
    required String graphqlQuery,
    Map<String, dynamic>? variables,
  }) async {
    final endpoint = Uri.parse(
      'https://$shopDomain/api/$storefrontApiVersion/graphql',
    );

    final response = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      },
      body: jsonEncode({'query': graphqlQuery, 'variables': variables}),
    );

    if (response.statusCode != 200) {
      throw Exception('Storefront API request failed: ${response.body}');
    }

    final result = jsonDecode(response.body);
    if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
      throw Exception(
        'Storefront GraphQL Error: ${result['errors'][0]['message']}',
      );
    }

    return result;
  }

  /// Create a new Cart
  /// If the user is authenticated, we attach their email to the cart's buyer identity.
  Future<Map<String, dynamic>> createCart({
    List<Map<String, dynamic>>? lines,
  }) async {
    final email = customerEmail;

    // Construct input. If user is logged in, we add their email to the cart.
    // Note: We cannot pass the OIDC accessToken here; Storefront API expects a different token type.
    // Passing email helps pre-fill checkout.
    final Map<String, dynamic> input = {
      if (lines != null) 'lines': lines,
      if (email != null) 'buyerIdentity': {'email': email},
    };

    const q = '''
      mutation CartCreate(\$input: CartInput) {
        cartCreate(input: \$input) {
          cart {
            id
            checkoutUrl
            lines(first: 10) {
              edges { node { id quantity merchandise { ... on ProductVariant { id title } } } }
            }
            cost {
              totalAmount { amount currencyCode }
            }
          }
        }
      }
    ''';

    final result = await storefrontQuery(
      graphqlQuery: q,
      variables: {'input': input},
    );
    final cartData = result['data']['cartCreate']['cart'];

    _cartId = cartData['id'];
    await _persistCartId();

    return cartData;
  }

  /// Get current cart details
  /// If no cart exists locally, returns null.
  Future<Map<String, dynamic>?> getCart() async {
    if (_cartId == null) return null;

    const q = '''
      query GetCart(\$cartId: ID!) {
        cart(id: \$cartId) {
          id
          checkoutUrl
          updatedAt
          lines(first: 50) {
            edges {
              node {
                id
                quantity
                merchandise {
                  ... on ProductVariant {
                    id
                    title
                    price { amount currencyCode }
                    image { url }
                    product { title }
                  }
                }
              }
            }
          }
          cost {
            subtotalAmount { amount currencyCode }
            totalAmount { amount currencyCode }
            totalTaxAmount { amount currencyCode }
          }
        }
      }
    ''';

    try {
      final result = await storefrontQuery(
        graphqlQuery: q,
        variables: {'cartId': _cartId},
      );
      return result['data']['cart'];
    } catch (e) {
      // If cart is not found (expired), clear local ID
      if (e.toString().contains('valid cart')) {
        _cartId = null;
        await _secureStorage.delete(key: _cartIdKey);
        return null;
      }
      rethrow;
    }
  }

  /// Add product variant to cart
  /// [lines] example: [{'merchandiseId': 'gid://shopify/ProductVariant/123', 'quantity': 1}]
  Future<Map<String, dynamic>> addToCart(
    List<Map<String, dynamic>> lines,
  ) async {
    _cartId ??= await _secureStorage.read(key: _cartIdKey);

    if (_cartId == null) {
      return createCart(lines: lines);
    }

    const q = '''
      mutation CartLinesAdd(\$cartId: ID!, \$lines: [CartLineInput!]!) {
        cartLinesAdd(cartId: \$cartId, lines: \$lines) {
          cart {
            id
            lines(first: 50) {
              edges { node { id quantity merchandise { ... on ProductVariant { id title } } } }
            }
            cost { totalAmount { amount currencyCode } }
          }
          userErrors { field message }
        }
      }
    ''';

    final result = await storefrontQuery(
      graphqlQuery: q,
      variables: {'cartId': _cartId, 'lines': lines},
    );

    final userErrors = result['data']['cartLinesAdd']['userErrors'] as List;
    if (userErrors.isNotEmpty) {
      throw Exception(userErrors.first['message']);
    }

    notifyListeners();
    return result['data']['cartLinesAdd']['cart'];
  }

  /// Remove items from cart
  /// [lineIds] are the IDs of the lines in the cart (not product IDs)
  Future<Map<String, dynamic>> removeFromCart(List<String> lineIds) async {
    if (_cartId == null) throw Exception('No active cart');

    const q = '''
      mutation CartLinesRemove(\$cartId: ID!, \$lineIds: [ID!]!) {
        cartLinesRemove(cartId: \$cartId, lineIds: \$lineIds) {
          cart {
            id
            lines(first: 50) {
              edges { node { id quantity } }
            }
            cost { totalAmount { amount currencyCode } }
          }
          userErrors { field message }
        }
      }
    ''';

    final result = await storefrontQuery(
      graphqlQuery: q,
      variables: {'cartId': _cartId, 'lineIds': lineIds},
    );

    final userErrors = result['data']['cartLinesRemove']['userErrors'] as List;
    if (userErrors.isNotEmpty) {
      throw Exception(userErrors.first['message']);
    }

    notifyListeners(); // 2. Notify when cart ID is set

    return result['data']['cartLinesRemove']['cart'];
  }

  /// Update quantity of an item
  Future<Map<String, dynamic>> updateCartLine(
    String lineId,
    int quantity,
  ) async {
    if (_cartId == null) throw Exception('No active cart');

    const q = '''
      mutation CartLinesUpdate(\$cartId: ID!, \$lines: [CartLineUpdateInput!]!) {
        cartLinesUpdate(cartId: \$cartId, lines: \$lines) {
          cart {
            id
            lines(first: 50) {
              edges { node { id quantity } }
            }
            cost { totalAmount { amount currencyCode } }
          }
          userErrors { field message }
        }
      }
    ''';

    final result = await storefrontQuery(
      graphqlQuery: q,
      variables: {
        'cartId': _cartId,
        'lines': [
          {'id': lineId, 'quantity': quantity},
        ],
      },
    );

    final userErrors = result['data']['cartLinesUpdate']['userErrors'] as List;
    if (userErrors.isNotEmpty) {
      throw Exception(userErrors.first['message']);
    }

    notifyListeners(); // 2. Notify when cart ID is set

    return result['data']['cartLinesUpdate']['cart'];
  }
}
