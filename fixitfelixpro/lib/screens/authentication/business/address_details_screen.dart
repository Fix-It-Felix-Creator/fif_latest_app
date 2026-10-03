import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/enum.dart';
import '../../../core/responsive/responsive.dart';
import '../../customers/address_search_screen.dart';
import '../confirm_details_screen.dart';
import '../widgets/postcode_search_button.dart';
import 'service_selection_screen.dart';

class BusinessAddressDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BusinessAddressDetailsScreen({super.key, required this.userData});

  @override
  State<BusinessAddressDetailsScreen> createState() =>
      _BusinessAddressDetailsScreenState();
}

class _BusinessAddressDetailsScreenState
    extends State<BusinessAddressDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late FocusNode _addressLine1FocusNode;
  late FocusNode _addressLine2FocusNode;
  late FocusNode _cityFocusNode;
  late FocusNode _countyFocusNode;
  late FocusNode _postcodeFocusNode;

  late TextEditingController _addressLine1Ctrl;
  late TextEditingController _addressLine2Ctrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _countyCtrl;
  late TextEditingController _postcodeCtrl;

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

    _addressLine1FocusNode = FocusNode();
    _addressLine2FocusNode = FocusNode();
    _cityFocusNode = FocusNode();
    _countyFocusNode = FocusNode();
    _postcodeFocusNode = FocusNode();

    final existing = widget.userData['address'];
    final seed = existing is Map ? Map<String, dynamic>.from(existing) : null;
    _addressLine1Ctrl =
        TextEditingController(text: seed?['addressLine1']?.toString() ?? '');
    _addressLine2Ctrl =
        TextEditingController(text: seed?['addressLine2']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: seed?['city']?.toString() ?? '');
    _countyCtrl =
        TextEditingController(text: seed?['county']?.toString() ?? '');
    _postcodeCtrl =
        TextEditingController(text: seed?['postcode']?.toString() ?? '');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _addressLine1FocusNode.dispose();
    _addressLine2FocusNode.dispose();
    _cityFocusNode.dispose();
    _countyFocusNode.dispose();
    _postcodeFocusNode.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _cityCtrl.dispose();
    _countyCtrl.dispose();
    _postcodeCtrl.dispose();
    super.dispose();
  }

  void _applyAddressSearchResult(AddressResult r) {
    setState(() {
      _addressLine1Ctrl.text = r.line1;
      _addressLine2Ctrl.text = r.line2 ?? '';
      _cityCtrl.text = r.city;
      _countyCtrl.text = r.county ?? '';
      _postcodeCtrl.text = r.postcode;
    });
    _formKey.currentState?.save();
  }

  bool get _isOwner => widget.userData['role'] == BusinessRole.owner.name;

  String? _validateAddressLine1(String value) {
    if (value.isEmpty) {
      return 'Address line 1 is required';
    }
    if (value.length < 5) {
      return 'Please enter a valid address';
    }
    return null;
  }

  String? _validateCity(String value) {
    if (value.isEmpty) {
      return 'City is required';
    }
    if (value.length < 2) {
      return 'Please enter a valid city name';
    }
    return null;
  }

  String? _validatePostcode(String value) {
    if (value.isEmpty) {
      return 'Postcode is required';
    }
    final postcodeRegex = RegExp(
      r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$',
      caseSensitive: false,
    );
    if (!postcodeRegex.hasMatch(value.trim())) {
      return 'Please enter a valid UK postcode';
    }
    return null;
  }

  void _onSubmit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;

      debugPrint('Address values: $values');

      // Prepare address data
      final Map<String, dynamic> addressData = {
        'addressLine1': values?['addressLine1'] ?? '',
        'addressLine2': values?['addressLine2'] ?? '',
        'city': values?['city'] ?? '',
        'county': values?['county'] ?? '',
        'postcode': values?['postcode'] ?? '',
      };

      // Combine with previous data
      final Map<String, dynamic> allData = {
        ...widget.userData,
        'address': addressData,
      };

      // Owner goes to service selection, staff goes to submit
      if (_isOwner) {
        // Owner flow - continue to service selection
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BusinessServiceSelectionScreen(previousData: allData),
          ),
        );
      } else {
        // Staff flow (Admin/CustomerSupport) - go to submit
        final Map<String, dynamic> submitData = {
          ...widget.userData,
          'address': addressData,
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmDetailsScreen(data: submitData),
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
            'Address Details',
            style:
                (deviceInfo.isTablet ? theme.textTheme.h2 : theme.textTheme.h3)
                    .copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ShadThemeData theme, DeviceInfo deviceInfo) {
    final title = _isOwner ? 'Business Address' : 'Personal Address';
    final description = _isOwner
        ? 'Please provide your business address details'
        : 'Please provide your personal address details';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(description, style: theme.textTheme.muted),
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
            // Postcode search — populates all fields from a UK address lookup
            PostcodeSearchButton(
              initialQuery: _postcodeCtrl.text.trim().isEmpty
                  ? null
                  : _postcodeCtrl.text.trim(),
              onPicked: _applyAddressSearchResult,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Address Line 1
            _buildInputField(
              theme,
              deviceInfo,
              id: 'addressLine1',
              label: 'Address Line 1',
              placeholder: 'House number and street name',
              icon: LucideIcons.house,
              validator: _validateAddressLine1,
              textCapitalization: TextCapitalization.words,
              focusNode: _addressLine1FocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addressLine2FocusNode.requestFocus(),
              controller: _addressLine1Ctrl,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Address Line 2 (Optional)
            _buildInputField(
              theme,
              deviceInfo,
              id: 'addressLine2',
              label: 'Address Line 2',
              placeholder: 'Apartment, suite, unit, etc.',
              icon: LucideIcons.building,
              isOptional: true,
              textCapitalization: TextCapitalization.words,
              focusNode: _addressLine2FocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _cityFocusNode.requestFocus(),
              controller: _addressLine2Ctrl,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // City / Town
            _buildInputField(
              theme,
              deviceInfo,
              id: 'city',
              label: 'City / Town',
              placeholder: 'Enter your city',
              icon: LucideIcons.mapPin,
              validator: _validateCity,
              textCapitalization: TextCapitalization.words,
              focusNode: _cityFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _countyFocusNode.requestFocus(),
              controller: _cityCtrl,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // County (Optional)
            _buildInputField(
              theme,
              deviceInfo,
              id: 'county',
              label: 'County',
              placeholder: 'Enter your county',
              icon: LucideIcons.map,
              isOptional: true,
              textCapitalization: TextCapitalization.words,
              focusNode: _countyFocusNode,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _postcodeFocusNode.requestFocus(),
              controller: _countyCtrl,
            ),
            SizedBox(height: deviceInfo.isTablet ? 20 : 16),

            // Postcode
            ShadInputFormField(
              id: 'postcode',
              controller: _postcodeCtrl,
              focusNode: _postcodeFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmit(),
              label: Text(
                'Postcode',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              placeholder: const Text('SW1A 1AA'),
              validator: _validatePostcode,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.mail,
                  size: deviceInfo.isTablet ? 20 : 18,
                  color: theme.colorScheme.mutedForeground,
                ),
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
    bool isOptional = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    TextEditingController? controller,
  }) {
    return ShadInputFormField(
      id: id,
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      label: isOptional
          ? Row(
              children: [
                Text(
                  label,
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
            )
          : Text(
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
    final buttonText = _isOwner ? 'Continue' : 'Submit';
    final buttonIcon = _isOwner ? LucideIcons.chevronRight : LucideIcons.check;

    return Container(
      padding: _getContentPadding(deviceInfo),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _getMaxWidth(deviceInfo)),
          child: ShadButton(
            width: double.infinity,
            height: deviceInfo.isTablet ? 52 : 48,
            onPressed: _onSubmit,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  buttonText,
                  style: TextStyle(
                    color: theme.colorScheme.primaryForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: deviceInfo.isTablet ? 16 : 15,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  buttonIcon,
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
