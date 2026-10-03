import 'package:equatable/equatable.dart';

import '../../models/customer.dart';

abstract class CustomersEvent extends Equatable {
  const CustomersEvent();

  @override
  List<Object?> get props => const [];
}

class CustomersStartWatching extends CustomersEvent {
  const CustomersStartWatching();
}

class CustomersStopWatching extends CustomersEvent {
  const CustomersStopWatching();
}

class CustomersUpdated extends CustomersEvent {
  const CustomersUpdated(this.items);
  final List<Customer> items;

  @override
  List<Object?> get props => [items];
}

class CustomerDeleteRequested extends CustomersEvent {
  const CustomerDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
