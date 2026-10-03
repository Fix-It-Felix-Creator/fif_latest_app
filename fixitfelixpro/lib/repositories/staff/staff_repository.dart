import '../../core/services/cache_service.dart';
import '../../core/enum.dart';
import '../../models/staff.dart';
import '../base/owned_collection_repository.dart';

/// CRUD + live stream for staff members.
///
/// Was `/staff/{uid}/{id}` in Realtime Database; now the `staff` table.
class StaffRepository extends OwnedCollectionRepository<Staff> {
  @override
  String get table => 'staff';

  /// No dedicated staff box exists, and staff are read alongside quotes and
  /// invoices when pricing labour, so they share the settings box.
  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  String idOf(Staff s) => s.id;

  @override
  int compare(Staff a, Staff b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Map<String, dynamic> toRow(Staff s) => {
        if (s.id.isNotEmpty) 'id': s.id,
        'name': s.name,
        'email': s.email,
        'phone': s.phone,
        'default_pay_type': s.defaultPayType.name,
        'rate': s.rate,
        'weekend_rate': s.weekendRate,
        'emergency_rate': s.emergencyRate,
        'sociable_rate': s.sociableRate,
      };

  @override
  Staff fromRow(Map<String, dynamic> row) => Staff(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        email: row['email']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        defaultPayType: StaffPayType.values.firstWhere(
          (e) => e.name == row['default_pay_type']?.toString(),
          orElse: () => StaffPayType.day,
        ),
        rate: (row['rate'] as num?)?.toDouble() ?? 0,
        weekendRate: (row['weekend_rate'] as num?)?.toDouble() ?? 0,
        emergencyRate: (row['emergency_rate'] as num?)?.toDouble() ?? 0,
        sociableRate: (row['sociable_rate'] as num?)?.toDouble() ?? 0,
        createdAt: OwnedCollectionRepository.parseTs(row['created_at']),
        updatedAt: OwnedCollectionRepository.parseTs(row['updated_at']),
      );
}
