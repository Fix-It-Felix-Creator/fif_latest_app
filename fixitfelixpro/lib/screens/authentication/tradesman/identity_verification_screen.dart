import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/enum.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../core/utils/image_validator.dart';
import 'selfie_upload_screen.dart';

/// Identity verification screen for tradesman registration
/// Allows upload of government-issued ID documents (passport, ID card, driver license)
/// Enforces image size limits from ImageLimitsConfigModel
class IdentityVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> previousData;

  const IdentityVerificationScreen({super.key, required this.previousData});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with SingleTickerProviderStateMixin {
  DocumentType? _selectedDocumentType;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _uploadSectionKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // For passport (single image)
  File? _passportImage;

  // For ID Card (front and back)
  File? _idCardFront;
  File? _idCardBack;

  // For Driver License (front and back)
  File? _driverLicenseFront;
  File? _driverLicenseBack;

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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToUploadSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _uploadSectionKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source, String imageType) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);

        // Validate file size using ImageValidator with loaded limits
        final validationError = await ImageValidator.validateIdentityDocument(
          file,
        );

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
          switch (imageType) {
            case 'passport':
              _passportImage = file;
              break;
            case 'idCardFront':
              _idCardFront = file;
              break;
            case 'idCardBack':
              _idCardBack = file;
              break;
            case 'driverLicenseFront':
              _driverLicenseFront = file;
              break;
            case 'driverLicenseBack':
              _driverLicenseBack = file;
              break;
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        CommonToasts.error(
          context,
          'Failed to pick image. Please try again.',
        );
      }
    }
  }

  void _showImageSourceDialog(String imageType) {
    final theme = ShadTheme.of(context);
    final colorScheme = theme.colorScheme;

    showShadDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.imageUp,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Select Image Source',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Choose how you want to upload your document',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 20),
                    ShadButton(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.camera,
                            size: 18,
                            color: colorScheme.primaryForeground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Camera',
                            style: TextStyle(
                              color: colorScheme.primaryForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _pickImage(ImageSource.camera, imageType);
                      },
                    ),
                    const SizedBox(height: 10),
                    ShadButton.outline(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.image,
                            size: 18,
                            color: colorScheme.foreground,
                          ),
                          const SizedBox(width: 8),
                          const Text('Gallery'),
                        ],
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _pickImage(ImageSource.gallery, imageType);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(String imageType) {
    setState(() {
      switch (imageType) {
        case 'passport':
          _passportImage = null;
          break;
        case 'idCardFront':
          _idCardFront = null;
          break;
        case 'idCardBack':
          _idCardBack = null;
          break;
        case 'driverLicenseFront':
          _driverLicenseFront = null;
          break;
        case 'driverLicenseBack':
          _driverLicenseBack = null;
          break;
      }
    });
  }

  bool _canContinue() {
    if (_selectedDocumentType == null) return false;

    switch (_selectedDocumentType!) {
      case DocumentType.passport:
        return _passportImage != null;
      case DocumentType.idCard:
        return _idCardFront != null && _idCardBack != null;
      case DocumentType.driverLicense:
        return _driverLicenseFront != null && _driverLicenseBack != null;
    }
  }

  void _onContinue() {
    if (_canContinue()) {
      debugPrint('Document type: $_selectedDocumentType');

      // Combine with previous data and add document paths
      final Map<String, dynamic> allData = {
        ...widget.previousData,
        'documentType': _selectedDocumentType.toString().split('.').last,
        'passportImagePath': _passportImage?.path,
        'idCardFrontImagePath': _idCardFront?.path,
        'idCardBackImagePath': _idCardBack?.path,
        'driverLicenseFrontImagePath': _driverLicenseFront?.path,
        'driverLicenseBackImagePath': _driverLicenseBack?.path,
      };

      // Navigate to step 6
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelfieUploadScreen(previousData: allData),
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
                      controller: _scrollController,
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

                              // Document Type Selection
                              _buildDocumentTypeSection(
                                theme,
                                isDark,
                                deviceInfo,
                              ),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Image Upload Section (only show if document type selected)
                              if (_selectedDocumentType != null)
                                Container(
                                  key: _uploadSectionKey,
                                  child: _buildImageUploadSection(
                                    theme,
                                    isDark,
                                    deviceInfo,
                                  ),
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
          Expanded(
            child: Text(
              'Identity Verification',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.h2
                          : theme.textTheme.h3)
                      .copyWith(fontWeight: FontWeight.bold),
            ),
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
          'Identity Verification',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a valid government-issued ID document',
          style: theme.textTheme.muted,
        ),
      ],
    );
  }

  Widget _buildDocumentTypeSection(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Document Type',
          style:
              (deviceInfo.isTablet ? theme.textTheme.h4 : theme.textTheme.large)
                  .copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),
        _buildDocumentTypeCard(
          theme,
          isDark,
          deviceInfo,
          DocumentType.passport,
          'Passport',
          LucideIcons.bookOpen,
          Colors.blue,
        ),
        SizedBox(height: deviceInfo.isTablet ? 14 : 12),
        _buildDocumentTypeCard(
          theme,
          isDark,
          deviceInfo,
          DocumentType.idCard,
          'ID Card',
          LucideIcons.creditCard,
          Colors.green,
        ),
        SizedBox(height: deviceInfo.isTablet ? 14 : 12),
        _buildDocumentTypeCard(
          theme,
          isDark,
          deviceInfo,
          DocumentType.driverLicense,
          'Driver License',
          LucideIcons.car,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildDocumentTypeCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
    DocumentType type,
    String title,
    IconData icon,
    Color accentColor,
  ) {
    final isSelected = _selectedDocumentType == type;
    final isTablet = deviceInfo.isTablet;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? accentColor
              : theme.colorScheme.border.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDocumentType = type;
              _passportImage = null;
              _idCardFront = null;
              _idCardBack = null;
              _driverLicenseFront = null;
              _driverLicenseBack = null;
            });
            _scrollToUploadSection();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 12 : 10,
            ),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 44 : 38,
                  height: isTablet ? 44 : 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 22 : 20,
                    color: accentColor,
                  ),
                ),
                SizedBox(width: isTablet ? 14 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.p.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: isTablet ? 18 : 16,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Document',
          style:
              (deviceInfo.isTablet ? theme.textTheme.h4 : theme.textTheme.large)
                  .copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),
        if (_selectedDocumentType == DocumentType.passport) ...[
          _buildImageUploadCard(
            theme,
            isDark,
            deviceInfo,
            'Passport Photo Page',
            'Upload the photo page of your passport',
            _passportImage,
            'passport',
          ),
        ] else if (_selectedDocumentType == DocumentType.idCard) ...[
          _buildImageUploadCard(
            theme,
            isDark,
            deviceInfo,
            'ID Card - Front',
            'Upload the front side of your ID card',
            _idCardFront,
            'idCardFront',
          ),
          SizedBox(height: deviceInfo.isTablet ? 14 : 12),
          _buildImageUploadCard(
            theme,
            isDark,
            deviceInfo,
            'ID Card - Back',
            'Upload the back side of your ID card',
            _idCardBack,
            'idCardBack',
          ),
        ] else if (_selectedDocumentType == DocumentType.driverLicense) ...[
          _buildImageUploadCard(
            theme,
            isDark,
            deviceInfo,
            'Driver License - Front',
            'Upload the front side of your driver license',
            _driverLicenseFront,
            'driverLicenseFront',
          ),
          SizedBox(height: deviceInfo.isTablet ? 14 : 12),
          _buildImageUploadCard(
            theme,
            isDark,
            deviceInfo,
            'Driver License - Back',
            'Upload the back side of your driver license',
            _driverLicenseBack,
            'driverLicenseBack',
          ),
        ],
      ],
    );
  }

  Widget _buildImageUploadCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
    String title,
    String description,
    File? imageFile,
    String imageType,
  ) {
    final hasImage = imageFile != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.card.withValues(alpha: 0.8)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(10),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasImage)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: theme.colorScheme.primaryForeground,
                    ),
                  ),
              ],
            ),
          ),

          // Image Preview or Upload Button
          if (hasImage) ...[
            // Image preview
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.file(
                    imageFile,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                // Overlay with actions
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Row(
                    children: [
                      // Remove button
                      GestureDetector(
                        onTap: () => _removeImage(imageType),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.destructive,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: theme.colorScheme.destructiveForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Re-upload button
                      GestureDetector(
                        onTap: () => _showImageSourceDialog(imageType),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Icon(
                            LucideIcons.refreshCw,
                            size: 18,
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
              onTap: () => _showImageSourceDialog(imageType),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.border.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                width: double.infinity,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        LucideIcons.upload,
                        size: 28,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to upload',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use camera or choose from gallery',
                      textAlign: TextAlign.center,
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
    );
  }

  Widget _buildBottomButton(ShadThemeData theme, DeviceInfo deviceInfo) {
    final canContinue = _canContinue();

    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: ShadButton(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            enabled: canContinue,
            onPressed: canContinue ? _onContinue : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    color: canContinue
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: canContinue
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
