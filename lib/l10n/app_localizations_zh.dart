// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get featuredProducts => '精選產品';

  @override
  String get home => '首頁';

  @override
  String get collections => '系列';

  @override
  String get blogs => '新聞';

  @override
  String get info => '資訊';

  @override
  String get cart => '購物車';

  @override
  String get account => '帳戶';

  @override
  String get pages => '頁面';

  @override
  String get checkout => '結帳';

  @override
  String get estimatedTotal => '預計總額';

  @override
  String get signInWithEmail => '以電郵登入／註冊';

  @override
  String get weWillSendOtp => '我們將會發送一次性安全驗證碼至您的電郵。';

  @override
  String get signInToYourAccount => '登入您的帳戶';

  @override
  String get trackOrdersManageYourProfile => '追蹤訂單、管理個人資料，並加快結帳流程。';

  @override
  String get selectVariant => '選擇款式';

  @override
  String get quantity => '數量';

  @override
  String get addToCart => '加入購物車';

  @override
  String get signOut => '登出';

  @override
  String get phone => '電話';

  @override
  String get address => '地址';

  @override
  String get email => '電郵';

  @override
  String get refresh => '重新整理';

  @override
  String get articles => '新聞';

  @override
  String get noArticlesFound => '沒有新聞';

  @override
  String get qtyColon => '數量︰';

  @override
  String get notSet => '未填寫';

  @override
  String get sessionExpired => '登入階段已過期';

  @override
  String get sessionActive => '登入階段有效';

  @override
  String get sessionExpiringSoon => '登入階段即將過期';

  @override
  String get outOfStock => '缺貨中';

  @override
  String get description => '描述';

  @override
  String get searchProducts => '搜尋貨品…';

  @override
  String get yourCartIsEmpty => '購物車目前是空的';

  @override
  String articlesCount(int count) {
    return '$count 文章';
  }

  @override
  String get opening => '打開中…';

  @override
  String get searching => '\'搜尋中…';

  @override
  String get loadingProducts => '載入貨品中…';

  @override
  String get cancel => '取消';

  @override
  String get confirmSignOut => '確認登出？';

  @override
  String get loginFailed => '登入失敗。';

  @override
  String welcomeBack(String customerName) {
    return '歡迎回來，$customerName！';
  }

  @override
  String get customer => '顧客';

  @override
  String get language => '語言';

  @override
  String searchResultsCount(int count, String query) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 項「$query」的搜尋結果',
    );
    return '$_temp0';
  }

  @override
  String addedToCart(String productTitle) {
    return '已將 $productTitle 加入購物車';
  }

  @override
  String get dismiss => '關閉';

  @override
  String get failedToLoadProfile => '載入個人資料失敗。請下拉重新整理。';

  @override
  String get sessionExpiredMessage => '您的登入階段已過期，請重新登入。';

  @override
  String get failedToStartLogin => '開始登入失敗，請重試。';

  @override
  String failedToStartLoginError(String error) {
    return '開始登入失敗：$error';
  }

  @override
  String get signedOutSuccessfully => '已成功登出';

  @override
  String get signedOut => '已登出';

  @override
  String get couldNotOpenBrowser =>
      '無法開啟瀏覽器，請前往 account.comfy-socks.com/profile';

  @override
  String get deleteAccount => '刪除帳戶';

  @override
  String get deleteAccountDialogTitle => '刪除帳戶？';

  @override
  String get deleteAccountDialogBody =>
      '您的登入由 Shop 管理。我們將帶您前往 Shop 永久刪除您的帳戶及個人資料。此操作無法復原，並且您將登出本應用程式。';

  @override
  String get deleteAccountContinue => '繼續';

  @override
  String get deleteAccountRedirectMessage => '您已登出。請在開啟的頁面中完成帳戶刪除。';

  @override
  String get loadingYourAccount => '正在載入您的帳戶…';

  @override
  String get yourOrders => '您的訂單';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個訂單',
    );
    return '$_temp0';
  }

  @override
  String get failedToLoadOrders => '載入訂單失敗，請重試。';

  @override
  String get noOrdersYet => '暫無訂單';

  @override
  String get noOrdersDescription => '下單後，訂單將顯示於此。';

  @override
  String get startShopping => '開始購物';

  @override
  String get orderDetailsComing => '訂單詳情即將推出';

  @override
  String orderNumber(String number) {
    return '訂單 #$number';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get featuredProducts => '精选产品';

  @override
  String get home => '首页';

  @override
  String get collections => '系列';

  @override
  String get blogs => '新闻';

  @override
  String get info => '資訊';

  @override
  String get cart => '购物车';

  @override
  String get account => '帐户';

  @override
  String get pages => '页面';

  @override
  String get checkout => '结帐';

  @override
  String get estimatedTotal => '预计总额';

  @override
  String get signInWithEmail => '以电邮登入／注册';

  @override
  String get weWillSendOtp => '我们将会发送一次性安全验证码至您的电邮。';

  @override
  String get signInToYourAccount => '登入您的帐户';

  @override
  String get trackOrdersManageYourProfile => '追踪订单、管理个人资料，并加快结帐流程。';

  @override
  String get selectVariant => '选择款式';

  @override
  String get quantity => '数量';

  @override
  String get addToCart => '加入购物车';

  @override
  String get signOut => '登出';

  @override
  String get phone => '电话';

  @override
  String get address => '地址';

  @override
  String get email => '电邮';

  @override
  String get refresh => '重新整理';

  @override
  String get articles => '新闻';

  @override
  String get noArticlesFound => '没有文章';

  @override
  String get qtyColon => '数量︰';

  @override
  String get notSet => '未填写';

  @override
  String get sessionExpired => '登入阶段已过期';

  @override
  String get sessionActive => '登入阶段有效';

  @override
  String get sessionExpiringSoon => '登入阶段即将过期';

  @override
  String get outOfStock => '缺货中';

  @override
  String get description => '描述';

  @override
  String get searchProducts => '搜寻货品…';

  @override
  String get yourCartIsEmpty => '购物车目前是空的';

  @override
  String articlesCount(int count) {
    return '$count 文章';
  }

  @override
  String get opening => '打开中…';

  @override
  String get searching => '\'搜寻中…';

  @override
  String get loadingProducts => '载入货品中…';

  @override
  String get cancel => '取消';

  @override
  String get confirmSignOut => '确认登出？';

  @override
  String get loginFailed => '登入失败。';

  @override
  String welcomeBack(String customerName) {
    return '欢迎回来，$customerName！';
  }

  @override
  String get customer => '顾客';

  @override
  String get language => '语言';

  @override
  String searchResultsCount(int count, String query) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 项「$query」的搜寻结果',
    );
    return '$_temp0';
  }

  @override
  String addedToCart(String productTitle) {
    return '已将 $productTitle 加入购物车';
  }

  @override
  String get dismiss => '关闭';

  @override
  String get failedToLoadProfile => '载入个人资料失败。请下拉刷新。';

  @override
  String get sessionExpiredMessage => '您的登入阶段已过期，请重新登入。';

  @override
  String get failedToStartLogin => '开始登入失败，请重试。';

  @override
  String failedToStartLoginError(String error) {
    return '开始登入失败：$error';
  }

  @override
  String get signedOutSuccessfully => '已成功登出';

  @override
  String get signedOut => '已登出';

  @override
  String get couldNotOpenBrowser =>
      '无法打开浏览器，请前往 account.comfy-socks.com/profile';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountDialogTitle => '删除账户？';

  @override
  String get deleteAccountDialogBody =>
      '您的登录由 Shop 管理。我们将带您前往 Shop 永久删除您的账户及个人资料。此操作无法撤销，并且您将退出本应用。';

  @override
  String get deleteAccountContinue => '继续';

  @override
  String get deleteAccountRedirectMessage => '您已退出登录。请在打开的页面中完成账户删除。';

  @override
  String get loadingYourAccount => '正在载入您的帐户…';

  @override
  String get yourOrders => '您的订单';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个订单',
    );
    return '$_temp0';
  }

  @override
  String get failedToLoadOrders => '载入订单失败，请重试。';

  @override
  String get noOrdersYet => '暂无订单';

  @override
  String get noOrdersDescription => '下单后，订单将显示于此。';

  @override
  String get startShopping => '开始购物';

  @override
  String get orderDetailsComing => '订单详情即将推出';

  @override
  String orderNumber(String number) {
    return '订单 #$number';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get featuredProducts => '精選產品';

  @override
  String get home => '首頁';

  @override
  String get collections => '系列';

  @override
  String get blogs => '新聞';

  @override
  String get info => '資訊';

  @override
  String get cart => '購物車';

  @override
  String get account => '帳戶';

  @override
  String get pages => '頁面';

  @override
  String get checkout => '結帳';

  @override
  String get estimatedTotal => '預計總額';

  @override
  String get signInWithEmail => '以電郵登入／註冊';

  @override
  String get weWillSendOtp => '我們將會發送一次性安全驗證碼至您的電郵。';

  @override
  String get signInToYourAccount => '登入您的帳戶';

  @override
  String get trackOrdersManageYourProfile => '追蹤訂單、管理個人資料，並加快結帳流程。';

  @override
  String get selectVariant => '選擇款式';

  @override
  String get quantity => '數量';

  @override
  String get addToCart => '加入購物車';

  @override
  String get signOut => '登出';

  @override
  String get phone => '電話';

  @override
  String get address => '地址';

  @override
  String get email => '電郵';

  @override
  String get refresh => '重新整理';

  @override
  String get articles => '新聞';

  @override
  String get noArticlesFound => '沒有新聞';

  @override
  String get qtyColon => '數量︰';

  @override
  String get notSet => '未填寫';

  @override
  String get sessionExpired => '登入階段已過期';

  @override
  String get sessionActive => '登入階段有效';

  @override
  String get sessionExpiringSoon => '登入階段即將過期';

  @override
  String get outOfStock => '缺貨中';

  @override
  String get description => '描述';

  @override
  String get searchProducts => '搜尋貨品…';

  @override
  String get yourCartIsEmpty => '購物車目前是空的';

  @override
  String articlesCount(int count) {
    return '$count 文章';
  }

  @override
  String get opening => '打開中…';

  @override
  String get searching => '\'搜尋中…';

  @override
  String get loadingProducts => '載入貨品中…';

  @override
  String get cancel => '取消';

  @override
  String get confirmSignOut => '確認登出？';

  @override
  String get loginFailed => '登入失敗。';

  @override
  String welcomeBack(String customerName) {
    return '歡迎回來，$customerName！';
  }

  @override
  String get customer => '顧客';

  @override
  String get language => '語言';

  @override
  String searchResultsCount(int count, String query) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 項「$query」的搜尋結果',
    );
    return '$_temp0';
  }

  @override
  String addedToCart(String productTitle) {
    return '已將 $productTitle 加入購物車';
  }

  @override
  String get dismiss => '關閉';

  @override
  String get failedToLoadProfile => '載入個人資料失敗。請下拉重新整理。';

  @override
  String get sessionExpiredMessage => '您的登入階段已過期，請重新登入。';

  @override
  String get failedToStartLogin => '開始登入失敗，請重試。';

  @override
  String failedToStartLoginError(String error) {
    return '開始登入失敗：$error';
  }

  @override
  String get signedOutSuccessfully => '已成功登出';

  @override
  String get signedOut => '已登出';

  @override
  String get couldNotOpenBrowser =>
      '無法開啟瀏覽器，請前往 account.comfy-socks.com/profile';

  @override
  String get deleteAccount => '刪除帳戶';

  @override
  String get deleteAccountDialogTitle => '刪除帳戶？';

  @override
  String get deleteAccountDialogBody =>
      '您的登入由 Shop 管理。我們將帶您前往 Shop 永久刪除您的帳戶及個人資料。此操作無法復原，並且您將登出本應用程式。';

  @override
  String get deleteAccountContinue => '繼續';

  @override
  String get deleteAccountRedirectMessage => '您已登出。請在開啟的頁面中完成帳戶刪除。';

  @override
  String get loadingYourAccount => '正在載入您的帳戶…';

  @override
  String get yourOrders => '您的訂單';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個訂單',
    );
    return '$_temp0';
  }

  @override
  String get failedToLoadOrders => '載入訂單失敗，請重試。';

  @override
  String get noOrdersYet => '暫無訂單';

  @override
  String get noOrdersDescription => '下單後，訂單將顯示於此。';

  @override
  String get startShopping => '開始購物';

  @override
  String get orderDetailsComing => '訂單詳情即將推出';

  @override
  String orderNumber(String number) {
    return '訂單 #$number';
  }
}
