import 'package:equatable/equatable.dart';

import '../../core/enum.dart';
import '../../models/invoice_model.dart';

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();

  @override
  List<Object?> get props => const [];
}

class InvoicesStartWatching extends InvoicesEvent {
  const InvoicesStartWatching();
}

class InvoicesStopWatching extends InvoicesEvent {
  const InvoicesStopWatching();
}

class InvoicesUpdated extends InvoicesEvent {
  const InvoicesUpdated(this.items);
  final List<Invoice> items;

  @override
  List<Object?> get props => [items];
}

class InvoiceDeleteRequested extends InvoicesEvent {
  const InvoiceDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class InvoiceStatusUpdateRequested extends InvoicesEvent {
  const InvoiceStatusUpdateRequested(this.id, this.status);
  final String id;
  final InvoiceStatus status;

  @override
  List<Object?> get props => [id, status];
}

class InvoiceMarkPaidRequested extends InvoicesEvent {
  const InvoiceMarkPaidRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
