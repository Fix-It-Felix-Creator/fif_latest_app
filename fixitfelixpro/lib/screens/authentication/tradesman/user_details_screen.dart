import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/responsive/responsive.dart';
import 'address_details_screen.dart';
import 'company_details_screen.dart';

class TradesmanUserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TradesmanUserDetailsScreen({super.key, required this.userData});

  @override
  State<TradesmanUserDetailsScreen> createState() =>
      _TradesmanUserDetailsScreenState();
}

class _TradesmanUserDetailsScreenState extends State<TradesmanUserDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  final _phoneController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasCompany = false;

  late FocusNode _firstNameFocusNode;
  late FocusNode _lastNameFocusNode;
  late FocusNode _phoneFocusNode;

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

    _firstNameFocusNode = FocusNode();
    _lastNameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String? _validateFirstName(String value) {
    if (value.isEmpty) {
      return 'First name is required';
    }
    if (value.length < 2) {
      return 'First name must be at least 2 characters';
    }
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return 'First name can only contain letters';
    }
    return null;
  }

  String? _validateLastName(String value) {
    if (value.isEmpty) {
      return 'Last name is required';
    }
    if (value.length < 2) {
      return 'Last name must be at least 2 characters';
    }
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return 'Last name can only contain letters';
    }
    return null;
  }

  String? _validatePhoneNumber(String value) {
    if (value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Please enter a valid 11-digit UK phone number';
    }
    if (!value.startsWith('0')) {
      return 'Phone number must start with 0';
    }
    return null;
  }

  void _onContinue() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;

      debugPrint('Form values: $values');

      // Merge with existing userData and add new fields
      final Map<String, dynamic> userData = {
        ...widget.userData,
        'firstName': values?['firstName'] ?? '',
        'lastName': values?['lastName'] ?? '',
        'phoneNumber': values?['phoneNumber'] ?? '',
      };

      if (_hasCompany) {
        // Navigate to company details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TradesmanCompanyDetailsScreen(userData: userData),
          ),
        );
      } else {
        // Navigate directly to address details (original flow)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TradesmanAddressDetailsScreen(userData: userData),
          ),
        );
      }
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
                              SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                              // Form Card
                              _buildFormCard(theme, isDark, deviceInfo),
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
            'Tradesman Details',
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
          'Personal Information',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Please provide your personal details to continue',
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
            // First Name Field
            _buildInputField(
              theme,
              deviceInfo,
              id: 'firstName',
              label: 'First Name',
              placeholder: 'Enter your first name',
              icon: LucideIcons.user,
              validator: _validateFirstName,
              textCapitalization: TextCapitalization.words,
              focusNode: _firstNameFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Last Name Field
            _buildInputField(
              theme,
              deviceInfo,
              id: 'lastName',
              label: 'Last Name',
              placeholder: 'Enter your last name',
              icon: LucideIcons.user,
              validator: _validateLastName,
              textCapitalization: TextCapitalization.words,
              focusNode: _lastNameFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _phoneFocusNode.requestFocus(),
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Phone Number Field
            ShadInputFormField(
              id: 'phoneNumber',
              focusNode: _phoneFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onContinue(),
              label: Text(
                'Phone Number',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              controller: _phoneController,
              placeholder: const Text('07123 456789'),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.phone,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              validator: _validatePhoneNumber,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // "I have a company" checkbox
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasCompany = !_hasCompany;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _hasCompany
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _hasCompany
                            ? theme.colorScheme.primary
                            : theme.colorScheme.mutedForeground,
                        width: 1.5,
                      ),
                    ),
                    child: _hasCompany
                        ? const Icon(
                            LucideIcons.check,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I have a company',
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add your company details in the next step',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildBottomButton(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: ShadButton(
            width: double.infinity,
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
      ),
    );
  }
}
