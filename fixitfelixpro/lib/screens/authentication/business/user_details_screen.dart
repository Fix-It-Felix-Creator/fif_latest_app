import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/enum.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/utils/common_toasts.dart';
import 'address_details_screen.dart';

class BusinessUserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BusinessUserDetailsScreen({super.key, required this.userData});

  @override
  State<BusinessUserDetailsScreen> createState() =>
      _BusinessUserDetailsScreenState();
}

class _BusinessUserDetailsScreenState extends State<BusinessUserDetailsScreen>
    with SingleTickerProviderStateMixin {
  var _formKey = GlobalKey<ShadFormState>();
  BusinessRole? _selectedRole = BusinessRole.owner;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Owner FocusNodes
  late FocusNode _businessNameFocusNode;
  late FocusNode _phoneFocusNode;
  late FocusNode _businessEmailFocusNode;
  late FocusNode _businessRegIdFocusNode;

  // Staff FocusNodes
  late FocusNode _firstNameFocusNode;
  late FocusNode _lastNameFocusNode;
  late FocusNode _staffPhoneFocusNode;

  final List<RoleItem> _roles = [
    RoleItem(
      role: BusinessRole.owner,
      name: 'Owner',
      icon: LucideIcons.briefcase,
    ),
    RoleItem(
      role: BusinessRole.admin,
      name: 'Admin',
      icon: LucideIcons.userCog,
    ),
    RoleItem(
      role: BusinessRole.customerSupport,
      name: 'Customer Support',
      icon: LucideIcons.headphones,
    ),
  ];

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

    _businessNameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _businessEmailFocusNode = FocusNode();
    _businessRegIdFocusNode = FocusNode();

    _firstNameFocusNode = FocusNode();
    _lastNameFocusNode = FocusNode();
    _staffPhoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _animationController.dispose();

    _businessNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _businessEmailFocusNode.dispose();
    _businessRegIdFocusNode.dispose();

    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _staffPhoneFocusNode.dispose();
    super.dispose();
  }

  String? _validateBusinessName(String value) {
    if (value.isEmpty) {
      return 'Business name is required';
    }
    if (value.length < 2) {
      return 'Business name must be at least 2 characters';
    }
    return null;
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

  String? _validateEmail(String value) {
    if (value.isEmpty) {
      return null; // Optional field
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates UK and Global Business Registration ID formats:
  /// - UK Company Registration Number (CRN): 8 chars (e.g., 12345678, SC123456, NI123456)
  /// - UK VAT Number: GB + 9/12 digits (e.g., GB123456789)
  /// - DUNS Number: 9 digits (e.g., 123456789)
  /// - EU VAT: 2 letter country code + 8-12 alphanumeric (e.g., DE123456789)
  /// - EIN (US): 9 digits with hyphen (e.g., 12-3456789)
  /// - ABN (Australia): 11 digits (e.g., 12345678901)
  String? _validateBusinessRegistrationId(String value) {
    if (value.isEmpty) {
      return null; // Optional field
    }

    final trimmed = value.trim().toUpperCase().replaceAll(' ', '');

    // UK Company Registration Number (CRN)
    // Format: 8 digits OR 2 letters (SC, NI, OC, etc.) + 6 digits
    final ukCrnRegex = RegExp(r'^([0-9]{8}|[A-Z]{2}[0-9]{6})$');
    if (ukCrnRegex.hasMatch(trimmed)) {
      return null; // Valid UK CRN
    }

    // UK VAT Number
    // Format: GB + 9 digits OR GB + 12 digits (for branch traders)
    final ukVatRegex = RegExp(r'^GB([0-9]{9}|[0-9]{12})$');
    if (ukVatRegex.hasMatch(trimmed)) {
      return null; // Valid UK VAT
    }

    // DUNS Number (Global)
    // Format: 9 digits
    final dunsRegex = RegExp(r'^[0-9]{9}$');
    if (dunsRegex.hasMatch(trimmed)) {
      return null; // Valid DUNS
    }

    // EU VAT Number (Various countries)
    // Format: 2 letter country code + 8-12 alphanumeric
    final euVatRegex = RegExp(r'^[A-Z]{2}[A-Z0-9]{8,12}$');
    if (euVatRegex.hasMatch(trimmed)) {
      return null; // Valid EU VAT
    }

    // US EIN (Employer Identification Number)
    // Format: 9 digits (with or without hyphen: 12-3456789 or 123456789)
    final einRegex = RegExp(r'^[0-9]{2}-?[0-9]{7}$');
    if (einRegex.hasMatch(trimmed)) {
      return null; // Valid US EIN
    }

    // Australian Business Number (ABN)
    // Format: 11 digits
    final abnRegex = RegExp(r'^[0-9]{11}$');
    if (abnRegex.hasMatch(trimmed)) {
      return null; // Valid ABN
    }

    // Generic alphanumeric (fallback for other countries)
    // Allow 6-15 alphanumeric characters
    final genericRegex = RegExp(r'^[A-Z0-9]{6,15}$');
    if (genericRegex.hasMatch(trimmed)) {
      return null; // Valid generic registration ID
    }

    return 'Enter a valid registration ID (e.g., UK: 12345678, VAT: GB123456789)';
  }

  void _onRoleSelected(RoleItem role) {
    setState(() {
      _selectedRole = role.role;
      _formKey = GlobalKey<ShadFormState>();
    });
  }

  void _onContinue() {
    if (_selectedRole == null) {
      CommonToasts.error(
        context,
        'You must select your role to continue',
        title: 'Please select a role',
      );
      return;
    }

    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;

      debugPrint('Form values: $values');
      debugPrint('Selected role: $_selectedRole');

      // Merge with existing userData and add new fields based on role
      Map<String, dynamic> userData;
      if (_selectedRole == BusinessRole.owner) {
        userData = {
          ...widget.userData,
          'role': BusinessRole.owner.name,
          'businessName': values?['businessName'] ?? '',
          'phoneNumber': values?['phoneNumber'] ?? '',
          'businessEmail': values?['businessEmail'] ?? '',
          'businessRegistrationId': values?['businessRegistrationId'] ?? '',
        };
      } else {
        userData = {
          ...widget.userData,
          'role': _selectedRole == BusinessRole.admin
              ? BusinessRole.admin.name
              : BusinessRole.customerSupport.name,
          'firstName': values?['firstName'] ?? '',
          'lastName': values?['lastName'] ?? '',
          'phoneNumber': values?['phoneNumber2'] ?? '',
        };
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BusinessAddressDetailsScreen(userData: userData),
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

                              // Role Selection Cards
                              _buildRoleSelection(theme, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

                              // Conditional Form Fields
                              if (_selectedRole != null) ...[
                                _buildFormCard(theme, deviceInfo),
                              ],
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
            'Business Details',
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
          'Select Your Role',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your role in the business to continue',
          style: theme.textTheme.muted,
        ),
      ],
    );
  }


  Widget _buildRoleSelection(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _roles.asMap().entries.map((entry) {
          final index = entry.key;
          final role = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : (deviceInfo.isTablet ? 6 : 4),
                right: index == _roles.length - 1
                    ? 0
                    : (deviceInfo.isTablet ? 6 : 4),
              ),
              child: _buildRoleCard(theme, role, deviceInfo),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoleCard(
    ShadThemeData theme,
    RoleItem role,
    DeviceInfo deviceInfo,
  ) {
    final isSelected = _selectedRole == role.role;

    return GestureDetector(
      onTap: () => _onRoleSelected(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(deviceInfo.isTablet ? 18 : 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.background,
          borderRadius: BorderRadius.circular(deviceInfo.isTablet ? 16 : 14),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(deviceInfo.isTablet ? 14 : 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(
                  deviceInfo.isTablet ? 12 : 10,
                ),
              ),
              child: Icon(
                role.icon,
                size: deviceInfo.isTablet ? 28 : 24,
                color: isSelected
                    ? theme.colorScheme.primaryForeground
                    : theme.colorScheme.foreground,
              ),
            ),
            SizedBox(height: deviceInfo.isTablet ? 10 : 8),
            Text(
              role.name,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    return ShadForm(
      key: _formKey,
      child: _selectedRole == BusinessRole.owner
          ? _buildOwnerFields(theme, deviceInfo)
          : _buildStaffFields(theme, deviceInfo),
    );
  }

  Widget _buildOwnerFields(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business Name Field
        ShadInputFormField(
          id: 'businessName',
          focusNode: _businessNameFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _phoneFocusNode.requestFocus(),
          label: Text(
            'Business Name',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          placeholder: const Text('Enter your business name'),
          validator: _validateBusinessName,
          textCapitalization: TextCapitalization.words,
          leading: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              LucideIcons.building2,
              size: deviceInfo.isTablet ? 20 : 18,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),

        // Phone Number Field
        ShadInputFormField(
          id: 'phoneNumber',
          focusNode: _phoneFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _businessEmailFocusNode.requestFocus(),
          label: Text(
            'Phone Number',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
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

        // Business Email (Optional)
        ShadInputFormField(
          id: 'businessEmail',
          focusNode: _businessEmailFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _businessRegIdFocusNode.requestFocus(),
          label: Row(
            children: [
              Text(
                'Business Email',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          placeholder: const Text('business@example.com'),
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
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

        // Business Registration ID (Optional)
        ShadInputFormField(
          id: 'businessRegistrationId',
          focusNode: _businessRegIdFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onContinue(),
          label: Row(
            children: [
              Text(
                'Business Registration ID',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          placeholder: const Text('e.g., 12345678'),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          validator: _validateBusinessRegistrationId,
          leading: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              LucideIcons.fileText,
              size: deviceInfo.isTablet ? 20 : 18,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffFields(ShadThemeData theme, DeviceInfo deviceInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Name Field
        ShadInputFormField(
          id: 'firstName',
          focusNode: _firstNameFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
          label: Text(
            'First Name',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          placeholder: const Text('Enter your first name'),
          validator: _validateFirstName,
          textCapitalization: TextCapitalization.words,
          leading: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              LucideIcons.user,
              size: deviceInfo.isTablet ? 20 : 18,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),

        // Last Name Field
        ShadInputFormField(
          id: 'lastName',
          focusNode: _lastNameFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _staffPhoneFocusNode.requestFocus(),
          label: Text(
            'Last Name',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          placeholder: const Text('Enter your last name'),
          validator: _validateLastName,
          textCapitalization: TextCapitalization.words,
          leading: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              LucideIcons.user,
              size: deviceInfo.isTablet ? 20 : 18,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ),
        SizedBox(height: deviceInfo.isTablet ? 20 : 16),

        // Phone Number Field
        ShadInputFormField(
          id: 'phoneNumber2',
          focusNode: _staffPhoneFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onContinue(),
          label: Text(
            'Phone Number',
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
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
      ],
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

class RoleItem {
  final BusinessRole role;
  final String name;
  final IconData icon;

  const RoleItem({required this.role, required this.name, required this.icon});
}
