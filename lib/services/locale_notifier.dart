// locale_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopify_flutter/shopify_flutter.dart'; // Import this
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import this

class LocaleNotifier extends ChangeNotifier {
  static final LocaleNotifier instance = LocaleNotifier._internal();
  LocaleNotifier._internal();

  static const String _localeKey = 'app_locale';

  Locale? _locale;
  Locale? get locale => _locale;

  /// Initialize locale from saved preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null) {
      _locale = _parseLocaleString(savedLocale);
      // Optional: Update config on init if needed,
      // but usually main.dart handles the very first load.
      notifyListeners();
    }
  }

  /// Set and persist the locale
  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;

    _locale = newLocale;

    // 1. Update Shopify Config Immediately
    _updateShopifyConfiguration(newLocale);

    notifyListeners();

    // 2. Persist to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, _localeToString(newLocale));
  }

  /// Helper to re-configure Shopify with the new language
  void _updateShopifyConfiguration(Locale locale) {
    String shopifyLanguage = 'en';

    // Robust check for language/script codes
    // Maps zh_Hant/Hans to zh-TW, others to en
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'Hans' || locale.scriptCode == 'Hant') {
        shopifyLanguage = 'zh-TW';
      }
    }

    // You must re-supply all parameters to setConfig
    ShopifyConfig.setConfig(
      storefrontAccessToken: dotenv.env['STOREFRONT_ACCESS_TOKEN'] ?? '',
      storeUrl: dotenv.env['STORE_URL'] ?? '',
      adminAccessToken: dotenv.env['ADMIN_ACCESS_TOKEN'],
      storefrontApiVersion: dotenv.env['STOREFRONT_API_VERSION'] ?? '2026-01',
      cachePolicy: CachePolicy.networkOnly,
      language: shopifyLanguage, // <--- The new language
    );

    print("Shopify Config Updated to: $shopifyLanguage");
  }

  Future<void> clearLocale() async {
    _locale = null;
    notifyListeners();
    // Potentially reset Shopify to default 'en' here if desired

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
  }

  String _localeToString(Locale locale) {
    if (locale.scriptCode != null) {
      return '${locale.languageCode}_${locale.scriptCode}';
    }
    return locale.languageCode;
  }

  Locale _parseLocaleString(String localeString) {
    if (localeString.contains('_')) {
      final parts = localeString.split('_');
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts.length > 1 ? parts[1] : null,
      );
    }
    return Locale(localeString);
  }
}
