import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/in_app_notification.dart';
import '../../repositories/notifications/notifications_repository.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required NotificationsRepository repository})
    : _repository = repository,
      super(NotificationsState.initial) {
    on<NotificationsStartWatching>(_onStart);
    on<NotificationsStopWatching>(_onStop);
    on<NotificationsUpdated>(_onUpdated);
    on<NotificationsMarkRead>(_onMarkRead);
    on<NotificationsMarkAllRead>(_onMarkAllRead);
    on<NotificationsClearOne>(_onClearOne);
    on<NotificationsClearAll>(_onClearAll);
  }

  final NotificationsRepository _repository;
  StreamSubscription<List<InAppNotification>>? _sub;

  void _onStart(
    NotificationsStartWatching event,
    Emitter<NotificationsState> emit,
  ) {
    _sub?.cancel();
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(NotificationsUpdated(items)),
      onError: (err) {
        debugPrint('NotificationsBloc stream error: $err');
      },
    );
  }

  void _onStop(
    NotificationsStopWatching event,
    Emitter<NotificationsState> emit,
  ) {
    _sub?.cancel();
    _sub = null;
    emit(NotificationsState.initial);
  }

  void _onUpdated(
    NotificationsUpdated event,
    Emitter<NotificationsState> emit,
  ) {
    emit(
      state.copyWith(
        status: NotificationsStatus.loaded,
        items: event.items,
        clearError: true,
      ),
    );
  }

  Future<void> _onMarkRead(
    NotificationsMarkRead event,
    Emitter<NotificationsState> emit,
  ) async {
    // Optimistic update — stream will reconcile.
    final updated = state.items
        .map(
          (n) => n.id == event.id && !n.read
              ? InAppNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  createdAt: n.createdAt,
                  read: true,
                  readAt: DateTime.now(),
                  payload: n.payload,
                )
              : n,
        )
        .toList();
    emit(state.copyWith(items: updated));
    await _repository.markRead(event.id);
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    final now = DateTime.now();
    final updated = state.items
        .map(
          (n) => n.read
              ? n
              : InAppNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  createdAt: n.createdAt,
                  read: true,
                  readAt: now,
                  payload: n.payload,
                ),
        )
        .toList();
    emit(state.copyWith(items: updated));
    await _repository.markAllRead();
  }

  Future<void> _onClearOne(
    NotificationsClearOne event,
    Emitter<NotificationsState> emit,
  ) async {
    final updated = state.items.where((n) => n.id != event.id).toList();
    emit(state.copyWith(items: updated));
    await _repository.clear(event.id);
  }

  Future<void> _onClearAll(
    NotificationsClearAll event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(items: const []));
    await _repository.clearAll();
  }

  void cancelSubscriptions() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  Future<void> close() {
    cancelSubscriptions();
    return super.close();
  }
}
