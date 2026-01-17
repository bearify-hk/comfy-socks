import 'package:comfy_socks/l10n/app_localizations.dart';
import 'package:comfy_socks/screens/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:comfy_socks/components/product_card.dart';

class CollectionTab extends StatefulWidget {
  const CollectionTab({super.key});

  @override
  CollectionTabState createState() => CollectionTabState();
}

class CollectionTabState extends State<CollectionTab> {
  List<Collection> collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    try {
      final fetched = await ShopifyStore.instance.getAllCollections();
      if (mounted) setState(() => collections = fetched);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Material 3 uses large titles and specific elevation behavior
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.collections), centerTitle: false),
      body: CustomScrollView(
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (collections.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text("No collections found")),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _CollectionListTile(collection: collections[index]),
                  childCount: collections.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionListTile extends StatelessWidget {
  final Collection collection;
  const _CollectionListTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    // Using ListTile provides native touch ripples, padding, and alignment
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: collection.image?.originalSrc != null
            ? Image.network(
                collection.image!.originalSrc,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              )
            : Container(
                width: 56,
                height: 56,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Icon(Icons.grid_view_rounded),
              ),
      ),
      title: Text(collection.title),
      subtitle: collection.description != null
          ? Text(
              collection.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionDetailScreen(
            collectionId: collection.id,
            collectionTitle: collection.title,
          ),
        ),
      ),
    );
  }
}

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;
  final String collectionTitle;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.collections), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: () async {}, // Logic to trigger state reload if needed
        child: CustomScrollView(
          slivers: [
            // Product Grid
            FutureBuilder<List<Product>?>(
              future: ShopifyStore.instance
                  .getXProductsAfterCursorWithinCollection(collectionId, 20),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text("No products found")),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(
                        product: products[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailScreen(product: products[index]),
                          ),
                        ),
                      ),
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
