import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Reusable toast notifications built on top of [ShadToaster].
///
/// Ensure the widget tree contains a `ShadApp` (which already provides
/// a `ShadToaster`). Call from anywhere via:
///   CommonToasts.success(context, 'Saved');
///   CommonToasts.error(context, 'Something went wrong');
///   CommonToasts.info(context, 'Update available');
///   CommonToasts.warning(context, 'Low disk space');
class CommonToasts {
  CommonToasts._();

  static const _success = Color(0xFF10B981);
  static const _error = Color(0xFFEF4444);
  static const _info = Color(0xFF3B82F6);
  static const _warning = Color(0xFFF59E0B);

  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) => _show(
        context,
        title: title ?? 'Success',
        message: message,
        icon: LucideIcons.circleCheck,
        accent: _success,
        duration: duration,
      );

  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) => _show(
        context,
        title: title ?? 'Error',
        message: message,
        icon: LucideIcons.circleX,
        accent: _error,
        duration: duration,
      );

  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) => _show(
        context,
        title: title ?? 'Info',
        message: message,
        icon: LucideIcons.info,
        accent: _info,
        duration: duration,
      );

  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) => _show(
        context,
        title: title ?? 'Warning',
        message: message,
        icon: LucideIcons.triangleAlert,
        accent: _warning,
        duration: duration,
      );

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    required Duration duration,
  }) {
    ShadToaster.of(context).show(
      ShadToast(
        duration: duration,
        radius: BorderRadius.circular(10),
        backgroundColor: Colors.white,
        border: ShadBorder.all(
          color: accent.withValues(alpha: 0.3),
          width: 1,
          radius: BorderRadius.circular(10),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        description: Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            message,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ),
    );
  }
}
