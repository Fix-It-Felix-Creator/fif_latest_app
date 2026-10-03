import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/pricing/pricing_bloc.dart';
import '../../blocs/quote_settings/quote_settings_bloc.dart';
import '../../blocs/quote_settings/quote_settings_event.dart';
import '../../blocs/quote_settings/quote_settings_state.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../core/enum.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/bank_details_model.dart';
import '../../models/customer.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_payment_method.dart';
import '../../models/pricing_item.dart';
import '../../models/quote_staff_draft.dart';
import '../../models/quote_term_model.dart';
import '../../models/staff.dart';
import '../../models/tools/tool_file.dart';
import '../../models/tools/tool_note.dart';
import '../../models/tools/tool_photo.dart';
import '../../models/tools/tool_video.dart';
import '../../repositories/invoices/invoices_repository.dart';
import '../../services/quote_title_service.dart';
import '../../widgets/attachments/attachments_tab.dart';
import '../../widgets/attachments/notes_tab.dart';
import '../customers/customers_screen.dart';
import '../quotes/quote_line_edit_screen.dart';
import '../quotes/quote_staff_edit_screen.dart';
import '../quotes/quote_terms_picker_screen.dart';
import '../tools/pickers/files_picker_screen.dart';
import '../tools/pickers/notes_picker_screen.dart';
import '../tools/pickers/photos_picker_screen.dart';
import '../tools/pickers/videos_picker_screen.dart';
import 'invoice_send_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Route arguments for `/invoices/new`. `existing` makes it open in
/// edit mode (and `nextSequence` is ignored). `nextSequence` is the
/// number the auto-generated reference should use for a brand-new
/// invoice.
class NewInvoiceArgs {
  const NewInvoiceArgs({this.existing, this.nextSequence = 1});
  final Invoice? existing;
  final int nextSequence;
}

