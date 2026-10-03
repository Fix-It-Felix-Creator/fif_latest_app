import 'package:equatable/equatable.dart';

import '../core/enum.dart';
import 'bank_details_model.dart';
import 'customer.dart';
import 'invoice_payment_method.dart';
import 'quote_line_draft.dart';
import 'quote_staff_draft.dart';
import 'quote_term_model.dart';
import 'tools/tool_file.dart';
import 'tools/tool_note.dart';
import 'tools/tool_photo.dart';
import 'tools/tool_video.dart';

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get wire => name;

  static InvoiceStatus fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'sent':
        return InvoiceStatus.sent;
      case 'paid':
        return InvoiceStatus.paid;
      case 'overdue':
        return InvoiceStatus.overdue;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      default:
        return InvoiceStatus.draft;
    }
  }
}

/// Invoice document stored under `/invoices/{uid}/{id}`. Customer,
/// staff, pricing items, and bank details (when payment method is
/// bankDeposit) are denormalized into the doc so the saved invoice
/// stays intact even if the source records change later.
///
/// Mirrors the shape of `Quote` — line/staff/term types are the same
/// generic drafts used by quotes since the underlying business rules
/// (rate / markup / discount / quantity) are identical.
class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.reference,
    required this.title,
    required this.status,
    required this.customer,
    required this.date,
    required this.dueDate,
    required this.staff,
    required this.lines,
    required this.total,
    required this.createdAt,
    required this.paymentMethod,
    this.bankSnapshot,
    this.sentAt,
    this.viewedAt,
    this.paidAt,
    this.shareToken,
    this.terms = const <QuoteTerm>[],
    this.attachedPhotos = const <ToolPhoto>[],
    this.attachedVideos = const <ToolVideo>[],
    this.attachedFiles = const <ToolFile>[],
    this.attachedNotes = const <ToolNote>[],
  });

  final String id;
  final String reference;
  final String title;
  final InvoiceStatus status;
  final Customer? customer;
  final DateTime date;

  /// When payment is expected. Drives the "due in N days" display on
  /// the list and PDF.
  final DateTime dueDate;

  final List<QuoteStaffDraft> staff;
  final List<QuoteLineDraft> lines;
  final double total;
  final DateTime createdAt;

  final InvoicePaymentMethod paymentMethod;

  /// Bank details snapshot taken at the time the invoice was saved. Only
  /// populated when [paymentMethod] is [InvoicePaymentMethod.bankDeposit].
  /// Frozen on the invoice so a later edit to companyDetails.bankDetails
  /// can't retroactively change a sent invoice's payment instructions.
  final BankDetailsModel? bankSnapshot;

  /// First time the invoice was actually sent to the customer.
  final DateTime? sentAt;

  /// First time anyone with the share link opened the public viewer.
  /// Mirrored from `/invoiceShares/{token}/viewedAt` by the Cloud
  /// Function so clients can read it without rule changes.
  final DateTime? viewedAt;

  /// Set when the tradesman taps "Mark as paid" on the invoice details.
  final DateTime? paidAt;

  /// Stable token minted by the share-link Cloud Function. Server-
  /// owned — the client only echoes it back on save so re-saves don't
  /// wipe it. Used by the delete flow to tombstone the right share doc.
  final String? shareToken;

  /// Terms & conditions attached to this invoice. Denormalized from the
  /// shared term library (under `/quoteTerms/{uid}`) so the invoice
  /// stays intact even if the source term is later edited or deleted.
  final List<QuoteTerm> terms;

  /// Snapshots of photos, videos, files, and notes pulled from the
  /// Tools section at attach time. Frozen on the invoice so a later
  /// edit or delete in /userTools/{uid} doesn't mutate a saved invoice.
  final List<ToolPhoto> attachedPhotos;
  final List<ToolVideo> attachedVideos;
  final List<ToolFile> attachedFiles;
  final List<ToolNote> attachedNotes;

  Invoice copyWith({
    String? reference,
    String? title,
    InvoiceStatus? status,
    Customer? customer,
    DateTime? date,
    DateTime? dueDate,
    List<QuoteStaffDraft>? staff,
    List<QuoteLineDraft>? lines,
    double? total,
    InvoicePaymentMethod? paymentMethod,
    BankDetailsModel? bankSnapshot,
    bool clearBankSnapshot = false,
    DateTime? sentAt,
    DateTime? viewedAt,
    DateTime? paidAt,
    bool clearPaidAt = false,
    String? shareToken,
    List<QuoteTerm>? terms,
    List<ToolPhoto>? attachedPhotos,
    List<ToolVideo>? attachedVideos,
    List<ToolFile>? attachedFiles,
    List<ToolNote>? attachedNotes,
  }) {
    return Invoice(
      id: id,
      reference: reference ?? this.reference,
      title: title ?? this.title,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      staff: staff ?? this.staff,
      lines: lines ?? this.lines,
      total: total ?? this.total,
      createdAt: createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankSnapshot:
          clearBankSnapshot ? null : (bankSnapshot ?? this.bankSnapshot),
      sentAt: sentAt ?? this.sentAt,
      viewedAt: viewedAt ?? this.viewedAt,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      shareToken: shareToken ?? this.shareToken,
      terms: terms ?? this.terms,
      attachedPhotos: attachedPhotos ?? this.attachedPhotos,
      attachedVideos: attachedVideos ?? this.attachedVideos,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      attachedNotes: attachedNotes ?? this.attachedNotes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    reference,
    title,
    status,
    customer,
    date,
    dueDate,
    staff,
    lines,
    total,
    createdAt,
    paymentMethod,
    bankSnapshot,
    sentAt,
    viewedAt,
    paidAt,
    shareToken,
    terms,
    attachedPhotos,
    attachedVideos,
    attachedFiles,
    attachedNotes,
  ];
}
