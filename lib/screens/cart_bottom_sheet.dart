// cart_bottom_sheet.dart
import 'dart:developer';
import 'package:comfy_socks/screens/checkout_webview.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import '../services/cart_service.dart';

class CartBottomSheet extends StatefulWidget {
  const CartBottomSheet({super.key});

  @override
  State<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<CartBottomSheet> {
  final CartService _cartService = CartService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to the service so the bottom sheet refreshes automatically
    _cartService.addListener(_updateUI);
  }

  @override
  void dispose() {
    _cartService.removeListener(_updateUI);
    super.dispose();
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
      // Close sheet if cart becomes empty via an update
      if (_cartService.itemCount == 0) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _changeQuantity(Line line, bool increment) async {
    setState(() => _isLoading = true);
    try {
      final currentQty = line.quantity ?? 0;
      final newQty = increment ? currentQty + 1 : currentQty - 1;

      if (newQty <= 0) {
        await _cartService.removeFromCart(line.id!);
      } else {
        await _cartService.updateQuantity(
          line.id!,
          line.merchandise!.id,
          newQty,
        );
      }
    } catch (e) {
      log('Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update quantity')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cartService.cart;
    
    // Handle empty or null cart states
    if (cart == null || cart.lines.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Your cart is empty')),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Cart (${_cartService.itemCount})', 
                style: Theme.of(context).textTheme.headlineSmall
              ),
              IconButton(
                onPressed: () => Navigator.pop(context), 
                icon: const Icon(Icons.close)
              ),
            ],
          ),
          const Divider(),
          
          // Cart Items List
          Expanded(
            child: ListView.builder(
              itemCount: cart.lines.length,
              itemBuilder: (context, index) {
                final line = cart.lines[index];
                final product = line.merchandise?.product;
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: product?.images.isNotEmpty == true 
                    ? Image.network(product!.images.first.originalSrc, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.shopping_bag_outlined),
                  title: Text(product?.title ?? 'Product'),
                  subtitle: Text(line.merchandise?.title ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _isLoading ? null : () => _changeQuantity(line, false),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${line.quantity}', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : () => _changeQuantity(line, true),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer with Checkout
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated Total', style: TextStyle(fontSize: 18)),
                Text(
                  '${cart.cost?.totalAmount.amount} ${cart.cost?.totalAmount.currencyCode}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
          
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, 
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
              onPressed: _isLoading ? null : () {
                final url = _cartService.checkoutUrl; 
                if (url != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewCheckout(checkoutUrl: url)
                    ),
                  );
                }
              },
              child: _isLoading 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  ) 
                : const Text('PROCEED TO CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}