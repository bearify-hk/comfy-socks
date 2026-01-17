// locale_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      notifyListeners();
    }
  }

  /// Set and persist the locale
  Future<void> setLocale(Locale newLocale) async {
    print('setLocale called with: $newLocale'); // Add this
    print('Current locale: $_locale'); // Add this
    if (_locale == newLocale) return;
    
    _locale = newLocale;
    notifyListeners();

    // Persist to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, _localeToString(newLocale));
  }

  /// Clear locale (use system default)
  Future<void> clearLocale() async {
    _locale = null;
    notifyListeners();

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