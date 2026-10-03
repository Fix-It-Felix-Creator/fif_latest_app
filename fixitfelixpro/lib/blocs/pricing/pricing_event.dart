import 'package:equatable/equatable.dart';

import '../../models/pricing_item.dart';

abstract class PricingEvent extends Equatable {
  const PricingEvent();

  @override
  List<Object?> get props => const [];
}

class PricingStartWatching extends PricingEvent {
  const PricingStartWatching();
}

class PricingStopWatching extends PricingEvent {
  const PricingStopWatching();
}

class PricingUpdated extends PricingEvent {
  const PricingUpdated(this.items);
  final List<PricingItem> items;

  @override
  List<Object?> get props => [items];
}

class PricingDeleteRequested extends PricingEvent {
  const PricingDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
