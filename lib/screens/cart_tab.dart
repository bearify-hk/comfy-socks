// cart_tab.dart
import 'dart:developer';
import 'package:comfy_socks/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
// import 'package:comfy_socks/screens/checkout_webview.dart';
import 'package:url_launcher/url_launcher.dart';

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  // Use the new service directly
  final ShopifyCustomerAccountAuth authService =
      ShopifyCustomerAccountAuth.instance;

  Map<String, dynamic>? currentCart; // Local state to hold the Map data
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to changes (like removals or additions)
    authService.addListener(_onAuthServiceUpdate);
    initializeCart();
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthServiceUpdate);
    super.dispose();
  }

  // When the service notifies (e.g. item removed), re-fetch data
  void _onAuthServiceUpdate() {
    if (mounted) initializeCart();
  }

  Future<void> initializeCart() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final cartData = await authService.getCart();
      // Only update state, do NOT call createCart() here.
      // If cartData is null, the UI should simply show the "Empty State".
      setState(() => currentCart = cartData);
    } catch (e) {
      log('Cart Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Safely extract lines from the GraphQL Map structure
    final List lines = currentCart?['lines']?['edges'] ?? [];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.cart),
        actions: [
          IconButton(
            onPressed: initializeCart,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading && currentCart == null
          ? const Center(child: CircularProgressIndicator())
          : lines.isEmpty
          ? _buildEmptyState(colorScheme)
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final node = lines[index]['node'];
                      final lineId = node['id'];
                      final quantity = node['quantity'];
                      final variant = node['merchandise'];
                      final productTitle =
                          variant['product']?['title'] ?? 'Product';
                      final variantTitle = variant['title'];

                      // Image and Price parsing from Map
                      final imageUrl = variant['image']?['url'];
                      final price = variant['price']?['amount'] ?? "0.0";
                      final currency = variant['price']?['currencyCode'] ?? "";

                      return Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    color: colorScheme.surfaceContainerHighest,
                                  ),
                          ),
                          title: Text(
                            productTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text("Qty: $quantity • $currency $price"),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              await authService.removeFromCart([lineId]);
                              // The listener will automatically trigger initializeCart()
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildCheckoutSummary(currentCart!, colorScheme),
              ],
            ),
    );
  }

  Widget _buildCheckoutSummary(
    Map<String, dynamic> cart,
    ColorScheme colorScheme,
  ) {
    final cost = cart['cost']?['totalAmount'];
    final total = cost?['amount'] ?? "0.0";
    final currency = cost?['currencyCode'] ?? "";
    final checkoutUrl = cart['checkoutUrl'];

    return Container(
      padding: const EdgeInsets.all(16),
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
                Text(AppLocalizations.of(context)!.estimatedTotal),
                Text(
                  "$currency $total",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: checkoutUrl != null
                    ? () => _launchCheckout(checkoutUrl)
                    : null,
                child: Text(AppLocalizations.of(context)!.checkout),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchCheckout(String url) async {
    final uri = Uri.parse(url);

    // FIX: Only append 'logged_in=true' if the user is actually authenticated
    final isAuthenticated = authService.isAuthenticated;

    Uri authenticatedUri = uri;

    if (isAuthenticated) {
      authenticatedUri = uri.replace(
        queryParameters: {...uri.queryParameters, 'logged_in': 'true'},
      );
    }

    if (await canLaunchUrl(authenticatedUri)) {
      await launchUrl(
        authenticatedUri,
        // Note: If you want to clear browser cookies entirely,
        // the user must manually sign out of the browser,
        // but dropping the Cart ID (Fix #1) usually solves the "Pre-filled info" issue.
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch $authenticatedUri';
    }
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 80,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.yourCartIsEmpty,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
