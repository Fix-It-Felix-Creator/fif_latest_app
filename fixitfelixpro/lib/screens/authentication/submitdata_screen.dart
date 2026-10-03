import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/enum.dart';
import '../../core/responsive/responsive.dart';
import '../../models/address_model.dart';

class SubmitDataScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const SubmitDataScreen({super.key, required this.data});

  @override
  State<SubmitDataScreen> createState() => _SubmitDataScreenState();
}

class _SubmitDataScreenState extends State<SubmitDataScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submitData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  AddressModel _buildAddress() {
    final addressData = widget.data['address'] as Map<String, dynamic>?;

    if (addressData != null) {
      return AddressModel(
        addressLine1: addressData['addressLine1'] ?? '',
        addressLine2: addressData['addressLine2'] ?? '',
        city: addressData['city'] ?? '',
        county: addressData['county'] ?? '',
        postcode: addressData['postcode'] ?? '',
      );
    }

    return AddressModel(
      addressLine1:
          widget.data['streetAddress'] ?? widget.data['addressLine1'] ?? '',
      addressLine2:
          widget.data['apartment'] ?? widget.data['addressLine2'] ?? '',
      city: widget.data['city'] ?? '',
      county: widget.data['county'] ?? '',
      postcode: widget.data['postcode'] ?? '',
    );
  }

  void _submitData() {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    final typeString = widget.data['accountCategoryType'] as String?;
    final accountType = AccountCategoryType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => AccountCategoryType.tradesman,
    );

    switch (accountType) {
      case AccountCategoryType.tradesman:
        _submitTradesmanData();
        break;
      case AccountCategoryType.business:
        _submitBusinessData();
        break;
      case AccountCategoryType.customer:
        break;
    }
  }

  void _submitTradesmanData() {
    final accountTypeStr = widget.data['accountCategoryType'] as String?;
    final accountType = AccountCategoryType.values.firstWhere(
      (e) => e.name == accountTypeStr,
      orElse: () => AccountCategoryType.tradesman,
    );

    final docTypeStr = widget.data['documentType'] as String?;
    final documentType = DocumentType.values.firstWhere(
      (e) => e.name == docTypeStr,
      orElse: () => DocumentType.passport,
    );

    context.read<AuthBloc>().add(
      TradesmanRegistrationEvent(
        accountCategoryType: accountType,
        firstName: widget.data['firstName'] ?? '',
        lastName: widget.data['lastName'] ?? '',
        phoneNumber: widget.data['phoneNumber'] ?? '',
        address: _buildAddress(),
        nationalInsuranceNumber: widget.data['nationalInsuranceNumber'],
        trade: widget.data['trade'],
        documentType: documentType,
        passportImagePath: widget.data['passportImagePath'],
        idCardFrontImagePath: widget.data['idCardFrontImagePath'],
        idCardBackImagePath: widget.data['idCardBackImagePath'],
        driverLicenseFrontImagePath: widget.data['driverLicenseFrontImagePath'],
        driverLicenseBackImagePath: widget.data['driverLicenseBackImagePath'],
        selfieImagePath: widget.data['selfieImagePath'],
        qualificationFiles: widget.data['qualificationFiles'] != null
            ? Map<String, String>.from(widget.data['qualificationFiles'] as Map)
            : null,
        hasCompany: widget.data['hasCompany'] == true,
        companyName: widget.data['companyName'],
        companiesHouseNumber: widget.data['companiesHouseNumber'],
        companyEmail: widget.data['companyEmail'],
        companyLandline: widget.data['companyLandline'],
        companyLogoImagePath: widget.data['companyLogoImagePath'],
      ),
    );
  }

  void _submitBusinessData() {
    final roleStr = widget.data['role'] as String?;
    final role = BusinessRole.values.firstWhere(
      (e) => e.name == roleStr,
      orElse: () => BusinessRole.owner,
    );

    context.read<AuthBloc>().add(
      BusinessRegistrationEvent(
        businessEmail: widget.data['businessEmail'] ?? '',
        businessRegistrationId: widget.data['businessRegistrationId'] ?? '',
        firstName: widget.data['firstName'] ?? '',
        lastName: widget.data['lastName'] ?? '',
        phoneNumber: widget.data['phoneNumber'] ?? '',
        address: _buildAddress(),
        businessName: widget.data['businessName'] ?? '',
        accountType: AccountCategoryType.business,
        role: role,
        trade: widget.data['trade'],
      ),
    );
  }

  void _retrySubmission() {
    setState(() {
      _hasSubmitted = false;
    });
    _submitData();
  }

  void _onSuccess() {
    context.read<AuthBloc>().add(const HandleAuthentication());
  }

  AccountCategoryType get _accountType {
    final typeString = widget.data['accountCategoryType'] as String?;
    return AccountCategoryType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => AccountCategoryType.tradesman,
    );
  }

  bool get _isTradesman => _accountType == AccountCategoryType.tradesman;

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
    final deviceInfo = context.deviceInfo;

    return Scaffold(
      body: Container(
        color: theme.colorScheme.background,
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isSuccess = state is TradesmanRegistrationCompleteState ||
                  state is BusinessRegistrationCompleteState;
              final isError = state is TradesmanRegistrationErrorState ||
                  state is BusinessRegistrationErrorState;
              final errorMessage = state is TradesmanRegistrationErrorState
                  ? state.message
                  : state is BusinessRegistrationErrorState
                      ? state.message
                      : '';

              if (isSuccess) {
                return _buildSuccessUI(theme, deviceInfo);
              }

              if (isError) {
                return _buildErrorUI(theme, deviceInfo, errorMessage);
              }

              return _buildLoadingUI(theme, deviceInfo);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingUI(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: Padding(
                padding: _getContentPadding(deviceInfo),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon
                    _SubmitGraphic(
                      animationController: _animationController,
                      theme: theme,
                      deviceInfo: deviceInfo,
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 48 : 40),

                    // Title
                    Text(
                      'Submitting Application',
                      style: (deviceInfo.isTablet
                              ? theme.textTheme.h1
                              : theme.textTheme.h2)
                          .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 12 : 8),

                    // Description
                    Text(
                      'Uploading your documents and information. This may take a moment...',
                      style: theme.textTheme.muted,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 40 : 32),

                    // Progress bar only
                    SizedBox(
                      width: deviceInfo.isTablet ? 300 : 260,
                      child: const ShadProgress(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessUI(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: Padding(
                padding: _getContentPadding(deviceInfo),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      padding: EdgeInsets.all(deviceInfo.isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.circleCheck,
                        color: Colors.green,
                        size: deviceInfo.isTablet ? 56 : 48,
                      ),
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 32 : 24),

                    // Title
                    Text(
                      'Success!',
                      style: (deviceInfo.isTablet
                              ? theme.textTheme.h1
                              : theme.textTheme.h2)
                          .copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 16 : 12),

                    // Description
                    Text(
                      _isTradesman
                          ? 'Your application has been submitted successfully. We will review your documents and get back to you shortly.'
                          : 'Your account has been created successfully. Welcome to FixItFelix Pro!',
                      style: theme.textTheme.muted.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Continue button
        Padding(
          padding: _getContentPadding(deviceInfo),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: ShadButton(
                width: double.infinity,
                height: deviceInfo.isTablet ? 52 : 48,
                backgroundColor: Colors.green,
                onPressed: _onSuccess,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: deviceInfo.isTablet ? 16 : 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
    String errorMessage,
  ) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: Padding(
                padding: _getContentPadding(deviceInfo),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error icon
                    Container(
                      padding: EdgeInsets.all(deviceInfo.isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.destructive
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.circleX,
                        color: theme.colorScheme.destructive,
                        size: deviceInfo.isTablet ? 56 : 48,
                      ),
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 32 : 24),

                    // Title
                    Text(
                      'Submission Failed',
                      style: (deviceInfo.isTablet
                              ? theme.textTheme.h1
                              : theme.textTheme.h2)
                          .copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.destructive,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: deviceInfo.isTablet ? 16 : 12),

                    // Description
                    Text(
                      errorMessage.isNotEmpty
                          ? errorMessage
                          : 'We couldn\'t submit your application. Please check your internet connection and try again.',
                      style: theme.textTheme.muted.copyWith(height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Retry & Back buttons
        Padding(
          padding: _getContentPadding(deviceInfo),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadButton(
                    width: double.infinity,
                    height: deviceInfo.isTablet ? 52 : 48,
                    onPressed: _retrySubmission,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.refreshCw,
                          size: 18,
                          color: theme.colorScheme.primaryForeground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: theme.colorScheme.primaryForeground,
                            fontWeight: FontWeight.w600,
                            fontSize: deviceInfo.isTablet ? 16 : 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ShadButton.outline(
                    width: double.infinity,
                    height: deviceInfo.isTablet ? 52 : 48,
                    onPressed: () => Navigator.pop(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.chevronLeft,
                          size: 18,
                          color: theme.colorScheme.foreground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Go Back',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: deviceInfo.isTablet ? 16 : 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitGraphic extends StatelessWidget {
  final AnimationController animationController;
  final ShadThemeData theme;
  final DeviceInfo deviceInfo;

  const _SubmitGraphic({
    required this.animationController,
    required this.theme,
    required this.deviceInfo,
  });

  @override
  Widget build(BuildContext context) {
    final size = deviceInfo.isTablet ? 160.0 : 130.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: animationController,
            builder: (context, child) {
              return Container(
                width: size * (0.75 + 0.25 * animationController.value),
                height: size * (0.75 + 0.25 * animationController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.15 * (1 - animationController.value),
                  ),
                ),
              );
            },
          ),

          // Solid outer circle
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.secondary,
            ),
          ),

          // Inner circle with icon
          Container(
            width: size * 0.55,
            height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
            child: AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -4 * animationController.value),
                  child: child,
                );
              },
              child: Icon(
                LucideIcons.cloudUpload,
                size: size * 0.22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
