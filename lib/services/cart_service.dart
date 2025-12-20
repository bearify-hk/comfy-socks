// cart_service.dart
import 'package:flutter/foundation.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;
  CartService._internal();

  final ShopifyCart _shopifyCart = ShopifyCart.instance;

  Cart? _cart;
  Cart? get cart => _cart;
  String? get cartId => _cart?.id;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
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
    _notifyListeners();
  }

  Future<void> fetchCart(String cartId) async {
    _cart = await _shopifyCart.getCartById(cartId);
    _notifyListeners();
  }

  Future<void> addToCart({
    required String variantId,
    int quantity = 1,
    List<AttributeInput>? attributes,
  }) async {
    if (_cart == null) {
      throw Exception('Cart not initialized. Call createCart() first.');
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

  int get itemCount => _cart?.lines.length ?? 0;

  void clearCart() {
    _cart = null;
    _notifyListeners();
  }
}