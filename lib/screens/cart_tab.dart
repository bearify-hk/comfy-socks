// cart_tab.dart
import 'dart:developer';
import 'package:comfy_socks/extension.dart';
import 'package:comfy_socks/services/cart_service.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
import 'package:comfy_socks/screens/checkout_webview.dart'; // Ensure this matches your project

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  final CartService cartService = CartService.instance;
  final ShopifyCustomerAccountAuth authService = ShopifyCustomerAccountAuth.instance;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    cartService.addListener(_onCartUpdate);
    initializeCart();
  }

  @override
  void dispose() {
    cartService.removeListener(_onCartUpdate);
    super.dispose();
  }

  void _onCartUpdate() => setState(() {});

  Future<void> initializeCart() async {
    if (cartService.cart != null) return;
    setState(() => isLoading = true);
    try {
      String? accessToken = authService.accessToken;
      String? customerEmail;
      if (accessToken != null) {
        final customerData = await authService.getCurrentCustomer();
        customerEmail = customerData['data']['customer']['emailAddress']['emailAddress'];
      }
      await cartService.createCart(email: customerEmail, accessToken: accessToken);
    } catch (e) {
      log('Init Cart Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = cartService.cart;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (cart != null)
            IconButton(onPressed: () => cartService.fetchCart(cart.id), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (cart == null || cart.lines.isEmpty)
              ? _buildEmptyState(colorScheme)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.lines.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final line = cart.lines[index];
                          final product = line.merchandise?.product;
                          final variant = line.merchandise;
                          // Extracting Thumbnail and Price
                          final imageUrl = variant?.image?.originalSrc;
                          final price = variant?.price.amount ?? 0.0;
                          final currency = variant?.price.currencyCode ?? 'USD';

                          return Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl != null
                                      ? Image.network(imageUrl, width: 64, height: 64, fit: BoxFit.cover)
                                      : Container(width: 64, height: 64, color: colorScheme.surfaceContainerHighest),
                                ),
                                title: Text(
                                  product?.title ?? 'Product',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Qty: ${line.quantity}", style: Theme.of(context).textTheme.bodySmall),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$currency ${price.toStringAsFixed(2)}",
                                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: () {
                                    // Add your logic to remove from cart here
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildCheckoutSummary(cart, colorScheme),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 80, color: colorScheme.outline),
          const SizedBox(height: 16),
          const Text("Your cart is empty", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummary(Cart cart, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Estimated Total", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(
                  "${cart.cost!.totalAmount.currencyCode} ${cart.cost!.totalAmount.amount.toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: cart.checkoutUrl != null ? () => _launchCheckout(cart.checkoutUrl!) : null,
                child: const Text("Proceed to Checkout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchCheckout(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => WebViewCheckout(checkoutUrl: url)));
  }
}