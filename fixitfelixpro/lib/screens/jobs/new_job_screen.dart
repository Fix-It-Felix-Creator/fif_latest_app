import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/invoices/invoices_event.dart';
import '../../blocs/invoices/invoices_state.dart';
import '../../blocs/jobs/jobs_bloc.dart';
import '../../blocs/quotes/quotes_bloc.dart';
import '../../blocs/quotes/quotes_event.dart';
import '../../blocs/quotes/quotes_state.dart';
import '../../core/maps/static_map_preview.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/customer.dart';
import '../../models/invoice_model.dart';
import '../../models/job_expense.dart';
import '../../models/job_model.dart';
import '../../models/job_time_entry.dart';
import '../../models/quote_model.dart';
import '../../models/tools/tool_file.dart';
import '../../models/tools/tool_note.dart';
import '../../models/tools/tool_photo.dart';
import '../../models/tools/tool_video.dart';
import '../../repositories/jobs/jobs_repository.dart';
import '../../widgets/attachments/attachments_tab.dart';
import '../../widgets/jobs/job_clock.dart';
import '../../widgets/attachments/notes_tab.dart';
import '../customers/customers_screen.dart';
import '../invoices/invoices_screen.dart';
import '../quotes/quotes_screen.dart';
import '../tools/pickers/files_picker_screen.dart';
import '../tools/pickers/notes_picker_screen.dart';
import '../tools/pickers/photos_picker_screen.dart';
import '../tools/pickers/videos_picker_screen.dart';
import 'expense_edit_screen.dart';
import 'job_time_log_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class NewJobArgs {
  const NewJobArgs({this.existing, this.nextSequence = 1});
  final Job? existing;
  final int nextSequence;
}

