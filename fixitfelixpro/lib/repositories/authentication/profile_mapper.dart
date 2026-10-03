/// Translates between the Postgres `profiles` row shape (snake_case, flat)
/// and the JSON shape `UserDetailsModel.fromJson` / `.toJson` already speak
/// (camelCase, nested).
///
/// This adapter exists so the model classes do NOT change during the
/// migration. RTDB stored exactly what `toJson()` produced; Postgres stores
/// typed, flattened columns. Rather than rewrite UserDetailsModel,
/// AddressModel, LocationModel, CompanyDetailsModel and
/// NotificationPreferencesModel — and every screen that reads them — the
/// conversion happens here, at the single boundary.
///
/// Every field round-trips 1:1. Nothing is collapsed onto a shared column:
/// `businessName` and `companyDetails.companyName` are separate fields in the
/// model and separate columns in the table, because editing one must never
/// silently overwrite the other.
class ProfileMapper {
  const ProfileMapper._();

  /// Postgres row → the JSON `UserDetailsModel.fromJson` expects.
  static Map<String, dynamic> rowToModelJson(Map<String, dynamic> row) {
    String? str(String key) {
      final v = row[key];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    List<String>? strList(String key) {
      final v = row[key];
      if (v is List) {
        final out = v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        return out.isEmpty ? null : out;
      }
      return null;
    }

    // Address is always present in the model (AddressModel.empty() fallback),
    // so emit it only when at least one component is set — otherwise let the
    // model supply its own empty instance.
    final addressParts = <String, dynamic>{
      'addressLine1': str('address_line1') ?? '',
      'addressLine2': str('address_line2') ?? '',
      'city': str('city') ?? '',
      'county': str('county') ?? '',
      'postcode': str('postcode') ?? '',
    };
    final hasAddress =
        addressParts.values.any((v) => (v as String).isNotEmpty);

    final lat = row['latitude'];
    final lng = row['longitude'];
    final hasLocation = lat != null && lng != null;

    // Company block — emitted only when something in it is set, so an
    // untouched company profile stays null rather than becoming an empty
    // object the settings screen would render as a blank card.
    final company = <String, dynamic>{
      'companyName': str('company_name') ?? '',
      'companiesHouseNumber': str('companies_house_number') ?? '',
      'companyLogoUrl': str('company_logo_url') ?? '',
      'companyEmail': str('company_email') ?? '',
      'companyLandline': str('company_landline') ?? '',
      'website': str('company_website') ?? '',
      'vatRegistered': row['vat_registered'] == true,
      'vatNumber': str('vat_number') ?? '',
      'bankDetails': {
        'bankName': str('bank_name') ?? '',
        'accountNumber': str('bank_account_number') ?? '',
        'sortCode': str('bank_sort_code') ?? '',
      },
    };
    final hasCompany = company.entries.any((e) {
      if (e.key == 'bankDetails') {
        return (e.value as Map).values.any((v) => v.toString().isNotEmpty);
      }
      if (e.key == 'vatRegistered') return e.value == true;
      return e.value.toString().isNotEmpty;
    });

    return <String, dynamic>{
      'uid': row['id']?.toString() ?? '',
      'email': str('email'),
      'firstName': str('first_name'),
      'lastName': str('last_name'),
      'phoneNumber': str('phone') ?? '',
      'accountType': str('account_type'),
      if (hasAddress) 'address': addressParts,
      if (hasLocation)
        'location': {
          'address': str('formatted_address') ?? '',
          'latitude': (lat as num).toDouble(),
          'longitude': (lng as num).toDouble(),
        },
      'businessName': str('business_name'),
      'businessEmail': str('business_email'),
      'businessRegistrationId': str('business_registration_id'),
      'dateOfBirth': str('date_of_birth'),
      'nationalInsuranceNumber': str('national_insurance_number'),
      'documentUrls': strList('document_urls'),
      'documentType': str('document_type'),
      'role': str('role'),
      'trade': strList('trade'),
      'selfieUrl': str('selfie_url'),
      'verificationStatus': str('verification_status'),
      'rejectionReason': str('rejection_reason'),
      'createdAt': str('created_at'),
      'updatedAt': str('updated_at'),
      'lastAddressUpdatedAt': str('last_address_updated_at'),
      'workStatus': str('work_status'),
      'profileImage': str('profile_image_url'),
      'subscriptionPlanSelected': str('subscription_plan_selected'),
      'links': strList('links'),
      'notificationPreferences': {
        // Columns are NOT NULL DEFAULT true, but a partial select may omit
        // them — default to enabled, matching
        // NotificationPreferencesModel.defaultEnabled().
        'pushEnabled': row['push_enabled'] as bool? ?? true,
        'emailEnabled': row['email_enabled'] as bool? ?? true,
        'smsEnabled': row['sms_enabled'] as bool? ?? true,
      },
      'bio': str('bio'),
      'introductionBio': str('introduction_bio'),
      if (hasCompany) 'companyDetails': company,
      'currency': str('currency') ?? 'GBP',
    };
  }

  /// `UserDetailsModel.toJson()` → a Postgres row for insert/update.
  ///
  /// [partial] drives an important behavioural difference. On a full save,
  /// absent fields are written as null (the model is the source of truth). On
  /// a partial update — which is what `updateUserDetails(Map)` does — only the
  /// keys actually supplied are emitted, so untouched columns keep their
  /// values instead of being nulled out.
  static Map<String, dynamic> modelJsonToRow(
    Map<String, dynamic> json, {
    bool partial = false,
  }) {
    final row = <String, dynamic>{};

    void put(String column, Object? value, {String? sourceKey}) {
      if (partial && !json.containsKey(sourceKey ?? column)) return;
      row[column] = value;
    }

    if (!partial || json.containsKey('uid')) {
      final uid = json['uid']?.toString();
      if (uid != null && uid.isNotEmpty) row['id'] = uid;
    }

    put('email', json['email'], sourceKey: 'email');
    put('first_name', json['firstName'], sourceKey: 'firstName');
    put('last_name', json['lastName'], sourceKey: 'lastName');
    put('phone', json['phoneNumber'], sourceKey: 'phoneNumber');
    put('account_type', json['accountType'], sourceKey: 'accountType');
    put('business_name', json['businessName'], sourceKey: 'businessName');
    put('business_email', json['businessEmail'], sourceKey: 'businessEmail');
    put('business_registration_id', json['businessRegistrationId'],
        sourceKey: 'businessRegistrationId');
    put('date_of_birth', json['dateOfBirth'], sourceKey: 'dateOfBirth');
    put('national_insurance_number', json['nationalInsuranceNumber'],
        sourceKey: 'nationalInsuranceNumber');
    put('document_urls', json['documentUrls'], sourceKey: 'documentUrls');
    put('document_type', json['documentType'], sourceKey: 'documentType');
    put('role', json['role'], sourceKey: 'role');
    put('trade', json['trade'], sourceKey: 'trade');
    put('selfie_url', json['selfieUrl'], sourceKey: 'selfieUrl');
    put('work_status', json['workStatus'], sourceKey: 'workStatus');
    put('profile_image_url', json['profileImage'], sourceKey: 'profileImage');
    put('subscription_plan_selected', json['subscriptionPlanSelected'],
        sourceKey: 'subscriptionPlanSelected');
    put('links', json['links'], sourceKey: 'links');
    put('bio', json['bio'], sourceKey: 'bio');
    put('introduction_bio', json['introductionBio'], sourceKey: 'introductionBio');
    put('currency', json['currency'], sourceKey: 'currency');
    put('last_address_updated_at', json['lastAddressUpdatedAt'],
        sourceKey: 'lastAddressUpdatedAt');

    // Nested address → flat columns.
    if (!partial || json.containsKey('address')) {
      final a = json['address'];
      if (a is Map) {
        row['address_line1'] = a['addressLine1'];
        row['address_line2'] = a['addressLine2'];
        row['city'] = a['city'];
        row['county'] = a['county'];
        row['postcode'] = a['postcode'];
      }
    }

    if (!partial || json.containsKey('location')) {
      final l = json['location'];
      if (l is Map) {
        row['formatted_address'] = l['address'];
        row['latitude'] = l['latitude'];
        row['longitude'] = l['longitude'];
      }
    }

    if (!partial || json.containsKey('notificationPreferences')) {
      final n = json['notificationPreferences'];
      if (n is Map) {
        row['push_enabled'] = n['pushEnabled'] ?? true;
        row['email_enabled'] = n['emailEnabled'] ?? true;
        row['sms_enabled'] = n['smsEnabled'] ?? true;
      }
    }

    if (!partial || json.containsKey('companyDetails')) {
      final c = json['companyDetails'];
      if (c is Map) {
        row['company_name'] = c['companyName'];
        row['companies_house_number'] = c['companiesHouseNumber'];
        row['company_logo_url'] = c['companyLogoUrl'];
        row['company_email'] = c['companyEmail'];
        row['company_landline'] = c['companyLandline'];
        row['company_website'] = c['website'];
        row['vat_registered'] = c['vatRegistered'] ?? false;
        row['vat_number'] = c['vatNumber'];
        final b = c['bankDetails'];
        if (b is Map) {
          row['bank_name'] = b['bankName'];
          row['bank_account_number'] = b['accountNumber'];
          row['bank_sort_code'] = b['sortCode'];
        }
      }
    }

    // `subscription` lives in its own table, and created_at/updated_at are
    // managed by the database — never write them from the client.
    row.remove('created_at');
    row.remove('updated_at');

    // Server-owned columns. The `profiles_guard_server_columns` BEFORE UPDATE
    // trigger raises if a non-service-role caller changes any of these:
    //
    //   profiles: verification_status is set by the server
    //   profiles: account_status is set by the server
    //   profiles: deletion timestamps are set by the server
    //
    // UserDetailsModel.toJson() includes `verificationStatus` and
    // `rejectionReason`, so a plain save would have thrown the moment a stale
    // or edited model carried a different status. They are read back in
    // rowToModelJson — the client just never writes them.
    for (final serverOwned in _serverOwnedColumns) {
      row.remove(serverOwned);
    }

    return row;
  }

  /// Columns only the service role may write. See
  /// `profiles_guard_server_columns` in the schema.
  static const Set<String> _serverOwnedColumns = {
    'verification_status',
    'rejection_reason',
    'account_status',
    'deletion_requested_at',
    'deletion_scheduled_at',
  };

  /// Maps a camelCase model key to its Postgres column, for callers that
  /// build partial updates by key (e.g. `updateUserDetails({'firstName': …})`).
  static const Map<String, String> modelKeyToColumn = {
    'uid': 'id',
    'email': 'email',
    'firstName': 'first_name',
    'lastName': 'last_name',
    'phoneNumber': 'phone',
    'accountType': 'account_type',
    'businessName': 'business_name',
    'businessEmail': 'business_email',
    'businessRegistrationId': 'business_registration_id',
    'dateOfBirth': 'date_of_birth',
    'nationalInsuranceNumber': 'national_insurance_number',
    'documentUrls': 'document_urls',
    'documentType': 'document_type',
    'role': 'role',
    'trade': 'trade',
    'selfieUrl': 'selfie_url',
    'workStatus': 'work_status',
    'profileImage': 'profile_image_url',
    'subscriptionPlanSelected': 'subscription_plan_selected',
    'links': 'links',
    'bio': 'bio',
    'introductionBio': 'introduction_bio',
    'currency': 'currency',
    'lastAddressUpdatedAt': 'last_address_updated_at',
  };
}
