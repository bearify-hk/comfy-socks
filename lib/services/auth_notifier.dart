// auth_notifier.dart
import 'package:flutter/foundation.dart';
import 'shopify_customer_account_auth.dart';
import 'cart_service.dart';

/// A simple notifier for authentication state changes
class AuthNotifier extends ChangeNotifier {
  static final AuthNotifier _instance = AuthNotifier._internal();
  static AuthNotifier get instance => _instance;
  AuthNotifier._internal();

  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  /// Initialize the auth state - call this on app startup
  Future<void> init() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final auth = ShopifyCustomerAccountAuth.instance;
      _isAuthenticated = await auth.init();

      // If authenticated, sync the cart with the user
      if (_isAuthenticated) {
        await CartService.instance.syncBuyerIdentity();
      }
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

  /// Call this when the OAuth callback is received
  Future<void> notifyAuthStateChanged() async {
    _isLoading = true;
    notifyListeners();

    try {
      final auth = ShopifyCustomerAccountAuth.instance;
      _isAuthenticated = auth.isAuthenticated;

      if (_isAuthenticated) {
        // Sync cart with the newly logged-in user
        await CartService.instance.syncBuyerIdentity();
      }
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
      final auth = ShopifyCustomerAccountAuth.instance;
      await auth.logout();

      // Clear the buyer identity from the cart
      await CartService.instance.clearBuyerIdentity();

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
    final auth = ShopifyCustomerAccountAuth.instance;
    await auth.silentLogout();
    await CartService.instance.clearBuyerIdentity();
    _isAuthenticated = false;
    notifyListeners();
  }
}
