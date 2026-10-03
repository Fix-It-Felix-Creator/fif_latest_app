import 'package:equatable/equatable.dart';

import '../../models/customer.dart';

enum CustomersStatus { initial, loading, loaded, error }

class CustomersState extends Equatable {
  const CustomersState({
    this.status = CustomersStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final CustomersStatus status;
  final List<Customer> items;
  final String? errorMessage;

  static const initial = CustomersState();

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomersState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
