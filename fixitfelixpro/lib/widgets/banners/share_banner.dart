import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_toasts.dart';

const _brand = Color(0xFFF64C13);
const _brandTint = Color(0xFFFFF4EE);

/// Marketing card mirroring [LearnBanner]'s visual — image + title +
/// body — but opens the system share sheet on tap instead of opening
/// a URL. Use for invite / referral slots where the call-to-action is
/// "send this to a friend" rather than "go read this page".
class ShareBanner extends StatelessWidget {
  const ShareBanner({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.body,
    required this.shareText,
    this.shareSubject,
  });

  final String imageAsset;
  final String title;
  final String body;

  /// Text payload sent to the share sheet (SMS body, email body, …).
  final String shareText;

  /// Subject line — used by mail clients; ignored elsewhere.
  final String? shareSubject;

  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: shareSubject),
      );
    } catch (_) {
      if (!context.mounted) return;
      CommonToasts.error(context, "Couldn't open the share sheet");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _share(context),
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
                          LucideIcons.share2,
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
