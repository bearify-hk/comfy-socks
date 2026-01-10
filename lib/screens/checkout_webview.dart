import 'dart:collection';
import 'package:comfy_socks/services/cart_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewCheckout extends StatefulWidget {
  const WebViewCheckout({super.key, required this.checkoutUrl});
  final String checkoutUrl;

  @override
  State<WebViewCheckout> createState() => _WebViewCheckoutState();
}

class _WebViewCheckoutState extends State<WebViewCheckout> {
  InAppWebViewController? webViewController;
  bool isLoading = true; // For the loading spinner

  final List<String> successPatterns = [
    '/thank_you',
    '/thank-you',
    '/orders/',
    'checkout/success',
    '/post_purchase',
  ];

  void handleUrlChanged(String url) {
    if (successPatterns.any((pattern) => url.contains(pattern))) {
      CartService.instance.clearCart(); 

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
    }

    if (url.contains('/account/login') || url.contains('/member-login/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please try again.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.checkoutUrl),
            ),
            initialSettings: InAppWebViewSettings(
              // Performance & Core Settings
              javaScriptEnabled: true,
              domStorageEnabled: true,
              cacheEnabled: true,
              databaseEnabled: true,
              hardwareAcceleration: true,
              
              // Shopify Specifics
              thirdPartyCookiesEnabled: true,
              useOnDownloadStart: true,
              supportZoom: false,
              
              // Prevent common Android/iOS lag
              allowsInlineMediaPlayback: true,
              isPagingEnabled: false,
            ),
            // AT_DOCUMENT_START is much faster than running JS after load
            initialUserScripts: UnmodifiableListView([
              UserScript(
                source: """
                  var style = document.createElement('style');
                  style.innerHTML = 'a[href*="myshopify.com"], .step__footer__previous-link { display: none !important; }';
                  document.head.appendChild(style);
                """,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() => isLoading = true);
              if (url != null) handleUrlChanged(url.toString());
            },
            onLoadStop: (controller, url) async {
              setState(() => isLoading = false);
              if (url != null) handleUrlChanged(url.toString());
            },
            onReceivedError: (controller, request, error) {
              setState(() => isLoading = false);
            },
          ),
          
          // Show spinner while Shopify is chugging
          if (isLoading)
            const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
        ],
      ),
    );
  }
}