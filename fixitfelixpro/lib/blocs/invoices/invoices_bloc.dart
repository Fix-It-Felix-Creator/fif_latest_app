import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../core/enum.dart';
import '../../models/invoice_model.dart';
import '../../repositories/invoices/invoices_repository.dart';
import 'invoices_event.dart';
import 'invoices_state.dart';

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  InvoicesBloc({required InvoicesRepository repository})
    : _repository = repository,
      super(InvoicesState.initial) {
    on<InvoicesStartWatching>(_onStart);
    on<InvoicesStopWatching>(_onStop);
    on<InvoicesUpdated>(_onUpdated);
    on<InvoiceDeleteRequested>(_onDelete);
    on<InvoiceStatusUpdateRequested>(_onStatus);
    on<InvoiceMarkPaidRequested>(_onMarkPaid);
  }

  final InvoicesRepository _repository;
  StreamSubscription<List<Invoice>>? _sub;

  void _onStart(InvoicesStartWatching _, Emitter<InvoicesState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: InvoicesStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(InvoicesUpdated(items)),
      onError: (err) {
        debugPrint('InvoicesBloc stream error: $err');
        add(const InvoicesUpdated(<Invoice>[]));
      },
    );
  }

  void _onStop(InvoicesStopWatching _, Emitter<InvoicesState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(InvoicesState.initial);
  }

  void _onUpdated(InvoicesUpdated event, Emitter<InvoicesState> emit) {
    emit(state.copyWith(
      status: InvoicesStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    InvoiceDeleteRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((i) => i.id != event.id).toList(),
    ));
    await _repository.delete(event.id);
  }

  Future<void> _onStatus(
    InvoiceStatusUpdateRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items
          .map((i) => i.id == event.id ? i.copyWith(status: event.status) : i)
          .toList(),
    ));
    await _repository.updateStatus(event.id, event.status);
  }

  Future<void> _onMarkPaid(
    InvoiceMarkPaidRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    final now = DateTime.now();
    emit(state.copyWith(
      items: state.items
          .map((i) => i.id == event.id
              ? i.copyWith(status: InvoiceStatus.paid, paidAt: now)
              : i)
          .toList(),
    ));
    await _repository.markAsPaid(event.id);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
