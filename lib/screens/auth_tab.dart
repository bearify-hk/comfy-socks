import 'dart:developer';
import '../extension.dart';
import 'package:flutter/material.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

class AuthTab extends StatefulWidget {
  const AuthTab({super.key});

  @override
  State<AuthTab> createState() => _AuthTabState();
}

class _AuthTabState extends State<AuthTab> {
  final shopifyAuth = ShopifyAuth.instance;
  ShopifyUser? shopifyUser;

  // Controllers for login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Controllers for registration
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _acceptsMarketing = false;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void showSnackbar(String message) => context.showSnackBar(message);

  Future<void> _checkIfLoggedIn() async {
    try {
      final isTokenExpired = await shopifyAuth.isAccessTokenExpired;
      log('isTokenExpired: $isTokenExpired');
      if (isTokenExpired) {
        setState(() => shopifyUser = null);
        final accessToken = await shopifyAuth.currentCustomerAccessToken;
        if (accessToken != null) {
          final user = await shopifyAuth.currentUser();
          setState(() => shopifyUser = user);
          log('shopify user after token refresh: $shopifyUser');
        } else {
          log('Token Expired. Login Again.');
        }
      } else {
        final user = await shopifyAuth.currentUser();
        setState(() => shopifyUser = user);
        log('shopify user: $shopifyUser');
      }
    } catch (e) {
      if (!mounted) return;
      showSnackbar(e.toString());
      debugPrint(e.toString());
    }
  }

  Future<void> _login() async {
    if (_loginEmailController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      showSnackbar('Please enter email and password');
      return;
    }
    try {

      
      await shopifyAuth.signInWithEmailAndPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      showSnackbar('Logged in successfully');
      _loginEmailController.clear();
      _loginPasswordController.clear();
      _checkIfLoggedIn();
    } catch (e) {
      if (!mounted) return;
      showSnackbar(e.toString());
      debugPrint(e.toString());
    }
  }

  Future<void> _register() async {
    if (_registerEmailController.text.isEmpty || _registerPasswordController.text.isEmpty) {
      showSnackbar('Please enter email and password');
      return;
    }
    try {
      final createdUser = await shopifyAuth.createUserWithEmailAndPassword(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        acceptsMarketing: _acceptsMarketing,
      );
      setState(() {
        shopifyUser = createdUser;
      });
      _registerEmailController.clear();
      _registerPasswordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _acceptsMarketing = false;
      showSnackbar('Account created successfully');
    } catch (e) {
      if (!mounted) return;
      showSnackbar(e.toString());
      debugPrint(e.toString());
    }
  }

  Future<void> _signout() async {
    try {
      await shopifyAuth.signOutCurrentUser();
      showSnackbar('Logged out successfully');
      _checkIfLoggedIn();
    } catch (e) {
      if (!mounted) return;
      showSnackbar(e.toString());
      debugPrint(e.toString());
    }
  }

  Future<void> _deleteAccount() async {
    if (shopifyUser == null || shopifyUser!.id == null) return;
    try {
      await shopifyAuth.deleteCustomer(userId: '${shopifyUser?.id}');
      setState(() {
        shopifyUser = null;
      });
      showSnackbar('Account deleted successfully');
    } catch (e) {
      if (!mounted) return;
      showSnackbar(e.toString());
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('User: ${shopifyUser?.email}'),
              const SizedBox(height: 20),
              if (shopifyUser == null) ...[
                // Login Section
                const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _loginEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _loginPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _login(),
                  child: const Text('Sign In'),
                ),
                const Divider(height: 40),
                // Registration Section
                const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _registerEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _registerPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _acceptsMarketing,
                      onChanged: (value) {
                        setState(() {
                          _acceptsMarketing = value ?? false;
                        });
                      },
                    ),
                    const Text('Accept Marketing'),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _register(),
                  child: const Text('Sign Up'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () => _signout(),
                  child: const Text('Sign Out'),
                ),
                ElevatedButton(
                  onPressed: () => _deleteAccount(),
                  child: const Text('Delete Account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}