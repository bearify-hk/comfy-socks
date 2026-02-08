// auth_notifier.dart
import 'package:flutter/foundation.dart';
import 'shopify_customer_account_auth.dart';

/// A simple notifier for authentication state changes
class AuthNotifier extends ChangeNotifier {
  // Singleton pattern
  static final AuthNotifier _instance = AuthNotifier._internal();
  static AuthNotifier get instance => _instance;
  AuthNotifier._internal();

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  final ShopifyCustomerAccountAuth _auth = ShopifyCustomerAccountAuth.instance;

  /// Initialize the auth state - call this on app startup
  Future<void> init() async {
    if (_isInitialized) return;

    _isLoading = true;
    // Notify listeners immediately so UI can show a loading state
    notifyListeners();

    try {
      // 1. Initialize the Auth Service (loads tokens & cart ID from storage)
      // This returns true if a valid access token was found/refreshed
      final success = await _auth.init();
      _isAuthenticated = success;
    } catch (e) {
      if (kDebugMode) {
        print('Auth init error: $e');
      }
      _isAuthenticated = false;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call this when the OAuth callback is received (e.g. deep link)
  Future<void> notifyAuthStateChanged() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check the source of truth
      _isAuthenticated = _auth.isAuthenticated;
    } catch (e) {
      if (kDebugMode) {
        print('Auth state change error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call this when the user logs out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 2. Delegate logout to the Auth Service
      // This clears tokens but KEEPS the cart ID (for guest checkout continuity)
      await _auth.logout();

      _isAuthenticated = false;
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silent logout without opening browser
  Future<void> silentLogout() async {
    await _auth.silentLogout();
    _isAuthenticated = false;
    notifyListeners();
  }
}