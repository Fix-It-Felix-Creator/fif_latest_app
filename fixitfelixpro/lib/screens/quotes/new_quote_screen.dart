import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../models/app_user.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/quote_settings/quote_settings_bloc.dart';
import '../../blocs/quote_settings/quote_settings_event.dart';
import '../../blocs/quote_settings/quote_settings_state.dart';
import '../../blocs/pricing/pricing_bloc.dart';
import '../../blocs/staff/staff_bloc.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/customer.dart';
import '../../models/pricing_item.dart';
import '../../models/quote_expiry.dart';
import '../../models/quote_model.dart';
import '../../models/quote_staff_draft.dart';
import '../../models/quote_term_model.dart';
import '../../models/staff.dart';
import '../../models/tools/tool_file.dart';
import '../../models/tools/tool_note.dart';
import '../../models/tools/tool_photo.dart';
import '../../models/tools/tool_video.dart';
import '../../repositories/quotes/quotes_repository.dart';
import '../../services/quote_title_service.dart';
import '../../widgets/attachments/attachments_tab.dart';
import '../../widgets/attachments/notes_tab.dart';
import '../customers/customers_screen.dart';
import '../tools/pickers/files_picker_screen.dart';
import '../tools/pickers/notes_picker_screen.dart';
import '../tools/pickers/photos_picker_screen.dart';
import '../tools/pickers/videos_picker_screen.dart';
import 'quote_line_edit_screen.dart';
import 'quote_send_screen.dart';
import 'quote_staff_edit_screen.dart';
import 'quote_terms_picker_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Route arguments for `/quotes/new`. `existing` makes it open in edit
/// mode (and `nextSequence` is ignored). `nextSequence` is the number
/// the auto-generated reference should use for a brand-new quote.
class NewQuoteArgs {
  const NewQuoteArgs({this.existing, this.nextSequence = 1});
  final Quote? existing;
  final int nextSequence;
}

String formatQuoteReference({required String prefix, required int sequence}) {
  final padded = sequence.toString().padLeft(4, '0');
  return prefix.isEmpty ? padded : '$prefix-$padded';
}

class NewQuoteScreen extends StatefulWidget {
  const NewQuoteScreen({
    super.key,
    this.existing,
    this.nextSequence = 1,
  });

  /// When non-null the screen opens in edit mode and pre-fills every
  /// field from this quote.
  final Quote? existing;

  /// Sequence number used for the auto-generated reference on a new
  /// quote (ignored when [existing] is non-null).
  final int nextSequence;

