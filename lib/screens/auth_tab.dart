// customer_account_auth_tab.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
import 'package:comfy_socks/services/auth_notifier.dart';

class CustomerAccountAuthTab extends StatefulWidget {
  const CustomerAccountAuthTab({super.key});

  @override
  State<CustomerAccountAuthTab> createState() => _CustomerAccountAuthTabState();
}

class _CustomerAccountAuthTabState extends State<CustomerAccountAuthTab> {
  final ShopifyCustomerAccountAuth _auth = ShopifyCustomerAccountAuth.instance;

  Map<String, dynamic>? _customer;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthNotifier.instance.addListener(_onAuthStateChanged);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    AuthNotifier.instance.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    if (_auth.accessToken != null && !_auth.isTokenExpired) {
      await _loadCustomer();
    } else {
      if (mounted) {
        setState(() => _customer = null);
      }
    }
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);

    try {
      final result = await _auth.getCurrentCustomer();

      if (result['errors'] != null) {
        throw Exception(result['errors'].toString());
      }

      if (mounted) {
        setState(() {
          _customer = result['data']['customer'];
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Failed to load customer: $e');
      if (mounted) {
        setState(() {
          _customer = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.launchAuthorization();
    } catch (e) {
      setState(() => _error = e.toString());
      _showSnackbar('Failed to start login: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.logout();
      if (mounted) {
        setState(() => _customer = null);
        AuthNotifier.instance.notifyAuthStateChanged();
        _showSnackbar('Logged out successfully');
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _showSnackbar('Logout failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // M3: Use the color scheme for dynamic styling
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: _checkAuthStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
          'Sign in to your account',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Track orders, manage your profile, and speed up checkout.',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // M3: FilledButton for primary actions
        FilledButton.icon(
          onPressed: _login,
          icon: const Icon(Icons.login),
          label: const Text('Sign In with Email'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 16),
        Text(
          'We will send a secure one-time code to your email.',
          style: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCustomerView(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final firstName = _customer!['firstName'] ?? '';
    final lastName = _customer!['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final initials = fullName.isNotEmpty ? firstName[0] : 'U';

    return Column(
      children: [
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
        if (_customer!['emailAddress'] != null)
          Text(
            _customer!['emailAddress']['emailAddress'] ?? '',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 32),

        // M3: Group related information in an Outlined Card
        Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildNativeListTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle:
                    _customer!['emailAddress']?['emailAddress'] ?? 'Not set',
              ),
              const Divider(height: 1, indent: 56),
              _buildNativeListTile(
                icon: Icons.phone_outlined,
                title: 'Phone',
                subtitle:
                    _customer!['phoneNumber']?['phoneNumber'] ?? 'Not set',
              ),
              const Divider(height: 1, indent: 56),
              _buildNativeListTile(
                icon: Icons.location_on_outlined,
                title: 'Address',
                subtitle:
                    (_customer!['defaultAddress']?['formatted'] as List?)?.join(
                      ', ',
                    ) ??
                    'Not set',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Actions
        // M3: Use Tonal buttons for secondary actions or ListTiles for navigation
        FilledButton.tonal(
          onPressed: () => _viewOrders(context),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long),
              SizedBox(width: 8), // Standard gap between icon and label
              Text('View Orders'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
        ),
      ],
    );
  }

  // Helper to standardise list tiles
  Widget _buildNativeListTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      // Dense layout is often cleaner for details
      dense: false,
    );
  }

  Future<void> _viewOrders(BuildContext context) async {
    try {
      final result = await _auth.getOrders();

      if (!mounted) return;

      if (result['errors'] != null) {
        _showSnackbar('Failed to load orders');
        return;
      }

      final orders = result['data']['customer']['orders']['edges'] as List;

      // M3: Bottom Sheet with drag handle
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true, // Specific to Material 3
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 1.0, // Open full height within safe area
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Your Orders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders yet',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: orders.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final order = orders[index]['node'];
                          final price = order['totalPrice'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                size: 20,
                              ),
                            ),
                            title: Text('Order #${order['number']}'),
                            subtitle: Text(order['financialStatus']),
                            trailing: Text(
                              '${price['amount']} ${price['currencyCode']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              // Optional: Navigate to order details
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackbar('Failed to load orders: $e');
    }
  }
}
