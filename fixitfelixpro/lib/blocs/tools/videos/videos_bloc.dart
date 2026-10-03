import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../models/tools/tool_video.dart';
import '../../../repositories/tools/videos_repository.dart';

abstract class VideosEvent extends Equatable {
  const VideosEvent();
  @override
  List<Object?> get props => const [];
}

class VideosStartWatching extends VideosEvent {
  const VideosStartWatching();
}

class VideosStopWatching extends VideosEvent {
  const VideosStopWatching();
}

class VideosUpdated extends VideosEvent {
  const VideosUpdated(this.items);
  final List<ToolVideo> items;
  @override
  List<Object?> get props => [items];
}

class VideoDeleteRequested extends VideosEvent {
  const VideoDeleteRequested(this.video);
  final ToolVideo video;
  @override
  List<Object?> get props => [video];
}

enum VideosStatus { initial, loading, loaded, error }

class VideosState extends Equatable {
  const VideosState({
    this.status = VideosStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final VideosStatus status;
  final List<ToolVideo> items;
  final String? errorMessage;

  static const initial = VideosState();

  VideosState copyWith({
    VideosStatus? status,
    List<ToolVideo>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VideosState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

class VideosBloc extends Bloc<VideosEvent, VideosState> {
  VideosBloc({required VideosRepository repository})
    : _repository = repository,
      super(VideosState.initial) {
    on<VideosStartWatching>((_, emit) {
      _sub?.cancel();
      emit(state.copyWith(status: VideosStatus.loading, clearError: true));
      _sub = _repository.watchAll().listen(
        (items) => add(VideosUpdated(items)),
        onError: (err) {
          debugPrint('VideosBloc stream error: $err');
          add(const VideosUpdated(<ToolVideo>[]));
        },
      );
    });
    on<VideosStopWatching>((_, emit) {
      _sub?.cancel();
      _sub = null;
      emit(VideosState.initial);
    });
    on<VideosUpdated>((event, emit) {
      emit(state.copyWith(
        status: VideosStatus.loaded,
        items: event.items,
        clearError: true,
      ));
    });
    on<VideoDeleteRequested>((event, emit) async {
      emit(state.copyWith(
        items: state.items.where((v) => v.id != event.video.id).toList(),
      ));
      await _repository.delete(event.video);
    });
  }

  final VideosRepository _repository;
  StreamSubscription<List<ToolVideo>>? _sub;

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
