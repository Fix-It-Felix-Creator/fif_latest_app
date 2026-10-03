import 'package:equatable/equatable.dart';

import '../../../models/tools/tool_photo.dart';

enum PhotosStatus { initial, loading, loaded, error }

class PhotosState extends Equatable {
  const PhotosState({
    this.status = PhotosStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final PhotosStatus status;
  final List<ToolPhoto> items;
  final String? errorMessage;

  static const initial = PhotosState();

  PhotosState copyWith({
    PhotosStatus? status,
    List<ToolPhoto>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhotosState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
