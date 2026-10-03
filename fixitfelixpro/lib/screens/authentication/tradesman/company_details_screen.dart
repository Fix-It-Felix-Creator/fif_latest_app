import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import 'address_details_screen.dart';

class TradesmanCompanyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TradesmanCompanyDetailsScreen({super.key, required this.userData});

  @override
  State<TradesmanCompanyDetailsScreen> createState() =>
      _TradesmanCompanyDetailsScreenState();
}

class _TradesmanCompanyDetailsScreenState
    extends State<TradesmanCompanyDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  File? _companyLogo;

  late FocusNode _companyNameFocusNode;
  late FocusNode _companiesHouseNumberFocusNode;
  late FocusNode _companyEmailFocusNode;
  late FocusNode _companyLandlineFocusNode;

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

    _companyNameFocusNode = FocusNode();
    _companiesHouseNumberFocusNode = FocusNode();
    _companyEmailFocusNode = FocusNode();
    _companyLandlineFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _companyNameFocusNode.dispose();
    _companiesHouseNumberFocusNode.dispose();
    _companyEmailFocusNode.dispose();
    _companyLandlineFocusNode.dispose();
    super.dispose();
  }

  String? _validateCompanyName(String value) {
    if (value.isEmpty) {
      return 'Company name is required';
    }
    if (value.length < 2) {
      return 'Company name must be at least 2 characters';
    }
    return null;
  }

  String? _validateCompaniesHouseNumber(String value) {
    if (value.isEmpty) {
      return 'Companies House number is required';
    }
    if (value.length != 8) {
      return 'Must be exactly 8 characters (e.g. AB123456)';
    }
    // Format: XX000000 or 00000000
    final regex = RegExp(r'^[A-Z]{2}\d{6}$|^\d{8}$', caseSensitive: false);
    if (!regex.hasMatch(value)) {
      return 'Invalid format (e.g. AB123456 or 12345678)';
    }
    return null;
  }

  String? _validateCompanyEmail(String value) {
    if (value.isEmpty) {
      return 'Company email is required';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateLandline(String value) {
    if (value.isEmpty) {
      return null; // Optional field
    }
    if (!value.startsWith('01') && !value.startsWith('02')) {
      return 'UK landline must start with 01 or 02';
    }
    if (value.length < 10 || value.length > 11) {
      return 'Please enter a valid UK landline number';
    }
    return null;
  }

  Future<void> _pickLogo() async {
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
                      'Choose how you want to upload your company logo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 20),
                    ShadButton(
                      width: double.infinity,
                      height: 48,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _pickImageFromSource(ImageSource.camera);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.camera,
                            size: 18,
                            color: colorScheme.primaryForeground,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              color: colorScheme.primaryForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ShadButton.outline(
                      width: double.infinity,
                      height: 48,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _pickImageFromSource(ImageSource.gallery);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.image, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'Choose from Gallery',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
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

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _companyLogo = File(pickedFile.path);
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

  void _onContinue() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;

      final Map<String, dynamic> userData = {
        ...widget.userData,
        'hasCompany': true,
        'companyName': values?['companyName'] ?? '',
        'companiesHouseNumber':
            (values?['companiesHouseNumber'] ?? '').toString().toUpperCase(),
        'companyEmail': values?['companyEmail'] ?? '',
        'companyLandline': values?['companyLandline'] ?? '',
        'companyLogoImagePath': _companyLogo?.path,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TradesmanAddressDetailsScreen(userData: userData),
        ),
      );
    }
  }

  void _onSkip() {
    final Map<String, dynamic> userData = {
      ...widget.userData,
      'hasCompany': false,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TradesmanAddressDetailsScreen(userData: userData),
      ),
    );
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
                _buildAppBar(theme, deviceInfo),
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
                              _buildHeaderSection(theme, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 32 : 28),
                              _buildFormCard(theme, isDark, deviceInfo),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomButtons(theme, deviceInfo),
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
            'Company Details',
            style:
                (deviceInfo.isTablet ? theme.textTheme.h2 : theme.textTheme.h3)
                    .copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: deviceInfo.isTablet ? 14 : 12,
            vertical: deviceInfo.isTablet ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.building2,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Optional Step',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),

        // Title
        Text(
          'Company Information',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your company details or skip this step',
          style: theme.textTheme.muted,
        ),
      ],
    );
  }

  Widget _buildFormCard(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return ShadForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Company Name
            _buildInputField(
              theme,
              deviceInfo,
              id: 'companyName',
              label: 'Company Name',
              placeholder: 'Enter company name',
              icon: LucideIcons.building2,
              validator: _validateCompanyName,
              textCapitalization: TextCapitalization.words,
              focusNode: _companyNameFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _companiesHouseNumberFocusNode.requestFocus(),
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Companies House Number
            ShadInputFormField(
              id: 'companiesHouseNumber',
              focusNode: _companiesHouseNumberFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _companyEmailFocusNode.requestFocus(),
              label: Text(
                'Companies House Number',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              placeholder: const Text('AB123456'),
              validator: _validateCompaniesHouseNumber,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(8),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.hash,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Company Logo (optional)
            _buildLogoUpload(theme, deviceInfo, isDark),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Company Email
            ShadInputFormField(
              id: 'companyEmail',
              focusNode: _companyEmailFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _companyLandlineFocusNode.requestFocus(),
              label: Text(
                'Company Email',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              placeholder: const Text('info@company.com'),
              keyboardType: TextInputType.emailAddress,
              validator: _validateCompanyEmail,
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.mail,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Business Landline (optional)
            ShadInputFormField(
              id: 'companyLandline',
              focusNode: _companyLandlineFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onContinue(),
              label: Row(
                children: [
                  Text(
                    'Business Landline',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.muted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              placeholder: const Text('01234 567890'),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: _validateLandline,
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.phone,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildLogoUpload(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Company Logo',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.foreground,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Optional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: double.infinity,
            height: _companyLogo != null ? 160 : 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.border,
                style: _companyLogo != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
            ),
            child: _companyLogo != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _companyLogo!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _companyLogo = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.destructive,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.imageUp,
                        size: 28,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload logo',
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required String id,
    required String label,
    required String placeholder,
    required IconData icon,
    String? Function(String)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return ShadInputFormField(
      id: id,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      label: Text(
        label,
        style: theme.textTheme.small.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.foreground,
        ),
      ),
      placeholder: Text(placeholder),
      validator: validator,
      textCapitalization: textCapitalization,
      leading: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          icon,
          size: deviceInfo.isTablet ? 20 : 18,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildBottomButtons(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: Row(
            children: [
              // Skip button
              Expanded(
                child: ShadButton.outline(
                  height: deviceInfo.isTablet ? 52 : 48,
                  onPressed: _onSkip,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: deviceInfo.isTablet ? 16 : 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Continue button
              Expanded(
                flex: 2,
                child: ShadButton(
                  height: deviceInfo.isTablet ? 52 : 48,
                  onPressed: _onContinue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          color: theme.colorScheme.primaryForeground,
                          fontWeight: FontWeight.w600,
                          fontSize: deviceInfo.isTablet ? 16 : 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: theme.colorScheme.primaryForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
