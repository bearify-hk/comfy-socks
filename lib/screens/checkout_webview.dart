import 'package:comfy_socks/services/cart_service.dart'; // Import your cart service
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewCheckout extends StatefulWidget {
  const WebViewCheckout({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<WebViewCheckout> createState() => _WebViewCheckoutState();
}

class _WebViewCheckoutState extends State<WebViewCheckout> {
  late final InAppWebViewController webViewController;

  // 2025 Shopify Success Patterns
  final List<String> successPatterns = [
    '/thank_you',
    '/thank-you',
    '/orders/',
    'checkout/success',
    '/post_purchase',
  ];

  void handleUrlChanged(String url) {
    // 1. Check for Successful Checkout
    if (successPatterns.any((pattern) => url.contains(pattern))) {
      // CLEAR LOCAL CART: This is crucial
      CartService.instance.clearCart(); 

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.pop(context, true); // Return true to indicate success
      });
    }

    // 2. Handle Login Redirects
    // If Shopify tries to redirect to a generic login page, 
    // it means the BuyerIdentity token expired or failed.
    if (url.contains('/account/login') || url.contains('/member-login/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please try again.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(widget.checkoutUrl),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            // Critical for Shopify session persistence:
            thirdPartyCookiesEnabled: true,
            domStorageEnabled: true,
            useOnDownloadStart: true,
            supportZoom: false,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onUpdateVisitedHistory: (controller, url, androidIsReload) {
            if (url != null) handleUrlChanged(url.toString());
          },
          onPageCommitVisible: (controller, url) {
            // Hiding elements is fragile because Shopify changes classes often.
            // In 2025, it's better to target by ARIA labels or simpler CSS if possible.
            controller.evaluateJavascript(source: """
              // Example: Hiding the "Return to Store" link if it leads out of the app
              var backLink = document.querySelector('a[href*="myshopify.com"]');
              if (backLink) { backLink.style.display = "none"; }
            """);
          },
        ),
      ),
    );
  }
}