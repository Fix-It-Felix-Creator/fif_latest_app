import 'package:equatable/equatable.dart';

import '../../models/staff.dart';

enum StaffStatus { initial, loading, loaded, error }

class StaffState extends Equatable {
  const StaffState({
    this.status = StaffStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final StaffStatus status;
  final List<Staff> items;
  final String? errorMessage;

  static const initial = StaffState();

  StaffState copyWith({
    StaffStatus? status,
    List<Staff>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StaffState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
