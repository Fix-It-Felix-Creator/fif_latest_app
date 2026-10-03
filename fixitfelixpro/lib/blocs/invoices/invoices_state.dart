import 'package:equatable/equatable.dart';

import '../../models/invoice_model.dart';

enum InvoicesStatus { initial, loading, loaded, error }

class InvoicesState extends Equatable {
  const InvoicesState({
    this.status = InvoicesStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final InvoicesStatus status;
  final List<Invoice> items;
  final String? errorMessage;

  static const initial = InvoicesState();

  InvoicesState copyWith({
    InvoicesStatus? status,
    List<Invoice>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InvoicesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
