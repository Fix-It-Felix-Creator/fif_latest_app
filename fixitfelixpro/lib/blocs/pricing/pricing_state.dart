import 'package:equatable/equatable.dart';

import '../../models/pricing_item.dart';

enum PricingStatus { initial, loading, loaded, error }

class PricingState extends Equatable {
  const PricingState({
    this.status = PricingStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final PricingStatus status;
  final List<PricingItem> items;
  final String? errorMessage;

  static const initial = PricingState();

  List<PricingItem> byKind(PricingKind kind) =>
      items.where((p) => p.kind == kind).toList();

  PricingState copyWith({
    PricingStatus? status,
    List<PricingItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PricingState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
