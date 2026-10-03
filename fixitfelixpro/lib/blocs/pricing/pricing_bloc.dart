import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/pricing_item.dart';
import '../../repositories/pricing/pricing_repository.dart';
import 'pricing_event.dart';
import 'pricing_state.dart';

class PricingBloc extends Bloc<PricingEvent, PricingState> {
  PricingBloc({required PricingRepository repository})
    : _repository = repository,
      super(PricingState.initial) {
    on<PricingStartWatching>(_onStart);
    on<PricingStopWatching>(_onStop);
    on<PricingUpdated>(_onUpdated);
    on<PricingDeleteRequested>(_onDelete);
  }

  final PricingRepository _repository;
  StreamSubscription<List<PricingItem>>? _sub;

  void _onStart(PricingStartWatching _, Emitter<PricingState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: PricingStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(PricingUpdated(items)),
      onError: (err) {
        debugPrint('PricingBloc stream error: $err');
      },
    );
  }

  void _onStop(PricingStopWatching _, Emitter<PricingState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(PricingState.initial);
  }

  void _onUpdated(PricingUpdated event, Emitter<PricingState> emit) {
    emit(state.copyWith(
      status: PricingStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    PricingDeleteRequested event,
    Emitter<PricingState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((p) => p.id != event.id).toList(),
    ));
    await _repository.delete(event.id);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
