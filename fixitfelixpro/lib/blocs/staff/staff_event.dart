import 'package:equatable/equatable.dart';

import '../../models/staff.dart';

abstract class StaffEvent extends Equatable {
  const StaffEvent();

  @override
  List<Object?> get props => const [];
}

class StaffStartWatching extends StaffEvent {
  const StaffStartWatching();
}

class StaffStopWatching extends StaffEvent {
  const StaffStopWatching();
}

class StaffUpdated extends StaffEvent {
  const StaffUpdated(this.items);
  final List<Staff> items;

  @override
  List<Object?> get props => [items];
}

class StaffDeleteRequested extends StaffEvent {
  const StaffDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
