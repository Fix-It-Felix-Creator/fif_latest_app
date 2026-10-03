import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';

/// A responsive button row that adapts to screen size
/// - Mobile portrait: Stacked vertically
/// - Mobile landscape / Tablet / Desktop: Horizontal row
class ResponsiveButtonRow extends StatelessWidget {
  final List<Widget> buttons;
  final double spacing;
  final MainAxisAlignment horizontalAlignment;
  final CrossAxisAlignment verticalAlignment;
  final bool reverseOnVertical;
  final bool forceHorizontal;
  final bool forceVertical;

  const ResponsiveButtonRow({
    super.key,
    required this.buttons,
    this.spacing = 12,
    this.horizontalAlignment = MainAxisAlignment.end,
    this.verticalAlignment = CrossAxisAlignment.stretch,
    this.reverseOnVertical = false,
    this.forceHorizontal = false,
    this.forceVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    final scaledSpacing = spacing * context.spacingMultiplier;

    // Determine if we should use horizontal layout
    bool useHorizontal;
    if (forceHorizontal) {
      useHorizontal = true;
    } else if (forceVertical) {
      useHorizontal = false;
    } else {
      // Use horizontal on larger screens or landscape
      useHorizontal =
          deviceInfo.isTablet || deviceInfo.isDesktop || deviceInfo.isLandscape;
    }

    final buttonList = reverseOnVertical && !useHorizontal
        ? buttons.reversed.toList()
        : buttons;

    if (useHorizontal) {
      return Row(
        mainAxisAlignment: horizontalAlignment,
        children: _addHorizontalSpacing(buttonList, scaledSpacing),
      );
    }

    return Column(
      crossAxisAlignment: verticalAlignment,
      children: _addVerticalSpacing(buttonList, scaledSpacing),
    );
  }

  List<Widget> _addHorizontalSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }

  List<Widget> _addVerticalSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }
}

/// A responsive form actions row (typically at bottom of forms)
class ResponsiveFormActions extends StatelessWidget {
  final Widget primaryAction;
  final Widget? secondaryAction;
  final Widget? tertiaryAction;
  final double spacing;

  const ResponsiveFormActions({
    super.key,
    required this.primaryAction,
    this.secondaryAction,
    this.tertiaryAction,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;
    final scaledSpacing = spacing * context.spacingMultiplier;

    // On mobile portrait, stack buttons
    if (deviceInfo.isMobile && deviceInfo.isPortrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primaryAction,
          if (secondaryAction != null) ...[
            SizedBox(height: scaledSpacing),
            secondaryAction!,
          ],
          if (tertiaryAction != null) ...[
            SizedBox(height: scaledSpacing),
            tertiaryAction!,
          ],
        ],
      );
    }

    // On larger screens, use row layout
    return Row(
      children: [
        if (tertiaryAction != null) ...[tertiaryAction!],
        const Spacer(),
        if (secondaryAction != null) ...[
          secondaryAction!,
          SizedBox(width: scaledSpacing),
        ],
        primaryAction,
      ],
    );
  }
}

/// Expands children to fill available space on tablet/desktop
class ResponsiveExpanded extends StatelessWidget {
  final Widget child;
  final int flex;
  final bool expandOnMobile;
  final bool expandOnTablet;
  final bool expandOnDesktop;

  const ResponsiveExpanded({
    super.key,
    required this.child,
    this.flex = 1,
    this.expandOnMobile = false,
    this.expandOnTablet = true,
    this.expandOnDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviceInfo = context.deviceInfo;

    bool shouldExpand;
    if (deviceInfo.isDesktop) {
      shouldExpand = expandOnDesktop;
    } else if (deviceInfo.isTablet) {
      shouldExpand = expandOnTablet;
    } else {
      shouldExpand = expandOnMobile;
    }

    if (shouldExpand) {
      return Expanded(flex: flex, child: child);
    }

    return child;
  }
}
