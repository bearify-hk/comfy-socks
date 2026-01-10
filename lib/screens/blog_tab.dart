import 'package:flutter/material.dart' hide Page;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

class BlogTab extends StatefulWidget {
  const BlogTab({super.key});

  @override
  BlogTabState createState() => BlogTabState();
}

class BlogTabState extends State<BlogTab> {
  List<Blog> blogs = [];
  List<Page> pages = [];
  bool _isLoading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final b = await ShopifyBlog.instance.getAllBlogs();
      final p = await ShopifyPage.instance.getAllPages();
      if (mounted) {
        setState(() {
          blogs = b ?? [];
          pages = p ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load content. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildPicker(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _fetchData)
                    : _selectedIndex == 0
                        ? _buildBlogList()
                        : _buildPagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Blogs'),
              icon: Icon(Icons.article_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Pages'),
              icon: Icon(Icons.description_outlined),
            ),
          ],
          selected: {_selectedIndex},
          onSelectionChanged: (set) => setState(() => _selectedIndex = set.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  Widget _buildBlogList() {
    if (blogs.isEmpty) return const _EmptyView(title: 'No Blogs found');
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        itemCount: blogs.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final blog = blogs[index];
          final articleCount = blog.articles?.articleList.length ?? 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.rss_feed, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(blog.title ?? 'Untitled Blog'),
            subtitle: Text('$articleCount articles'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => ArticlesPage(blog: blog)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagesList() {
    if (pages.isEmpty) return const _EmptyView(title: 'No Pages found');
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        itemCount: pages.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final page = pages[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(Icons.description, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            title: Text(page.title),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => PageDetailScreen(handle: page.handle)),
            ),
          );
        },
      ),
    );
  }
}

class ArticlesPage extends StatelessWidget {
  final Blog blog;
  const ArticlesPage({super.key, required this.blog});

  @override
  Widget build(BuildContext context) {
    final articles = blog.articles?.articleList ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(blog.title ?? 'Articles')),
      body: articles.isEmpty
          ? const _EmptyView(title: 'No articles in this blog')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => ArticleDetailScreen(article: article)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (article.image != null)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(article.image!.originalSrc, fit: BoxFit.cover),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title ?? '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              if (article.publishedAt != null)
                                Text(
                                  article.publishedAt!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(article.title ?? 'Article'),
          ),
          if (article.image != null)
            SliverToBoxAdapter(
              child: Image.network(article.image!.originalSrc, fit: BoxFit.cover),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: HtmlWidget(
                article.contentHtml ?? article.content ?? '',
                textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class PageDetailScreen extends StatefulWidget {
  final String handle;
  const PageDetailScreen({super.key, required this.handle});

  @override
  State<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends State<PageDetailScreen> {
  Page? page;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ShopifyPage.instance.getPageByHandle(widget.handle).then((p) {
      if (mounted) setState(() { page = p; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar.large(title: Text(page?.title ?? 'Page')),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: HtmlWidget(
                      page?.body ?? '',
                      textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}

// Reusable standard views
class _EmptyView extends StatelessWidget {
  final String title;
  const _EmptyView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}