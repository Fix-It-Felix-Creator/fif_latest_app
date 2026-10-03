import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/responsive/responsive.dart';

/// Navigation item configuration
class NavItem {
  final int index;
  final IconData icon;
  final String label;

  const NavItem({required this.index, required this.icon, required this.label});
}

/// A responsive home shell that adapts navigation based on screen size
/// - Mobile: Bottom navigation bar
/// - Tablet Portrait: Bottom navigation bar with larger touch targets
/// - Tablet Landscape: Side navigation rail
/// - Desktop: Side navigation with labels
class ResponsiveHomeShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<NavItem> navItems;
  final Widget child;
  final Color? backgroundColor;
  final Widget? header; // Optional header for side navigation
  final Widget? footer; // Optional footer for side navigation
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const ResponsiveHomeShell({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.navItems,
    required this.child,
    this.backgroundColor,
    this.header,
    this.footer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    // Tablet landscape or desktop: use side navigation
    if ((deviceInfo.isTablet && deviceInfo.isLandscape) ||
        deviceInfo.isDesktop) {
      return Scaffold(
        backgroundColor: backgroundColor ?? colorScheme.background,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Row(
          children: [
            // Side navigation
            _buildSideNavigation(context, deviceInfo, colorScheme),
            // Vertical divider
            VerticalDivider(width: 1, thickness: 1, color: colorScheme.border),
            // Main content
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile or tablet portrait: use bottom navigation
    return Scaffold(
      backgroundColor: backgroundColor ?? colorScheme.background,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: child,
      bottomNavigationBar: _buildBottomNavigation(
        context,
        deviceInfo,
        colorScheme,
      ),
    );
  }

  Widget _buildSideNavigation(
    BuildContext context,
    DeviceInfo deviceInfo,
    ShadColorScheme colorScheme,
  ) {
    final isDesktop = deviceInfo.isDesktop;
    final width = isDesktop ? 240.0 : 80.0;

    return Container(
      width: width,
      color: colorScheme.background,
      child: SafeArea(
        child: Column(
          children: [
            if (header != null) ...[
              Padding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: header,
              ),
              Divider(height: 1, color: colorScheme.border),
            ],
            const SizedBox(height: 16),
            // Navigation items
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12),
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  return _buildSideNavItem(
                    context: context,
                    item: item,
                    isSelected: currentIndex == item.index,
                    colorScheme: colorScheme,
                    showLabel: isDesktop,
                  );
                },
              ),
            ),
            if (footer != null) ...[
              Divider(height: 1, color: colorScheme.border),
              Padding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: footer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavItem({
    required BuildContext context,
    required NavItem item,
    required bool isSelected,
    required ShadColorScheme colorScheme,
    required bool showLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onIndexChanged(item.index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 24,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.mutedForeground,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(
    BuildContext context,
    DeviceInfo deviceInfo,
    ShadColorScheme colorScheme,
  ) {
    final isTablet = deviceInfo.isTablet;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.background,
        border: Border(top: BorderSide(color: colorScheme.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 8,
            vertical: isTablet ? 12 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) {
              return _buildBottomNavItem(
                context: context,
                item: item,
                isSelected: currentIndex == item.index,
                colorScheme: colorScheme,
                isTablet: isTablet,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required NavItem item,
    required bool isSelected,
    required ShadColorScheme colorScheme,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: () => onIndexChanged(item.index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: isTablet ? 28 : 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.mutedForeground,
            ),
            SizedBox(height: isTablet ? 6 : 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
