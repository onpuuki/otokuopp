import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  String _getMonetizedUrl(String originalUrl) {
    try {
      final uri = Uri.parse(originalUrl);
      final host = uri.host.toLowerCase();
      if (host.contains('google.com') || host.contains('yahoo.co.jp')) {
        final queryParams = Map<String, dynamic>.from(uri.queryParameters);
        queryParams['ref'] = 'otokuopp_invite_code_123';
        return uri.replace(queryParameters: queryParams).toString();
      }
    } catch (e) {
      // Return original URL if parsing fails
    }
    return originalUrl;
  }

  @override
  void initState() {
    super.initState();
    final monetizedUrl = _getMonetizedUrl(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(monetizedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
