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
      setState(() {
        _customer = null;
      });
    }
  }

  Future<void> _loadCustomer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _auth.getCurrentCustomer();

      if (result['errors'] != null) {
        throw Exception(result['errors'].toString());
      }

      setState(() {
        _customer = result['data']['customer'];
        _isLoading = false;
      });
    } catch (e) {
      log('Failed to load customer: $e');
      setState(() {
        _customer = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.launchAuthorization();
      // The actual login completion happens via deep link in main.dart
    } catch (e) {
      setState(() => _error = e.toString());
      _showSnackbar('Failed to start login: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.logout();
      setState(() => _customer = null);
      AuthNotifier.instance.notifyAuthStateChanged();
      _showSnackbar('Logged out successfully');
    } catch (e) {
      setState(() => _error = e.toString());
      _showSnackbar('Logout failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Account'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_customer == null) ...[
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Sign in to your account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in with your email to view orders, manage your profile, and more.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _login,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In with Email'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'You\'ll receive a one-time code via email to sign in securely.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Icon(
                        Icons.account_circle,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${_customer!['firstName'] ?? ''} ${_customer!['lastName'] ?? ''}'
                                .trim()
                                .isEmpty
                            ? 'Welcome!'
                            : 'Welcome, ${_customer!['firstName']}!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (_customer!['emailAddress'] != null)
                        Text(
                          _customer!['emailAddress']['emailAddress'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 30),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              _buildInfoRow(
                                'Email',
                                _customer!['emailAddress']?['emailAddress'] ??
                                    'Not set',
                              ),
                              _buildInfoRow(
                                'Phone',
                                _customer!['phoneNumber']?['phoneNumber'] ??
                                    'Not set',
                              ),
                              if (_customer!['defaultAddress'] != null)
                                _buildInfoRow(
                                  'Address',
                                  (_customer!['defaultAddress']['formatted']
                                              as List?)
                                          ?.join(', ') ??
                                      'Not set',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => _viewOrders(context),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('View Orders'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
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

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: orders.isEmpty
                    ? const Center(child: Text('No orders yet'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index]['node'];
                          return ListTile(
                            leading: const Icon(Icons.shopping_bag),
                            title: Text('Order #${order['number']}'),
                            subtitle: Text(
                              '${order['financialStatus']} • ${order['totalPrice']['amount']} ${order['totalPrice']['currencyCode']}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
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