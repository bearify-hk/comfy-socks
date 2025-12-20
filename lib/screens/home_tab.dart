import 'dart:async';
import 'package:comfy_socks/components/product_card.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'product_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  HomeTabState createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  List<Product> products = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Theme colors

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      _fetchAllProducts();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchForProduct(query);
    });
  }

  Future<void> _searchForProduct(String searchKeyword) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shopifyStore = ShopifyStore.instance;
      final searchResults = await shopifyStore.searchProducts(
        searchKeyword,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          products = searchResults ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    _debounceTimer?.cancel();
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
    });
    _fetchAllProducts();
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _fetchAllProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: _stopSearch,
          icon: const Icon(Icons.arrow_back),
          color: Theme.of(context).primaryColor,
          tooltip: 'Back',
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            if (query.isNotEmpty) {
              _debounceTimer?.cancel();
              _searchForProduct(query);
            }
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Clear',
              color: Colors.grey[600],
            ),
        ],
      );
    }

    return AppBar(
      elevation: 0,
      title: const Text(
        'Comfy Socks',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _fetchAllProducts,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          color: Theme.of(context).primaryColor,
        ),
        IconButton(
          onPressed: _startSearch,
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          color: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'Searching...' : 'Loading products...',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (products.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildSearchEmptyState();
      }
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _searchQuery.isNotEmpty 
          ? () => _searchForProduct(_searchQuery)
          : _fetchAllProducts,
      color: Theme.of(context).primaryColor,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(
                _buildProductCountText(products.length),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => ProductCard(
                  product: products[index],
                  onTap: () => _navigateToProductDetailScreen(products[index]),
                ),
                childCount: products.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  String _buildProductCountText(int count) {
    if (_searchQuery.isNotEmpty) {
      return '$count ${count == 1 ? 'Result' : 'Results'} for "$_searchQuery"';
    }
    // return '$count Products';
    return 'Featured Products';
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No products match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear Search'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: const BorderSide(color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _searchQuery.isNotEmpty 
                  ? () => _searchForProduct(_searchQuery)
                  : _fetchAllProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Products Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new arrivals',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchAllProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: const BorderSide(color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAllProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final shopifyStore = ShopifyStore.instance;
      final bestSellingProducts = await shopifyStore.getNProducts(20);

      if (mounted) {
        setState(() {
          products = bestSellingProducts ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load products. Please check your connection.';
        });
      }
    }
  }

  void _navigateToProductDetailScreen(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }
}