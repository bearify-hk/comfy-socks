// product_card.dart
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // We calculate height based on the available space
            // Giving the image 65% of the card and text 35%
            double imageHeight = constraints.maxHeight * 0.65;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed Image Area
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: product.images.isNotEmpty
                      ? Image.network(
                          product.images.first.originalSrc,
                          fit: BoxFit.cover,
                        )
                      : _buildPlaceholder(context),
                ),

                // Flexible Text Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          product.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    13, // Slightly smaller for grid safety
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getProductPrice() ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.upcoming_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String? _getProductPrice() {
    if (product.productVariants.isEmpty) return null;
    final price = product.productVariants.first.price.amount;
    return '\$${price.toStringAsFixed(2)}';
  }
}
