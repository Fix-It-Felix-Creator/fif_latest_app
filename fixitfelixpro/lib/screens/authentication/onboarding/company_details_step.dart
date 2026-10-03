import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../core/utils/common_toasts.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

/// Step 2 of the simplified onboarding flow — only shown when the
/// user ticked "I have a registered company" on step 1.
///
/// Captures the same company-profile fields as
/// `settings/company_details_screen.dart` (sans logo — the user can
/// add that later from Settings) and writes through the same
/// `SaveBusinessProfileRequested` event so the persisted shape stays
/// consistent.
class CompanyDetailsStep extends StatefulWidget {
  const CompanyDetailsStep({super.key});

  @override
  State<CompanyDetailsStep> createState() => _CompanyDetailsStepState();
}

class _CompanyDetailsStepState extends State<CompanyDetailsStep> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _vatNumberCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _vatNumberFocus = FocusNode();

  bool _vatRegistered = false;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  void _hydrate() {
    if (_hydrated) return;
    final user = context.read<AuthBloc>().state.userDetails;
    if (user != null) {
      final company = user.companyDetails;
      _nameCtrl.text = company?.companyName ?? '';
      _phoneCtrl.text = user.phoneNumber;
      _websiteCtrl.text = company?.website ?? '';
      _vatNumberCtrl.text = company?.vatNumber ?? '';
      _vatRegistered = company?.vatRegistered ?? false;
    }
    setState(() => _hydrated = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _vatNumberCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _websiteFocus.dispose();
    _vatNumberFocus.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_saving) return false;
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_phoneCtrl.text.trim().length < 7) return false;
    return true;
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);

    context.read<AuthBloc>().add(
      SaveBusinessProfileRequested(
        companyName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        vatRegistered: _vatRegistered,
        vatNumber: _vatRegistered && _vatNumberCtrl.text.trim().isNotEmpty
            ? _vatNumberCtrl.text.trim()
            : null,
      ),
    );

    // Wait for the stream listener to flush so the next step hydrates
    // off the freshest userDetails.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pushNamed('/onboarding/address');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        setState(() => _saving = false);
        CommonToasts.error(context, state.errorMessage ?? 'Save failed');
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text('Your company'),
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _StepHeader(
                step: 2,
                total: 3,
                title: 'Company details',
                subtitle:
                    'Shown on your invoices and quotes. You can change all '
                    'of this later from Settings.',
              ),
              const SizedBox(height: 16),
              _Group(
                children: [
                  _LabelledField(
                    label: 'Company name',
                    child: TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _phoneFocus.requestFocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ABC PVT LTD',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'Company phone',
                    child: TextField(
                      controller: _phoneCtrl,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _websiteFocus.requestFocus(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0141 737 6868',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const _HairlineDivider(),
                  _LabelledField(
                    label: 'Website (optional)',
                    child: TextField(
                      controller: _websiteCtrl,
                      focusNode: _websiteFocus,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'www.example.com',
                        hintStyle: _hintStyle,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Group(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'VAT registered',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _vatRegistered,
                          activeThumbColor: _brand,
                          onChanged: (v) =>
                              setState(() => _vatRegistered = v),
                        ),
                      ],
                    ),
                  ),
                  if (_vatRegistered) ...[
                    const _HairlineDivider(),
                    _LabelledField(
                      label: 'VAT number',
                      child: TextField(
                        controller: _vatNumberCtrl,
                        focusNode: _vatNumberFocus,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'GB 123 4567 89',
                          hintStyle: _hintStyle,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canContinue ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final int total;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step OF $total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: _brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey.shade200,
        ),
      );
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
