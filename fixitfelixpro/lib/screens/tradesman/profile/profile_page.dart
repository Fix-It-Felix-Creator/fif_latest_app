import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../settings/settings_screen.dart';

/// Tradesman home → Profile tab. The body is the same iOS-style
/// settings list rendered behind the owner-home gear icon, so the
/// tradesman doesn't need a separate trip to /settings to manage
/// account / notifications / support / sign-out / delete.
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
        title: const Text('Profile'),
      ),
      body: const SettingsBody(),
    );
  }
}
