import 'package:equatable/equatable.dart';

import 'tools/tool_photo.dart';

/// One row of cost-tracking on a Job. Embedded inline on the Job
/// document at `/jobs/{uid}/{jobId}/expenses/[i]` — there's no
/// separate /expenses collection because expenses don't exist outside
/// the parent job.
class JobExpense extends Equatable {
  const JobExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.description = '',
    this.receipt,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String description;

  /// Snapshot of a [ToolPhoto] from the Photos tool, attached as the
  /// receipt for this expense. Frozen at attach time so a later delete
  /// from /userTools/{uid}/photos doesn't strip the receipt off a
  /// saved expense.
  final ToolPhoto? receipt;

  JobExpense copyWith({
    String? title,
    double? amount,
    DateTime? date,
    String? description,
    ToolPhoto? receipt,
    bool clearReceipt = false,
  }) {
    return JobExpense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      receipt: clearReceipt ? null : (receipt ?? this.receipt),
    );
  }

  Map<String, dynamic> toRtdb() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        if (description.isNotEmpty) 'description': description,
        if (receipt != null)
          'receipt': {'id': receipt!.id, ...receipt!.toRtdb()},
      };

  factory JobExpense.fromRtdb(Map<dynamic, dynamic> raw) {
    // `notes` was the original field name; honour both for old rows
    // saved before the rename.
    final descRaw =
        raw['description']?.toString() ?? raw['notes']?.toString() ?? '';
    ToolPhoto? receipt;
    final receiptRaw = raw['receipt'];
    if (receiptRaw is Map) {
      receipt = ToolPhoto.fromRtdb(
        receiptRaw['id']?.toString() ?? '',
        receiptRaw,
      );
    }
    return JobExpense(
      id: raw['id']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      amount: (raw['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(
        (raw['date'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      description: descRaw,
      receipt: receipt,
    );
  }

  @override
  List<Object?> get props => [id, title, amount, date, description, receipt];
}
