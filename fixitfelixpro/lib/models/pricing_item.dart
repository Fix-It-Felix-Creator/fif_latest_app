import 'package:equatable/equatable.dart';

enum PricingKind { service, material }

extension PricingKindX on PricingKind {
  String get wire => this == PricingKind.service ? 'service' : 'material';
  String get label => this == PricingKind.service ? 'Service' : 'Material';

  static PricingKind fromWire(String? raw) {
    return (raw ?? '').toLowerCase() == 'material'
        ? PricingKind.material
        : PricingKind.service;
  }
}

class PricingItem extends Equatable {
  final String id;
  final PricingKind kind;
  final String name;
  final double unitCost;
  final double unitMarkup;
  final String itemCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  PricingItem({
    required this.id,
    required this.kind,
    required this.name,
    this.unitCost = 0,
    this.unitMarkup = 0,
    this.itemCode = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  PricingItem copyWith({
    String? id,
    PricingKind? kind,
    String? name,
    double? unitCost,
    double? unitMarkup,
    String? itemCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PricingItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      unitCost: unitCost ?? this.unitCost,
      unitMarkup: unitMarkup ?? this.unitMarkup,
      itemCode: itemCode ?? this.itemCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    name,
    unitCost,
    unitMarkup,
    itemCode,
    createdAt,
    updatedAt,
  ];
}
