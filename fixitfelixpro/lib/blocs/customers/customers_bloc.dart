import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/customer.dart';
import '../../repositories/customers/customers_repository.dart';
import 'customers_event.dart';
import 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc({required CustomersRepository repository})
    : _repository = repository,
      super(CustomersState.initial) {
    on<CustomersStartWatching>(_onStart);
    on<CustomersStopWatching>(_onStop);
    on<CustomersUpdated>(_onUpdated);
    on<CustomerDeleteRequested>(_onDelete);
  }

  final CustomersRepository _repository;
  StreamSubscription<List<Customer>>? _sub;

  void _onStart(CustomersStartWatching _, Emitter<CustomersState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: CustomersStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(CustomersUpdated(items)),
      onError: (err) {
        debugPrint('CustomersBloc stream error: $err');
      },
    );
  }

  void _onStop(CustomersStopWatching _, Emitter<CustomersState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(CustomersState.initial);
  }

  void _onUpdated(CustomersUpdated event, Emitter<CustomersState> emit) {
    emit(state.copyWith(
      status: CustomersStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    CustomerDeleteRequested event,
    Emitter<CustomersState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((c) => c.id != event.id).toList(),
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
