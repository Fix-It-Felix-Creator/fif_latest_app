import 'package:equatable/equatable.dart';

import 'customer.dart';
import 'job_expense.dart';
import 'job_time_entry.dart';
import 'tools/tool_file.dart';
import 'tools/tool_note.dart';
import 'tools/tool_photo.dart';
import 'tools/tool_video.dart';

enum JobStatus { draft, active, completed, cancelled }

extension JobStatusX on JobStatus {
  String get label {
    switch (this) {
      case JobStatus.draft:
        return 'Draft';
      case JobStatus.active:
        return 'Active';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get wire => name;

  static JobStatus fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'active':
        return JobStatus.active;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.draft;
    }
  }
}

/// Container for a piece of work the tradesman is delivering for a
/// customer. Stored at `/jobs/{uid}/{jobId}` in RTDB.
///
/// Tools-style attachments (photos / videos / files / notes) are
/// snapshotted onto the doc, so deleting the source from /userTools
/// won't mutate the job.
class Job extends Equatable {
  const Job({
    required this.id,
    required this.reference,
    required this.title,
    required this.description,
    required this.status,
    required this.customer,
    required this.startDate,
    required this.createdAt,
    this.updatedAt,
    this.expenses = const <JobExpense>[],
    this.attachedPhotos = const <ToolPhoto>[],
    this.attachedVideos = const <ToolVideo>[],
    this.attachedFiles = const <ToolFile>[],
    this.attachedNotes = const <ToolNote>[],
    this.linkedQuoteIds = const <String>[],
    this.linkedInvoiceIds = const <String>[],
    this.clockInAt,
    this.timeEntries = const <JobTimeEntry>[],
  });

  final String id;
  final String reference;
  final String title;
  final String description;
  final JobStatus status;
  final Customer? customer;
  final DateTime startDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Timestamp of the currently-running clock session, or null when the
  /// tradesperson is not clocked in on this job. A non-null value means a
  /// live timer is ticking on the home tab.
  final DateTime? clockInAt;

  /// Completed clock-in → clock-out sessions.
  final List<JobTimeEntry> timeEntries;

  final List<JobExpense> expenses;
  final List<ToolPhoto> attachedPhotos;
  final List<ToolVideo> attachedVideos;
  final List<ToolFile> attachedFiles;
  final List<ToolNote> attachedNotes;

  /// Ids of quotes linked to this job for organisation only — the quote
  /// docs themselves live under `/quotes/{uid}/{id}` and are unaffected
  /// when this list is mutated.
  final List<String> linkedQuoteIds;

  /// Same idea as [linkedQuoteIds] but for invoices — link is purely
  /// organisational, source docs live under `/invoices/{uid}/{id}`.
  final List<String> linkedInvoiceIds;

  Job copyWith({
    String? reference,
    String? title,
    String? description,
    JobStatus? status,
    Customer? customer,
    DateTime? startDate,
    DateTime? updatedAt,
    List<JobExpense>? expenses,
    List<ToolPhoto>? attachedPhotos,
    List<ToolVideo>? attachedVideos,
    List<ToolFile>? attachedFiles,
    List<ToolNote>? attachedNotes,
    List<String>? linkedQuoteIds,
    List<String>? linkedInvoiceIds,
    DateTime? clockInAt,
    bool clearClockIn = false,
    List<JobTimeEntry>? timeEntries,
  }) {
    return Job(
      id: id,
      reference: reference ?? this.reference,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expenses: expenses ?? this.expenses,
      attachedPhotos: attachedPhotos ?? this.attachedPhotos,
      attachedVideos: attachedVideos ?? this.attachedVideos,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      attachedNotes: attachedNotes ?? this.attachedNotes,
      linkedQuoteIds: linkedQuoteIds ?? this.linkedQuoteIds,
      linkedInvoiceIds: linkedInvoiceIds ?? this.linkedInvoiceIds,
      clockInAt: clearClockIn ? null : (clockInAt ?? this.clockInAt),
      timeEntries: timeEntries ?? this.timeEntries,
    );
  }

  /// True while a clock session is running on this job.
  bool get isClockedIn => clockInAt != null;

  /// Total time from completed sessions only (excludes any running one).
  Duration get loggedDuration =>
      timeEntries.fold(Duration.zero, (acc, e) => acc + e.duration);

  /// Sum of expenses on this job. Drives the cost summary on the
  /// list / details views.
  double get expensesTotal =>
      expenses.fold<double>(0, (acc, e) => acc + e.amount);

  @override
  List<Object?> get props => [
        id,
        reference,
        title,
        description,
        status,
        customer,
        startDate,
        createdAt,
        updatedAt,
        expenses,
        attachedPhotos,
        attachedVideos,
        attachedFiles,
        attachedNotes,
        linkedQuoteIds,
        linkedInvoiceIds,
        clockInAt,
        timeEntries,
      ];
}
