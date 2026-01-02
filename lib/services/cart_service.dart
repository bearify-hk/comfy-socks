// cart_service.dart
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;
  CartService._internal();

  final ShopifyCart _shopifyCart = ShopifyCart.instance;
  static const String _cartIdKey = 'shopify_cart_id';

  Cart? _cart;
  Cart? get cart => _cart;
  
  // Modifies URL to auto-login the user in the WebView
  String? get checkoutUrl {
    if (_cart?.checkoutUrl == null) return null;
    final uri = Uri.parse(_cart!.checkoutUrl!);
    // 2025 Shopify Standard: Append logged_in=true to carry the session
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'logged_in': 'true',
    }).toString();
  }

  String? get cartId => _cart?.id;

  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notifyListeners() => _listeners.forEach((l) => l());

  /// Call this when the app starts to restore the previous session
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_cartIdKey);
    if (savedId != null) {
      log('Restoring cart: $savedId');
      await fetchCart(savedId);
    }
  }

  Future<void> createCart({String? email, String? accessToken}) async {
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
  Future<void> syncBuyerIdentity({String? email, String? accessToken}) async {
    if (_cart == null) return;
    
    await updateBuyerIdentity(CartBuyerIdentityInput(
      email: email ?? '',
      customerAccessToken: accessToken,
    ));
  }

  Future<void> fetchCart(String id) async {
    try {
      _cart = await _shopifyCart.getCartById(id);
      _notifyListeners();
    } catch (e) {
      log('Cart expired or not found, clearing local ID');
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
      String lineId, String variantId, int quantity) async {
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

    _cart = await _shopifyCart.updateNoteInCart(
      cartId: _cart!.id,
      note: note,
    );
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