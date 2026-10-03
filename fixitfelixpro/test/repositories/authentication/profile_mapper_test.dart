import 'package:flutter_test/flutter_test.dart';

import 'package:fixitfelix/core/enum.dart';
import 'package:fixitfelix/models/address_model.dart';
import 'package:fixitfelix/models/bank_details_model.dart';
import 'package:fixitfelix/models/company_details_model.dart';
import 'package:fixitfelix/models/location_model.dart';
import 'package:fixitfelix/models/notification_preferences_model.dart';
import 'package:fixitfelix/models/user_details_model.dart';
import 'package:fixitfelix/repositories/authentication/profile_mapper.dart';

/// Proves the Postgres `profiles` row shape round-trips through
/// UserDetailsModel without losing or corrupting a field. If this passes, the
/// model classes and every screen reading them can stay untouched.
void main() {
  UserDetailsModel buildFullUser() => UserDetailsModel(
        uid: '8f14e45f-ea8f-4b3f-9b1a-2c3d4e5f6a7b',
        email: 'felix@example.com',
        firstName: 'Felix',
        lastName: 'Fixer',
        phoneNumber: '07700900123',
        accountType: AccountCategoryType.tradesman,
        address: const AddressModel(
          addressLine1: '12 Trade Street',
          addressLine2: 'Unit 4',
          city: 'Glasgow',
          county: 'Lanarkshire',
          postcode: 'G1 1AA',
        ),
        location: const LocationModel(
          address: '12 Trade Street, Glasgow, G1 1AA',
          latitude: 55.8642,
          longitude: -4.2518,
        ),
        businessName: 'Felix Trading Ltd',
        businessEmail: 'accounts@felix.example',
        businessRegistrationId: 'SC123456',
        dateOfBirth: DateTime.utc(1985, 4, 12),
        nationalInsuranceNumber: 'QQ123456C',
        documentUrls: const ['https://x/doc1.jpg', 'https://x/doc2.jpg'],
        documentType: 'passport',
        role: BusinessRole.owner,
        trade: const ['plumbing', 'heating'],
        selfieUrl: 'https://x/selfie.jpg',
        verificationStatus: VerificationStatus.verified,
        rejectionReason: 'none',
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
        lastAddressUpdatedAt: DateTime.utc(2026, 3, 4),
        workStatus: 'available',
        profileImage: 'https://x/avatar.jpg',
        subscriptionPlanSelected: 'plus',
        links: const ['https://felix.example'],
        notificationPreferences: const NotificationPreferencesModel(
          pushEnabled: true,
          emailEnabled: false,
          smsEnabled: true,
        ),
        bio: 'Short bio',
        introductionBio: 'Longer intro',
        companyDetails: const CompanyDetailsModel(
          companyName: 'Felix Trading Ltd',
          companiesHouseNumber: 'SC123456',
          companyLogoUrl: 'https://x/logo.png',
          companyEmail: 'hello@felix.example',
          companyLandline: '01417376868',
          website: 'https://felix.example',
          vatRegistered: true,
          vatNumber: 'GB123456789',
          bankDetails: BankDetailsModel(
            bankName: 'Test Bank',
            accountNumber: '12345678',
            sortCode: '00-00-00',
          ),
        ),
        currency: 'GBP',
      );

  test('full model survives model -> row -> model', () {
    final original = buildFullUser();

    final row = ProfileMapper.modelJsonToRow(original.toJson());
    // The DB supplies these; the mapper must not emit them.
    expect(row.containsKey('created_at'), isFalse);
    expect(row.containsKey('updated_at'), isFalse);

    // Server-owned columns must not be in a client write either.
    expect(row.containsKey('verification_status'), isFalse);
    expect(row.containsKey('rejection_reason'), isFalse);

    // Simulate what PostgREST hands back: the database supplies the
    // timestamps, and the server supplies the verification fields.
    row['created_at'] = original.createdAt.toIso8601String();
    row['updated_at'] = original.updatedAt.toIso8601String();
    row['verification_status'] = original.verificationStatus?.name;
    row['rejection_reason'] = original.rejectionReason;

    final restored =
        UserDetailsModel.fromJson(ProfileMapper.rowToModelJson(row));

    expect(restored.uid, original.uid);
    expect(restored.email, original.email);
    expect(restored.firstName, original.firstName);
    expect(restored.lastName, original.lastName);
    expect(restored.phoneNumber, original.phoneNumber);
    expect(restored.accountType, original.accountType);
    expect(restored.address.addressLine1, original.address.addressLine1);
    expect(restored.address.postcode, original.address.postcode);
    expect(restored.location?.latitude, original.location?.latitude);
    expect(restored.location?.longitude, original.location?.longitude);
    expect(restored.nationalInsuranceNumber, original.nationalInsuranceNumber);
    expect(restored.documentUrls, original.documentUrls);
    expect(restored.documentType, original.documentType);
    expect(restored.role, original.role);
    expect(restored.trade, original.trade);
    expect(restored.selfieUrl, original.selfieUrl);
    expect(restored.verificationStatus, original.verificationStatus);
    expect(restored.rejectionReason, original.rejectionReason);
    expect(restored.workStatus, original.workStatus);
    expect(restored.profileImage, original.profileImage);
    expect(restored.subscriptionPlanSelected, original.subscriptionPlanSelected);
    expect(restored.links, original.links);
    expect(restored.bio, original.bio);
    expect(restored.introductionBio, original.introductionBio);
    expect(restored.currency, original.currency);
    expect(restored.notificationPreferences.emailEnabled, isFalse);
    expect(restored.notificationPreferences.pushEnabled, isTrue);
  });

  test('businessName and companyDetails.companyName do NOT collide', () {
    // The whole reason business_* got its own columns: these two fields are
    // independently settable and must never overwrite each other.
    final user = buildFullUser().copyWith(
      businessName: 'Trading Name',
      companyDetails: const CompanyDetailsModel(
        companyName: 'Legal Entity Ltd',
        companiesHouseNumber: 'SC999999',
        companyLogoUrl: '',
        companyEmail: 'legal@example.com',
        companyLandline: '',
        website: '',
        vatRegistered: false,
        vatNumber: '',
        bankDetails: BankDetailsModel(
          bankName: '',
          accountNumber: '',
          sortCode: '',
        ),
      ),
      businessEmail: 'trading@example.com',
      businessRegistrationId: 'SC111111',
    );

    final row = ProfileMapper.modelJsonToRow(user.toJson());

    expect(row['business_name'], 'Trading Name');
    expect(row['company_name'], 'Legal Entity Ltd');
    expect(row['business_email'], 'trading@example.com');
    expect(row['company_email'], 'legal@example.com');
    expect(row['business_registration_id'], 'SC111111');
    expect(row['companies_house_number'], 'SC999999');

    final restored =
        UserDetailsModel.fromJson(ProfileMapper.rowToModelJson(row));
    expect(restored.businessName, 'Trading Name');
    expect(restored.companyDetails?.companyName, 'Legal Entity Ltd');
    expect(restored.businessEmail, 'trading@example.com');
    expect(restored.companyDetails?.companyEmail, 'legal@example.com');
  });

  test('server-owned columns are never written by the client', () {
    // profiles_guard_server_columns raises if a non-service-role caller
    // changes verification_status / account_status / deletion timestamps.
    // UserDetailsModel.toJson() carries verificationStatus and
    // rejectionReason, so the mapper must drop them on write while still
    // reading them back.
    final user = buildFullUser();
    final row = ProfileMapper.modelJsonToRow(user.toJson());

    expect(row.containsKey('verification_status'), isFalse);
    expect(row.containsKey('rejection_reason'), isFalse);
    expect(row.containsKey('account_status'), isFalse);
    expect(row.containsKey('deletion_requested_at'), isFalse);
    expect(row.containsKey('deletion_scheduled_at'), isFalse);

    // ...but they still round-trip on read.
    final restored = UserDetailsModel.fromJson(ProfileMapper.rowToModelJson({
      'id': user.uid,
      'verification_status': 'verified',
      'rejection_reason': 'none',
      'account_type': 'tradesman',
    }));
    expect(restored.verificationStatus, VerificationStatus.verified);
    expect(restored.rejectionReason, 'none');
  });

  test('partial update cannot route around the guard', () {
    final row = ProfileMapper.modelJsonToRow(
      {'verificationStatus': 'verified', 'firstName': 'Felix'},
      partial: true,
    );
    expect(row.containsKey('verification_status'), isFalse);
    expect(row['first_name'], 'Felix');
  });

  test('partial update touches only the supplied keys', () {
    // updateUserDetails({'firstName': ...}) must not null out every other
    // column — the RTDB `.update()` it replaces was inherently partial.
    final row = ProfileMapper.modelJsonToRow(
      {'firstName': 'NewName'},
      partial: true,
    );

    expect(row.keys.toSet(), {'first_name'});
    expect(row['first_name'], 'NewName');
  });

  test('empty profile does not fabricate address or company blocks', () {
    final json = ProfileMapper.rowToModelJson({
      'id': 'abc',
      'email': 'a@b.c',
      'account_type': 'tradesman',
    });

    expect(json.containsKey('address'), isFalse);
    expect(json.containsKey('companyDetails'), isFalse);
    expect(json.containsKey('location'), isFalse);

    final model = UserDetailsModel.fromJson(json);
    expect(model.companyDetails, isNull);
    expect(model.location, isNull);
    expect(model.address.addressLine1, isEmpty);
    // Defaults must survive a bare row.
    expect(model.notificationPreferences.pushEnabled, isTrue);
    expect(model.currency, 'GBP');
  });
}
