import '../../core/services/cache_service.dart';
import '../../core/enum.dart';
import '../../models/pricing_item.dart';
import '../base/owned_collection_repository.dart';

/// CRUD + live stream for pricing items (materials and services).
///
/// Was `/pricing/{uid}/{id}` in Realtime Database; now `pricing_items`, where
/// `kind` distinguishes the two.
class PricingRepository extends OwnedCollectionRepository<PricingItem> {
  @override
  String get table => 'pricing_items';

  @override
  String get cacheBox => CacheBoxes.services;

  @override
  String idOf(PricingItem i) => i.id;

  @override
  int compare(PricingItem a, PricingItem b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Map<String, dynamic> toRow(PricingItem i) => {
        if (i.id.isNotEmpty) 'id': i.id,
        'kind': i.kind.name,
        'name': i.name,
        'unit_cost': i.unitCost,
        'unit_markup': i.unitMarkup,
        'item_code': i.itemCode,
      };

  @override
  PricingItem fromRow(Map<String, dynamic> row) => PricingItem(
        id: row['id']?.toString() ?? '',
        kind: PricingKind.values.firstWhere(
          (e) => e.name == row['kind']?.toString(),
          orElse: () => PricingKind.values.first,
        ),
        name: row['name']?.toString() ?? '',
        unitCost: (row['unit_cost'] as num?)?.toDouble() ?? 0,
        unitMarkup: (row['unit_markup'] as num?)?.toDouble() ?? 0,
        itemCode: row['item_code']?.toString() ?? '',
        createdAt: OwnedCollectionRepository.parseTs(row['created_at']),
        updatedAt: OwnedCollectionRepository.parseTs(row['updated_at']),
      );
}
