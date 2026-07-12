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
  String get blogs => 'News';

  @override
  String get info => 'Information';

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
  String get signInWithEmail => 'Sign in / Register with Email';

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
  String get articles => 'News';

  @override
  String get noArticlesFound => 'No news found';

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
    return '$count news';
  }

  @override
  String get opening => 'Opening...';

  @override
  String get searching => '\'Searching...';

  @override
  String get loadingProducts => 'Loading products...';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmSignOut => 'Are you sure you want to sign out?';

  @override
  String get loginFailed => 'Login Failed.';

  @override
  String welcomeBack(String customerName) {
    return 'Welcome back, $customerName!';
  }

  @override
  String get customer => 'Customer';

  @override
  String get language => 'Language';

  @override
  String searchResultsCount(int count, String query) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Results for \"$query\"',
      one: '1 Result for \"$query\"',
    );
    return '$_temp0';
  }

  @override
  String addedToCart(String productTitle) {
    return 'Added $productTitle to cart';
  }

  @override
  String get dismiss => 'Close';

  @override
  String get failedToLoadProfile => 'Failed to load profile. Pull to refresh.';

  @override
  String get sessionExpiredMessage =>
      'Your session has expired. Please sign in again.';

  @override
  String get failedToStartLogin => 'Failed to start login. Please try again.';

  @override
  String failedToStartLoginError(String error) {
    return 'Failed to start login: $error';
  }

  @override
  String get signedOutSuccessfully => 'Signed out successfully';

  @override
  String get signedOut => 'Signed out';

  @override
  String get couldNotOpenBrowser =>
      'Could not open browser. Please visit account.comfy-socks.com/profile';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountDialogTitle => 'Delete Account?';

  @override
  String get deleteAccountDialogBody =>
      'Your sign-in is managed by Shop. You\'ll be taken to Shop to permanently delete your account and personal data. This can\'t be undone, and you\'ll be signed out of this app.';

  @override
  String get deleteAccountContinue => 'Continue';

  @override
  String get deleteAccountRedirectMessage =>
      'You\'ve been signed out. Finish deleting your account in the page that opened.';

  @override
  String get loadingYourAccount => 'Loading your account...';

  @override
  String get yourOrders => 'Your Orders';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
    );
    return '$_temp0';
  }

  @override
  String get failedToLoadOrders => 'Failed to load orders. Please try again.';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get noOrdersDescription =>
      'When you place an order, it will appear here.';

  @override
  String get startShopping => 'Start Shopping';

  @override
  String get orderDetailsComing => 'Order details coming soon';

  @override
  String orderNumber(String number) {
    return 'Order #$number';
  }
}