  @override
  State<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends State<NewQuoteScreen> {
  late final ShadTabsController<String> _tabsCtrl;

  Customer? _customer;
  DateTime _date = DateTime.now();
  final _referenceCtrl = TextEditingController();
  QuoteExpiry _expiry = QuoteExpiry.days14;
  final List<QuoteStaffDraft> _staffLines = [];
  final List<QuoteLineDraft> _lines = [];
  final List<QuoteTerm> _terms = [];
  final List<ToolPhoto> _attachedPhotos = [];
  final List<ToolVideo> _attachedVideos = [];
  final List<ToolFile> _attachedFiles = [];
  final List<ToolNote> _attachedNotes = [];
  bool _saving = false;

  /// True once the user taps "Edit" on a previously-sent quote. Lets a
  /// `sent` quote re-enter the editable form without affecting the
  /// terminal `accepted`/`rejected` flow (which can never be edited).
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = ShadTabsController<String>(value: 'details');
    final existing = widget.existing;
    if (existing != null) {
      _customer = existing.customer;
      _date = existing.date;
      _expiry = existing.expiry;
      _staffLines.addAll(existing.staff);
      _lines.addAll(existing.lines);
      _terms.addAll(existing.terms);
      _attachedPhotos.addAll(existing.attachedPhotos);
      _attachedVideos.addAll(existing.attachedVideos);
      _attachedFiles.addAll(existing.attachedFiles);
      _attachedNotes.addAll(existing.attachedNotes);
      _referenceCtrl.text = existing.reference;
    }
    // Reference text directly affects whether Save/Send are enabled when
    // auto-generate is off, so rebuild on every change.
    _referenceCtrl.addListener(_onReferenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuoteSettingsBloc>().add(
        const QuoteSettingsStartWatching(),
      );
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
    // The child reference row sets `controller.text = …` in its build
    // path, which fires this listener mid-build. Defer the rebuild to
    // the next frame so we don't markNeedsBuild during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
    if (picked != null) setState(() => _date = picked);
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

  /// Quotes already accepted or rejected by the customer are
  /// permanently locked — neither Save, Send, nor an Edit toggle can
  /// reopen them.
  bool get _isTerminal {
    final s = widget.existing?.status;
    return s == QuoteStatus.accepted || s == QuoteStatus.rejected;
  }

  /// Read-only render mode. New quotes and drafts are never locked.
  /// Sent quotes are locked by default but unlock when the user taps
  /// "Edit" (toggling [_editMode]). Accepted/rejected quotes are
  /// permanently locked.
  bool get _locked {
    if (_isTerminal) return true;
    final e = widget.existing;
    if (e == null) return false;
    if (e.status == QuoteStatus.draft) return false;
    return !_editMode;
  }

  bool get _canSave {
    if (_locked) return false;
    if (_customer == null) return false;
    if (_lines.isEmpty) return false;
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
      return formatQuoteReference(
        prefix: settings.prefix,
        sequence: widget.nextSequence,
      );
    }
    return '—';
  }

  /// Local fallback title — used when the LLM call fails or the API
  /// key isn't configured.
  String _fallbackTitle() {
    if (_lines.isEmpty) return '';
    final first = _lines.first.item.name;
    if (_lines.length == 1) return first;
    return '$first + ${_lines.length - 1} more';
  }

  Future<void> _saveAsDraft() async {
    final saved = await _persist(QuoteStatus.draft);
    if (!mounted || saved == null) return;
    Navigator.of(context).pop();
  }

  Future<void> _openSendScreen() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Quote? toShare;
    bool savedFresh = false;
    if (_locked) {
      // Already-sent quote being re-shared without edits — no persist
      // needed, just push the existing record.
      toShare = widget.existing;
    } else {
      if (_customer == null) return;
      // Persist as draft. The status only flips to "sent" once the
      // user actually picks a share method on the next screen — not
      // just by visiting it.
      toShare = await _persist(QuoteStatus.draft);
      savedFresh = toShare != null;
    }
    if (!mounted || toShare == null) return;
    await Navigator.of(context).pushNamed(
      '/quotes/send',
      arguments: QuoteSendArgs(quote: toShare),
    );
    if (!mounted) return;
    // Fresh save (was new/draft) → drop back to the list so the user
    // sees the quote — its status will reflect whatever they did on the
    // share screen. Re-shares of an existing quote stay on the details
    // screen.
    if (savedFresh) Navigator.of(context).pop();
  }

