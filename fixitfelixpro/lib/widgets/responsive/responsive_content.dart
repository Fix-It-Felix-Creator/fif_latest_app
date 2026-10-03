import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';

/// A responsive content wrapper that adapts padding and max width based on device
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;
  final bool scrollable;
  final ScrollPhysics? physics;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.useSafeArea = true,
    this.scrollable = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    Widget content = child;

    // Apply max width constraint
    final effectiveMaxWidth = maxWidth ?? _getDefaultMaxWidth(deviceInfo);
    if (effectiveMaxWidth != double.infinity) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: content,
        ),
      );
    }

    // Apply padding
    final effectivePadding = padding ?? _getDefaultPadding(deviceInfo);
    content = Padding(padding: effectivePadding, child: content);

    // Make scrollable if needed
    if (scrollable) {
      content = SingleChildScrollView(physics: physics, child: content);
    }

    // Apply safe area if needed
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }

  double _getDefaultMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 1200;
    if (deviceInfo.isTablet) {
      return deviceInfo.isLandscape ? 900 : 700;
    }
    return double.infinity; // Full width on mobile
  }

  EdgeInsets _getDefaultPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return const EdgeInsets.all(32);
    }
    if (deviceInfo.isTablet) {
      return EdgeInsets.symmetric(
        horizontal: deviceInfo.isLandscape ? 32 : 24,
        vertical: 24,
      );
    }
    // Mobile
    return EdgeInsets.symmetric(
      horizontal: deviceInfo.isLandscape ? 24 : 16,
      vertical: 16,
    );
  }
}

/// A responsive list view that adapts to different screen sizes
class ResponsiveListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? header;
  final Widget? footer;

  const ResponsiveListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.maxWidth,
    this.shrinkWrap = false,
    this.physics,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    final effectiveMaxWidth = maxWidth ?? _getDefaultMaxWidth(deviceInfo);
    final effectivePadding = padding ?? _getDefaultPadding(deviceInfo);

    Widget listView = ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: effectivePadding,
      itemCount:
          itemCount + (header != null ? 1 : 0) + (footer != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return header!;
        }
        if (footer != null && index == itemCount + (header != null ? 1 : 0)) {
          return footer!;
        }
        final adjustedIndex = index - (header != null ? 1 : 0);
        return itemBuilder(context, adjustedIndex);
      },
    );

    if (effectiveMaxWidth != double.infinity) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: listView,
        ),
      );
    }

    return listView;
  }

  double _getDefaultMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 800;
    if (deviceInfo.isTablet) return deviceInfo.isLandscape ? 700 : 600;
    return double.infinity;
  }

  EdgeInsets _getDefaultPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    if (deviceInfo.isTablet) {
      return EdgeInsets.symmetric(
        horizontal: deviceInfo.isLandscape ? 24 : 20,
        vertical: 16,
      );
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}

/// A responsive grid that adapts columns based on screen size
class ResponsiveGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final int? mobileColumns;
  final int? tabletPortraitColumns;
  final int? tabletLandscapeColumns;
  final int? desktopColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mobileColumns,
    this.tabletPortraitColumns,
    this.tabletLandscapeColumns,
    this.desktopColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1,
    this.padding,
    this.maxWidth,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    final columns = _getColumns(deviceInfo);
    final effectiveMaxWidth = maxWidth ?? _getDefaultMaxWidth(deviceInfo);
    final effectivePadding = padding ?? _getDefaultPadding(deviceInfo);
    final scaledSpacing = spacing * context.spacingMultiplier;
    final scaledRunSpacing = runSpacing * context.spacingMultiplier;

    Widget gridView = GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: effectivePadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: scaledSpacing,
        mainAxisSpacing: scaledRunSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );

    if (effectiveMaxWidth != double.infinity) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: gridView,
        ),
      );
    }

    return gridView;
  }

  int _getColumns(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return desktopColumns ?? 4;
    }
    if (deviceInfo.isTablet) {
      if (deviceInfo.isLandscape) {
        return tabletLandscapeColumns ?? tabletPortraitColumns ?? 3;
      }
      return tabletPortraitColumns ?? 2;
    }
    // Mobile
    if (deviceInfo.isLandscape) {
      return mobileColumns ?? 2;
    }
    return mobileColumns ?? 1;
  }

  double _getDefaultMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 1200;
    if (deviceInfo.isTablet) return 1000;
    return double.infinity;
  }

  EdgeInsets _getDefaultPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) {
      return const EdgeInsets.all(24);
    }
    if (deviceInfo.isTablet) {
      return const EdgeInsets.all(20);
    }
    return const EdgeInsets.all(16);
  }
}
