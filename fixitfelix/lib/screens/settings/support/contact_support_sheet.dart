import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/support_config.dart';
import '../../../core/utils/common_toasts.dart';

/// Opens the contact-support picker. On iOS this is a native
/// `CupertinoActionSheet` so the chrome (Cancel button, slide-up
/// animation) matches the system. Android keeps the Material modal
/// bottom sheet — Cupertino sheets look out-of-place there.
Future<void> showContactSupportSheet(BuildContext context) {
  if (Platform.isIOS) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Contact Support'),
        message: const Text('How would you like to reach us?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _callSupport(ctx),
            child: const Text('Call us'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _emailSupport(ctx),
            child: const Text('Email us'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _ContactSupportSheet(),
  );
}

/// Tap → opens the system phone dialer pre-filled with [kSupportPhone].
/// Pops the host sheet first so the dialer takes the foreground cleanly.
Future<void> _callSupport(BuildContext context) async {
  Navigator.of(context).pop();
  final uri = Uri(scheme: 'tel', path: kSupportPhone);
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      CommonToasts.error(context, 'Could not open dialer');
    }
  } catch (_) {
    if (context.mounted) {
      CommonToasts.error(context, 'Could not open dialer');
    }
  }
}

/// Tap → opens the device's default mail app composing to
/// [kSupportEmail]. `LaunchMode.externalApplication` is required on
/// iOS — without it `mailto:` resolves to nothing.
Future<void> _emailSupport(BuildContext context) async {
  Navigator.of(context).pop();
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: 'subject=FixItFelix%20Pro%20Support',
  );
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      CommonToasts.error(context, 'Could not open email app');
    }
  } catch (_) {
    if (context.mounted) {
      CommonToasts.error(context, 'Could not open email app');
    }
  }
}

class _ContactSupportSheet extends StatelessWidget {
  const _ContactSupportSheet();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Contact Support',
                style: theme.textTheme.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(LucideIcons.phone, color: colorScheme.primary),
            title: const Text('Call us'),
            subtitle: Text(kSupportPhone),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _callSupport(context),
          ),
          ListTile(
            leading: Icon(LucideIcons.mail, color: colorScheme.primary),
            title: const Text('Email us'),
            subtitle: Text(kSupportEmail),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _emailSupport(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
