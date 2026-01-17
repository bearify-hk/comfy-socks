// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get featuredProducts => 'Featured Products';

  @override
  String get home => 'Home';

  @override
  String get collections => 'Collections';

  @override
  String get blogs => 'Blogs';

  @override
  String get cart => 'Cart';

  @override
  String get account => 'Account';

  @override
  String get pages => 'Pages';

  @override
  String get checkout => 'Checkout';

  @override
  String get estimatedTotal => 'Estimated Total';

  @override
  String get signInWithEmail => 'Sign in with Email';

  @override
  String get weWillSendOtp =>
      'We will send a secure one-time code to your email.';

  @override
  String get signInToYourAccount => 'Sign in to your account';

  @override
  String get trackOrdersManageYourProfile =>
      'Track orders, manage your profile, and speed up checkout.';

  @override
  String get selectVariant => 'Select Variant';

  @override
  String get quantity => 'Quantity';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get signOut => 'Sign Out';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get email => 'Email';

  @override
  String get refresh => 'Refresh';

  @override
  String get articles => 'Articles';

  @override
  String get noArticlesFound => 'No article is found';

  @override
  String get qtyColon => 'Qty:';

  @override
  String get notSet => 'Not set';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String get sessionActive => 'Session active';

  @override
  String get sessionExpiringSoon => 'Session expiring soon';

  @override
  String get outOfStock => 'Out of Stock';

  @override
  String get description => 'Description';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get yourCartIsEmpty => 'Your cart is empty';

  @override
  String articlesCount(int count) {
    return '$count articles';
  }

  @override
  String get opening => 'Opening...';

  @override
  String welcomeBack(String customerName) {
    return 'Welcome back, $customerName!';
  }

  @override
  String get customer => 'Customer';

  @override
  String get language => 'Language';
}
