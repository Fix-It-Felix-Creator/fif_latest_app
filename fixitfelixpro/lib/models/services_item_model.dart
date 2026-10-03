import 'package:equatable/equatable.dart';

/// Distinguishes catalog entries stored under services vs materials paths.
enum PriceListItemKind {
  service,
  material,
}

PriceListItemKind priceListItemKindFromWire(String? v) {
  switch (v) {
    case 'material':
      return PriceListItemKind.material;
    default:
      return PriceListItemKind.service;
  }
}

/// Line item / catalog row for invoices and quotations.
///
/// Selling unit price is always [unitCost] + [unitMarkup]. Legacy records that
/// only stored `unitPrice` are loaded as cost `0` and markup equal to that value.
class ServicesItemModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final int quantity;
  final double unitCost;
  final double unitMarkup;
  final String sku;
  final PriceListItemKind kind;

  const ServicesItemModel({
    required this.id,
    required this.name,
    this.description = '',
    this.quantity = 1,
    this.unitCost = 0,
    this.unitMarkup = 0,
    this.sku = '',
    this.kind = PriceListItemKind.service,
  });

  double get unitPrice => unitCost + unitMarkup;

  double get total => quantity * unitPrice;

  factory ServicesItemModel.fromJson(Map<String, dynamic> json, String id) {
    final legacyUnit = (json['unitPrice'] as num?)?.toDouble();
    final uc = (json['unitCost'] as num?)?.toDouble();
    final um = (json['unitMarkup'] as num?)?.toDouble();

    final double cost;
    final double markup;
    if (uc != null || um != null) {
      cost = uc ?? 0.0;
      markup = um ?? 0.0;
    } else {
      cost = 0.0;
      markup = legacyUnit ?? 0.0;
    }

    return ServicesItemModel(
      id: id,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitCost: cost,
      unitMarkup: markup,
      sku: json['sku'] as String? ?? '',
      kind: priceListItemKindFromWire(json['kind'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'quantity': quantity,
      'unitCost': unitCost,
      'unitMarkup': unitMarkup,
      'unitPrice': unitPrice,
      'sku': sku,
      'kind': kind.name,
    };
  }

  ServicesItemModel copyWith({
    String? id,
    String? name,
    String? description,
    int? quantity,
    double? unitCost,
    double? unitMarkup,
    double? unitPrice,
    String? sku,
    PriceListItemKind? kind,
  }) {
    if (unitPrice != null && unitCost == null && unitMarkup == null) {
      return ServicesItemModel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitCost: 0,
        unitMarkup: unitPrice,
        sku: sku ?? this.sku,
        kind: kind ?? this.kind,
      );
    }
    return ServicesItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      unitMarkup: unitMarkup ?? this.unitMarkup,
      sku: sku ?? this.sku,
      kind: kind ?? this.kind,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    quantity,
    unitCost,
    unitMarkup,
    sku,
    kind,
  ];
}
