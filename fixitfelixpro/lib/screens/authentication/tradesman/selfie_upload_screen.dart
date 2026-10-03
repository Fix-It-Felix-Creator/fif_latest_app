import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../core/utils/image_validator.dart';
import 'trade_qualifications_screen.dart';

/// Selfie upload screen for tradesman registration
/// Captures a selfie photo for identity verification
/// Enforces image size limits from ImageLimitsConfigModel
class SelfieUploadScreen extends StatefulWidget {
  final Map<String, dynamic> previousData;

  const SelfieUploadScreen({super.key, required this.previousData});

  @override
  State<SelfieUploadScreen> createState() => _SelfieUploadScreenState();
}

class _SelfieUploadScreenState extends State<SelfieUploadScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _selfieImage;
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

  Future<void> _takeSelfie() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Validate file size using ImageValidator with loaded limits
        final validationError = await ImageValidator.validateSelfie(file);

        if (validationError != null) {
          if (mounted) {
            CommonToasts.error(
              context,
              validationError,
              title: 'Image Too Large',
            );
          }
          return;
        }

        setState(() {
          _selfieImage = file;
        });
      }
    } catch (e) {
      debugPrint('Error taking selfie: $e');
      if (mounted) {
        CommonToasts.error(
          context,
          'Failed to capture selfie. Please try again.',
        );
      }
    }
  }

  void _removeSelfie() {
    setState(() {
      _selfieImage = null;
    });
  }

  void _onSubmit() {
    if (_selfieImage != null) {
      debugPrint('Selfie uploaded');

      // Combine with previous data
      final Map<String, dynamic> allData = {
        ...widget.previousData,
        'selfieImagePath': _selfieImage?.path ?? '',
      };

      debugPrint('All data: $allData');

      // Navigate to trade qualifications screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TradeQualificationsScreen(previousData: allData),
        ),
      );
    }
  }

  double _getMaxWidth(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return 500;
    if (deviceInfo.isTablet) return 480;
    return 400;
  }

  EdgeInsets _getContentPadding(DeviceInfo deviceInfo) {
    if (deviceInfo.isDesktop) return const EdgeInsets.all(40);
    if (deviceInfo.isTablet) return const EdgeInsets.all(32);
    return const EdgeInsets.all(24);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.background),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
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
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Info Card
                              _buildInfoCard(theme, isDark, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Selfie Upload Section
                              _buildSelfieUploadSection(
                                theme,
                                isDark,
                                deviceInfo,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Fixed bottom button
                _buildBottomButton(theme, deviceInfo),
              ],
            ),
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
            'Upload Selfie',
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
          'Upload Selfie',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Take a clear photo of your face', style: theme.textTheme.muted),
      ],
    );
  }

  Widget _buildInfoCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Container(
      padding: EdgeInsets.all(deviceInfo.isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(deviceInfo.isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  LucideIcons.userCheck,
                  size: deviceInfo.isTablet ? 24 : 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 14 : 12),
              Text(
                'Why We Need Your Selfie',
                style:
                    (deviceInfo.isTablet
                            ? theme.textTheme.h4
                            : theme.textTheme.large)
                        .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Description
          Text(
            'A selfie helps us verify that you are the person in the identity document. Please take a clear photo of your face in good lighting.',
            style:
                (deviceInfo.isTablet
                        ? theme.textTheme.p
                        : theme.textTheme.small)
                    .copyWith(
                      color: theme.colorScheme.mutedForeground,
                      height: 1.5,
                    ),
          ),
          SizedBox(height: deviceInfo.isTablet ? 20 : 16),

          // Tips
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(deviceInfo.isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tips for a good selfie:',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.p
                              : theme.textTheme.small)
                          .copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: deviceInfo.isTablet ? 10 : 8),
                _buildTipItem(theme, deviceInfo, 'Face the camera directly'),
                _buildTipItem(theme, deviceInfo, 'Ensure good lighting'),
                _buildTipItem(theme, deviceInfo, 'Remove glasses or hats'),
                _buildTipItem(theme, deviceInfo, 'Keep a neutral expression'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
    String text,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: deviceInfo.isTablet ? 6 : 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.check,
              size: deviceInfo.isTablet ? 14 : 12,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: deviceInfo.isTablet ? 10 : 8),
          Text(
            text,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfieUploadSection(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    final hasImage = _selfieImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Selfie',
          style:
              (deviceInfo.isTablet ? theme.textTheme.h4 : theme.textTheme.large)
                  .copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.card.withValues(alpha: 0.8)
                : theme.colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasImage
                  ? theme.colorScheme.primary
                  : theme.colorScheme.border.withValues(alpha: 0.5),
              width: hasImage ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                // Image preview
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(
                        _selfieImage!,
                        width: double.infinity,
                        height: deviceInfo.isTablet ? 350 : 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Success badge
                    Positioned(
                      top: deviceInfo.isTablet ? 14 : 12,
                      right: deviceInfo.isTablet ? 14 : 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: deviceInfo.isTablet ? 14 : 12,
                          vertical: deviceInfo.isTablet ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: deviceInfo.isTablet ? 16 : 14,
                              color: theme.colorScheme.primaryForeground,
                            ),
                            SizedBox(width: deviceInfo.isTablet ? 6 : 4),
                            Text(
                              'Captured',
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.primaryForeground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Overlay with actions
                    Positioned(
                      bottom: deviceInfo.isTablet ? 14 : 12,
                      right: deviceInfo.isTablet ? 14 : 12,
                      child: Row(
                        children: [
                          // Remove button
                          GestureDetector(
                            onTap: _removeSelfie,
                            child: Container(
                              padding: EdgeInsets.all(
                                deviceInfo.isTablet ? 12 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.destructive,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                LucideIcons.trash2,
                                size: deviceInfo.isTablet ? 20 : 18,
                                color: theme.colorScheme.destructiveForeground,
                              ),
                            ),
                          ),
                          SizedBox(width: deviceInfo.isTablet ? 10 : 8),
                          // Retake button
                          GestureDetector(
                            onTap: _takeSelfie,
                            child: Container(
                              padding: EdgeInsets.all(
                                deviceInfo.isTablet ? 12 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                LucideIcons.refreshCw,
                                size: deviceInfo.isTablet ? 20 : 18,
                                color: theme.colorScheme.primaryForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Upload area
                GestureDetector(
                  onTap: _takeSelfie,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(deviceInfo.isTablet ? 56 : 48),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            deviceInfo.isTablet ? 24 : 20,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.muted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.camera,
                            size: deviceInfo.isTablet ? 56 : 48,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                        SizedBox(height: deviceInfo.isTablet ? 20 : 16),
                        Text(
                          'Take a Selfie',
                          style:
                              (deviceInfo.isTablet
                                      ? theme.textTheme.h3
                                      : theme.textTheme.h4)
                                  .copyWith(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: deviceInfo.isTablet ? 6 : 4),
                        Text(
                          'Tap to open camera',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton(ShadThemeData theme, DeviceInfo deviceInfo) {
    final canSubmit = _selfieImage != null;

    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: ShadButton(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            enabled: canSubmit,
            onPressed: canSubmit ? _onSubmit : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Submit and Verify',
                  style: TextStyle(
                    color: canSubmit
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.circleCheck,
                  size: 18,
                  color: canSubmit
                      ? theme.colorScheme.primaryForeground
                      : theme.colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