String formatInvoiceReference({required String prefix, required int sequence}) {
  final padded = sequence.toString().padLeft(4, '0');
  return prefix.isEmpty ? padded : '$prefix-$padded';
}

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({
    super.key,
    this.existing,
    this.nextSequence = 1,
  });

  final Invoice? existing;
  final int nextSequence;

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  late final ShadTabsController<String> _tabsCtrl;

  Customer? _customer;
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  final _referenceCtrl = TextEditingController();
  InvoicePaymentMethod _paymentMethod = InvoicePaymentMethod.cash;
  final List<QuoteStaffDraft> _staffLines = [];
  final List<QuoteLineDraft> _lines = [];
  final List<QuoteTerm> _terms = [];
  final List<ToolPhoto> _attachedPhotos = [];
  final List<ToolVideo> _attachedVideos = [];
  final List<ToolFile> _attachedFiles = [];
  final List<ToolNote> _attachedNotes = [];
  bool _saving = false;

  /// True once the user taps "Edit" on a previously-sent invoice. Lets
  /// a `sent` invoice re-enter the editable form without affecting the
  /// terminal `paid`/`cancelled` flow (which can never be edited).
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = ShadTabsController<String>(value: 'details');
    final existing = widget.existing;
    if (existing != null) {
      _customer = existing.customer;
      _date = existing.date;
      _dueDate = existing.dueDate;
      _paymentMethod = existing.paymentMethod;
      _staffLines.addAll(existing.staff);
      _lines.addAll(existing.lines);
      _terms.addAll(existing.terms);
      _attachedPhotos.addAll(existing.attachedPhotos);
      _attachedVideos.addAll(existing.attachedVideos);
      _attachedFiles.addAll(existing.attachedFiles);
      _attachedNotes.addAll(existing.attachedNotes);
      _referenceCtrl.text = existing.reference;
    }
    _referenceCtrl.addListener(_onReferenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Quote settings drives both the reference auto-gen (shared
      // prefix + autoGenerate) and the term library used by the
      // picker.
      context
          .read<QuoteSettingsBloc>()
          .add(const QuoteSettingsStartWatching());
      _seedDefaultsFromSettings();
    });
  }

  @override
  void dispose() {
    _tabsCtrl.dispose();
    _referenceCtrl.removeListener(_onReferenceChanged);
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _onReferenceChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// On a brand-new invoice, seed dueDate to a fixed 14-day window
  /// from the issue date. Payment method always starts at Cash — the
  /// user picks per-invoice.
  static const int _defaultDueDays = 14;

  void _seedDefaultsFromSettings() {
    if (widget.existing != null) return;
    setState(() {
      _dueDate = _date.add(const Duration(days: _defaultDueDays));
    });
  }

  BankDetailsModel? get _userBankDetails {
    final auth = context.read<AuthBloc>().state;
    return auth.userDetails?.companyDetails?.bankDetails;
  }

  bool get _bankDetailsOnFile {
    final b = _userBankDetails;
    return b != null && b.isNotEmpty;
  }

  /// Push the bank-details edit page and rebuild on return so the
  /// "needs bank details" banner can clear and Save can unlock the
  /// instant the user comes back with details on file.
  Future<void> _openBankDetails() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).pushNamed('/settings/bank');
    if (mounted) setState(() {});
  }

  Future<void> _pickCustomer() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CustomersBloc>(),
          child: const CustomersScreen(pickMode: true),
        ),
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        // If the user picks a new invoice date and the current dueDate
        // is now in the past relative to it, push dueDate forward by
        // the same gap so the relative window is preserved.
        if (_dueDate.isBefore(picked)) {
          _dueDate = picked.add(const Duration(days: _defaultDueDays));
        }
      });
    }
  }

  Future<void> _pickDueDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _date,
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _openStaffEditor({QuoteStaffDraft? existing}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<QuoteStaffEditResult>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<StaffBloc>(),
          child: QuoteStaffEditScreen(existing: existing),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      switch (result) {
        case QuoteStaffSaved(:final draft):
          final idx = _staffLines.indexWhere((s) => s.id == draft.id);
          if (idx >= 0) {
            _staffLines[idx] = draft;
          } else {
            _staffLines.add(draft);
          }
        case QuoteStaffDeleted(:final id):
          _staffLines.removeWhere((s) => s.id == id);
      }
    });
  }

  Future<void> _openLineEditor({QuoteLineDraft? existing}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<QuoteLineEditResult>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PricingBloc>(),
          child: QuoteLineEditScreen(existing: existing),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      switch (result) {
        case QuoteLineSaved(:final draft):
          final idx = _lines.indexWhere((l) => l.id == draft.id);
          if (idx >= 0) {
            _lines[idx] = draft;
          } else {
            _lines.add(draft);
          }
        case QuoteLineDeleted(:final id):
          _lines.removeWhere((l) => l.id == id);
      }
    });
  }

  Future<void> _openTermsPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<QuoteTerm>>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<QuoteSettingsBloc>(),
          child: QuoteTermsPickerScreen(
            alreadySelectedIds: _terms.map((t) => t.id).toSet(),
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _terms
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _openPhotosPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<ToolPhoto>>(
      MaterialPageRoute(
        builder: (_) => PhotosPickerScreen(
          initialSelectedIds: _attachedPhotos.map((p) => p.id).toSet(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _attachedPhotos
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _openVideosPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<ToolVideo>>(
      MaterialPageRoute(
        builder: (_) => VideosPickerScreen(
          initialSelectedIds: _attachedVideos.map((v) => v.id).toSet(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _attachedVideos
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _openFilesPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<ToolFile>>(
      MaterialPageRoute(
        builder: (_) => FilesPickerScreen(
          initialSelectedIds: _attachedFiles.map((f) => f.id).toSet(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _attachedFiles
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _openNotesPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<ToolNote>>(
      MaterialPageRoute(
        builder: (_) => NotesPickerScreen(
          initialSelectedIds: _attachedNotes.map((n) => n.id).toSet(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _attachedNotes
        ..clear()
        ..addAll(picked);
    });
  }

  /// Invoices in `paid` or `cancelled` are permanently locked.
  bool get _isTerminal {
    final s = widget.existing?.status;
    return s == InvoiceStatus.paid || s == InvoiceStatus.cancelled;
  }

  bool get _locked {
    if (_isTerminal) return true;
    final e = widget.existing;
    if (e == null) return false;
    if (e.status == InvoiceStatus.draft) return false;
    return !_editMode;
  }

  bool get _bankDepositValid {
    if (_paymentMethod != InvoicePaymentMethod.bankDeposit) return true;
    return _bankDetailsOnFile;
  }

  bool get _canSave {
    if (_locked) return false;
    if (_customer == null) return false;
    if (_lines.isEmpty) return false;
    if (!_bankDepositValid) return false;
    final settings = context.read<QuoteSettingsBloc>().state.settings;
    if (!settings.autoGenerateNumber &&
        _referenceCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool get _canSend => _canSave;

  String _resolvedReference() {
    final raw = _referenceCtrl.text.trim();
    if (raw.isNotEmpty) return raw;
    final settings = context.read<QuoteSettingsBloc>().state.settings;
    if (settings.autoGenerateNumber) {
      return formatInvoiceReference(
        prefix: settings.prefix,
        sequence: widget.nextSequence,
      );
    }
    return '—';
  }

  String _fallbackTitle() {
    if (_lines.isEmpty) return '';
    final first = _lines.first.item.name;
    if (_lines.length == 1) return first;
    return '$first + ${_lines.length - 1} more';
  }

  Future<void> _saveAsDraft() async {
    final saved = await _persist(InvoiceStatus.draft);
    if (!mounted || saved == null) return;
    Navigator.of(context).pop();
  }

  Future<void> _openSendScreen() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Invoice? toShare;
    bool savedFresh = false;
    if (_locked) {
      toShare = widget.existing;
    } else {
      if (_customer == null) return;
      toShare = await _persist(InvoiceStatus.draft);
      savedFresh = toShare != null;
    }
    if (!mounted || toShare == null) return;
    await Navigator.of(context).pushNamed(
      '/invoices/send',
      arguments: InvoiceSendArgs(invoice: toShare),
    );
    if (!mounted) return;
    if (savedFresh) Navigator.of(context).pop();
  }

  Future<Invoice?> _persist(InvoiceStatus newStatus) async {
    if (!_canSave || _saving) return null;
    setState(() => _saving = true);

    // Refresh `_customer` from CustomersBloc by id before snapshotting
    // it onto the invoice. The local copy was captured when the user
    // picked the customer (or hydrated from `existing.customer`) and
    // may be stale if the user has since edited the customer's email /
    // phone / address — the persisted invoice doc must carry the
    // up-to-date record so the send-email cloud function uses it.
    final pickedId = _customer?.id ?? '';
    if (pickedId.isNotEmpty) {
      for (final c in context.read<CustomersBloc>().state.items) {
        if (c.id == pickedId) {
          _customer = c;
          break;
        }
      }
    }

    final aiTitle = await QuoteTitleService().generate(
      itemNames: _lines.map((l) => l.item.name).toList(),
      customerName: _customer?.name,
    );
    if (!mounted) return null;

    final title =
        (aiTitle != null && aiTitle.isNotEmpty) ? aiTitle : _fallbackTitle();
    final existing = widget.existing;
    // Once paid/cancelled the status is locked. Otherwise hitting Save
    // doesn't downgrade Sent → Draft.
    InvoiceStatus resolvedStatus;
    if (existing != null &&
        (existing.status == InvoiceStatus.paid ||
            existing.status == InvoiceStatus.cancelled)) {
      resolvedStatus = existing.status;
    } else if (existing != null && newStatus == InvoiceStatus.draft) {
      resolvedStatus = existing.status;
    } else {
      resolvedStatus = newStatus;
    }
    final sentAt = (resolvedStatus == InvoiceStatus.sent)
        ? (existing?.sentAt ?? DateTime.now())
        : existing?.sentAt;

    // Snapshot bank details only when bankDeposit. Frozen on the
    // invoice so a later edit to companyDetails.bankDetails can't
    // change a sent invoice.
    final bankSnapshot = _paymentMethod == InvoicePaymentMethod.bankDeposit
        ? _userBankDetails
        : null;

    final invoice = Invoice(
      id: existing?.id ?? '',
      reference: _resolvedReference(),
      title: title,
      status: resolvedStatus,
      customer: _customer,
      date: _date,
      dueDate: _dueDate,
      staff: List<QuoteStaffDraft>.from(_staffLines),
      lines: List<QuoteLineDraft>.from(_lines),
      total: _invoiceTotal(_lines, _staffLines),
      createdAt: existing?.createdAt ?? DateTime.now(),
      paymentMethod: _paymentMethod,
      bankSnapshot: bankSnapshot,
      sentAt: sentAt,
      viewedAt: existing?.viewedAt,
      paidAt: existing?.paidAt,
      shareToken: existing?.shareToken,
      terms: List<QuoteTerm>.from(_terms),
      attachedPhotos: List<ToolPhoto>.from(_attachedPhotos),
      attachedVideos: List<ToolVideo>.from(_attachedVideos),
      attachedFiles: List<ToolFile>.from(_attachedFiles),
      attachedNotes: List<ToolNote>.from(_attachedNotes),
    );

    final repo = context.read<InvoicesRepository>();
    String? savedId;
    if (existing == null) {
      savedId = await repo.create(invoice);
    } else {
      final ok = await repo.update(invoice);
      savedId = ok ? existing.id : null;
    }

    if (!mounted) return null;
    setState(() => _saving = false);
    if (savedId == null) {
      CommonToasts.error(context, 'Could not save the invoice');
      return null;
    }
    return Invoice(
      id: savedId,
      reference: invoice.reference,
      title: invoice.title,
      status: invoice.status,
      customer: invoice.customer,
      date: invoice.date,
      dueDate: invoice.dueDate,
      staff: invoice.staff,
      lines: invoice.lines,
      total: invoice.total,
      createdAt: invoice.createdAt,
      paymentMethod: invoice.paymentMethod,
      bankSnapshot: invoice.bankSnapshot,
      sentAt: invoice.sentAt,
      viewedAt: invoice.viewedAt,
      paidAt: invoice.paidAt,
      shareToken: invoice.shareToken,
      terms: invoice.terms,
      attachedPhotos: invoice.attachedPhotos,
      attachedVideos: invoice.attachedVideos,
      attachedFiles: invoice.attachedFiles,
      attachedNotes: invoice.attachedNotes,
    );
  }

  bool get _hasChanges {
    if (_locked) return false;
    if (_customer != null) return true;
    if (_staffLines.isNotEmpty) return true;
    if (_lines.isNotEmpty) return true;
    if (_attachedPhotos.isNotEmpty) return true;
    if (_attachedVideos.isNotEmpty) return true;
    if (_attachedFiles.isNotEmpty) return true;
    if (_attachedNotes.isNotEmpty) return true;
    final today = DateTime.now();
    if (_date.year != today.year ||
        _date.month != today.month ||
        _date.day != today.day) {
      return true;
    }
    final settings = context.read<QuoteSettingsBloc>().state.settings;
    String expectedAuto = '';
    if (settings.autoGenerateNumber) {
      const seed = '0001';
      expectedAuto = settings.prefix.isEmpty
          ? seed
          : '${settings.prefix}-$seed';
    }
    if (_referenceCtrl.text.trim() != expectedAuto) return true;
    return false;
  }

  Future<void> _confirmDiscard() async {
    bool discard = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Discard changes?',
      message:
          'You have unsaved changes on this invoice. Going back will lose them.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  Future<void> _onBackPressed() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmDiscard();
  }

  Widget _bodyForSelected() {
    switch (_tabsCtrl.selected) {
      case 'staff':
        return _StaffTab(
          staff: _staffLines,
          readOnly: _locked,
          onAdd: () => _openStaffEditor(),
          onEdit: (line) => _openStaffEditor(existing: line),
        );
      case 'attachment':
        return AttachmentsTab(
          photos: _attachedPhotos,
          videos: _attachedVideos,
          files: _attachedFiles,
          readOnly: _locked,
          onAddPhotos: _openPhotosPicker,
          onAddVideos: _openVideosPicker,
          onAddFiles: _openFilesPicker,
          onRemovePhoto: (id) => setState(
            () => _attachedPhotos.removeWhere((p) => p.id == id),
          ),
          onRemoveVideo: (id) => setState(
            () => _attachedVideos.removeWhere((v) => v.id == id),
          ),
          onRemoveFile: (id) => setState(
            () => _attachedFiles.removeWhere((f) => f.id == id),
          ),
        );
      case 'notes':
        return NotesTab(
          notes: _attachedNotes,
          readOnly: _locked,
          onAdd: _openNotesPicker,
          onRemove: (id) => setState(
            () => _attachedNotes.removeWhere((n) => n.id == id),
          ),
        );
      case 'terms':
        return _TermsTab(
          terms: _terms,
          readOnly: _locked,
          onAdd: _openTermsPicker,
          onRemove: (id) =>
              setState(() => _terms.removeWhere((t) => t.id == id)),
        );
      case 'details':
      default:
        return _DetailsTab(
          customer: _customer,
          date: _date,
          dueDate: _dueDate,
          referenceCtrl: _referenceCtrl,
          referenceSequence: widget.nextSequence,
          paymentMethod: _paymentMethod,
          bankDetails: _userBankDetails,
          lines: _lines,
          staff: _staffLines,
          existing: widget.existing,
          readOnly: _locked,
          onPickCustomer: _pickCustomer,
          onPickDate: _pickDate,
          onPickDueDate: _pickDueDate,
          onPaymentMethodChanged: (v) =>
              setState(() => _paymentMethod = v),
          onAddBankDetails: _openBankDetails,
          onAddLine: () => _openLineEditor(),
          onEditLine: (line) => _openLineEditor(existing: line),
          onDelete: widget.existing == null ? null : _confirmDelete,
        );
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null || _saving) return;
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete invoice ${existing.reference}?',
      message:
          'This invoice will be removed permanently. This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _saving = true);
    final ok = await context.read<InvoicesRepository>().delete(existing.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      CommonToasts.error(context, 'Could not delete the invoice');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _hasChanges;
    return BlocListener<QuoteSettingsBloc, QuoteSettingsState>(
      listenWhen: (p, c) =>
          p.settings.autoGenerateNumber != c.settings.autoGenerateNumber,
      listener: (_, __) {
        if (mounted) setState(() {});
      },
      child: PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _confirmDiscard();
        },
        child: Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: _pageBg,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: _onBackPressed,
            ),
            title: Text(_locked
                ? 'Invoice details'
                : widget.existing == null
                    ? 'New invoice'
                    : 'Edit invoice'),
            actions: [
              if (!_locked)
                TextButton(
                  onPressed: (_canSave && !_saving) ? _saveAsDraft : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _brand,
                          ),
                        )
                      : Text(
                          'Save',
                          style: TextStyle(
                            color: _canSave ? _brand : Colors.grey.shade400,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                )
              else if (widget.existing?.status == InvoiceStatus.sent)
                TextButton(
                  onPressed: () => setState(() => _editMode = true),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: ShadTabs<String>(
                  controller: _tabsCtrl,
                  scrollable: true,
                  tabs: const [
                    ShadTab(
                      value: 'details',
                      content: SizedBox.shrink(),
                      child: Text('Details'),
                    ),
                    ShadTab(
                      value: 'staff',
                      content: SizedBox.shrink(),
                      child: Text('Staff'),
                    ),
                    ShadTab(
                      value: 'attachment',
                      content: SizedBox.shrink(),
                      child: Text('Attachment'),
                    ),
                    ShadTab(
                      value: 'notes',
                      content: SizedBox.shrink(),
                      child: Text('Notes'),
                    ),
                    ShadTab(
                      value: 'terms',
                      content: SizedBox.shrink(),
                      child: Text('Terms & Conditions'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: ListenableBuilder(
            listenable: _tabsCtrl,
            builder: (context, _) => _bodyForSelected(),
          ),
          bottomNavigationBar: _isTerminal
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving
                            ? null
                            : (_locked || _canSend ? _openSendScreen : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Send Invoice'),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.customer,
    required this.date,
    required this.dueDate,
    required this.referenceCtrl,
    required this.referenceSequence,
    required this.paymentMethod,
    required this.bankDetails,
    required this.lines,
    required this.staff,
    required this.existing,
    required this.readOnly,
    required this.onPickCustomer,
    required this.onPickDate,
    required this.onPickDueDate,
    required this.onPaymentMethodChanged,
    required this.onAddBankDetails,
    required this.onAddLine,
    required this.onEditLine,
    required this.onDelete,
  });

  final Customer? customer;
  final DateTime date;
  final DateTime dueDate;
  final TextEditingController referenceCtrl;
  final int referenceSequence;
  final InvoicePaymentMethod paymentMethod;
  final BankDetailsModel? bankDetails;
  final List<QuoteLineDraft> lines;
  final List<QuoteStaffDraft> staff;
  final Invoice? existing;
  final bool readOnly;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickDate;
  final VoidCallback onPickDueDate;
  final ValueChanged<InvoicePaymentMethod> onPaymentMethodChanged;
  final VoidCallback onAddBankDetails;
  final VoidCallback onAddLine;
  final ValueChanged<QuoteLineDraft> onEditLine;
  final VoidCallback? onDelete;

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuoteSettingsBloc, QuoteSettingsState>(
      builder: (context, state) {
        final autoGen = state.settings.autoGenerateNumber;
        final prefix = state.settings.prefix;
        final hasBank = bankDetails != null && bankDetails!.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (readOnly && existing != null)
                _StatusStripe(invoice: existing!),
              _Group(
                children: [
                  _PickerRow(
                    label: 'Customer',
                    icon: LucideIcons.userRound,
                    value: customer?.name,
                    placeholder: 'Select a customer',
                    onTap: readOnly ? null : onPickCustomer,
                  ),
                  const _HairlineDivider(),
                  _PickerRow(
                    label: 'Issue date',
                    icon: LucideIcons.calendar,
                    value: _formatDate(date),
                    onTap: readOnly ? null : onPickDate,
                  ),
                  const _HairlineDivider(),
                  _PickerRow(
                    label: 'Due date',
                    icon: LucideIcons.clock,
                    value: _formatDate(dueDate),
                    onTap: readOnly ? null : onPickDueDate,
                  ),
                  const _HairlineDivider(),
                  _ReferenceRow(
                    controller: referenceCtrl,
                    autoGenerate: autoGen,
                    prefix: prefix,
                    sequence: referenceSequence,
                    settingsLoaded:
                        state.status == QuoteSettingsStatus.loaded,
                    readOnly: readOnly,
                  ),
                ],
              ),

              const _SectionHeader('Payment method'),
              _PaymentMethodCard(
                method: paymentMethod,
                bankDetails: bankDetails,
                readOnly: readOnly,
                onChanged: onPaymentMethodChanged,
                onAddBankDetails: onAddBankDetails,
              ),
              if (paymentMethod == InvoicePaymentMethod.bankDeposit &&
                  !hasBank &&
                  !readOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: _BankDetailsBanner(onTap: onAddBankDetails),
                ),

              const _SectionHeader('Services & Materials'),
              _LinesCard(
                lines: lines,
                onEdit: readOnly ? null : onEditLine,
              ),
              if (!readOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddLine,
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: Text(
                        lines.isEmpty ? 'Add Item' : 'Add another item',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: _brand),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              if (lines.isNotEmpty || staff.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.grey.shade300,
                  ),
                ),
                _SummaryCard(lines: lines, staff: staff),
                _BalanceCard(lines: lines, staff: staff),
              ],

              if (onDelete != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Delete invoice'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
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
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.value,
    this.placeholder,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final interactive = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                hasValue ? value! : (placeholder ?? ''),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? _brand : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (interactive) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferenceRow extends StatefulWidget {
  const _ReferenceRow({
    required this.controller,
    required this.autoGenerate,
    required this.prefix,
    required this.sequence,
    required this.settingsLoaded,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final bool autoGenerate;
  final String prefix;
  final int sequence;
  final bool settingsLoaded;
  final bool readOnly;

  @override
  State<_ReferenceRow> createState() => _ReferenceRowState();
}

class _ReferenceRowState extends State<_ReferenceRow> {
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) {
      _userEdited = true;
      return;
    }
    _syncFromSettings();
  }

  @override
  void didUpdateWidget(covariant _ReferenceRow old) {
    super.didUpdateWidget(old);
    if (_userEdited) return;
    final changed = old.settingsLoaded != widget.settingsLoaded ||
        old.autoGenerate != widget.autoGenerate ||
        old.prefix != widget.prefix ||
        old.sequence != widget.sequence;
    if (changed) _syncFromSettings();
  }

  void _syncFromSettings() {
    if (!widget.settingsLoaded) return;
    final next = widget.autoGenerate
        ? formatInvoiceReference(
            prefix: widget.prefix,
            sequence: widget.sequence,
          )
        : '';
    if (widget.controller.text != next) {
      widget.controller.text = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(LucideIcons.hash, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          const Text(
            'Reference number',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: (_) => _userEdited = true,
              readOnly: widget.readOnly,
              enableInteractiveSelection: !widget.readOnly,
              textAlign: TextAlign.right,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              ],
              style: const TextStyle(
                fontSize: 15,
                letterSpacing: 0.5,
                color: _brand,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Reference',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.bankDetails,
    required this.readOnly,
    required this.onChanged,
    required this.onAddBankDetails,
  });

  final InvoicePaymentMethod method;
  final BankDetailsModel? bankDetails;
  final bool readOnly;
  final ValueChanged<InvoicePaymentMethod> onChanged;
  final VoidCallback onAddBankDetails;

  @override
  Widget build(BuildContext context) {
    final hasBank = bankDetails != null && bankDetails!.isNotEmpty;
    return _Group(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _PaymentSegment(
                  label: 'Cash',
                  icon: LucideIcons.banknote,
                  selected: method == InvoicePaymentMethod.cash,
                  enabled: !readOnly,
                  onTap: () => onChanged(InvoicePaymentMethod.cash),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentSegment(
                  label: 'Bank deposit',
                  icon: LucideIcons.landmark,
                  selected: method == InvoicePaymentMethod.bankDeposit,
                  enabled: !readOnly,
                  onTap: () => onChanged(InvoicePaymentMethod.bankDeposit),
                ),
              ),
            ],
          ),
        ),
        if (method == InvoicePaymentMethod.bankDeposit && hasBank) ...[
          const _HairlineDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bankDetails!.bankName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account ${bankDetails!.accountNumber}  ·  '
                  'Sort ${bankDetails!.sortCodeFormatted}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'These details will be shown on the invoice PDF and email.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentSegment extends StatelessWidget {
  const _PaymentSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _brand.withValues(alpha: 0.10) : Colors.white;
    final border = selected ? _brand : Colors.grey.shade300;
    final fg = selected ? _brand : Colors.grey.shade700;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankDetailsBanner extends StatelessWidget {
  const _BankDetailsBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                LucideIcons.triangleAlert,
                size: 18,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your bank details to use bank deposit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'They\'ll appear on the invoice so the customer '
                      'knows where to pay.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Color(0xFFB45309),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesCard extends StatelessWidget {
  const _LinesCard({required this.lines, required this.onEdit});

  final List<QuoteLineDraft> lines;
  final ValueChanged<QuoteLineDraft>? onEdit;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return _Group(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              'No services or materials added yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }
    return _Group(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const _HairlineDivider(),
          _LineRow(
            index: i + 1,
            draft: lines[i],
            onTap: onEdit == null ? null : () => onEdit!(lines[i]),
          ),
        ],
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.index,
    required this.draft,
    required this.onTap,
  });

  final int index;
  final QuoteLineDraft draft;
  final VoidCallback? onTap;

  String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

  String _subtitle() {
    final kind = draft.kind == PricingKind.service ? 'Service' : 'Material';
    return '$kind  ·  Qty ${draft.quantity}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$index.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _subtitle(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtMoney(draft.lineTotal),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _brand,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ] else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _StaffTab extends StatelessWidget {
  const _StaffTab({
    required this.staff,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
  });

  final List<QuoteStaffDraft> staff;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<QuoteStaffDraft> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (staff.isNotEmpty)
          _Group(
            children: [
              for (var i = 0; i < staff.length; i++) ...[
                if (i > 0) const _HairlineDivider(),
                _StaffRow(
                  draft: staff[i],
                  onTap: readOnly ? null : () => onEdit(staff[i]),
                ),
              ],
            ],
          )
        else
          _Group(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Text(
                  'No staff assigned yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        if (!readOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(staff.isEmpty ? 'Add Staff' : 'Add more staff'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.draft, required this.onTap});

  final QuoteStaffDraft draft;
  final VoidCallback? onTap;

  String _fmtMoneyLocal(double v) => '£${v.toStringAsFixed(2)}';

  String _subtitle() {
    final unit = draft.payType.label.toLowerCase();
    final plural = draft.quantity == 1 ? '' : 's';
    final rate = _fmtMoneyLocal(draft.rate);
    return '${draft.quantity} $unit$plural × $rate';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: avatarColorFor(draft.staff.name),
              child: Text(
                initialsFromName(draft.staff.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.staff.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${draft.rateType.label} rate',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _subtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtMoneyLocal(draft.lineTotal),
              style: const TextStyle(
                fontSize: 14,
                color: _brand,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ] else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

String _fmtMoney(double v) => '£${v.toStringAsFixed(2)}';

double _itemsSubTotal(List<QuoteLineDraft> lines) {
  double sum = 0;
  for (final l in lines) {
    sum += (l.rate + l.unitMarkup) * l.quantity;
  }
  return sum;
}

double _itemsTotal(List<QuoteLineDraft> lines) {
  double sum = 0;
  for (final l in lines) {
    sum += l.lineTotal;
  }
  return sum;
}

double _labourTotal(List<QuoteStaffDraft> staff) {
  double sum = 0;
  for (final s in staff) {
    sum += s.lineTotal;
  }
  return sum;
}

double _invoiceTotal(
  List<QuoteLineDraft> lines,
  List<QuoteStaffDraft> staff,
) {
  return _itemsTotal(lines) + _labourTotal(staff);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lines, required this.staff});
  final List<QuoteLineDraft> lines;
  final List<QuoteStaffDraft> staff;

  @override
  Widget build(BuildContext context) {
    final itemsSub = _itemsSubTotal(lines);
    final itemsTotal = _itemsTotal(lines);
    final discount = itemsSub - itemsTotal;
    final hasDiscount = discount > 0.005;
    final labour = _labourTotal(staff);
    final hasLabour = labour > 0.005;
    final total = itemsTotal + labour;
    return _Group(
      children: [
        _SummaryRow(label: 'Sub total', value: _fmtMoney(itemsSub)),
        if (hasDiscount) ...[
          const _HairlineDivider(),
          _SummaryRow(
            label: 'Discount',
            value: '-${_fmtMoney(discount)}',
            valueColor: Colors.red.shade700,
          ),
        ],
        if (hasLabour) ...[
          const _HairlineDivider(),
          _SummaryRow(label: 'Labour charges', value: _fmtMoney(labour)),
        ],
        const _HairlineDivider(),
        _SummaryRow(label: 'Total', value: _fmtMoney(total)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.lines, required this.staff});
  final List<QuoteLineDraft> lines;
  final List<QuoteStaffDraft> staff;

  @override
  Widget build(BuildContext context) {
    final total = _invoiceTotal(lines, staff);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text(
            'Balance',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _fmtMoney(total),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsTab extends StatefulWidget {
  const _TermsTab({
    required this.terms,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<QuoteTerm> terms;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_TermsTab> createState() => _TermsTabState();
}

class _TermsTabState extends State<_TermsTab> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final terms = widget.terms;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (terms.isEmpty)
          _Group(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Text(
                  widget.readOnly
                      ? 'No terms attached.'
                      : 'No terms attached yet. Tap below to pick from your '
                          'saved library.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          )
        else
          _Group(
            children: [
              for (var i = 0; i < terms.length; i++) ...[
                if (i > 0) const _HairlineDivider(),
                _TermAccordionRow(
                  term: terms[i],
                  expanded: _expanded.contains(terms[i].id),
                  onToggle: () {
                    setState(() {
                      final id = terms[i].id;
                      _expanded.contains(id)
                          ? _expanded.remove(id)
                          : _expanded.add(id);
                    });
                  },
                  onRemove: widget.readOnly
                      ? null
                      : () => widget.onRemove(terms[i].id),
                ),
              ],
            ],
          ),
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(terms.isEmpty
                    ? 'Add terms & conditions'
                    : 'Manage attached terms'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TermAccordionRow extends StatelessWidget {
  const _TermAccordionRow({
    required this.term,
    required this.expanded,
    required this.onToggle,
    required this.onRemove,
  });

  final QuoteTerm term;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasDetails = term.details.trim().isNotEmpty;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    term.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove from invoice',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: onRemove,
                  ),
                Icon(
                  expanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Text(
                hasDetails ? term.details : 'No additional details.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: hasDetails
                      ? Colors.grey.shade800
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Simple top-of-form status stripe shown only on locked invoices.
/// Surfaces sentAt / paidAt timestamps without the full activity
/// timeline (no public viewer for invoices yet, so there's no
/// "viewed" or "responded" event to render).
class _StatusStripe extends StatelessWidget {
  const _StatusStripe({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    lines.add(_stripeRow(
      label: 'CREATED',
      when: invoice.createdAt,
      color: const Color(0xFF92400E),
      bg: const Color(0xFFFEF3C7),
    ));
    if (invoice.sentAt != null) {
      lines.add(_stripeRow(
        label: 'SENT',
        when: invoice.sentAt!,
        color: const Color(0xFF374151),
        bg: const Color(0xFFE5E7EB),
      ));
    }
    if (invoice.paidAt != null) {
      lines.add(_stripeRow(
        label: 'PAID',
        when: invoice.paidAt!,
        color: const Color(0xFF065F46),
        bg: const Color(0xFFD1FAE5),
      ));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                _fmtMoney(invoice.total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            lines[i],
          ],
        ],
      ),
    );
  }

  Widget _stripeRow({
    required String label,
    required DateTime when,
    required Color color,
    required Color bg,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatStripeTimestamp(when),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

String _formatStripeTimestamp(DateTime d) {
  final hour12 = ((d.hour % 12) == 0) ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '$hour12:$mm$ampm ${d.day} ${months[d.month - 1]} ${d.year}';
}
