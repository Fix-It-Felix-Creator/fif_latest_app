import 'package:equatable/equatable.dart';

import '../../../models/tools/tool_photo.dart';

abstract class PhotosEvent extends Equatable {
  const PhotosEvent();

  @override
  List<Object?> get props => const [];
}

class PhotosStartWatching extends PhotosEvent {
  const PhotosStartWatching();
}

class PhotosStopWatching extends PhotosEvent {
  const PhotosStopWatching();
}

class PhotosUpdated extends PhotosEvent {
  const PhotosUpdated(this.items);
  final List<ToolPhoto> items;

  @override
  List<Object?> get props => [items];
}

class PhotoDeleteRequested extends PhotosEvent {
  const PhotoDeleteRequested(this.photo);
  final ToolPhoto photo;

  @override
  List<Object?> get props => [photo];
}
