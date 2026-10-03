import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/utils/common_toasts.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _sortCodeCtrl = TextEditingController(); // shows "12-34-56"

  final _bankNameFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _sortCodeFocus = FocusNode();

  bool _saving = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  void _hydrate() {
    if (_hydrated) return;
    final bank =
        context.read<AuthBloc>().state.userDetails?.companyDetails?.bankDetails;
    if (bank == null) {
      setState(() => _hydrated = true);
      return;
    }
    _bankNameCtrl.text = bank.bankName;
    _accountCtrl.text = bank.accountNumber;
    _sortCodeCtrl.text = bank.sortCodeFormatted;
    setState(() => _hydrated = true);
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _sortCodeCtrl.dispose();
    _bankNameFocus.dispose();
    _accountFocus.dispose();
    _sortCodeFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final bankName = _bankNameCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final sortDigits = _sortCodeCtrl.text.replaceAll('-', '').trim();

    if (account.isNotEmpty && account.length != 8) {
      CommonToasts.error(context, 'Account number must be 8 digits');
      return;
    }
    if (sortDigits.isNotEmpty && sortDigits.length != 6) {
      CommonToasts.error(context, 'Sort code must be 6 digits');
      return;
    }

    setState(() => _saving = true);
    context.read<AuthBloc>().add(
      SaveBankDetailsRequested(
        bankName: bankName,
        accountNumber: account,
        sortCode: sortDigits,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _saving = false);
    CommonToasts.success(context, 'Bank details saved');
    Navigator.of(context).pop();
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
          title: const Text('Bank Details'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _saving ? Colors.grey : _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _Notice(),

              _Group(
                child: TextField(
                  controller: _bankNameCtrl,
                  focusNode: _bankNameFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _accountFocus.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Bank name',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),

              _Group(
                child: _InlineDigits(
                  label: 'Account number',
                  controller: _accountCtrl,
                  focusNode: _accountFocus,
                  hintText: '8 digits',
                  maxDigits: 8,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _sortCodeFocus.requestFocus(),
                ),
              ),

              _Group(
                child: _InlineDigits(
                  label: 'Sort code',
                  controller: _sortCodeCtrl,
                  focusNode: _sortCodeFocus,
                  hintText: '12-34-56',
                  maxDigits: 6,
                  formatter: _SortCodeFormatter(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 16, color: _brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'These payment details are included on the quotes and invoices '
              'you send out — customers use them to pay you directly.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDigits extends StatelessWidget {
  const _InlineDigits({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.maxDigits,
    required this.textInputAction,
    required this.onSubmitted,
    this.formatter,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final int maxDigits;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;
  final TextInputFormatter? formatter;

  @override
  Widget build(BuildContext context) {
    final formatters = <TextInputFormatter>[
      if (formatter != null) formatter! else _DigitsMaxFormatter(maxDigits),
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => focusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: formatters,
                style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// Digits-only with a hard cap.
class _DigitsMaxFormatter extends TextInputFormatter {
  _DigitsMaxFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > max ? digits.substring(0, max) : digits;
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// Takes whatever the user types, keeps only digits (max 6), and displays
/// it as `XX-XX-XX` (partial chunks OK: `12`, `12-3`, `12-34-5`).
class _SortCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 6) digits = digits.substring(0, 6);

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('-');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
