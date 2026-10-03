import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/common_toasts.dart';
import '../../screens/shared/webview_screen.dart';

const _brand = Color(0xFFF64C13);
const _brandTint = Color(0xFFFFF4EE);

/// Marketing card with image + title + body that deep-links into a
/// native app (YouTube, Facebook, …) and falls back to the in-app
/// WebView when the OS has no non-browser handler.
///
/// `url` empty → renders nothing, so callers can dark-launch / kill
/// the slot via Remote Config without an app update.
class LearnBanner extends StatelessWidget {
  const LearnBanner({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.body,
    required this.url,
    this.webviewTitle,
  });

  final String imageAsset;
  final String title;
  final String body;
  final String url;

  /// Title shown when we fall back to the in-app WebView. Defaults to
  /// the banner's own title.
  final String? webviewTitle;

  Future<void> _open(BuildContext context) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (ok) return;
    } catch (_) {
      // Android throws when no native handler exists; fall through.
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: trimmed,
          title: webviewTitle ?? title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          try {
            await _open(context);
          } catch (_) {
            if (!context.mounted) return;
            CommonToasts.error(context, "Couldn't open this link");
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _brandTint,
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.image,
                      color: _brand,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        Icon(
                          LucideIcons.arrowUpRight,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
