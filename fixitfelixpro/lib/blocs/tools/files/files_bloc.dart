import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../models/tools/tool_file.dart';
import '../../../repositories/tools/files_repository.dart';

abstract class FilesEvent extends Equatable {
  const FilesEvent();
  @override
  List<Object?> get props => const [];
}

class FilesStartWatching extends FilesEvent {
  const FilesStartWatching();
}

class FilesStopWatching extends FilesEvent {
  const FilesStopWatching();
}

class FilesUpdated extends FilesEvent {
  const FilesUpdated(this.items);
  final List<ToolFile> items;
  @override
  List<Object?> get props => [items];
}

class FileDeleteRequested extends FilesEvent {
  const FileDeleteRequested(this.file);
  final ToolFile file;
  @override
  List<Object?> get props => [file];
}

enum FilesStatus { initial, loading, loaded, error }

class FilesState extends Equatable {
  const FilesState({
    this.status = FilesStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final FilesStatus status;
  final List<ToolFile> items;
  final String? errorMessage;

  static const initial = FilesState();

  FilesState copyWith({
    FilesStatus? status,
    List<ToolFile>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FilesState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  FilesBloc({required FilesRepository repository})
    : _repository = repository,
      super(FilesState.initial) {
    on<FilesStartWatching>((_, emit) {
      _sub?.cancel();
      emit(state.copyWith(status: FilesStatus.loading, clearError: true));
      _sub = _repository.watchAll().listen(
        (items) => add(FilesUpdated(items)),
        onError: (err) {
          debugPrint('FilesBloc stream error: $err');
          add(const FilesUpdated(<ToolFile>[]));
        },
      );
    });
    on<FilesStopWatching>((_, emit) {
      _sub?.cancel();
      _sub = null;
      emit(FilesState.initial);
    });
    on<FilesUpdated>((event, emit) {
      emit(state.copyWith(
        status: FilesStatus.loaded,
        items: event.items,
        clearError: true,
      ));
    });
    on<FileDeleteRequested>((event, emit) async {
      emit(state.copyWith(
        items: state.items.where((f) => f.id != event.file.id).toList(),
      ));
      await _repository.delete(event.file);
    });
  }

  final FilesRepository _repository;
  StreamSubscription<List<ToolFile>>? _sub;

  @override
  Future<void> close() {
    _sub?.cancel();
    _sub = null;
    return super.close();
  }
}