  /// Builds the Quote, generates a title (AI with local fallback), and
  /// writes it to RTDB via [QuotesRepository]. Returns the persisted
  /// [Quote] with its real id on success, `null` on failure (and shows
  /// an error toast).
  Future<Quote?> _persist(QuoteStatus newStatus) async {
    if (!_canSave || _saving) return null;
    setState(() => _saving = true);

    // Refresh `_customer` from CustomersBloc by id before snapshotting
    // it onto the quote. The local copy was captured when the user
    // picked the customer (or hydrated from `existing.customer`) and
    // may be stale if the user has since edited the customer's email /
    // phone / address — the persisted quote doc must carry the
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
    // Status preservation rules:
    //   1. Once a customer has accepted/rejected, the quote is locked —
    //      neither "Save as draft" nor "Send Quote" can downgrade it.
    //   2. Otherwise, hitting "Save" while editing keeps the current
    //      status (don't downgrade Sent → Draft).
    QuoteStatus resolvedStatus;
    if (existing != null &&
        (existing.status == QuoteStatus.accepted ||
            existing.status == QuoteStatus.rejected)) {
      resolvedStatus = existing.status;
    } else if (existing != null && newStatus == QuoteStatus.draft) {
      resolvedStatus = existing.status;
    } else {
      resolvedStatus = newStatus;
    }
    // First time the quote enters `sent`, stamp `sentAt` so the
    // activity timeline can render it. Re-saves of an already-sent
    // quote keep the original timestamp.
    final sentAt = (resolvedStatus == QuoteStatus.sent)
        ? (existing?.sentAt ?? DateTime.now())
        : existing?.sentAt;

    final quote = Quote(
      id: existing?.id ?? '',
      reference: _resolvedReference(),
      title: title,
      status: resolvedStatus,
      customer: _customer,
      date: _date,
      expiry: _expiry,
      staff: List<QuoteStaffDraft>.from(_staffLines),
      lines: List<QuoteLineDraft>.from(_lines),
      total: _quoteTotal(_lines, _staffLines),
      createdAt: existing?.createdAt ?? DateTime.now(),
      sentAt: sentAt,
      viewedAt: existing?.viewedAt,
      respondedAt: existing?.respondedAt,
      shareToken: existing?.shareToken,
      terms: List<QuoteTerm>.from(_terms),
      attachedPhotos: List<ToolPhoto>.from(_attachedPhotos),
      attachedVideos: List<ToolVideo>.from(_attachedVideos),
      attachedFiles: List<ToolFile>.from(_attachedFiles),
      attachedNotes: List<ToolNote>.from(_attachedNotes),
    );

    final repo = context.read<QuotesRepository>();
    String? savedId;
    if (existing == null) {
      savedId = await repo.create(quote);
    } else {
      final ok = await repo.update(quote);
      savedId = ok ? existing.id : null;
    }

    if (!mounted) return null;
    setState(() => _saving = false);
    if (savedId == null) {
      CommonToasts.error(context, 'Could not save the quote');
      return null;
    }
    return Quote(
      id: savedId,
      reference: quote.reference,
      title: quote.title,
      status: quote.status,
      customer: quote.customer,
      date: quote.date,
      expiry: quote.expiry,
      staff: quote.staff,
      lines: quote.lines,
      total: quote.total,
      createdAt: quote.createdAt,
      sentAt: quote.sentAt,
      viewedAt: quote.viewedAt,
      respondedAt: quote.respondedAt,
      shareToken: quote.shareToken,
      terms: quote.terms,
      attachedPhotos: quote.attachedPhotos,
      attachedVideos: quote.attachedVideos,
      attachedFiles: quote.attachedFiles,
      attachedNotes: quote.attachedNotes,
    );
  }

