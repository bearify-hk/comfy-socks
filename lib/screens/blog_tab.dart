import 'package:flutter/material.dart' hide Page;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

// Custom theme colors
class AppColors {
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8C33);
  static const Color primaryDark = Color(0xFFCC5500);
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color cardBorder = Color(0xFFF3F4F6);
}

class BlogTab extends StatefulWidget {
  const BlogTab({super.key});

  @override
  BlogTabState createState() => BlogTabState();
}

class BlogTabState extends State<BlogTab> {
  List<Blog> blogs = [];
  bool _isBlogsLoading = true;
  String? _blogsError;

  List<Page> pages = [];
  bool _isPagesLoading = true;
  String? _pagesError;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllBlogs();
    _fetchAllPages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Content',
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: _selectedIndex == 0 ? _buildBlogList() : _buildPagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBorder,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0 ? AppColors.background : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _selectedIndex == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'Blogs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1 ? AppColors.background : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _selectedIndex == 1
                        ? [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    'Pages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedIndex == 1 ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogList() {
    if (_isBlogsLoading) {
      return const _LoadingIndicator();
    }

    if (_blogsError != null) {
      return _ErrorView(
        message: _blogsError!,
        onRetry: _fetchAllBlogs,
      );
    }

    if (blogs.isEmpty) {
      return const _EmptyView(
        icon: Icons.article_outlined,
        title: 'No Blogs',
        subtitle: 'Check back later',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchAllBlogs,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: blogs.length,
        itemBuilder: (context, index) => _BlogCard(
          blog: blogs[index],
          onTap: () => _navigateToArticles(blogs[index]),
        ),
      ),
    );
  }

  Widget _buildPagesList() {
    if (_isPagesLoading) {
      return const _LoadingIndicator();
    }

    if (_pagesError != null) {
      return _ErrorView(
        message: _pagesError!,
        onRetry: _fetchAllPages,
      );
    }

    if (pages.isEmpty) {
      return const _EmptyView(
        icon: Icons.description_outlined,
        title: 'No Pages',
        subtitle: 'Check back later',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchAllPages,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pages.length,
        itemBuilder: (context, index) => _PageCard(
          page: pages[index],
          onTap: () => _navigateToPage(pages[index]),
        ),
      ),
    );
  }

  void _navigateToArticles(Blog blog) {
    if (blog.articles != null && blog.articles!.articleList.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArticlesPage(
            title: blog.title ?? 'Blog',
            articles: blog.articles!,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No articles available'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _navigateToPage(Page page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageDetailScreen(handle: page.handle),
      ),
    );
  }

  Future<void> _fetchAllPages() async {
    if (!_isPagesLoading) {
      setState(() {
        _isPagesLoading = true;
        _pagesError = null;
      });
    }

    try {
      final shopifyPage = ShopifyPage.instance;
      final p = await shopifyPage.getAllPages();
      if (mounted) {
        setState(() {
          pages = p ?? [];
          _isPagesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pagesError = 'Failed to load pages';
          _isPagesLoading = false;
        });
      }
      debugPrint(e.toString());
    }
  }

  Future<void> _fetchAllBlogs() async {
    if (!_isBlogsLoading) {
      setState(() {
        _isBlogsLoading = true;
        _blogsError = null;
      });
    }

    try {
      final shopifyBlog = ShopifyBlog.instance;
      final b = await shopifyBlog.getAllBlogs();
      if (mounted) {
        setState(() {
          blogs = b ?? [];
          _isBlogsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _blogsError = 'Failed to load blogs';
          _isBlogsLoading = false;
        });
      }
      debugPrint(e.toString());
    }
  }
}

class _BlogCard extends StatelessWidget {
  final Blog blog;
  final VoidCallback onTap;

