import 'package:comfy_socks/screens/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:comfy_socks/components/product_card.dart';

// Theme colors
const Color primaryOrange = Color(0xFFFF6B00);
const Color lightOrange = Color(0xFFFFF3E0);
const Color backgroundColor = Color(0xFFFAFAFA);

class CollectionTab extends StatefulWidget {
  const CollectionTab({super.key});

  @override
  CollectionTabState createState() => CollectionTabState();
}

class CollectionTabState extends State<CollectionTab> {
  List<Collection> collections = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Collections',
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryOrange,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (collections.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: primaryOrange,
      onRefresh: _fetchCollections,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, int index) => _buildCollectionCard(collections[index]),
      ),
    );
  }

  Widget _buildCollectionCard(Collection collection) {
    final hasImage = collection.image?.originalSrc != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _navigateToCollectionDetailScreen(collection.id, collection.title),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Collection Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: lightOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.network(
                        collection.image!.originalSrc,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildCollectionIcon(),
                      )
                    : _buildCollectionIcon(),
              ),
              const SizedBox(width: 16),
              // Collection Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (collection.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        collection.description ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionIcon() {
    return Center(
      child: Icon(
        Icons.grid_view_rounded,
        color: primaryOrange.withAlpha(150),
        size: 28,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No collections found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _fetchCollections,
              style: TextButton.styleFrom(foregroundColor: primaryOrange),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchCollections() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final shopifyStore = ShopifyStore.instance;
      final fetchedCollections = await shopifyStore.getAllCollections();
      if (mounted) {
        setState(() {
          collections = fetchedCollections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCollectionDetailScreen(
    String collectionId,
    String collectionTitle,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(
          collectionId: collectionId,
          collectionTitle: collectionTitle,
        ),
      ),
    );
  }
}

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
  });

  final String collectionId;
  final String collectionTitle;

  @override
  CollectionDetailScreenState createState() => CollectionDetailScreenState();
}

class CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<Product> products = [];
  bool _isLoading = true;
  Collection? collection;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchProductsByCollectionId(),
      _fetchCollectionDetail(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          collection?.title ?? widget.collectionTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryOrange,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: primaryOrange,
      onRefresh: _refreshProducts,
      child: CustomScrollView(
        slivers: [
          // Collection Description
          if (collection?.description != null &&
              (collection!.description?.isNotEmpty ?? false))
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: lightOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  collection!.description ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ),
            ),
          // Product Count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${products.length} ${products.length == 1 ? 'product' : 'products'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Product Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
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
          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No products in this collection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new arrivals',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load products',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _fetchData();
  }

  Future<void> _fetchProductsByCollectionId() async {
    try {
      final shopifyStore = ShopifyStore.instance;
      final fetchedProducts = await shopifyStore
          .getXProductsAfterCursorWithinCollection(
            widget.collectionId,
            20,
            startCursor: null,
            sortKey: SortKeyProductCollection.RELEVANCE,
          );
      if (mounted) {
        setState(() {
          products = fetchedProducts ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCollectionDetail() async {
    try {
      final shopifyStore = ShopifyStore.instance;
      final collectionInfo = await shopifyStore.getCollectionById(
        widget.collectionId,
      );
      if (mounted) {
        setState(() {
          collection = collectionInfo;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
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