String formatJobReference({required int sequence}) {
  return 'JOB-${sequence.toString().padLeft(4, '0')}';
}

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key, this.existing, this.nextSequence = 1});

  final Job? existing;
  final int nextSequence;

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  late final ShadTabsController<String> _tabsCtrl;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  Customer? _customer;
  DateTime _startDate = DateTime.now();
  JobStatus _status = JobStatus.draft;
  final List<JobExpense> _expenses = [];
  final List<ToolPhoto> _attachedPhotos = [];
  final List<ToolVideo> _attachedVideos = [];
  final List<ToolFile> _attachedFiles = [];
  final List<ToolNote> _attachedNotes = [];
  final List<String> _linkedQuoteIds = [];
  final List<String> _linkedInvoiceIds = [];
  bool _saving = false;

  /// Live copy of the persisted job (clock state + logged sessions).
  /// Null for a brand-new, unsaved job — the clock only appears once a
  /// job exists.
  Job? _job;
  bool _clockBusy = false;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = ShadTabsController<String>(value: 'details');
    _job = widget.existing;
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _descCtrl.text = existing.description;
      _refCtrl.text = existing.reference;
      _customer = existing.customer;
      _startDate = existing.startDate;
      _status = existing.status;
      _expenses.addAll(existing.expenses);
      _attachedPhotos.addAll(existing.attachedPhotos);
      _attachedVideos.addAll(existing.attachedVideos);
      _attachedFiles.addAll(existing.attachedFiles);
      _attachedNotes.addAll(existing.attachedNotes);
      _linkedQuoteIds.addAll(existing.linkedQuoteIds);
      _linkedInvoiceIds.addAll(existing.linkedInvoiceIds);
    } else {
      _refCtrl.text = formatJobReference(sequence: widget.nextSequence);
    }
    _titleCtrl.addListener(() => setState(() {}));
    // The pickers and the linked-row resolution both read live data
    // out of the quotes/invoices blocs, so make sure they're streaming.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuotesBloc>().add(const QuotesStartWatching());
      context.read<InvoicesBloc>().add(const InvoicesStartWatching());
    });
  }

  @override
  void dispose() {
    _tabsCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _titleCtrl.text.trim().isNotEmpty;

  bool get _hasChanges {
    final existing = widget.existing;
    if (existing == null) {
      // New job — any entered content counts as unsaved work.
      if (_customer != null) return true;
      if (_titleCtrl.text.trim().isNotEmpty) return true;
      if (_descCtrl.text.trim().isNotEmpty) return true;
      if (_expenses.isNotEmpty) return true;
      if (_attachedPhotos.isNotEmpty) return true;
      if (_attachedVideos.isNotEmpty) return true;
      if (_attachedFiles.isNotEmpty) return true;
      if (_attachedNotes.isNotEmpty) return true;
      if (_linkedQuoteIds.isNotEmpty) return true;
      if (_linkedInvoiceIds.isNotEmpty) return true;
      return false;
    }
    // Editing — dirty only when the form actually differs from the saved
    // job. Clock/time-log state is persisted separately and excluded.
    if (_titleCtrl.text.trim() != existing.title.trim()) return true;
    if (_descCtrl.text.trim() != existing.description.trim()) return true;
    if (_refCtrl.text.trim() != existing.reference.trim()) return true;
    if (_customer?.id != existing.customer?.id) return true;
    if (_startDate != existing.startDate) return true;
    if (_status != existing.status) return true;
    if (!listEquals(_expenses, existing.expenses)) return true;
    if (!listEquals(_attachedPhotos, existing.attachedPhotos)) return true;
    if (!listEquals(_attachedVideos, existing.attachedVideos)) return true;
    if (!listEquals(_attachedFiles, existing.attachedFiles)) return true;
    if (!listEquals(_attachedNotes, existing.attachedNotes)) return true;
    if (!listEquals(_linkedQuoteIds, existing.linkedQuoteIds)) return true;
    if (!listEquals(_linkedInvoiceIds, existing.linkedInvoiceIds)) return true;
    return false;
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
      initialDate: _startDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _addOrEditExpense({JobExpense? existing}) async {
    final result = await Navigator.of(context).push<JobExpense?>(
      MaterialPageRoute(
        builder: (_) => ExpenseEditScreen(existing: existing),
      ),
    );
    if (result == null) return;
    setState(() {
      final idx = _expenses.indexWhere((e) => e.id == result.id);
      if (idx >= 0) {
        _expenses[idx] = result;
      } else {
        _expenses.add(result);
      }
    });
  }

  void _removeExpense(String id) {
    setState(() => _expenses.removeWhere((e) => e.id == id));
  }

  Future<void> _openPhotosPicker() async {
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

  Future<void> _openQuotesPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Pushes the live /quotes screen in multi-select pickMode. The
    // user can tick existing quotes, tap "+" to create a new one
    // (then come back to the picker), and confirm with "Add (n)".
    // Existing links are deduped against the returned ids.
    final picked = await Navigator.of(context).push<List<Quote>>(
      MaterialPageRoute(
        builder: (_) => QuotesScreen(
          pickMode: true,
          excludeIds: List<String>.from(_linkedQuoteIds),
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final existing = _linkedQuoteIds.toSet();
    final fresh = picked
        .where((q) => !existing.contains(q.id))
        .map((q) => q.id)
        .toList();
    if (fresh.isEmpty) return;
    setState(() => _linkedQuoteIds.addAll(fresh));
  }

  void _unlinkQuote(String id) {
    setState(() => _linkedQuoteIds.remove(id));
  }

  Future<void> _openInvoicesPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await Navigator.of(context).push<List<Invoice>>(
      MaterialPageRoute(
        builder: (_) => InvoicesScreen(
          pickMode: true,
          excludeIds: List<String>.from(_linkedInvoiceIds),
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    final existing = _linkedInvoiceIds.toSet();
    final fresh = picked
        .where((inv) => !existing.contains(inv.id))
        .map((inv) => inv.id)
        .toList();
    if (fresh.isEmpty) return;
    setState(() => _linkedInvoiceIds.addAll(fresh));
  }

  void _unlinkInvoice(String id) {
    setState(() => _linkedInvoiceIds.remove(id));
  }

  Future<void> _openNotesPicker() async {
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

  /// Clock in / out on the current job. Persists via a lightweight RTDB
  /// patch (leaves the rest of the doc alone) and mirrors the new clock
  /// state locally so a later full-save doesn't wipe it.
  Future<void> _toggleClock() async {
    final job = _job;
    if (job == null || job.id.isEmpty || _clockBusy) return;
    setState(() => _clockBusy = true);
    final repo = context.read<JobsRepository>();
    Job updated;
    if (job.isClockedIn) {
      await repo.clockOut(job);
      updated = job.copyWith(
        clearClockIn: true,
        timeEntries: [
          ...job.timeEntries,
          JobTimeEntry(start: job.clockInAt!, end: DateTime.now()),
        ],
        updatedAt: DateTime.now(),
      );
    } else {
      final now = DateTime.now();
      await repo.clockIn(job.id);
      updated = job.copyWith(
        clockInAt: now,
        status: JobStatus.active,
        updatedAt: now,
      );
    }
    if (!mounted) return;
    setState(() {
      _job = updated;
      _status = updated.status;
      _clockBusy = false;
    });
  }

  Future<Job?> _persist() async {
    if (!_canSave) return null;
    setState(() => _saving = true);
    final existing = widget.existing;
    final job = Job(
      id: existing?.id ?? '',
      reference: _refCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: _status,
      customer: _customer,
      startDate: _startDate,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: existing == null ? null : DateTime.now(),
      expenses: List<JobExpense>.from(_expenses),
      attachedPhotos: List<ToolPhoto>.from(_attachedPhotos),
      attachedVideos: List<ToolVideo>.from(_attachedVideos),
      attachedFiles: List<ToolFile>.from(_attachedFiles),
      attachedNotes: List<ToolNote>.from(_attachedNotes),
      linkedQuoteIds: List<String>.from(_linkedQuoteIds),
      linkedInvoiceIds: List<String>.from(_linkedInvoiceIds),
      // Preserve live clock state through a full-document save.
      clockInAt: _job?.clockInAt,
      timeEntries: _job?.timeEntries ?? const <JobTimeEntry>[],
    );
    final repo = context.read<JobsRepository>();
    String? savedId;
    if (existing == null) {
      savedId = await repo.create(job);
    } else {
      final ok = await repo.update(job);
      savedId = ok ? existing.id : null;
    }
    if (!mounted) return null;
    setState(() => _saving = false);
    if (savedId == null) {
      CommonToasts.error(context, 'Could not save the job');
      return null;
    }
    return job.copyWith();
  }

  Future<void> _saveAndPop() async {
    final saved = await _persist();
    if (!mounted || saved == null) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    bool discard = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes on this job.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  Future<void> _onBack() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmDiscard();
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    bool doDelete = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Delete job?',
      message:
          'This permanently removes "${existing.title.isEmpty ? 'this job' : existing.title}". '
          'This cannot be undone.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Keep',
      onConfirm: () => doDelete = true,
    );
    if (!mounted || !doDelete) return;
    context.read<JobsBloc>().add(JobDeleteRequested(existing.id));
    Navigator.of(context).pop();
  }

  Widget _bodyForSelected() {
    switch (_tabsCtrl.selected) {
      case 'quotes':
        return _LinkedQuotesTab(
          ids: _linkedQuoteIds,
          onAdd: _openQuotesPicker,
          onRemove: _unlinkQuote,
        );
      case 'invoices':
        return _LinkedInvoicesTab(
          ids: _linkedInvoiceIds,
          onAdd: _openInvoicesPicker,
          onRemove: _unlinkInvoice,
        );
      case 'expenses':
        return _ExpensesTab(
          expenses: _expenses,
          onAdd: () => _addOrEditExpense(),
          onEdit: (e) => _addOrEditExpense(existing: e),
          onRemove: _removeExpense,
        );
      case 'attachment':
        return AttachmentsTab(
          photos: _attachedPhotos,
          videos: _attachedVideos,
          files: _attachedFiles,
          readOnly: false,
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
          readOnly: false,
          onAdd: _openNotesPicker,
          onRemove: (id) => setState(
            () => _attachedNotes.removeWhere((n) => n.id == id),
          ),
        );
      case 'details':
      default:
        return _DetailsTab(
          customer: _customer,
          startDate: _startDate,
          status: _status,
          referenceCtrl: _refCtrl,
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          linkedInvoiceIds: _linkedInvoiceIds,
          onPickCustomer: _pickCustomer,
          onPickDate: _pickDate,
          onStatusChanged: (s) => setState(() => _status = s),
          isEditing: widget.existing != null,
          clockJob: _job,
          clockBusy: _clockBusy,
          onToggleClock: _toggleClock,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
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
            onPressed: _onBack,
          ),
          title: Text(widget.existing == null ? 'New job' : 'Edit job'),
          actions: [
            if (widget.existing != null)
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 20),
                color: Colors.red.shade600,
                tooltip: 'Delete job',
                onPressed: _saving ? null : _confirmDelete,
              ),
            TextButton(
              onPressed: _canSave ? _saveAndPop : null,
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
                    value: 'quotes',
                    content: SizedBox.shrink(),
                    child: Text('Quotes'),
                  ),
                  ShadTab(
                    value: 'invoices',
                    content: SizedBox.shrink(),
                    child: Text('Invoices'),
                  ),
                  ShadTab(
                    value: 'expenses',
                    content: SizedBox.shrink(),
                    child: Text('Expenses'),
                  ),
                  ShadTab(
                    value: 'attachment',
                    content: SizedBox.shrink(),
                    child: Text('Attachments'),
                  ),
                  ShadTab(
                    value: 'notes',
                    content: SizedBox.shrink(),
                    child: Text('Notes'),
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
      ),
    );
  }
}

// ─── Details tab ────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.customer,
    required this.startDate,
    required this.status,
    required this.referenceCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.linkedInvoiceIds,
    required this.onPickCustomer,
    required this.onPickDate,
    required this.onStatusChanged,
    required this.isEditing,
    required this.clockJob,
    required this.clockBusy,
    required this.onToggleClock,
  });

  final Customer? customer;
  final DateTime startDate;
  final JobStatus status;
  final TextEditingController referenceCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final List<String> linkedInvoiceIds;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickDate;
  final ValueChanged<JobStatus> onStatusChanged;
  final bool isEditing;

  /// The persisted job when editing (drives the clock control); null for
  /// a brand-new job that hasn't been saved yet.
  final Job? clockJob;
  final bool clockBusy;
  final VoidCallback onToggleClock;

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // A completed / cancelled job can't track new time. While a clock
    // session is running the status is locked to Active until clock-out.
    final clockClosed =
        status == JobStatus.completed || status == JobStatus.cancelled;
    final statusLocked = clockJob?.isClockedIn ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        // Clock in / out — only for a saved job.
        if (clockJob != null) ...[
          JobClockControl(
            job: clockJob!,
            busy: clockBusy,
            onToggle: onToggleClock,
            enabled: !clockClosed,
            disabledMessage: clockClosed
                ? 'Time tracking is closed for '
                    '${status.label.toLowerCase()} jobs'
                : null,
          ),
          const SizedBox(height: 8),
          _TimeLogTile(job: clockJob!),
          const SizedBox(height: 12),
        ],
        // Customer
        _Card(
          child: InkWell(
            onTap: onPickCustomer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (customer != null)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarColorFor(customer!.name),
                      child: Text(
                        initialsFromName(customer!.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.user,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer == null
                              ? 'Pick a customer'
                              : customer!.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: customer == null
                                ? Colors.grey.shade600
                                : Colors.black87,
                          ),
                        ),
                        if (customer != null &&
                            customer!.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            customer!.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (linkedInvoiceIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InvoicesTotalCard(ids: linkedInvoiceIds),
        ],
        const SizedBox(height: 12),
        // Reference + title + description
        _Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              children: [
                _LabeledField(
                  label: 'Reference',
                  child: TextField(
                    controller: referenceCtrl,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _LabeledField(
                  label: 'Job name',
                  child: TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'e.g. Boiler service — Glasgow',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.28),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _LabeledField(
                  label: 'Description',
                  child: TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    minLines: 3,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'What needs doing on this job?',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.28),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Start date + status
        _Card(
          child: Column(
            children: [
              InkWell(
                onTap: onPickDate,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Start date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _fmtDate(startDate),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.flag,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (statusLocked)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                LucideIcons.lock,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          )
                        else
                          DropdownButton<JobStatus>(
                            value: status,
                            onChanged: (v) {
                              if (v != null) onStatusChanged(v);
                            },
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            items: JobStatus.values
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                    if (statusLocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Clock out to change the status.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (customer != null) ...[
          const SizedBox(height: 12),
          _CustomerLocationCard(customer: customer!),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

/// Details-tab row linking to the full clock-in/out log for a job, with
/// the running total on the right.
class _TimeLogTile extends StatelessWidget {
  const _TimeLogTile({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobTimeLogScreen(job: job)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.list, size: 20, color: _brand),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Time log',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                formatJobDuration(jobElapsed(job)),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}


// ─── Customer-location card (Details tab) ──────────────────────────

/// "Site location" card for the Details tab: map thumbnail + address +
/// Contact / Directions actions. The map only renders when the
/// customer has coordinates; the action buttons are only enabled when
/// the corresponding contact/destination data exists.
class _CustomerLocationCard extends StatelessWidget {
  const _CustomerLocationCard({required this.customer});
  final Customer customer;

  String _readableAddress() {
    final formatted = customer.formattedAddress?.trim() ?? '';
    if (formatted.isNotEmpty) return formatted;
    final parts = <String>[
      customer.addressLine1,
      if ((customer.addressLine2 ?? '').isNotEmpty) customer.addressLine2!,
      customer.city,
      if ((customer.county ?? '').isNotEmpty) customer.county!,
      customer.postcode,
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String? _directionsQuery() {
    final addr = _readableAddress();
    if (addr.isNotEmpty) return addr;
    final lat = customer.latitude;
    final lng = customer.longitude;
    if (lat != null && lng != null) return '$lat,$lng';
    return null;
  }

  bool get _hasContact =>
      customer.phone.trim().isNotEmpty || customer.email.trim().isNotEmpty;

  bool get _hasDirections => _directionsQuery() != null;

  // ---------- launchers ----------

  Future<void> _call() async {
    final phone = customer.phone.trim();
    if (phone.isEmpty) return;
    await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _emailDefault() async {
    final to = customer.email.trim();
    if (to.isEmpty) return;
    await launchUrl(
      Uri(scheme: 'mailto', path: to),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _emailGmail() async {
    final to = customer.email.trim();
    if (to.isEmpty) return;
    final gmail = Uri.parse('googlegmail:///co?to=$to');
    try {
      final ok = await launchUrl(gmail, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await _emailDefault();
  }

  Future<void> _openAppleMaps() async {
    final dest = _directionsQuery();
    if (dest == null) return;
    await launchUrl(
      Uri(
        scheme: 'http',
        host: 'maps.apple.com',
        queryParameters: {'daddr': dest},
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openGoogleMaps() async {
    final dest = _directionsQuery();
    if (dest == null) return;
    await launchUrl(
      Uri(
        scheme: 'https',
        host: 'www.google.com',
        path: '/maps/dir/',
        queryParameters: {'api': '1', 'destination': dest},
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  // ---------- action sheets ----------

  Future<void> _showContactSheet(BuildContext context) async {
    final hasPhone = customer.phone.trim().isNotEmpty;
    final hasEmail = customer.email.trim().isNotEmpty;
    if (!hasPhone && !hasEmail) return;
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Contact'),
          actions: [
            if (hasPhone)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _call();
                },
                child: const Text('Call'),
              ),
            if (hasEmail)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showEmailSheet(context);
                },
                child: const Text('Email'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _materialSheet(context, [
      if (hasPhone) _SheetItem(LucideIcons.phone, 'Call', _call),
      if (hasEmail)
        _SheetItem(LucideIcons.mail, 'Email', () => _showEmailSheet(context)),
    ]);
  }

  Future<void> _showEmailSheet(BuildContext context) async {
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Send email via'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _emailGmail();
              },
              child: const Text('Gmail'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _emailDefault();
              },
              child: const Text('Mail'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _materialSheet(context, [
      _SheetItem(LucideIcons.mail, 'Gmail', _emailGmail),
      _SheetItem(LucideIcons.mail, 'Default Mail', _emailDefault),
    ]);
  }

  Future<void> _showDirectionsSheet(BuildContext context) async {
    if (!_hasDirections) return;
    // Apple Maps doesn't exist on Android — go straight to Google Maps.
    if (Platform.isAndroid) {
      await _openGoogleMaps();
      return;
    }
    if (Platform.isIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (c) => CupertinoActionSheet(
          title: const Text('Get directions'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(c).pop();
                _openAppleMaps();
              },
              child: const Text('Apple Maps'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(c).pop();
                _openGoogleMaps();
              },
              child: const Text('Google Maps'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
      return;
    }
    await _openGoogleMaps();
  }

  Future<void> _materialSheet(
    BuildContext context,
    List<_SheetItem> items,
  ) async {
    if (items.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            for (final it in items)
              ListTile(
                leading: Icon(it.icon, color: _brand),
                title: Text(it.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  it.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = _readableAddress();
    final lat = customer.latitude;
    final lng = customer.longitude;
    final hasCoords = lat != null && lng != null;
    if (!hasCoords && address.isEmpty && !_hasContact) {
      return const SizedBox.shrink();
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, size: 16, color: _brand),
                const SizedBox(width: 8),
                const Text(
                  'Site location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (hasCoords)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: StaticMapPreview(lat: lat, lng: lng),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              address.isEmpty ? 'No address on file' : address,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color:
                    address.isEmpty ? Colors.grey.shade500 : Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: LucideIcons.phone,
                  label: 'Contact',
                  enabled: _hasContact,
                  onTap: () => _showContactSheet(context),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade200),
              Expanded(
                child: _ActionButton(
                  icon: LucideIcons.navigation,
                  label: 'Directions',
                  enabled: _hasDirections,
                  onTap: () => _showDirectionsSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _brand : Colors.grey.shade400;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem {
  const _SheetItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ─── Expenses tab ───────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.expenses,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<JobExpense> expenses;
  final VoidCallback onAdd;
  final ValueChanged<JobExpense> onEdit;
  final ValueChanged<String> onRemove;

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        expenses.fold<double>(0, (acc, e) => acc + e.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        Row(
          children: [
            const Icon(LucideIcons.wallet, size: 18, color: _brand),
            const SizedBox(width: 8),
            const Text(
              'Expenses',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (expenses.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '(${expenses.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16, color: _brand),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
          _EmptyHint(
            icon: LucideIcons.wallet,
            label: 'Track materials, fuel, and other costs.',
          )
        else ...[
          for (final e in expenses) ...[
            _ExpenseRow(
              expense: e,
              onTap: () => onEdit(e),
              onDelete: () => onRemove(e.id),
              fmtDate: _fmtDate,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brand.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '£${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _brand,
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

// ─── Expense row ────────────────────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.onTap,
    required this.onDelete,
    required this.fmtDate,
  });

  final JobExpense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(DateTime) fmtDate;

  Future<void> _confirmDelete(BuildContext context) async {
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete expense?',
      message: '"${expense.title}" will be removed.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;
    onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: expense.receipt != null
                      ? CachedNetworkImage(
                          imageUrl: expense.receipt!.url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.receipt,
                            color: Colors.grey.shade500,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtDate(expense.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (expense.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        expense.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '£${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    icon: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: Color(0xFFB91C1C),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Linked-quotes tab ──────────────────────────────────────────────

class _LinkedQuotesTab extends StatelessWidget {
  const _LinkedQuotesTab({
    required this.ids,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> ids;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuotesBloc, QuotesState>(
      builder: (context, qState) {
        final byId = {for (final q in qState.items) q.id: q};
        // Preserve link order; drop ids that no longer exist (deleted
        // quotes still leave their id in the job until next save).
        final quotes = <Quote>[
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        final loading =
            qState.status == QuotesStatus.loading && qState.items.isEmpty;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Row(
              children: [
                const Icon(LucideIcons.fileText, size: 18, color: _brand),
                const SizedBox(width: 8),
                const Text(
                  'Quotes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (ids.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${ids.length})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 16, color: _brand),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ids.isEmpty)
              _EmptyHint(
                icon: LucideIcons.fileText,
                label: 'Link quotes to keep this job organised.',
              )
            else if (loading && quotes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: _brand),
                ),
              )
            else
              for (final q in quotes) ...[
                _LinkedQuoteRow(
                  quote: q,
                  onTap: () => Navigator.of(context).pushNamed(
                    '/quotes/new',
                    arguments: q,
                  ),
                  onRemove: () => onRemove(q.id),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

/// Row for a linked quote on the job. Mirrors the terms-list pattern
/// from QuoteSettingsScreen — tap the row to open the quote, trash
/// icon to unlink (with confirm dialog), chevron at the end to signal
/// navigation. "Unlink" is *not* a delete: the quote itself stays in
/// the user's Quotes list.
class _LinkedQuoteRow extends StatelessWidget {
  const _LinkedQuoteRow({
    required this.quote,
    required this.onTap,
    required this.onRemove,
  });

  final Quote quote;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Future<void> _confirmUnlink(BuildContext context) async {
    bool confirmed = false;
    final displayTitle =
        quote.title.isEmpty ? 'Untitled quote' : quote.title;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Unlink "$displayTitle"?',
      message:
          'The quote will be removed from this job. The quote itself stays in your Quotes list.',
      icon: LucideIcons.unlink,
      yesText: 'Unlink',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;
    onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        quote.title.isEmpty ? 'Untitled quote' : quote.title;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(
          displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          quote.reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Unlink',
              icon: Icon(
                LucideIcons.unlink,
                size: 18,
                color: Colors.grey.shade500,
              ),
              onPressed: () => _confirmUnlink(context),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Linked-invoices tab ────────────────────────────────────────────

class _LinkedInvoicesTab extends StatelessWidget {
  const _LinkedInvoicesTab({
    required this.ids,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> ids;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      builder: (context, iState) {
        final byId = {for (final inv in iState.items) inv.id: inv};
        // Preserve link order; drop ids that no longer exist (deleted
        // invoices still leave their id in the job until next save).
        final invoices = <Invoice>[
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        final loading = iState.status == InvoicesStatus.loading &&
            iState.items.isEmpty;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Row(
              children: [
                const Icon(LucideIcons.receipt, size: 18, color: _brand),
                const SizedBox(width: 8),
                const Text(
                  'Invoices',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (ids.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${ids.length})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 16, color: _brand),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ids.isEmpty)
              _EmptyHint(
                icon: LucideIcons.receipt,
                label: 'Link invoices to keep this job organised.',
              )
            else if (loading && invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: _brand),
                ),
              )
            else ...[
              if (invoices.isNotEmpty) ...[
                _InvoicesTotal(invoices: invoices),
                const SizedBox(height: 12),
              ],
              for (final inv in invoices) ...[
                _LinkedInvoiceRow(
                  invoice: inv,
                  onTap: () => Navigator.of(context).pushNamed(
                    '/invoices/new',
                    arguments: inv,
                  ),
                  onRemove: () => onRemove(inv.id),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Branded total card sitting at the top of the Invoices tab inside a
/// job. Pure presentation — caller has already resolved the linked
/// invoices off InvoicesBloc.
class _InvoicesTotal extends StatelessWidget {
  const _InvoicesTotal({required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold<double>(0, (acc, inv) => acc + inv.total);
    return Container(
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brand.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Text(
            'Invoices total',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            '£${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same total card as [_InvoicesTotal] but rendered on the Details tab
/// — resolves invoices from [InvoicesBloc] given just the linked-id
/// list, and hides itself if none of the ids resolve (e.g. the source
/// invoices were deleted).
class _InvoicesTotalCard extends StatelessWidget {
  const _InvoicesTotalCard({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      builder: (context, state) {
        final byId = {for (final inv in state.items) inv.id: inv};
        final invoices = <Invoice>[
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        if (invoices.isEmpty) return const SizedBox.shrink();
        return _InvoicesTotal(invoices: invoices);
      },
    );
  }
}

/// Row for a linked invoice on the job. Same affordances as
/// [_LinkedQuoteRow] — tap to open, trash to unlink (with confirm),
/// chevron at the end.
class _LinkedInvoiceRow extends StatelessWidget {
  const _LinkedInvoiceRow({
    required this.invoice,
    required this.onTap,
    required this.onRemove,
  });

  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String _displayTitle() {
    if (invoice.title.isNotEmpty) return invoice.title;
    if (invoice.lines.isNotEmpty) return invoice.lines.first.item.name;
    return 'Untitled invoice';
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    bool confirmed = false;
    final title = _displayTitle();
    await CommonDialogs.showWarningBox(
      context,
      title: 'Unlink "$title"?',
      message:
          'The invoice will be removed from this job. The invoice itself stays in your Invoices list.',
      icon: LucideIcons.unlink,
      yesText: 'Unlink',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;
    onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(
          _displayTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          invoice.reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Unlink',
              icon: Icon(
                LucideIcons.unlink,
                size: 18,
                color: Colors.grey.shade500,
              ),
              onPressed: () => _confirmUnlink(context),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