  bool get _hasChanges {
    // Read-only quotes (sent / accepted / rejected) can never have
    // edits, so skip the dirty check entirely — the user shouldn't see
    // a "Discard changes?" prompt when there's nothing to discard.
    if (_locked) return false;
    if (_customer != null) return true;
    if (_staffLines.isNotEmpty) return true;
    if (_lines.isNotEmpty) return true;
    if (_attachedPhotos.isNotEmpty) return true;
    if (_attachedVideos.isNotEmpty) return true;
    if (_attachedFiles.isNotEmpty) return true;
    if (_attachedNotes.isNotEmpty) return true;
    if (_expiry != QuoteExpiry.days14) return true;

    final today = DateTime.now();
    if (_date.year != today.year ||
        _date.month != today.month ||
        _date.day != today.day) {
      return true;
    }

    // The reference field is auto-prefilled when autoGenerate is on. It's
    // only "edited" if the current text differs from what the prefill
    // would produce (or from empty, when auto is off).
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
          'You have unsaved changes on this quote. Going back will lose them.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  /// Back-arrow handler. Runs the dirty check + discard dialog the same
  /// way PopScope does for system-back / swipe-back gestures.
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
          expiry: _expiry,
          referenceCtrl: _referenceCtrl,
          referenceSequence: widget.nextSequence,
          lines: _lines,
          staff: _staffLines,
          existing: widget.existing,
          readOnly: _locked,
          onPickCustomer: _pickCustomer,
          onPickDate: _pickDate,
          onExpiryChanged: (v) => setState(() => _expiry = v),
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
      title: 'Delete quote ${existing.reference}?',
      message:
          'This quote will be removed permanently. If your customer '
          'still has the share link, they will see a "withdrawn" '
          'message. This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _saving = true);
    final ok = await context.read<QuotesRepository>().delete(existing.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      CommonToasts.error(context, 'Could not delete the quote');
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
            ? 'Quote details'
            : widget.existing == null
                ? 'New quote'
                : 'Edit quote'),
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
          else if (widget.existing?.status == QuoteStatus.sent)
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
                    // Sent quotes in read-only mode can resend straight
                    // from this button without re-validating; only the
                    // editable path needs the form-validity gate.
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
                    child: const Text('Send Quote'),
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
    required this.expiry,
    required this.referenceCtrl,
    required this.referenceSequence,
    required this.lines,
    required this.staff,
    required this.existing,
    required this.readOnly,
    required this.onPickCustomer,
    required this.onPickDate,
    required this.onExpiryChanged,
    required this.onAddLine,
    required this.onEditLine,
    required this.onDelete,
  });

  final Customer? customer;
  final DateTime date;
  final QuoteExpiry expiry;
  final TextEditingController referenceCtrl;
  final int referenceSequence;
  final List<QuoteLineDraft> lines;
  final List<QuoteStaffDraft> staff;
  final Quote? existing;
  final bool readOnly;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickDate;
  final ValueChanged<QuoteExpiry> onExpiryChanged;
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (readOnly && existing != null)
                _ActivityCard(quote: existing!),
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
                    label: 'Date',
                    icon: LucideIcons.calendar,
                    value: _formatDate(date),
                    onTap: readOnly ? null : onPickDate,
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
                  const _HairlineDivider(),
                  _ExpiryRow(
                    expiry: expiry,
                    onChanged: onExpiryChanged,
                    readOnly: readOnly,
                  ),
                ],
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
                    label: const Text('Delete quote'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  /// True once the QuoteSettingsBloc has emitted real settings. While
  /// false, the row leaves the field alone so we don't pre-fill with
  /// the bloc's default state (autoGenerate=true, prefix='').
  final bool settingsLoaded;

  final bool readOnly;

  @override
  State<_ReferenceRow> createState() => _ReferenceRowState();
}

