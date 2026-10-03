import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/data/uk_trade_requirements.dart';
import '../../core/enum.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/common_toasts.dart';
import 'submitdata_screen.dart';

/// Confirmation screen shown before final submission
/// Displays a summary of all entered data for the user to review
class ConfirmDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ConfirmDetailsScreen({super.key, required this.data});

  @override
  State<ConfirmDetailsScreen> createState() => _ConfirmDetailsScreenState();
}

class _ConfirmDetailsScreenState extends State<ConfirmDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _confirmed = false;

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

  AccountCategoryType get _accountType {
    final typeString = widget.data['accountCategoryType'] as String?;
    return AccountCategoryType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => AccountCategoryType.tradesman,
    );
  }

  String get _accountTypeLabel {
    switch (_accountType) {
      case AccountCategoryType.tradesman:
        return 'Tradesman';
      case AccountCategoryType.business:
        return 'Business';
      case AccountCategoryType.customer:
        return 'Customer';
    }
  }

  void _onConfirm() {
    if (!_confirmed) {
      CommonToasts.warning(
        context,
        'Please tick the checkbox to confirm your information is accurate.',
        title: 'Please Confirm',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitDataScreen(data: widget.data),
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
                            SizedBox(height: deviceInfo.isTablet ? 28 : 24),
                            ..._buildSections(theme, deviceInfo),
                            SizedBox(height: deviceInfo.isTablet ? 24 : 20),
                            _buildConfirmationCheckbox(
                              theme,
                              isDark,
                              deviceInfo,
                            ),
                            const SizedBox(height: 24),
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
            'Review Details',
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
        // Title
        Text(
          'Review & Confirm',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review all details below before submitting your $_accountTypeLabel registration.',
          style: theme.textTheme.muted,
        ),
      ],
    );
  }

  List<Widget> _buildSections(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
  ) {
    final sections = <Widget>[];

    // Personal Details section (all account types)
    sections.add(
      _buildSectionCard(
        theme,
        deviceInfo,
        title: 'Personal Details',
        icon: LucideIcons.user,
        items: _buildPersonalItems(),
      ),
    );

    // Address section (all account types)
    final addressData = widget.data['address'] as Map<String, dynamic>?;
    if (addressData != null) {
      sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
      sections.add(
        _buildSectionCard(
          theme,
          deviceInfo,
          title: 'Address',
          icon: LucideIcons.mapPin,
          items: _buildAddressItems(addressData),
        ),
      );
    }

    // Tradesman-specific sections
    if (_accountType == AccountCategoryType.tradesman) {
      // Trade & Insurance
      sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
      sections.add(
        _buildSectionCard(
          theme,
          deviceInfo,
          title: 'Trade & Insurance',
          icon: LucideIcons.wrench,
          items: _buildTradeItems(),
        ),
      );

      // Identity Verification
      sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
      sections.add(
        _buildSectionCard(
          theme,
          deviceInfo,
          title: 'Identity Verification',
          icon: LucideIcons.shieldCheck,
          items: _buildIdentityItems(),
        ),
      );

      // Trade Qualifications
      final qualFiles =
          widget.data['qualificationFiles'] as Map<String, dynamic>?;
      if (qualFiles != null && qualFiles.isNotEmpty) {
        sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
        sections.add(
          _buildSectionCard(
            theme,
            deviceInfo,
            title: 'Trade Qualifications',
            icon: LucideIcons.graduationCap,
            items: _buildQualificationItems(qualFiles),
          ),
        );
      }

      // Company Details (if applicable)
      if (widget.data['hasCompany'] == true) {
        sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
        sections.add(
          _buildSectionCard(
            theme,
            deviceInfo,
            title: 'Company Details',
            icon: LucideIcons.building2,
            items: _buildCompanyItems(),
          ),
        );
      }
    }

    // Business-specific sections
    if (_accountType == AccountCategoryType.business) {
      sections.add(SizedBox(height: deviceInfo.isTablet ? 20 : 16));
      sections.add(
        _buildSectionCard(
          theme,
          deviceInfo,
          title: 'Business Details',
          icon: LucideIcons.building2,
          items: _buildBusinessItems(),
        ),
      );
    }

    return sections;
  }

  List<_DetailItem> _buildPersonalItems() {
    final items = <_DetailItem>[];
    final firstName = widget.data['firstName'] as String? ?? '';
    final lastName = widget.data['lastName'] as String? ?? '';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      items.add(_DetailItem('Full Name', '$firstName $lastName'.trim()));
    }

    final phone = widget.data['phoneNumber'] as String? ?? '';
    if (phone.isNotEmpty) {
      items.add(_DetailItem('Phone Number', phone));
    }

    return items;
  }

  List<_DetailItem> _buildAddressItems(Map<String, dynamic> addressData) {
    final items = <_DetailItem>[];

    final line1 = addressData['addressLine1'] as String? ?? '';
    if (line1.isNotEmpty) {
      items.add(_DetailItem('Address Line 1', line1));
    }

    final line2 = addressData['addressLine2'] as String? ?? '';
    if (line2.isNotEmpty) {
      items.add(_DetailItem('Address Line 2', line2));
    }

    final city = addressData['city'] as String? ?? '';
    if (city.isNotEmpty) {
      items.add(_DetailItem('City / Town', city));
    }

    final county = addressData['county'] as String? ?? '';
    if (county.isNotEmpty) {
      items.add(_DetailItem('County', county));
    }

    final postcode = addressData['postcode'] as String? ?? '';
    if (postcode.isNotEmpty) {
      items.add(_DetailItem('Postcode', postcode));
    }

    return items;
  }

  List<_DetailItem> _buildTradeItems() {
    final items = <_DetailItem>[];

    final trade = widget.data['trade'];
    if (trade != null) {
      if (trade is List) {
        items.add(_DetailItem('Trade', trade.map((e) => _capitalize(e.toString())).join(', ')));
      } else if (trade.toString().isNotEmpty) {
        items.add(_DetailItem('Trade', _capitalize(trade.toString())));
      }
    }

    final ni = widget.data['nationalInsuranceNumber'] as String? ?? '';
    if (ni.isNotEmpty) {
      items.add(_DetailItem('National Insurance', ni));
    }

    return items;
  }

  List<_DetailItem> _buildIdentityItems() {
    final items = <_DetailItem>[];

    final docTypeStr = widget.data['documentType'] as String? ?? '';
    if (docTypeStr.isNotEmpty) {
      String label;
      switch (docTypeStr) {
        case 'passport':
          label = 'Passport';
          break;
        case 'idCard':
          label = 'ID Card';
          break;
        case 'driverLicense':
          label = "Driver's License";
          break;
        default:
          label = docTypeStr;
      }
      items.add(_DetailItem('Document Type', label));
    }

    // Show which documents are uploaded
    final docUploads = <String>[];
    if (_hasFile('passportImagePath')) docUploads.add('Passport');
    if (_hasFile('idCardFrontImagePath')) docUploads.add('ID Card (Front)');
    if (_hasFile('idCardBackImagePath')) docUploads.add('ID Card (Back)');
    if (_hasFile('driverLicenseFrontImagePath')) {
      docUploads.add('License (Front)');
    }
    if (_hasFile('driverLicenseBackImagePath')) {
      docUploads.add('License (Back)');
    }
    if (_hasFile('selfieImagePath')) docUploads.add('Selfie');

    if (docUploads.isNotEmpty) {
      items.add(
        _DetailItem('Uploaded Documents', docUploads.join(', ')),
      );
    }

    return items;
  }

  List<_DetailItem> _buildCompanyItems() {
    final items = <_DetailItem>[];

    final name = widget.data['companyName'] as String? ?? '';
    if (name.isNotEmpty) {
      items.add(_DetailItem('Company Name', name));
    }

    final chNum = widget.data['companiesHouseNumber'] as String? ?? '';
    if (chNum.isNotEmpty) {
      items.add(_DetailItem('Companies House No.', chNum));
    }

    final email = widget.data['companyEmail'] as String? ?? '';
    if (email.isNotEmpty) {
      items.add(_DetailItem('Company Email', email));
    }

    final landline = widget.data['companyLandline'] as String? ?? '';
    if (landline.isNotEmpty) {
      items.add(_DetailItem('Business Landline', landline));
    }

    final hasLogo = _hasFile('companyLogoImagePath');
    items.add(
      _DetailItem('Company Logo', hasLogo ? 'Uploaded' : 'Not provided'),
    );

    return items;
  }

  List<_DetailItem> _buildBusinessItems() {
    final items = <_DetailItem>[];

    final bName = widget.data['businessName'] as String? ?? '';
    if (bName.isNotEmpty) {
      items.add(_DetailItem('Business Name', bName));
    }

    final bEmail = widget.data['businessEmail'] as String? ?? '';
    if (bEmail.isNotEmpty) {
      items.add(_DetailItem('Business Email', bEmail));
    }

    final bRegId = widget.data['businessRegistrationId'] as String? ?? '';
    if (bRegId.isNotEmpty) {
      items.add(_DetailItem('Registration ID', bRegId));
    }

    final roleStr = widget.data['role'] as String? ?? '';
    if (roleStr.isNotEmpty) {
      items.add(_DetailItem('Role', roleStr[0].toUpperCase() + roleStr.substring(1)));
    }

    final trade = widget.data['trade'];
    if (trade != null) {
      if (trade is List) {
        items.add(_DetailItem('Services', trade.map((e) => _capitalize(e.toString())).join(', ')));
      } else if (trade.toString().isNotEmpty) {
        items.add(_DetailItem('Services', _capitalize(trade.toString())));
      }
    }

    return items;
  }

  List<_DetailItem> _buildQualificationItems(Map<String, dynamic> qualFiles) {
    final items = <_DetailItem>[];
    final allReqs = UkTradeRequirements.allRequirements;

    for (final reqId in qualFiles.keys) {
      final matches = allReqs.where((r) => r.id == reqId);
      if (matches.isNotEmpty) {
        final req = matches.first;
        items.add(_DetailItem(req.name, req.isMandatory ? 'Mandatory' : 'Optional'));
      } else {
        items.add(_DetailItem(reqId, 'Uploaded'));
      }
    }

    items.add(_DetailItem(
      'Total Uploaded',
      '${qualFiles.length} document${qualFiles.length != 1 ? 's' : ''}',
    ));

    return items;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _hasFile(String key) {
    final path = widget.data[key] as String?;
    return path != null && path.isNotEmpty;
  }

  Widget _buildSectionCard(
    ShadThemeData theme,
    DeviceInfo deviceInfo, {
    required String title,
    required IconData icon,
    required List<_DetailItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              icon,
              size: deviceInfo.isTablet ? 18 : 16,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: deviceInfo.isTablet ? 10 : 8),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
                fontSize: deviceInfo.isTablet ? 13 : 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          thickness: 1.5,
          height: 1,
        ),
        SizedBox(height: deviceInfo.isTablet ? 14 : 10),

        // Detail rows
        ...items.map((item) => _buildDetailRow(theme, deviceInfo, item)),
      ],
    );
  }

  Widget _buildDetailRow(
    ShadThemeData theme,
    DeviceInfo deviceInfo,
    _DetailItem item,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: deviceInfo.isTablet ? 8 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: deviceInfo.isTablet ? 150 : 130,
            child: Text(
              item.label,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w400,
                fontSize: deviceInfo.isTablet ? 13 : 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: deviceInfo.isTablet ? 13 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCheckbox(
    ShadThemeData theme,
    bool isDark,
    DeviceInfo deviceInfo,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _confirmed = !_confirmed;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: deviceInfo.isTablet ? 26 : 24,
            height: deviceInfo.isTablet ? 26 : 24,
            decoration: BoxDecoration(
              color: _confirmed
                  ? Colors.green
                  : theme.colorScheme.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(7),
              border: _confirmed
                  ? null
                  : Border.all(
                      color: theme.colorScheme.border,
                      width: 1.5,
                    ),
            ),
            child: _confirmed
                ? const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : null,
          ),
          SizedBox(width: deviceInfo.isTablet ? 14 : 12),
          Expanded(
            child: Text(
              'I confirm that all information provided is accurate',
              style:
                  (deviceInfo.isTablet
                          ? theme.textTheme.p
                          : theme.textTheme.small)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        color: _confirmed
                            ? Colors.green.shade700
                            : theme.colorScheme.foreground,
                      ),
            ),
          ),
        ],
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
              // Back button
              Expanded(
                child: ShadButton.outline(
                  height: deviceInfo.isTablet ? 44 : 40,
                  onPressed: () => Navigator.pop(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 16,
                        color: theme.colorScheme.foreground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: deviceInfo.isTablet ? 14 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Confirm & Submit button
              Expanded(
                flex: 2,
                child: ShadButton(
                  height: deviceInfo.isTablet ? 44 : 40,
                  enabled: _confirmed,
                  onPressed: _confirmed ? _onConfirm : null,
                  backgroundColor:
                      _confirmed ? Colors.green : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirm & Submit',
                        style: TextStyle(
                          color: _confirmed
                              ? Colors.white
                              : theme.colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                          fontSize: deviceInfo.isTablet ? 14 : 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.circleCheck,
                        size: 18,
                        color: _confirmed
                            ? Colors.white
                            : theme.colorScheme.mutedForeground,
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

class _DetailItem {
  final String label;
  final String value;

  const _DetailItem(this.label, this.value);
}
