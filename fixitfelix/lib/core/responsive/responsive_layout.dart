import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'device_type.dart';
import 'responsive_extensions.dart';

/// A responsive layout wrapper that constrains content width and adds appropriate padding
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool centerContent;
  final Color? backgroundColor;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    final effectiveMaxWidth = maxWidth ?? _getDefaultMaxWidth(deviceInfo);
    final effectivePadding = padding ?? context.adaptivePadding;

    Widget content = child;

    // Apply max width constraint
    if (effectiveMaxWidth != double.infinity) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      );
    }

    // Center if needed
    if (centerContent) {
      content = Center(child: content);
    }

    // Apply padding
    content = Padding(padding: effectivePadding, child: content);

    // Apply background color if provided
    if (backgroundColor != null) {
      content = ColoredBox(color: backgroundColor!, child: content);
    }

    return content;
  }

  double _getDefaultMaxWidth(DeviceInfo deviceInfo) {
    switch (deviceInfo.type) {
      case DeviceType.desktop:
        return ResponsiveBreakpoints.maxContentWidthDesktop;
      case DeviceType.tablet:
        return ResponsiveBreakpoints.maxContentWidthTablet;
      case DeviceType.mobile:
        return double.infinity; // Full width on mobile
    }
  }
}

/// A responsive scaffold that adapts to different screen sizes
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  /// For tablet/desktop: optional side navigation
  final Widget? sideNavigation;

  /// For tablet/desktop: optional side panel
  final Widget? sidePanel;

  /// Width of side navigation in tablet/desktop mode
  final double sideNavigationWidth;

  /// Width of side panel in tablet/desktop mode
  final double sidePanelWidth;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
    this.sideNavigation,
    this.sidePanel,
    this.sideNavigationWidth = 280,
    this.sidePanelWidth = 320,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    // Build the main body with optional side navigation/panel for larger screens
    Widget mainBody = body;

    // On tablet in landscape or desktop, show side navigation if provided
    if ((deviceInfo.isTablet && deviceInfo.isLandscape) ||
        deviceInfo.isDesktop) {
      if (sideNavigation != null || sidePanel != null) {
        mainBody = Row(
          children: [
            if (sideNavigation != null)
              SizedBox(width: sideNavigationWidth, child: sideNavigation),
            Expanded(child: body),
            if (sidePanel != null)
              SizedBox(width: sidePanelWidth, child: sidePanel),
          ],
        );
      }
    }

    // Determine if we should show bottom navigation
    // On tablet landscape/desktop, bottom nav is typically replaced by side nav
    final showBottomNav =
        bottomNavigationBar != null &&
        !(sideNavigation != null &&
            ((deviceInfo.isTablet && deviceInfo.isLandscape) ||
                deviceInfo.isDesktop));

    return Scaffold(
      appBar: appBar,
      body: mainBody,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: showBottomNav ? bottomNavigationBar : null,
      drawer: _shouldShowDrawer(deviceInfo) ? drawer : null,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  bool _shouldShowDrawer(DeviceInfo deviceInfo) {
    // Don't show drawer if side navigation is visible
    if (sideNavigation != null &&
        ((deviceInfo.isTablet && deviceInfo.isLandscape) ||
            deviceInfo.isDesktop)) {
      return false;
    }
    return drawer != null;
  }
}

/// A responsive grid layout that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    int columns;
    switch (deviceInfo.type) {
      case DeviceType.desktop:
        columns = desktopColumns ?? tabletColumns ?? 4;
        break;
      case DeviceType.tablet:
        columns = tabletColumns ?? 2;
        break;
      case DeviceType.mobile:
        columns = mobileColumns ?? (deviceInfo.isLandscape ? 2 : 1);
        break;
    }

    Widget grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing * context.spacingMultiplier,
        mainAxisSpacing: runSpacing * context.spacingMultiplier,
        childAspectRatio: childAspectRatio ?? 1,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );

    if (padding != null) {
      grid = Padding(padding: padding!, child: grid);
    }

    return grid;
  }
}

/// A responsive row that wraps to column on smaller screens
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final bool forceColumn;
  final bool forceRow;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.forceColumn = false,
    this.forceRow = false,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    final scaledSpacing = spacing * context.spacingMultiplier;

    // Determine layout direction
    bool useRow;
    if (forceRow) {
      useRow = true;
    } else if (forceColumn) {
      useRow = false;
    } else {
      // Default behavior: row on tablet landscape/desktop, column on mobile/tablet portrait
      useRow =
          (deviceInfo.isTablet && deviceInfo.isLandscape) ||
          deviceInfo.isDesktop;
    }

    if (useRow) {
      return Row(
        mainAxisAlignment: rowMainAxisAlignment,
        crossAxisAlignment: rowCrossAxisAlignment,
        children: _addSpacing(children, scaledSpacing, isHorizontal: true),
      );
    } else {
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: _addSpacing(children, scaledSpacing, isHorizontal: false),
      );
    }
  }

  List<Widget> _addSpacing(
    List<Widget> widgets,
    double spacing, {
    required bool isHorizontal,
  }) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(
          isHorizontal ? SizedBox(width: spacing) : SizedBox(height: spacing),
        );
      }
    }
    return result;
  }
}

/// A widget that shows different layouts for split view on larger screens
class ResponsiveSplitView extends StatelessWidget {
  final Widget primaryContent;
  final Widget? secondaryContent;
  final double splitRatio;
  final bool showSecondaryOnMobile;

  const ResponsiveSplitView({
    super.key,
    required this.primaryContent,
    this.secondaryContent,
    this.splitRatio = 0.5,
    this.showSecondaryOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    // On mobile portrait, show only primary content (unless forced)
    if (deviceInfo.isMobile &&
        deviceInfo.isPortrait &&
        !showSecondaryOnMobile) {
      return primaryContent;
    }

    // On larger screens or landscape, show split view if secondary content exists
    if (secondaryContent != null &&
        (deviceInfo.isTablet ||
            deviceInfo.isDesktop ||
            deviceInfo.isLandscape)) {
      return Row(
        children: [
          Expanded(flex: (splitRatio * 100).round(), child: primaryContent),
          Expanded(
            flex: ((1 - splitRatio) * 100).round(),
            child: secondaryContent!,
          ),
        ],
      );
    }

    return primaryContent;
  }
}
