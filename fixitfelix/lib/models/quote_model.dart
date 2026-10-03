import 'package:equatable/equatable.dart';

import 'customer.dart';
import 'quote_expiry.dart';
import 'quote_line_draft.dart';
import 'quote_staff_draft.dart';
import 'quote_term_model.dart';
import 'tools/tool_file.dart';
import 'tools/tool_note.dart';
import 'tools/tool_photo.dart';
import 'tools/tool_video.dart';

enum QuoteStatus { draft, sent, accepted, rejected }

extension QuoteStatusX on QuoteStatus {
  String get label {
    switch (this) {
      case QuoteStatus.draft:
        return 'Draft';
      case QuoteStatus.sent:
        return 'Sent';
      case QuoteStatus.accepted:
        return 'Accept';
      case QuoteStatus.rejected:
        return 'Reject';
    }
  }

  String get wire => name;

  static QuoteStatus fromWire(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'sent':
        return QuoteStatus.sent;
      case 'accepted':
        return QuoteStatus.accepted;
      case 'rejected':
        return QuoteStatus.rejected;
      default:
        return QuoteStatus.draft;
    }
  }
}

class Quote extends Equatable {
  const Quote({
    required this.id,
    required this.reference,
    required this.title,
    required this.status,
    required this.customer,
    required this.date,
    required this.expiry,
    required this.staff,
    required this.lines,
    required this.total,
    required this.createdAt,
    this.sentAt,
    this.viewedAt,
    this.respondedAt,
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
  final QuoteStatus status;
  final Customer? customer;
  final DateTime date;
  final QuoteExpiry expiry;
  final List<QuoteStaffDraft> staff;
  final List<QuoteLineDraft> lines;
  final double total;
  final DateTime createdAt;

  /// First time the tradesman flipped the quote to `sent`. Mirrors the
  /// activity timeline shown in the locked details view. Null while the
  /// quote is still a draft.
  final DateTime? sentAt;

  /// First time anyone with the share link opened the public viewer.
  /// Mirrored from `/quoteShares/{token}/viewedAt` by the Cloud
  /// Function so clients can read it without rule changes.
  final DateTime? viewedAt;

  /// When the customer accepted or rejected the quote on the public
  /// viewer. Use `status` to know which action it was.
  final DateTime? respondedAt;

  /// Stable token minted by the share-link Cloud Function. Server-
  /// owned — the client only echoes it back on save so re-saves don't
  /// wipe it. Used by the delete flow to tombstone the right share
  /// doc.
  final String? shareToken;

  /// Terms & conditions attached to this quote. Denormalized from the
  /// tradesman's term library so a quote remains intact even if the
  /// source term is later edited or deleted.
  final List<QuoteTerm> terms;

  /// Snapshots of photos, videos, files, and notes pulled from the
  /// Tools section at attach time. Frozen on the quote so a later
  /// edit or delete in /userTools/{uid} doesn't mutate a saved quote.
  final List<ToolPhoto> attachedPhotos;
  final List<ToolVideo> attachedVideos;
  final List<ToolFile> attachedFiles;
  final List<ToolNote> attachedNotes;

  Quote copyWith({
    String? reference,
    String? title,
    QuoteStatus? status,
    Customer? customer,
    DateTime? date,
    QuoteExpiry? expiry,
    List<QuoteStaffDraft>? staff,
    List<QuoteLineDraft>? lines,
    double? total,
    DateTime? sentAt,
    DateTime? viewedAt,
    DateTime? respondedAt,
    String? shareToken,
    List<QuoteTerm>? terms,
    List<ToolPhoto>? attachedPhotos,
    List<ToolVideo>? attachedVideos,
    List<ToolFile>? attachedFiles,
    List<ToolNote>? attachedNotes,
  }) {
    return Quote(
      id: id,
      reference: reference ?? this.reference,
      title: title ?? this.title,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      expiry: expiry ?? this.expiry,
      staff: staff ?? this.staff,
      lines: lines ?? this.lines,
      total: total ?? this.total,
      createdAt: createdAt,
      sentAt: sentAt ?? this.sentAt,
      viewedAt: viewedAt ?? this.viewedAt,
      respondedAt: respondedAt ?? this.respondedAt,
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
    expiry,
    staff,
    lines,
    total,
    createdAt,
    sentAt,
    viewedAt,
    respondedAt,
    shareToken,
    terms,
    attachedPhotos,
    attachedVideos,
    attachedFiles,
    attachedNotes,
  ];
}
