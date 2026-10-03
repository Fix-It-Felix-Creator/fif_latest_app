import 'package:equatable/equatable.dart';

import '../../models/quote_model.dart';

abstract class QuotesEvent extends Equatable {
  const QuotesEvent();

  @override
  List<Object?> get props => const [];
}

class QuotesStartWatching extends QuotesEvent {
  const QuotesStartWatching();
}

class QuotesStopWatching extends QuotesEvent {
  const QuotesStopWatching();
}

class QuotesUpdated extends QuotesEvent {
  const QuotesUpdated(this.items);
  final List<Quote> items;

  @override
  List<Object?> get props => [items];
}

class QuoteDeleteRequested extends QuotesEvent {
  const QuoteDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class QuoteStatusUpdateRequested extends QuotesEvent {
  const QuoteStatusUpdateRequested(this.id, this.status);
  final String id;
  final QuoteStatus status;

  @override
  List<Object?> get props => [id, status];
}
