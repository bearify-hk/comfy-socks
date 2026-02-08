// main.dart
import 'package:app_links/app_links.dart';
import 'package:comfy_socks/screens/auth_tab.dart';
import 'package:comfy_socks/screens/blog_tab.dart';
import 'package:comfy_socks/screens/cart_tab.dart';
import 'package:comfy_socks/screens/collection_tab.dart';
import 'package:comfy_socks/services/auth_notifier.dart';
import 'package:comfy_socks/services/locale_notifier.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'screens/home_tab.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleNotifier.instance.initialize();

  await dotenv.load(fileName: '.env');

  // Initialize Shopify Customer Account Auth
  ShopifyCustomerAccountAuth.initialize(
    clientId: dotenv.env['CUSTOMER_ACCOUNT_API_CLIENT_ID'] ?? '',
    shopDomain: dotenv.env['STORE_URL'] ?? '',
    storefrontAccessToken: dotenv.env['STOREFRONT_ACCESS_TOKEN'] ?? '',
    redirectUri: dotenv.env['REDIRECT_URI'] ?? '',
  );

  final currentLocale = LocaleNotifier.instance.locale;
  // print('Current Locale: ${currentLocale.toString()}');
  String shopifyLanguage = 'en'; // Default

  if (currentLocale != null) {
    // Map based on your logic: zh_Hans/zh_Hant -> zh, everything else -> en
    shopifyLanguage =
        currentLocale.toString() == 'zh_Hant' ||
            currentLocale.toString() == 'zh_Hans'
        ? 'zh-TW'
        : 'en';
  }

  // Initialize Shopify Storefront API config
  ShopifyConfig.setConfig(
    storefrontAccessToken: dotenv.env['STOREFRONT_ACCESS_TOKEN'] ?? '',
    storeUrl: dotenv.env['STORE_URL'] ?? '',
    adminAccessToken: dotenv.env['ADMIN_ACCESS_TOKEN'],
    storefrontApiVersion: dotenv.env['STOREFRONT_API_VERSION'] ?? '2026-01',
    cachePolicy: CachePolicy.networkOnly,
    language: shopifyLanguage,
  );

  // Initialize services - restore previous sessions
  await AuthNotifier.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LocaleNotifier.instance),
        ChangeNotifierProvider.value(value: AuthNotifier.instance),
        // Add CartService here if it extends ChangeNotifier
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeNotifier = context.watch<LocaleNotifier>();

    return ListenableBuilder(
      listenable: LocaleNotifier.instance,
      builder: (context, child) {
        return MaterialApp(
          locale: localeNotifier.locale,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
              countryCode: 'HK',
            ),
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
              countryCode: 'CN',
            ),
            Locale('en'),
          ],
          title: 'Comfy Socks',
          themeMode: ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8C00),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.dark,
            ),
          ),
          home: MyHomePage(key: ValueKey(localeNotifier.locale)),
        );
      },
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
    _initDeepLinks();
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
    // Check if the link is your Shopify callback
    if (uri.host == 'callback' || uri.path.contains('callback')) {
      try {
        final auth = ShopifyCustomerAccountAuth.instance;

        // Exchange the 'code' for tokens
        await auth.handleCallback(uri);

        // Notify the UI that the auth state has changed
        await AuthNotifier.instance.notifyAuthStateChanged();

        if (kDebugMode) {
          print("Login Successful! Customer: ${auth.customerEmail}");
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.welcomeBack(
                  auth.customerEmail ?? AppLocalizations.of(context)!.customer,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("Auth Callback Error: $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.loginFailed),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Widget> tabs = [
    const HomeTab(),
    const CollectionTab(),
    const BlogTab(),
    const CartTab(),
    const CustomerAccountAuthTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            label: AppLocalizations.of(context)!.collections,
          ),
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            label: AppLocalizations.of(context)!.info,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: AppLocalizations.of(context)!.cart,
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: AppLocalizations.of(context)!.account,
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
