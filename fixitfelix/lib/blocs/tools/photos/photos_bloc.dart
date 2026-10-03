import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../models/tools/tool_photo.dart';
import '../../../repositories/tools/photos_repository.dart';
import 'photos_event.dart';
import 'photos_state.dart';

class PhotosBloc extends Bloc<PhotosEvent, PhotosState> {
  PhotosBloc({required PhotosRepository repository})
    : _repository = repository,
      super(PhotosState.initial) {
    on<PhotosStartWatching>(_onStart);
    on<PhotosStopWatching>(_onStop);
    on<PhotosUpdated>(_onUpdated);
    on<PhotoDeleteRequested>(_onDelete);
  }

  final PhotosRepository _repository;
  StreamSubscription<List<ToolPhoto>>? _sub;

  void _onStart(PhotosStartWatching _, Emitter<PhotosState> emit) {
    _sub?.cancel();
    emit(state.copyWith(status: PhotosStatus.loading, clearError: true));
    _sub = _repository.watchAll().listen(
      (items) => add(PhotosUpdated(items)),
      onError: (err) {
        debugPrint('PhotosBloc stream error: $err');
        add(const PhotosUpdated(<ToolPhoto>[]));
      },
    );
  }

  void _onStop(PhotosStopWatching _, Emitter<PhotosState> emit) {
    _sub?.cancel();
    _sub = null;
    emit(PhotosState.initial);
  }

  void _onUpdated(PhotosUpdated event, Emitter<PhotosState> emit) {
    emit(state.copyWith(
      status: PhotosStatus.loaded,
      items: event.items,
      clearError: true,
    ));
  }

  Future<void> _onDelete(
    PhotoDeleteRequested event,
    Emitter<PhotosState> emit,
  ) async {
    emit(state.copyWith(
      items: state.items.where((p) => p.id != event.photo.id).toList(),
    ));
    await _repository.delete(event.photo);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
