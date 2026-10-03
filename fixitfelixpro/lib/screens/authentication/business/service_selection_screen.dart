import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/tradesman_services.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import '../confirm_details_screen.dart';

class BusinessServiceSelectionScreen extends StatefulWidget {
  final Map<String, dynamic>? previousData;

  const BusinessServiceSelectionScreen({super.key, this.previousData});

  @override
  State<BusinessServiceSelectionScreen> createState() =>
      _BusinessServiceSelectionScreenState();
}

class _BusinessServiceSelectionScreenState
    extends State<BusinessServiceSelectionScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedServices = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleService(TradesmanServiceItem service) {
    setState(() {
      if (_selectedServices.contains(service.key)) {
        _selectedServices.remove(service.key);
      } else {
        _selectedServices.add(service.key);
      }
    });
  }

  void _onContinue() {
    if (_selectedServices.isEmpty) {
      CommonToasts.warning(
        context,
        'Please select at least one service to continue.',
        title: 'No Services Selected',
      );
      return;
    }

    // Print selected services
    debugPrint('Selected services: $_selectedServices');

    // Get selected service details for display
    final selectedNames = tradesmanServices
        .where((s) => _selectedServices.contains(s.key))
        .map((s) => '${s.name} = ${s.key}')
        .toList();

    for (final item in selectedNames) {
      debugPrint(item);
    }

    // Combine with previous data
    final Map<String, dynamic> allData = {
      ...?widget.previousData,
      'trade': _selectedServices.toList(),
    };

    debugPrint('All data: $allData');

    // Navigate to submit data screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDetailsScreen(data: allData),
      ),
    );
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 600;
    if (deviceInfo.isTablet) return 550;
    return 500;
  }

  EdgeInsets _getContentPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(40);
    if (deviceInfo.isTablet) return const EdgeInsets.all(32);
    return const EdgeInsets.all(24);
  }

  int _getColumnsPerRow(DeviceInfo deviceInfo) {
    if (deviceInfo.isTablet && deviceInfo.isLandscape) return 4;
    if (deviceInfo.isTablet) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: SafeArea(
          child: Column(
            children: [
              // Modern AppBar
              _buildAppBar(theme, deviceInfo),

              // Scrollable content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: _getContentPadding(deviceInfo),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _getMaxWidth(deviceInfo),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress Section
                            _buildProgressSection(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                            // Service Grid
                            _buildServiceGrid(theme, isDark, deviceInfo),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Continue Button
              _buildBottomButton(theme, isDark, deviceInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 20 : 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ShadButton.ghost(
              width: deviceInfo.isTablet ? 48 : 44,
              height: deviceInfo.isTablet ? 48 : 44,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Icon(
                LucideIcons.chevronLeft,
                size: deviceInfo.isTablet ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Services',
            style:
                (deviceInfo.isTablet ? theme.textTheme.h2 : theme.textTheme.h3)
                    .copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Select Your Services',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the services your business offers to customers',
          style: theme.textTheme.muted,
        ),
      ],
    );
  }

  Widget _buildServiceGrid(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final columnsPerRow = _getColumnsPerRow(deviceInfo);

    // Group services into rows
    final List<List<TradesmanServiceItem>> rows = [];
    for (int i = 0; i < tradesmanServices.length; i += columnsPerRow) {
      rows.add(
        tradesmanServices.sublist(
          i,
          i + columnsPerRow > tradesmanServices.length
              ? tradesmanServices.length
              : i + columnsPerRow,
        ),
      );
    }

    return Column(
      children: rows.map((row) {
        final missing = columnsPerRow - row.length;
        return Padding(
          padding: EdgeInsets.only(bottom: deviceInfo.isTablet ? 16 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...row.asMap().entries.map((entry) {
                  final index = entry.key;
                  final service = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : (deviceInfo.isTablet ? 8 : 6),
                        right: index == columnsPerRow - 1
                            ? 0
                            : (deviceInfo.isTablet ? 8 : 6),
                      ),
                      child: _buildServiceCard(theme, service, deviceInfo),
                    ),
                  );
                }),
                for (int i = 0; i < missing; i++)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceCard(
    ShadThemeData theme,
    TradesmanServiceItem service,
    DeviceInfo deviceInfo,
  ) {
    final isSelected = _selectedServices.contains(service.key);

    return GestureDetector(
      onTap: () => _toggleService(service),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(deviceInfo.isTablet ? 14 : 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.background,
          borderRadius: BorderRadius.circular(deviceInfo.isTablet ? 8 : 7),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(deviceInfo.isTablet ? 14 : 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.muted,
                  borderRadius: BorderRadius.circular(
                    deviceInfo.isTablet ? 6 : 5,
                  ),
                ),
                child: Icon(
                  service.icon,
                  size: deviceInfo.isTablet ? 28 : 24,
                  color: isSelected
                      ? theme.colorScheme.primaryForeground
                      : theme.colorScheme.foreground,
                ),
              ),
              SizedBox(height: deviceInfo.isTablet ? 10 : 8),
              // Service name
              _buildServiceName(theme, service.name, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceName(ShadThemeData theme, String name, bool isSelected) {
    final hasBreakPoint = name.contains(' ') || name.contains('/');
    final textColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.foreground;

    if (hasBreakPoint) {
      // Multi-word: allow wrapping at space or /
      return Text(
        name,
        style: theme.textTheme.small.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      // Single word: keep on one line, scale down if needed
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          name,
          style: theme.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      );
    }
  }

  Widget _buildBottomButton(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: ShadButton(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            onPressed: _selectedServices.isNotEmpty ? _onContinue : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedServices.isEmpty
                      ? 'Select Services to Continue'
                      : 'Continue (${_selectedServices.length} selected)',
                  style: TextStyle(
                    color: _selectedServices.isNotEmpty
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
                if (_selectedServices.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.primaryForeground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