  const _BlogCard({required this.blog, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final articleCount = blog.articles?.articleList.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blog.title ?? 'Untitled',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$articleCount ${articleCount == 1 ? 'article' : 'articles'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  final Page page;
  final VoidCallback onTap;

  const _PageCard({required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    page.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator.adaptive(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textSecondary.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArticlesPage extends StatelessWidget {
  final Articles articles;
  final String title;

  const ArticlesPage({
    super.key,
    required this.articles,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
        ),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: articles.articleList.isEmpty
          ? const _EmptyView(
              icon: Icons.article_outlined,
              title: 'No Articles',
              subtitle: 'This blog has no articles yet',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: articles.articleList.length,
              itemBuilder: (context, index) {
                final article = articles.articleList[index];
                return _ArticleCard(
                  article: article,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailScreen(article: article),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = article.image != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    article.image!.originalSrc,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.cardBorder,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.textSecondary,
                        size: 32,
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.cardBorder,
                        child: const Center(
                          child: CircularProgressIndicator.adaptive(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title ?? 'Untitled',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (article.author?.name != null) ...[
                          Text(
                            article.author!.name!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (article.publishedAt != null)
                            const Text(
                              ' • ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                        if (article.publishedAt != null)
                          Text(
                            article.publishedAt ?? '',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final hasImage = article.image != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            expandedHeight: hasImage ? 240 : 0,
            pinned: true,
            stretch: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background.withAlpha(90),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      article.image!.originalSrc,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.cardBorder,
                      ),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title ?? 'Untitled',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaInfo(),
                  const SizedBox(height: 24),
                  Container(height: 1, color: AppColors.divider),
                  const SizedBox(height: 24),
                  _buildArticleContent(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo() {
    final hasAuthor = article.author?.name != null;
    final hasDate = article.publishedAt != null;

    if (!hasAuthor && !hasDate) return const SizedBox.shrink();

    return Row(
      children: [
        if (hasAuthor) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                article.author!.name![0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            article.author!.name!,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (hasDate)
            const Text(
              ' • ',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
        ],
        if (hasDate)
          Text(
            article.publishedAt ?? '',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildArticleContent() {
    final content = article.contentHtml ?? article.content ?? '';

    if (content.isEmpty) {
      return const Center(
        child: Text(
          'No content available',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }

    final isHtml = content.contains('<') && content.contains('>');

    if (isHtml) {
      return HtmlWidget(
        content,
        textStyle: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
        customStylesBuilder: (element) => _getHtmlStyles(element.localName),
        onTapUrl: (url) {
          debugPrint('Tapped URL: $url');
          return true;
        },
      );
    }

    return Text(
      content,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.7,
      ),
    );
  }

  Map<String, String>? _getHtmlStyles(String? tagName) {
    const orangeHex = '#FF6B00';
    switch (tagName) {
      case 'p':
        return {'margin': '0 0 16px 0', 'line-height': '1.7'};
      case 'h1':
        return {'margin': '24px 0 16px 0', 'font-size': '26px', 'font-weight': 'bold'};
      case 'h2':
        return {'margin': '20px 0 12px 0', 'font-size': '22px', 'font-weight': 'bold'};
      case 'h3':
        return {'margin': '16px 0 10px 0', 'font-size': '18px', 'font-weight': 'bold'};
      case 'ul':
      case 'ol':
        return {'margin': '0 0 16px 0', 'padding-left': '20px'};
      case 'li':
        return {'margin': '0 0 8px 0', 'line-height': '1.6'};
      case 'blockquote':
        return {
          'margin': '16px 0',
          'padding': '12px 20px',
          'border-left': '3px solid $orangeHex',
          'background-color': '#FFF7ED',
        };
      case 'a':
        return {'color': orangeHex, 'text-decoration': 'none'};
      case 'img':
        return {'margin': '16px 0', 'border-radius': '8px', 'max-width': '100%'};
      default:
        return null;
    }
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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      final shopifyPage = ShopifyPage.instance;
      final p = await shopifyPage.getPageByHandle(widget.handle);
      if (mounted) {
        setState(() {
          page = p;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load page';
          _isLoading = false;
        });
      }
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isLoading ? 'Loading...' : page?.title ?? 'Page',
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _LoadingIndicator();
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _fetchPage();
        },
      );
    }

    // Use body instead of bodySummary for full content
    // bodySummary is truncated, body or bodyHtml contains full content
    final content = page?.body ?? page?.bodySummary ?? '';

    if (content.isEmpty) {
      return const _EmptyView(
        icon: Icons.description_outlined,
        title: 'No Content',
        subtitle: 'This page has no content',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageContent(content),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPageContent(String content) {
    final isHtml = content.contains('<') && content.contains('>');

    if (isHtml) {
      return HtmlWidget(
        content,
        textStyle: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
        customStylesBuilder: (element) => _getHtmlStyles(element.localName),
        onTapUrl: (url) {
          debugPrint('Tapped URL: $url');
          return true;
        },
        // Enable full rendering
        renderMode: RenderMode.column,
      );
    }

    return Text(
      content,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.7,
      ),
    );
  }

  Map<String, String>? _getHtmlStyles(String? tagName) {
    const orangeHex = '#FF6B00';
    switch (tagName) {
      case 'p':
        return {'margin': '0 0 16px 0', 'line-height': '1.7'};
      case 'h1':
        return {'margin': '24px 0 16px 0', 'font-size': '26px', 'font-weight': 'bold'};
      case 'h2':
        return {'margin': '20px 0 12px 0', 'font-size': '22px', 'font-weight': 'bold'};
      case 'h3':
        return {'margin': '16px 0 10px 0', 'font-size': '18px', 'font-weight': 'bold'};
      case 'ul':
      case 'ol':
        return {'margin': '0 0 16px 0', 'padding-left': '20px'};
      case 'li':
        return {'margin': '0 0 8px 0', 'line-height': '1.6'};
      case 'blockquote':
        return {
          'margin': '16px 0',
          'padding': '12px 20px',
          'border-left': '3px solid $orangeHex',
          'background-color': '#FFF7ED',
        };
      case 'a':
        return {'color': orangeHex, 'text-decoration': 'none'};
      case 'img':
        return {'margin': '16px 0', 'border-radius': '8px', 'max-width': '100%'};
      default:
        return null;
    }
  }
}