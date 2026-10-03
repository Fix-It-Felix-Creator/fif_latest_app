import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/quote_model.dart';
import '../../repositories/quotes/quotes_repository.dart';
import 'quotes_event.dart';
import 'quotes_state.dart';

class QuotesBloc extends Bloc<QuotesEvent, QuotesState> {
  QuotesBloc({required QuotesRepository repository})
    : _repository = repository,
      super(QuotesState.initial) {
    on<QuotesStartWatching>(_onStart);
    on<QuotesStopWatching>(_onStop);
    on<QuotesUpdated>(_onUpdated);
    on<QuoteDeleteRequested>(_onDelete);
    on<QuoteStatusUpdateRequested>(_onStatus);
  }

  final QuotesRepository _repository;
  StreamSubscription<List<Quote>>? _sub;

  void _onStart(QuotesStartWatching _, Emitter<QuotesState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: QuotesStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(QuotesUpdated(items)),
      onError: (err) {
        debugPrint('QuotesBloc stream error: $err');
        add(const QuotesUpdated(<Quote>[]));
      },
    );
  }

  void _onStop(QuotesStopWatching _, Emitter<QuotesState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(QuotesState.initial);
  }

  void _onUpdated(QuotesUpdated event, Emitter<QuotesState> emit) {
    emit(state.copyWith(
      status: QuotesStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    QuoteDeleteRequested event,
    Emitter<QuotesState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((q) => q.id != event.id).toList(),
    ));
    await _repository.delete(event.id);
  }

  Future<void> _onStatus(
    QuoteStatusUpdateRequested event,
    Emitter<QuotesState> emit,
  ) async {
    // Optimistic update so the badge flips immediately.
    emit(state.copyWith(
      items: state.items
          .map((q) => q.id == event.id ? q.copyWith(status: event.status) : q)
          .toList(),
    ));
    await _repository.updateStatus(event.id, event.status);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
