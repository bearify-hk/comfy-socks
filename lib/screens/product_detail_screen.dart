import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

import '../extension.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;

  @override
  ProductDetailScreenState createState() => ProductDetailScreenState();
}

class ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product product;
  final ShopifyStore shopifyStore = ShopifyStore.instance;
  final ShopifyCart shopifyCart = ShopifyCart.instance;

  Cart? cart;
  bool isLoading = false;

  // Map to track quantity for each variant
  Map<String, int> variantQuantities = {};

  // PageController for image carousel
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    product = widget.product;
    _initializeQuantities();
    _initCart();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initializeQuantities() {
    for (var variant in product.productVariants) {
      variantQuantities[variant.id] = 1;
    }
  }

  Future<void> _initCart() async {
    setState(() => isLoading = true);
    try {
      String? accessToken =
          await ShopifyAuth.instance.currentCustomerAccessToken;
      String? email = await ShopifyAuth.instance.currentUser().then((user) => user?.email);
      if (accessToken == null || email == null) {
        log('User not logged in. Cannot create cart.');
        return;
      }
      
      final CartInput cartInput = CartInput(
        buyerIdentity: CartBuyerIdentityInput(
          customerAccessToken: accessToken,
          email: email,
        ),
      );
      cart = await shopifyCart.createCart(cartInput);
      log('Cart created: ${cart?.id}');
    } catch (error) {
      log('Error creating cart: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchProductDetails() async {
    setState(() => isLoading = true);
    try {
      final productDetails = await shopifyStore.getProductsByIds([product.id]);
      for (final Product productDetails in (productDetails ?? [])) {
        final variants = productDetails.productVariants;
        for (var variant in variants) {
          log(
            'Variant SellingPlanAllocation: ${variant.sellingPlanAllocations}',
          );
        }
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _incrementQuantity(String variantId) {
    setState(() {
      variantQuantities[variantId] = (variantQuantities[variantId] ?? 1) + 1;
    });
  }

  void _decrementQuantity(String variantId) {
    setState(() {
      final currentQty = variantQuantities[variantId] ?? 1;
      if (currentQty > 1) {
        variantQuantities[variantId] = currentQty - 1;
      }
    });
  }

  Future<void> _addToCart(ProductVariant variant) async {
    if (cart == null) {
      context.showSnackBar('Cart not initialized. Please wait...');
      await _initCart();
      if (cart == null) {
        context.showSnackBar('Failed to create cart');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final quantity = variantQuantities[variant.id] ?? 1;
      final cartLineInput = CartLineUpdateInput(
        quantity: quantity,
        merchandiseId: variant.id,
        attributes: [
          AttributeInput(key: 'variant_title', value: variant.title),
        ],
      );

      final updatedCart = await shopifyCart.addLineItemsToCart(
        cartId: cart!.id,
        cartLineInputs: [cartLineInput],
      );

      setState(() {
        cart = updatedCart;
      });

      log('Added to cart: ${variant.title} x $quantity');
      log('Cart now has ${updatedCart.lines.length} items');

      if (!mounted) return;
      context.showSnackBar('Added ${variant.title} x $quantity to cart');
    } catch (error) {
      log('Error adding to cart: $error');
      if (!mounted) return;
      context.showSnackBar('Error adding to cart: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showCartBottomSheet() {
    if (cart == null || cart!.lines.isEmpty) {
      context.showSnackBar('Cart is empty');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CartBottomSheet(
        cart: cart!,
        onCartUpdated: (updatedCart) {
          setState(() {
            cart = updatedCart;
          });
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        actions: [
          IconButton(
            onPressed: fetchProductDetails,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showCartBottomSheet,
            icon: Badge.count(
              count: cart?.lines.length ?? 0,
              child: const Icon(Icons.shopping_cart),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            children: <Widget>[
              // Image Carousel
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
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Variants',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ..._buildProductVariants(),
              const SizedBox(height: 80),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
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
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          variant.price.formattedPriceWithLocale('en_US'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (!isAvailable)
                          Text(
                            'Out of stock',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Quantity selector
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: quantity > 1
                              ? () => _decrementQuantity(variant.id)
                              : null,
                          icon: const Icon(Icons.remove),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 40),
                          alignment: Alignment.center,
                          child: Text(
                            '$quantity',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _incrementQuantity(variant.id),
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add to cart button
                  ElevatedButton.icon(
                    onPressed: isAvailable && !isLoading
                        ? () => _addToCart(variant)
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
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

class CartBottomSheet extends StatefulWidget {
  final Cart cart;
  final Function(Cart) onCartUpdated;

  const CartBottomSheet({
    super.key,
    required this.cart,
    required this.onCartUpdated,
  });

  @override
  State<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<CartBottomSheet> {
  final ShopifyCart shopifyCart = ShopifyCart.instance;
  late Cart cart;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    cart = widget.cart;
  }

  Future<void> _updateLineItem(Line line, {bool increment = true}) async {
    setState(() => isLoading = true);

    try {
      int quantity = line.quantity ?? 0;
      if (!increment && quantity <= 1) {
        // Remove item if quantity would be 0
        await _removeLineItem(line);
        return;
      }

      quantity = increment ? quantity + 1 : quantity - 1;

      final cartLineInput = CartLineUpdateInput(
        id: line.id,
        quantity: quantity,
        merchandiseId: line.variantId ?? '',
      );

      final updatedCart = await shopifyCart.updateLineItemsInCart(
        cartId: cart.id,
        cartLineInputs: [cartLineInput],
      );

      setState(() {
        cart = updatedCart;
      });
      widget.onCartUpdated(updatedCart);

      if (!mounted) return;
      context.showSnackBar('Updated cart');
    } catch (error) {
      log('Error updating cart: $error');
      if (!mounted) return;
      context.showSnackBar('Error updating cart');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeLineItem(Line line) async {
    setState(() => isLoading = true);

    try {
      final updatedCart = await shopifyCart.removeLineItemsFromCart(
        cartId: cart.id,
        lineIds: [line.id!],
      );

      setState(() {
        cart = updatedCart;
      });
      widget.onCartUpdated(updatedCart);

      if (!mounted) return;

      if (updatedCart.lines.isEmpty) {
        Navigator.pop(context);
      }

      context.showSnackBar('Removed item from cart');
    } catch (error) {
      log('Error removing item: $error');
      if (!mounted) return;
      context.showSnackBar('Error removing item');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart (${cart.lines.length} items)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          if (isLoading)
            const LinearProgressIndicator()
          else
            const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: cart.lines.length,
              itemBuilder: (context, index) {
                final line = cart.lines[index];
                final merchandise = line.merchandise;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchandise?.product?.title ??
                                    merchandise?.title ??
                                    'Unknown Product',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (merchandise?.title != null &&
                                  merchandise?.title != 'Default')
                                Text(
                                  merchandise!.title,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '${merchandise?.price.amount ?? 0} ${merchandise?.price.currencyCode ?? ''}',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => _updateLineItem(
                                          line,
                                          increment: false,
                                        ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  iconSize: 24,
                                ),
                                Text(
                                  '${line.quantity}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                IconButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => _updateLineItem(line),
                                  icon: const Icon(Icons.add_circle_outline),
                                  iconSize: 24,
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _removeLineItem(line),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          if (cart.cost != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total:', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${cart.cost!.totalAmount.amount} ${cart.cost!.totalAmount.currencyCode}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cart.checkoutUrl != null
                  ? () {
                      // Navigate to checkout
                      log('Checkout URL: ${cart.checkoutUrl}');
                      // You can navigate to WebViewCheckout here
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Proceed to Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}