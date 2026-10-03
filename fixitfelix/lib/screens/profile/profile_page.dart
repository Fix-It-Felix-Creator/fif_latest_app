import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../settings/settings_screen.dart';

/// Home → Profile tab.
///
/// The same body the Pro app puts behind its Profile tab: one settings list
/// covering the account, notifications, support, sign-out and deletion, so
/// there is no separate trip to a /settings route.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile'),
      ),
      body: const SettingsBody(),
    );
  }
}
