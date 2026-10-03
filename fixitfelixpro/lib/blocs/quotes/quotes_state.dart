import 'package:equatable/equatable.dart';

import '../../models/quote_model.dart';

enum QuotesStatus { initial, loading, loaded, error }

class QuotesState extends Equatable {
  const QuotesState({
    this.status = QuotesStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final QuotesStatus status;
  final List<Quote> items;
  final String? errorMessage;

  static const initial = QuotesState();

  QuotesState copyWith({
    QuotesStatus? status,
    List<Quote>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return QuotesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
