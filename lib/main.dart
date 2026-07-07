// main.dart
import 'package:comfy_socks/screens/auth_tab.dart';
import 'package:comfy_socks/screens/blog_tab.dart';
import 'package:comfy_socks/screens/cart_tab.dart';
import 'package:comfy_socks/screens/collection_tab.dart';
import 'package:comfy_socks/services/auth_notifier.dart';
import 'package:comfy_socks/services/locale_notifier.dart';
import 'package:comfy_socks/services/shopify_customer_account_auth.dart';
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

  // Note: OAuth login no longer relies on deep-link callbacks. The in-app
  // authentication session (see ShopifyCustomerAccountAuth.launchAuthorization)
  // captures the redirect and exchanges the code inline.

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
