// customer_account_auth_tab.dart
import 'dart:developer';
import 'package:comfy_socks/l10n/app_localizations.dart';
import 'package:comfy_socks/services/locale_notifier.dart';
import 'package:flutter/material.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
import 'package:comfy_socks/services/auth_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerAccountAuthTab extends StatefulWidget {
  const CustomerAccountAuthTab({super.key});

  @override
  State<CustomerAccountAuthTab> createState() => _CustomerAccountAuthTabState();
}

class _CustomerAccountAuthTabState extends State<CustomerAccountAuthTab> {
  final ShopifyCustomerAccountAuth _auth = ShopifyCustomerAccountAuth.instance;

  Map<String, dynamic>? _customer;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _error;

  // Language options
  static const List<({String code, String label})> _languages = [
    (code: 'en', label: 'EN'),
    (code: 'zh_Hans', label: '简体'),
    (code: 'zh_Hant', label: '繁體'),
  ];

  @override
  void initState() {
    super.initState();
    AuthNotifier.instance.addListener(_onAuthStateChanged);
    _initializeAuth();
  }

  @override
  void dispose() {
    AuthNotifier.instance.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  /// Initialize authentication state on first load
  Future<void> _initializeAuth() async {
    setState(() => _isInitialLoading = true);

    try {
      // Check if we have a valid session
      if (_auth.isAuthenticated) {
        await _loadCustomer();
      } else if (_auth.refreshToken != null) {
        // Try to refresh the token if we have a refresh token
        try {
          await _auth.refreshAccessToken();
          await _loadCustomer();
        } catch (e) {
          log('Token refresh failed during init: $e');
          // Session expired, user needs to login again
          await _auth.logout();
        }
      }
    } catch (e) {
      log('Auth initialization error: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  void _onAuthStateChanged() {
    if (mounted) {
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    if (_auth.isAuthenticated) {
      if (_customer == null) {
        await _loadCustomer();
      } else {
        // Just refresh the UI
        setState(() {});
      }
    } else {
      if (mounted) {
        setState(() {
          _customer = null;
          _error = null;
        });
      }
    }
  }

  Future<void> _loadCustomer() async {
    if (!_auth.isAuthenticated) {
      setState(() => _customer = null);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _auth.getCurrentCustomer();

      if (result['errors'] != null) {
        final errors = result['errors'] as List;
        throw Exception(errors.first['message'] ?? 'Unknown error');
      }

      if (mounted) {
        setState(() {
          _customer = result['data']?['customer'];
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Failed to load customer: $e');

      // Check if it's an auth error
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('expired') ||
          errorMessage.contains('unauthorized') ||
          errorMessage.contains('not authenticated')) {
        // Session is invalid, log out
        await _handleSessionExpired();
      } else {
        if (mounted) {
          setState(() {
            _error = AppLocalizations.of(context)!.failedToLoadProfile;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await _auth.silentLogout();
    if (mounted) {
      setState(() {
        _customer = null;
        _isLoading = false;
        _error = null;
      });
      _showSnackbar(AppLocalizations.of(context)!.sessionExpiredMessage);
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.launchAuthorization();
      // Note: The actual login completion happens via deep link callback
      // which triggers AuthNotifier.notifyAuthStateChanged()
    } catch (e) {
      setState(() => _error = AppLocalizations.of(context)!.failedToStartLogin);
      _showSnackbar(AppLocalizations.of(context)!.failedToStartLoginError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.signOut),
        content: Text(AppLocalizations.of(context)!.confirmSignOut),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.signOut),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthNotifier.instance.logout();
      if (mounted) {
        setState(() {
          _customer = null;
        });
        _showSnackbar(AppLocalizations.of(context)!.signedOutSuccessfully);
      }
    } catch (e) {
      log('Logout error: $e');
      // Even if server logout fails, clear local session
      await AuthNotifier.instance.silentLogout();
      if (mounted) {
        setState(() {
          _customer = null;
        });
        _showSnackbar(AppLocalizations.of(context)!.signedOut);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openProfileUrl() async {
    final uri = Uri.parse('https://account.comfy-socks.com/profile');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackbar(AppLocalizations.of(context)!.couldNotOpenBrowser);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _onLanguageChanged(String languageCode) {
    Locale newLocale;
    if (languageCode == 'zh_Hans') {
      newLocale = const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      );
    } else if (languageCode == 'zh_Hant') {
      newLocale = const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      );
    } else {
      newLocale = const Locale('en');
    }

    // Use LocaleNotifier to change the locale
    LocaleNotifier.instance.setLocale(newLocale);
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'zh_Hans':
        return '简体中文';
      case 'zh_Hant':
        return '繁體中文';
      default:
        return code;
    }
  }

  String _getCurrentLanguageCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'Hans') {
        return 'zh_Hans';
      } else if (locale.scriptCode == 'Hant') {
        return 'zh_Hant';
      }
      // Default to Hans for Chinese without script
      return 'zh_Hans';
    }
    return locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading indicator during initial auth check
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.account),
          centerTitle: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.loadingYourAccount),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.account),
        centerTitle: false,
        actions: [
          if (_customer != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadCustomer,
              tooltip: AppLocalizations.of(context)!.refresh,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_auth.isAuthenticated) {
            await _loadCustomer();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error card
              if (_error != null) ...[
                Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: colorScheme.onErrorContainer,
                          ),
                          onPressed: () => setState(() => _error = null),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Loading overlay for customer data
              if (_isLoading && _customer != null)
                const LinearProgressIndicator(),

              // Main content
              if (_customer == null)
                _buildGuestView(context)
              else
                _buildCustomerView(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentLanguage = _getCurrentLanguageCode(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.language, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.language,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          expandedInsets: EdgeInsets.zero,
          segments: _languages
              .map(
                (lang) => ButtonSegment<String>(
                  value: lang.code,
                  label: Text(lang.label),
                ),
              )
              .toList(),
          selected: {currentLanguage},
          onSelectionChanged: (Set<String> selection) {
            if (selection.isNotEmpty) {
              _onLanguageChanged(selection.first);
            }
          },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: colorScheme.primaryContainer,
            selectedForegroundColor: colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildGuestView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.account_circle_outlined,
          size: 100,
          color: colorScheme.secondary,
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.signInToYourAccount,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context)!.trackOrdersManageYourProfile,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _isLoading ? null : _login,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(
            _isLoading
                ? AppLocalizations.of(context)!.opening
                : AppLocalizations.of(context)!.signInWithEmail,
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.weWillSendOtp,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Language toggle section
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildLanguageToggle(context),
          ),
        ),

        // Benefits section
        /*
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why sign in?',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBenefitRow(
                  Icons.local_shipping_outlined,
                  'Track your orders in real-time',
                ),
                _buildBenefitRow(
                  Icons.speed_outlined,
                  'Faster checkout with saved info',
                ),
                _buildBenefitRow(
                  Icons.history_outlined,
                  'View your order history',
                ),
                _buildBenefitRow(
                  Icons.favorite_outline,
                  'Save items for later',
                ),
              ],
            ),
          ),
        ),
        */
      ],
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final firstName = _customer?['firstName'] ?? '';
    final lastName = _customer?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email =
        _customer?['emailAddress']?['emailAddress'] ??
        _auth.customerEmail ??
        '';

    // Get initials
    String initials = 'U';
    if (firstName.isNotEmpty) {
      initials = firstName[0];
      if (lastName.isNotEmpty) {
        initials += lastName[0];
      }
    } else if (email.isNotEmpty) {
      initials = email[0].toUpperCase();
    }

    return Column(
      children: [
        // Profile header
        CircleAvatar(
          radius: 40,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            initials.toUpperCase(),
            style: textTheme.headlineMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          fullName.isNotEmpty ? fullName : 'Welcome!',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (email.isNotEmpty)
          Text(
            email,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

        // Session status indicator
        if (_auth.tokenExpiresAt != null) ...[
          const SizedBox(height: 8),
          _buildSessionIndicator(context),
        ],

        const SizedBox(height: 32),

        // Customer details card
        Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildNativeListTile(
                icon: Icons.email_outlined,
                title: AppLocalizations.of(context)!.email,
                subtitle: email.isNotEmpty
                    ? email
                    : AppLocalizations.of(context)!.notSet,
                onTap: _openProfileUrl,
              ),
              const Divider(height: 1, indent: 56),
              _buildNativeListTile(
                icon: Icons.phone_outlined,
                title: AppLocalizations.of(context)!.phone,
                subtitle:
                    _customer?['defaultAddress']?['phoneNumber'] ??
                    AppLocalizations.of(context)!.notSet,
                onTap: _openProfileUrl,
              ),
              const Divider(height: 1, indent: 56),
              _buildNativeListTile(
                icon: Icons.location_on_outlined,
                title: AppLocalizations.of(context)!.address,
                subtitle: _formatAddress(_customer?['defaultAddress']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Language toggle section
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildLanguageToggle(context),
          ),
        ),
        const SizedBox(height: 16),

        // Actions card
        /*
        Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Order History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _viewOrders(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Manage Addresses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSnackbar('Address management coming soon'),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Account Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSnackbar('Account settings coming soon'),
              ),
            ],
          ),
        ),
        */
        const SizedBox(height: 24),

        // Sign out button
        TextButton.icon(
          onPressed: _isLoading ? null : _logout,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: Text(AppLocalizations.of(context)!.signOut),
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSessionIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expiresAt = _auth.tokenExpiresAt;

    if (expiresAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final remaining = expiresAt.difference(now);

    // Determine session status
    Color indicatorColor;
    String statusText;

    if (remaining.isNegative) {
      indicatorColor = colorScheme.error;
      statusText = AppLocalizations.of(context)!.sessionExpired;
    } else if (remaining.inMinutes < 5) {
      indicatorColor = colorScheme.error;
      statusText = AppLocalizations.of(context)!.sessionExpiringSoon;
    } else if (remaining.inMinutes < 30) {
      indicatorColor = Colors.orange;
      statusText = AppLocalizations.of(context)!.sessionActive;
    } else {
      indicatorColor = Colors.green;
      statusText = AppLocalizations.of(context)!.sessionActive;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return AppLocalizations.of(context)!.notSet;

    final formatted = address['formatted'];
    if (formatted == null) return AppLocalizations.of(context)!.notSet;

    if (formatted is List) {
      return formatted.join(', ');
    }

    return formatted.toString();
  }

  Widget _buildNativeListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
      dense: false,
    );
  }

  Future<void> _viewOrders(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final result = await _auth.getOrders(first: 20);

      if (!mounted) return;

      // Dismiss loading dialog
      Navigator.of(context).pop();

      if (result['errors'] != null) {
        final errors = result['errors'] as List;
        throw Exception(errors.first['message'] ?? 'Failed to load orders');
      }

      final orders =
          result['data']?['customer']?['orders']?['edges'] as List? ?? [];

      // Show orders bottom sheet
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.yourOrders,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.ordersCount(orders.length),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? _buildEmptyOrdersView(context)
                    : _buildOrdersList(context, orders, scrollController),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      log('Failed to load orders: $e');

      // Check for session expiry
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('expired') ||
          errorMessage.contains('unauthorized')) {
        await _handleSessionExpired();
      } else {
        _showSnackbar(AppLocalizations.of(context)!.failedToLoadOrders);
      }
    }
  }

  Widget _buildEmptyOrdersView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noOrdersYet, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noOrdersDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.startShopping),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List orders,
    ScrollController scrollController,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index]['node'];
        final price = order['totalPrice'];
        final financialStatus = order['financialStatus'] ?? 'Unknown';
        final processedAt = order['processedAt'];

        // Parse date
        String formattedDate = '';
        if (processedAt != null) {
          try {
            final date = DateTime.parse(processedAt);
            formattedDate = '${date.day}/${date.month}/${date.year}';
          } catch (_) {
            formattedDate = processedAt.toString();
          }
        }

        // Get fulfillment status
        final fulfillments = (order['fulfillments']?['edges'] as List?) ?? [];
        final status = fulfillments.isNotEmpty
            ? (fulfillments.first as Map?)?['node']?['status']
            : null;
        final fulfillmentStatus = status?.toString() ?? 'Processing';

        // Status color
        Color statusColor;
        switch (financialStatus.toString().toUpperCase()) {
          case 'PAID':
            statusColor = Colors.green;
            break;
          case 'PENDING':
            statusColor = Colors.orange;
            break;
          case 'REFUNDED':
          case 'PARTIALLY_REFUNDED':
            statusColor = Colors.blue;
            break;
          default:
            statusColor = colorScheme.onSurfaceVariant;
        }

        return Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _showSnackbar(AppLocalizations.of(context)!.orderDetailsComing);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.orderNumber(order['number'].toString()),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${price['amount']} ${price['currencyCode']}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatStatus(financialStatus),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatStatus(fulfillmentStatus),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatStatus(String status) {
    // Convert SCREAMING_SNAKE_CASE to Title Case
    return status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }
}
