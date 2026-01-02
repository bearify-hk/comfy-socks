// product_detail_screen.dart

import 'dart:developer';
import 'package:comfy_socks/screens/cart_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

import '../services/cart_service.dart';
import '../services/shopify_customer_account_auth.dart';
import '../extension.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;

  @override
  ProductDetailScreenState createState() => ProductDetailScreenState();
}

class ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product product;
  final CartService _cartService = CartService.instance;
  final ShopifyCustomerAccountAuth _authService =
      ShopifyCustomerAccountAuth.instance;

  bool isLoading = false;
  Map<String, int> variantQuantities = {};
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    product = widget.product;
    _initializeQuantities();

    // Listen to the central service for changes (item count, cart creation, etc.)
    _cartService.addListener(_updateUI);

    // Initialize/Restore the cart session on load
    _initCartSession();
  }

  @override
  void dispose() {
    _cartService.removeListener(_updateUI);
    _pageController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _initializeQuantities() {
    for (var variant in product.productVariants) {
      variantQuantities[variant.id] = 1;
    }
  }

  Future<void> _initCartSession() async {
    if (_cartService.cart != null) return;

    setState(() => isLoading = true);
    try {
      // Restore existing cart from SharedPreferences or fetch from Shopify
      await _cartService.init();

      // If still null after init, create a new one with current auth identity
      if (_cartService.cart == null) {
        String? accessToken = _authService.accessToken;
        String? email;

        if (accessToken != null) {
          final customerData = await _authService.getCurrentCustomer();
          email =
              customerData['data']['customer']['emailAddress']['emailAddress'];
        }

        await _cartService.createCart(email: email, accessToken: accessToken);
      }
    } catch (error) {
      log('Error initializing cart session: $error');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addToCart(ProductVariant variant) async {
    setState(() => isLoading = true);

    try {
      final quantity = variantQuantities[variant.id] ?? 1;

      // The service handles logic for "create if null" internally
      await _cartService.addToCart(
        variantId: variant.id,
        quantity: quantity,
        attributes: [
          AttributeInput(key: 'variant_title', value: variant.title),
        ],
      );

      if (!mounted) return;
      context.showSnackBar('Added ${product.title} to cart');
    } catch (error) {
      log('Error adding to cart: $error');
      if (mounted) context.showSnackBar('Could not add to cart');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showCartBottomSheet() {
    if (_cartService.cart == null) {
      context.showSnackBar('Cart is initializing...');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CartBottomSheet(),
    );
  }

  // UI Helper methods (same as before but using _cartService.itemCount)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        actions: [
          IconButton(
            onPressed: _showCartBottomSheet,
            icon: Badge.count(
              count: _cartService.itemCount,
              child: const Icon(Icons.shopping_cart),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            children: <Widget>[
              _buildImageCarousel(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Variants',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ..._buildProductVariants(),
              const SizedBox(height: 100),
            ],
          ),
          if (isLoading)
            const ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final images = product.images;
    final imageHeight = MediaQuery.of(context).size.height / 3;

    if (images.isEmpty) {
      return Container(
        height: imageHeight,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          size: 64,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      children: [
        // Image PageView
        SizedBox(
          height: imageHeight,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openImageViewer(index),
                    child: Image.network(
                      images[index].originalSrc,
                      width: MediaQuery.of(context).size.width,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              // Navigation arrows (only show if more than 1 image)
              if (images.length > 1) ...[
                // Left arrow
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavigationButton(
                      icon: Icons.chevron_left,
                      onPressed: _currentImageIndex > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                // Right arrow
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavigationButton(
                      icon: Icons.chevron_right,
                      onPressed: _currentImageIndex < images.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                // Image counter badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Dot indicators (only show if more than 1 image)
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => _buildDotIndicator(index),
              ),
            ),
          ),
        // Thumbnail strip (only show if more than 1 image)
        if (images.length > 1)
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentImageIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        images[index].originalSrc,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              size: 24,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDotIndicator(int index) {
    final isSelected = index == _currentImageIndex;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isSelected ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.white38,
            size: 24,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildProductVariants() {
    return product.productVariants.map((variant) {
      final quantity = variantQuantities[variant.id] ?? 1;
      final isAvailable = variant.availableForSale;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              ListTile(
                title: Text(variant.title),
                subtitle: Text(variant.price.amount.toString()),
                trailing: !isAvailable
                    ? const Text(
                        'Out of stock',
                        style: TextStyle(color: Colors.red),
                      )
                    : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _decrementQuantity(variant.id),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$quantity'),
                      IconButton(
                        onPressed: () => _incrementQuantity(variant.id),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: isAvailable && !isLoading
                        ? () => _addToCart(variant)
                        : null,
                    child: const Text('Add to Cart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _openImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          images: product.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _incrementQuantity(String id) =>
      setState(() => variantQuantities[id] = (variantQuantities[id] ?? 1) + 1);
  void _decrementQuantity(String id) => setState(() {
    if ((variantQuantities[id] ?? 1) > 1)
      variantQuantities[id] = variantQuantities[id]! - 1;
  });

}

// Full-screen image viewer
class ImageViewerScreen extends StatefulWidget {
  final List<ShopifyImage> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index].originalSrc,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
