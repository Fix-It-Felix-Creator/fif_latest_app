
import '../../core/services/cache_service.dart';
import '../../models/customer.dart';
import '../base/owned_collection_repository.dart';

/// CRUD + live stream for customers.
///
/// Was `/customers/{uid}/{id}` in Realtime Database; now the `customers`
/// table, scoped by `owner_id` RLS. Reads fall back to the offline cache and
/// writes queue when offline — see [OwnedCollectionRepository].
class CustomersRepository extends OwnedCollectionRepository<Customer> {
  @override
  String get table => 'customers';

  @override
  String get cacheBox => CacheBoxes.customers;

  @override
  String idOf(Customer c) => c.id;

  /// Alphabetical by name, matching the sort the RTDB version applied after
  /// reading the whole node.
  @override
  int compare(Customer a, Customer b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Map<String, dynamic> toRow(Customer c) => {
        if (c.id.isNotEmpty) 'id': c.id,
        'name': c.name,
        'email': c.email,
        'phone': c.phone,
        'address_line1': c.addressLine1,
        'address_line2': c.addressLine2,
        'city': c.city,
        'county': c.county,
        'postcode': c.postcode,
        'latitude': c.latitude,
        'longitude': c.longitude,
        'company': c.company,
        'notes': c.notes,
        'formatted_address': c.formattedAddress,
      };

  @override
  Customer fromRow(Map<String, dynamic> row) => Customer(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        email: row['email']?.toString() ?? '',
        phone: row['phone']?.toString() ?? '',
        addressLine1: row['address_line1']?.toString() ?? '',
        addressLine2: row['address_line2']?.toString(),
        city: row['city']?.toString() ?? '',
        county: row['county']?.toString(),
        postcode: row['postcode']?.toString() ?? '',
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        company: row['company']?.toString(),
        notes: row['notes']?.toString(),
        formattedAddress: row['formatted_address']?.toString(),
        createdAt: OwnedCollectionRepository.parseTsOr(
            row['created_at'], DateTime.now()),
        updatedAt: OwnedCollectionRepository.parseTsOr(
            row['updated_at'], DateTime.now()),
      );
}
