import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/responsive/responsive.dart';
import 'identity_verification_screen.dart';

class NationalInsuranceScreen extends StatefulWidget {
  final Map<String, dynamic> previousData;

  const NationalInsuranceScreen({super.key, required this.previousData});

  @override
  State<NationalInsuranceScreen> createState() =>
      _NationalInsuranceScreenState();
}

class _NationalInsuranceScreenState extends State<NationalInsuranceScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<ShadFormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late FocusNode _niFocusNode;

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

    _niFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _niFocusNode.dispose();
    super.dispose();
  }

  String? _validateNINumber(String value) {
    if (value.isEmpty) {
      return 'National Insurance Number is required';
    }

    // Remove spaces for validation
    final cleanValue = value.replaceAll(' ', '').toUpperCase();

    if (cleanValue.length != 9) {
      return 'NI Number must be 9 characters (e.g., AB123456C)';
    }

    // UK NI Number format: 2 letters + 6 digits + 1 letter
    // First two letters cannot be D, F, I, Q, U, V
    // Second letter cannot be O
    // Last letter can only be A, B, C, D
    final niRegex = RegExp(
      r'^[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z][0-9]{6}[A-D]$',
      caseSensitive: false,
    );

    if (!niRegex.hasMatch(cleanValue)) {
      return 'Please enter a valid UK NI Number';
    }

    return null;
  }

  void _onContinue() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState?.value;

      debugPrint('NI Number: $values');

      // Combine with previous data
      final Map<String, dynamic> allData = {
        ...widget.previousData,
        'nationalInsuranceNumber': values?['nationalInsuranceNumber'] ?? '',
      };

      // Navigate to step 5
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              IdentityVerificationScreen(previousData: allData),
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
                              SizedBox(height: deviceInfo.isTablet ? 32 : 28),

                              // Info Card
                              _buildInfoCard(theme, isDark, deviceInfo),
                              SizedBox(height: deviceInfo.isTablet ? 28 : 24),

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
            'National Insurance',
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
          'National Insurance Number',
          style: (deviceInfo.isTablet ? theme.textTheme.h1 : theme.textTheme.h2)
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your UK National Insurance Number',
          style: theme.textTheme.muted,
        ),
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
                  LucideIcons.info,
                  size: deviceInfo.isTablet ? 24 : 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: deviceInfo.isTablet ? 14 : 12),
              Text(
                'What is a NI Number?',
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
            'Your National Insurance Number (NI Number) is a unique 9-character code issued by HM Revenue and Customs (HMRC). It\'s essential for employment, tax, and benefits purposes in the UK.',
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

          // Format example
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
                  'Your NI Number looks like:',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.p
                              : theme.textTheme.small)
                          .copyWith(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: deviceInfo.isTablet ? 10 : 8),
                Text(
                  'AB 12 34 56 C',
                  style:
                      (deviceInfo.isTablet
                              ? theme.textTheme.h3
                              : theme.textTheme.h4)
                          .copyWith(fontFamily: 'monospace', letterSpacing: 2),
                ),
                SizedBox(height: deviceInfo.isTablet ? 10 : 8),
                Text(
                  '2 letters, followed by 6 digits, ending with a letter',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            // NI Number Field
            ShadInputFormField(
              id: 'nationalInsuranceNumber',
              focusNode: _niFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onContinue(),
              label: Text(
                'National Insurance Number',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              placeholder: const Text('AB 12 34 56 C'),
              validator: _validateNINumber,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                _NINumberFormatter(),
                LengthLimitingTextInputFormatter(13),
              ],
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

/// Custom formatter to add spaces in NI Number format: AB 12 34 56 C
class _NINumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all spaces and convert to uppercase
    final text = newValue.text.replaceAll(' ', '').toUpperCase();

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Build formatted string: AB 12 34 56 C
    final buffer = StringBuffer();
    for (int i = 0; i < text.length && i < 9; i++) {
      if (i == 2 || i == 4 || i == 6 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
