import 'package:app_links/app_links.dart';
import 'package:comfy_socks/screens/auth_tab.dart';
import 'package:comfy_socks/screens/blog_tab.dart';
import 'package:comfy_socks/screens/cart_tab.dart';
import 'package:comfy_socks/screens/collection_tab.dart';
// import 'package:comfy_socks/screens/order_tab.dart';
// import 'package:comfy_socks/screens/search_tab.dart';
import 'package:comfy_socks/services/auth_notifier.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'screens/home_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  ShopifyCustomerAccountAuth.initialize(
    clientId: dotenv.env['CUSTOMER_ACCOUNT_API_CLIENT_ID'] ?? '',
    shopDomain: dotenv.env['STORE_URL'] ?? '',
    redirectUri: dotenv.env['REDIRECT_URI'] ?? '',
  );

  ShopifyConfig.setConfig(
    storefrontAccessToken: dotenv.env['STOREFRONT_ACCESS_TOKEN'] ?? '',
    storeUrl: dotenv.env['STORE_URL'] ?? '',
    adminAccessToken: dotenv.env['ADMIN_ACCESS_TOKEN'],
    storefrontApiVersion: dotenv.env['STOREFRONT_API_VERSION'] ?? '2023-07',
    cachePolicy: CachePolicy.networkOnly,
    language: dotenv.env['COUNTRY_LOCALE'],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comfy Socks',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8C00), brightness: Brightness.light),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // Start listening for the redirect
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 1. Handle links when the app is already open (Background/Foreground)
    _appLinks.uriLinkStream.listen((uri) {
      _processAuthRedirect(uri);
    });

    // 2. Handle the link if the app was completely closed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _processAuthRedirect(uri);
    });
  }

  Future<void> _processAuthRedirect(Uri uri) async {
    // Check if the link is your Shopify callback (e.g., shop.123.app://callback)
    if (uri.host == 'callback' || uri.path.contains('callback')) {
      try {
        final auth = ShopifyCustomerAccountAuth.instance;

        // This exchanges the 'code' for an 'accessToken' inside your service
        await auth.handleCallback(uri);

        // THIS IS WHAT YOU MISSED:
        // Notify the UI that the auth state has changed
        AuthNotifier.instance.notifyAuthStateChanged();

        if (kDebugMode) {
          print("Login Successful!");
        }
      } catch (e) {
        print("Auth Callback Error: $e");
      }
    }
  }

  List<Widget> tabs = [
    const HomeTab(),
    const CollectionTab(),
    // const SearchTab(),
    // const ShopTab(),
    const BlogTab(),
    const CartTab(),
    // const OrderTab(),
    const CustomerAccountAuthTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Collections',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            label: 'Blog',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          // BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Orders'),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Login',
          ),
        ],
      ),
    );
  }

  void _onNavigationDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