class _ReferenceRowState extends State<_ReferenceRow> {
  /// Whether the user has typed into the field. Once true the
  /// controller value belongs to the user and we never overwrite it.
  /// Programmatic `controller.text = ...` writes don't fire
  /// `TextField.onChanged`, so this flag stays accurate.
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) {
      // Pre-existing reference (edit mode, or autoGenerate just
      // pre-filled it): treat as user value so we don't overwrite.
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

  /// Idempotent: writes the auto reference when settings are loaded
  /// and auto-generate is on, clears the field when auto-generate is
  /// off, and does nothing while settings are still loading.
  void _syncFromSettings() {
    if (!widget.settingsLoaded) return;
    final next = widget.autoGenerate
        ? formatQuoteReference(
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

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({
    required this.expiry,
    required this.onChanged,
    this.readOnly = false,
  });

  final QuoteExpiry expiry;
  final ValueChanged<QuoteExpiry> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          const Text(
            'Quote expiry',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const Spacer(),
          if (readOnly)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                expiry.label,
                style: const TextStyle(
                  fontSize: 15,
                  color: _brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ShadSelect<QuoteExpiry>(
              initialValue: expiry,
              minWidth: 130,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              options: [
                for (final e in QuoteExpiry.values)
                  ShadOption(value: e, child: Text(e.label)),
              ],
              selectedOptionBuilder: (context, value) => Text(
                value.label,
                style: const TextStyle(
                  fontSize: 15,
                  color: _brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
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

/// Pre-discount subtotal of services & materials lines only.
double _itemsSubTotal(List<QuoteLineDraft> lines) {
  double sum = 0;
  for (final l in lines) {
    sum += (l.rate + l.unitMarkup) * l.quantity;
  }
  return sum;
}

/// Post-discount total of services & materials lines only.
double _itemsTotal(List<QuoteLineDraft> lines) {
  double sum = 0;
  for (final l in lines) {
    sum += l.lineTotal;
  }
  return sum;
}

/// Sum of all staff line totals.
double _labourTotal(List<QuoteStaffDraft> staff) {
  double sum = 0;
  for (final s in staff) {
    sum += s.lineTotal;
  }
  return sum;
}

double _quoteTotal(
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
    final total = _quoteTotal(lines, staff);
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
  /// IDs of terms whose details are currently expanded.
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
                    tooltip: 'Remove from quote',
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

enum _EvKind { created, sent, opened, accepted, rejected }

class _ActivityEvent {
  _ActivityEvent({
    required this.kind,
    required this.when,
    required this.isCustomer,
    this.actorName,
  });

  final _EvKind kind;
  final DateTime when;
  final bool isCustomer;
  final String? actorName;
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.quote});

  final Quote quote;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _expanded = true;

  List<_ActivityEvent> _events() {
    final q = widget.quote;
    final out = <_ActivityEvent>[
      _ActivityEvent(
        kind: _EvKind.created,
        when: q.createdAt,
        isCustomer: false,
      ),
    ];
    if (q.sentAt != null) {
      out.add(_ActivityEvent(
        kind: _EvKind.sent,
        when: q.sentAt!,
        isCustomer: false,
      ));
    }
    if (q.viewedAt != null) {
      out.add(_ActivityEvent(
        kind: _EvKind.opened,
        when: q.viewedAt!,
        isCustomer: true,
        actorName: q.customer?.name,
      ));
    }
    if (q.respondedAt != null) {
      out.add(_ActivityEvent(
        kind: q.status == QuoteStatus.accepted
            ? _EvKind.accepted
            : _EvKind.rejected,
        when: q.respondedAt!,
        isCustomer: true,
        actorName: q.customer?.name,
      ));
    }
    return out;
  }

  String _ownerLabel() {
    final user = SupabaseService().auth.currentUser;
    final dn = user == null ? null : AppUser.fromSupabase(user).displayName?.trim();
    return (dn != null && dn.isNotEmpty) ? dn : 'You';
  }

  @override
  Widget build(BuildContext context) {
    final events = _events();
    final ownerName = _ownerLabel();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                'ACTIVITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        _expanded ? 'HIDE ACTIVITY' : 'SHOW ACTIVITY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _fmtMoney(widget.quote.total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < events.length; i++)
              _ActivityRow(
                event: events[i],
                ownerName: ownerName,
                isFirst: i == 0,
                isLast: i == events.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.event,
    required this.ownerName,
    required this.isFirst,
    required this.isLast,
  });

  final _ActivityEvent event;
  final String ownerName;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final actorName =
        event.isCustomer ? (event.actorName ?? 'Customer') : ownerName;
    final palette = _activityChipPalette(event.kind);
    final label = _activityEventLabel(event, actorName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isFirst
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isLast
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: avatarColorFor(actorName),
                    child: Text(
                      initialsFromName(actorName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    // No maxLines/ellipsis — long labels (e.g. "Quote
                    // opened by {full customer name}") wrap onto a
                    // second line and the row grows to fit.
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        height: 1.3,
                        color: palette.fg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatActivityTimestamp(event.when),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({Color bg, Color fg}) _activityChipPalette(_EvKind k) {
  switch (k) {
    case _EvKind.created:
      return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E));
    case _EvKind.sent:
      return (bg: const Color(0xFFE5E7EB), fg: const Color(0xFF374151));
    case _EvKind.opened:
      return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF5B21B6));
    case _EvKind.accepted:
      return (bg: const Color(0xFFD1FAE5), fg: const Color(0xFF065F46));
    case _EvKind.rejected:
      return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
  }
}

String _activityEventLabel(_ActivityEvent e, String actorName) {
  switch (e.kind) {
    case _EvKind.created:
      return 'Quote created';
    case _EvKind.sent:
      return 'Quote sent';
    case _EvKind.opened:
      return 'Quote opened by $actorName';
    case _EvKind.accepted:
      return 'Quote accepted by $actorName';
    case _EvKind.rejected:
      return 'Quote declined by $actorName';
  }
}

String _formatActivityTimestamp(DateTime d) {
  final hour12 = ((d.hour % 12) == 0) ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '$hour12:$mm$ampm ${d.day} ${months[d.month - 1]} ${d.year}';
}
