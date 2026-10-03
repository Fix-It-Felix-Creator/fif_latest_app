import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/responsive/responsive.dart';

/// A simple webview screen for displaying web content
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          // webview_flutter has no native "download" hook, so we
          // intercept attachment links here. Anything that looks like a
          // file (or a Firebase Storage download URL) is handed to the
          // OS so it can save / open with the right app instead of
          // trying to render it inline.
          onNavigationRequest: (NavigationRequest req) async {
            final initial = Uri.tryParse(widget.url);
            if (_isAttachmentUrl(req.url, initial)) {
              await launchUrl(
                Uri.parse(req.url),
                mode: LaunchMode.externalApplication,
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// True if [url] looks like a downloadable attachment rather than a
  /// page navigation. We treat it as an attachment when the host is a
  /// Storage domain, when the path ends in a recognisable file
  /// extension, or when it has the `download` query param the public
  /// viewer adds. Cross-origin links from the embedded viewer are also
  /// considered attachments — staying inside the same shared-page host
  /// is the only "navigate" case we need to keep.
  bool _isAttachmentUrl(String url, Uri? initial) {
    final u = Uri.tryParse(url);
    if (u == null) return false;
    final host = u.host.toLowerCase();
    if (host.endsWith('firebasestorage.googleapis.com') ||
        host.endsWith('googleusercontent.com')) {
      return true;
    }
    final path = u.path.toLowerCase();
    // The shared-viewer proxy uses /q/{token}/d/... and /i/{token}/d/...
    // for download links. Catching the `/d/` segment is what lets the
    // OS handle the save instead of the WebView trying to render it
    // inline (which webview_flutter has no native hook for).
    if (RegExp(r'^/(q|i)/[^/]+/d/').hasMatch(path)) return true;
    const exts = [
      '.pdf', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.heic',
      '.mp4', '.mov', '.m4v', '.webm',
      '.docx', '.doc', '.xlsx', '.xls', '.csv',
      '.zip', '.txt',
    ];
    if (exts.any(path.endsWith)) return true;
    if (u.queryParametersAll.containsKey('download')) return true;
    if (initial != null && host.isNotEmpty && initial.host != host) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              LucideIcons.chevronLeft,
              color: theme.colorScheme.foreground,
              size: deviceInfo.isTablet ? 24 : 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.title,
          style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: theme.colorScheme.muted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
