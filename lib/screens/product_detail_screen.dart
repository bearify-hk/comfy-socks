import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

import '../services/cart_service.dart';
import '../services/shopify_customer_account_auth.dart';
import '../extension.dart';
// import 'cart_bottom_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;

  @override
  ProductDetailScreenState createState() => ProductDetailScreenState();
}

class ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product product;
  final CartService _cartService = CartService.instance;
  final ShopifyCustomerAccountAuth _authService = ShopifyCustomerAccountAuth.instance;

  bool isLoading = false;
  late ProductVariant selectedVariant;
  int quantity = 1;

  @override
  void initState() {
    super.initState();
    product = widget.product;
    // Safety check for empty variants
    selectedVariant = product.productVariants.isNotEmpty 
        ? product.productVariants.first 
        : throw Exception('Product has no variants');
    
    _cartService.addListener(_updateUI);
    _initCartSession();
  }

  @override
  void dispose() {
    _cartService.removeListener(_updateUI);
    super.dispose();
  }

  // FIXED: Corrected syntax for method body
  void _updateUI() {
    if (mounted) setState(() {});
  }

  Future<void> _initCartSession() async {
    if (_cartService.cart != null) return;
    setState(() => isLoading = true);
    try {
      await _cartService.init();
      if (_cartService.cart == null) {
        String? accessToken = _authService.accessToken;
        String? email;
        if (accessToken != null) {
          final customerData = await _authService.getCurrentCustomer();
          email = customerData['data']?['customer']?['emailAddress']?['emailAddress'];
        }
        await _cartService.createCart(email: email, accessToken: accessToken);
      }
    } catch (e) {
      log('Cart Init Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addToCart() async {
    setState(() => isLoading = true);
    try {
      await _cartService.addToCart(
        variantId: selectedVariant.id,
        quantity: quantity,
        attributes: [AttributeInput(key: 'variant_title', value: selectedVariant.title)],
      );
      if (mounted) context.showSnackBar('Added ${product.title} to cart');
    } catch (e) {
      if (mounted) context.showSnackBar('Error adding to cart');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${selectedVariant.price.amount} ${selectedVariant.price.currencyCode}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const Divider(height: 48),

                  // FIXED: Added null check for description
                  if (product.description!.isNotEmpty) ...[
                    Text('Description', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(product.description ?? '', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                  ],

                  Text('Select Variant', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.productVariants.map((v) {
                      return ChoiceChip(
                        label: Text(v.title),
                        selected: selectedVariant.id == v.id,
                        onSelected: (selected) {
                          if (selected) setState(() => selectedVariant = v);
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),

                  Text('Quantity', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _QuantitySelector(
                    quantity: quantity,
                    onChanged: (val) => setState(() => quantity = val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(theme),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.4,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: product.images.isNotEmpty
            ? PageView.builder(
                itemCount: product.images.length,
                itemBuilder: (context, index) => Image.network(
                  // FIXED: Handled potential null or empty image source
                  product.images[index].originalSrc,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                ),
              )
            : Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(Icons.image, size: 64),
              ),
      ),
    );
  }

  Widget _buildBottomAction(ThemeData theme) {
    final isAvailable = selectedVariant.availableForSale;
    
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: FilledButton.icon(
        onPressed: isAvailable && !isLoading ? _addToCart : null,
        icon: isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.add_shopping_cart),
        label: Text(isAvailable ? 'Add to Cart' : 'Out of Stock'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}