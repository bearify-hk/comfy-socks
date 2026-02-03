// cart_service.dart
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'shopify_customer_account_auth.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;
  CartService._internal();

  final ShopifyCart _shopifyCart = ShopifyCart.instance;
  static const String _cartIdKey = 'shopify_cart_id';

  Cart? _cart;
  Cart? get cart => _cart;

  /// Gets the checkout URL with proper authentication handling
  ///
  /// Note: The Customer Account API uses a different auth system than the
  /// Storefront API's checkout. For proper authenticated checkout, you may
  /// need to use the Customer Account API's checkout flow or implement
  /// a server-side solution to bridge the two systems.
  String? get checkoutUrl {
    if (_cart?.checkoutUrl == null) return null;

    final uri = Uri.parse(_cart!.checkoutUrl!);
    final auth = ShopifyCustomerAccountAuth.instance;

    // If user is authenticated with Customer Account API, we need to handle
    // the checkout differently. The 'logged_in=true' parameter alone won't work
    // because we're using Customer Account API, not Storefront API auth.
    if (auth.isAuthenticated && auth.customerEmail != null) {
      // For now, just append the email to prefill the checkout form
      // For full authentication, consider using Shopify's multipass or
      // having the user sign in again during checkout
      return uri
          .replace(
            queryParameters: {...uri.queryParameters, 'logged_in': 'true'},
          )
          .toString();
    }

    return _cart!.checkoutUrl;
  }

  String? get cartId => _cart?.id;

  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Call this when the app starts to restore the previous session
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_cartIdKey);
    if (savedId != null) {
      log('Restoring cart: $savedId');
      await fetchCart(savedId);
    }
  }

  /// Creates a new cart with optional buyer identity
  ///
  /// Note: The Customer Account API access token is NOT compatible with
  /// the Storefront API's customerAccessToken field. We use email-based
  /// identification instead.

  Future<void> createCart({String? email, String? accessToken}) async {
    final auth = ShopifyCustomerAccountAuth.instance;

    final cartInput = CartInput(
      buyerIdentity: CartBuyerIdentityInput(
        email: email ?? '',
        customerAccessToken: accessToken,
      ),
    );
    _cart = await _shopifyCart.createCart(cartInput);

    if (_cart?.id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartIdKey, _cart!.id);
    }

    _notifyListeners();
  }

  /// Syncs an existing guest cart with a newly logged-in user
  ///
  /// This updates the buyer identity with the customer's email from the
  /// Customer Account API session.
  Future<void> syncBuyerIdentity({String? email, String? accessToken}) async {
    if (_cart == null) return;

    final auth = ShopifyCustomerAccountAuth.instance;

    if (!auth.isAuthenticated || auth.customerEmail == null) {
      log('Cannot sync buyer identity: user not authenticated');
      return;
    }

    await updateBuyerIdentity(
      CartBuyerIdentityInput(
        email: email ?? '',
        customerAccessToken: accessToken,
      ),
    );
  }

  /// Clears the buyer identity when user logs out
  Future<void> clearBuyerIdentity() async {
    if (_cart == null) return;

    // Create a new cart without buyer identity
    // This is cleaner than trying to nullify the existing cart's identity
    final oldCart = _cart!;
    await createCart();

    // Transfer line items to the new cart
    for (final line in oldCart.lines) {
      if (line.merchandise?.id != null && line.quantity != null) {
        await addToCart(
          variantId: line.merchandise!.id,
          quantity: line.quantity!,
        );
      }
    }
  }

  Future<void> fetchCart(String id) async {
    try {
      _cart = await _shopifyCart.getCartById(id);
      _notifyListeners();
    } catch (e) {
      log('Cart expired or not found, clearing local ID: $e');
      await clearCart();
    }
  }

  Future<void> addToCart({
    required String variantId,
    int quantity = 1,
    List<AttributeInput>? attributes,
  }) async {
    if (_cart == null) {
      await createCart();
    }

    final cartLineInput = CartLineUpdateInput(
      quantity: quantity,
      merchandiseId: variantId,
      attributes: attributes ?? [],
    );

    _cart = await _shopifyCart.addLineItemsToCart(
      cartId: _cart!.id,
      cartLineInputs: [cartLineInput],
    );
    _notifyListeners();
  }

  Future<void> updateQuantity(
    String lineId,
    String variantId,
    int quantity,
  ) async {
    if (_cart == null) return;

    final cartLineInput = CartLineUpdateInput(
      id: lineId,
      quantity: quantity,
      merchandiseId: variantId,
    );

    _cart = await _shopifyCart.updateLineItemsInCart(
      cartId: _cart!.id,
      cartLineInputs: [cartLineInput],
    );
    _notifyListeners();
  }

  Future<void> removeFromCart(String lineId) async {
    if (_cart == null) return;

    _cart = await _shopifyCart.removeLineItemsFromCart(
      cartId: _cart!.id,
      lineIds: [lineId],
    );
    _notifyListeners();
  }

  Future<void> updateNote(String note) async {
    if (_cart == null) return;

    _cart = await _shopifyCart.updateNoteInCart(cartId: _cart!.id, note: note);
    _notifyListeners();
  }

  Future<void> updateBuyerIdentity(CartBuyerIdentityInput buyerIdentity) async {
    if (_cart == null) return;

    _cart = await _shopifyCart.updateBuyerIdentityInCart(
      cartId: _cart!.id,
      buyerIdentity: buyerIdentity,
    );
    _notifyListeners();
  }

  int get itemCount {
    if (_cart == null) return 0;
    return _cart!.lines.fold(0, (sum, line) => sum + (line.quantity ?? 0));
  }

  Future<void> clearCart() async {
    _cart = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartIdKey);
    _notifyListeners();
  }
}
