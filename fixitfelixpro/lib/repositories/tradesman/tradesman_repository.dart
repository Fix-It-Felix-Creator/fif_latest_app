import 'dart:io';


import '../../core/config/environment_variables.dart';
import '../../core/enum.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/image_validator.dart';
import '../../core/services/supabase_service.dart';
import '../../generated/database_paths.dart';
import '../../models/app_user.dart';
import '../usage/usage_mapper.dart';
import '../authentication/profile_mapper.dart';
import 'tradesman_store.dart';
import '../../globals.dart';
import '../../models/address_model.dart';
import '../../models/company_details_model.dart';
import '../../models/extra_document_model.dart';
import '../../models/portfolio_media_model.dart';
import '../../models/trade_card_model.dart';
import '../../models/trade_requirement.dart';
import '../../models/member_subscription_model.dart';
import '../../models/tradesman_model.dart';
import '../../models/user_subscription_container_model.dart';
import '../configurations/configurations_repositories.dart';
import 'base_tradesman_repository.dart';

class TradesmanRepository extends BaseTradesmanRepository {
  final ConfigurationRepository remoteConfigRepository;

  TradesmanRepository({
    required this.remoteConfigRepository,
  });

  final TradesmanStore _store = TradesmanStore();

  String? get _uid => SupabaseService().auth.currentUser?.id;

  @override
  void setENVConfig(EnvironmentVariables envData) {
    print('TradesmanRegistrationRepository: Environment variables set');
  }

  @override
  AppUser? get currentUser {
    final u = SupabaseService().auth.currentUser;
    return u == null ? null : AppUser.fromSupabase(u);
  }

  /// Upload image to Firebase Storage with smart compression.
  ///
  /// [imageType] determines the size limit: 'identity', 'selfie', 'logo', 'profile', etc.
  /// If [imageType] is null, no compression is applied (for non-image files like PDFs).
  Future<String> _uploadImage({
    required String localPath,
    required String storagePath,
    String? imageType,
  }) {
    return _store.uploadImage(
      localPath: localPath,
      storagePath: storagePath,
      imageType: imageType,
    );
  }

  /// PortfolioMediaModel / PortfolioHighlightModel JSON <-> a
  /// `portfolio_media` row. All four RTDB sibling nodes share this table,
  /// split by `kind`.
  Map<String, dynamic> _portfolioToRow(Map<String, dynamic> json) {
    const map = {
      'title': 'title',
      'description': 'description',
      'url': 'url',
      'thumbnailUrl': 'thumbnail_url',
      'coverUrl': 'cover_url',
      'mediaUrl': 'media_url',
      'isVideo': 'is_video',
      'jobId': 'job_id',
      'jobTitle': 'job_title',
      'fileSize': 'file_size',
      'durationSeconds': 'duration_seconds',
    };
    final row = <String, dynamic>{};
    map.forEach((k, column) {
      if (json.containsKey(k)) row[column] = json[k];
    });
    return row;
  }

  Map<String, dynamic> _portfolioToJson(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'title': row['title']?.toString() ?? '',
        'description': row['description']?.toString() ?? '',
        'url': row['url']?.toString() ?? '',
        'thumbnailUrl': row['thumbnail_url'],
        'coverUrl': row['cover_url'],
        'mediaUrl': row['media_url'],
        'isVideo': row['is_video'] ?? false,
        'jobId': row['job_id'],
        'jobTitle': row['job_title'],
        'fileSize': (row['file_size'] as num?)?.toInt() ?? 0,
        'durationSeconds': (row['duration_seconds'] as num?)?.toInt(),
        'type': row['kind'] == 'video' || row['kind'] == 'job_video'
            ? 'video'
            : 'image',
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
      };

  /// ExtraDocumentModel JSON <-> an `extra_documents` row.
  Map<String, dynamic> _extraDocToRow(Map<String, dynamic> json) {
    const map = {
      'name': 'name',
      'description': 'description',
      'type': 'type',
      'url': 'url',
      'fileSize': 'file_size',
    };
    final row = <String, dynamic>{};
    map.forEach((k, column) {
      if (json.containsKey(k)) row[column] = json[k];
    });
    return row;
  }

  Map<String, dynamic> _extraDocToJson(Map<String, dynamic> row) => {
        'id': row['id']?.toString() ?? '',
        'name': row['name']?.toString() ?? '',
        'description': row['description']?.toString() ?? '',
        'type': row['type'],
        'url': row['url']?.toString() ?? '',
        'fileSize': (row['file_size'] as num?)?.toInt() ?? 0,
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
      };

  /// TradeCardModel JSON -> a `trade_cards` row. Only keys present are
  /// emitted, so a partial update does not null untouched columns.
  Map<String, dynamic> _tradeCardToRow(Map<String, dynamic> json) {
    const map = {
      'cardScheme': 'card_scheme',
      'cardColor': 'card_color',
      'qualificationLevel': 'qualification_level',
      'registrationNumber': 'registration_number',
      'expiryDate': 'expiry_date',
      'imageUrl': 'image_url',
      'mappedTrade': 'mapped_trade',
      'fileSize': 'file_size',
      'uploadedAt': 'uploaded_at',
    };
    final row = <String, dynamic>{};
    map.forEach((k, column) {
      if (json.containsKey(k)) row[column] = json[k];
    });
    // verification_status / rejection_reason are moderation fields — read
    // back below, never written from here.
    return row;
  }

  Map<String, dynamic> _tradeCardToJson(Map<String, dynamic> row) => {
        'id': row['owner_id']?.toString() ?? '',
        'cardScheme': row['card_scheme'],
        'cardColor': row['card_color'],
        'qualificationLevel': row['qualification_level'],
        'registrationNumber': row['registration_number'],
        'expiryDate': row['expiry_date'],
        'imageUrl': row['image_url'],
        'mappedTrade': row['mapped_trade'],
        'uploadedAt': row['uploaded_at'],
        'updatedAt': row['updated_at'],
        'verificationStatus': row['verification_status'] ?? 'pending',
        'rejectionReason': row['rejection_reason'],
        'fileSize': (row['file_size'] as num?)?.toInt() ?? 0,
      };

  /// `trade_qualifications` row -> the JSON TradeQualificationDoc expects.
  ///
  /// `verification_status` and `rejection_reason` are read here but never
  /// written by the client: they are moderation fields, guarded server-side
  /// like the ones on `profiles`.
  Map<String, dynamic> _qualificationToJson(Map<String, dynamic> row) => {
        'requirementId':
            row['requirement_id']?.toString() ?? row['name']?.toString() ?? '',
        'documentUrl': row['url']?.toString() ?? '',
        'isMandatory': row['is_mandatory'] ?? true,
        'uploadedAt': row['uploaded_at'] ?? row['created_at'],
        'verificationStatus': row['verification_status'] ?? 'pending',
        'rejectionReason': row['rejection_reason'],
        'verifiedAt': row['verified_at'],
        'verifiedBy': row['verified_by'],
        'fileSize': (row['file_size'] as num?)?.toInt() ?? 0,
      };

  /// Object key for a stored media URL.
  ///
  /// Records keep their `storagePath` alongside the URL, but a few legacy
  /// call sites only have the URL. Signed URLs embed the key as
  /// `/object/sign/{bucket}/{key}?token=...`, so it is recoverable.
  String? _objectKeyFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final path = Uri.parse(url).path;
      final marker = '/${TradesmanStore.bucket}/';
      final i = path.indexOf(marker);
      if (i < 0) return null;
      return Uri.decodeComponent(path.substring(i + marker.length));
    } catch (_) {
      return null;
    }
  }

  /// Atomic counter change via the bump_usage function.
  Future<void> _bumpUsage(String field, int amount) async {
    final column = UsageMapper.columnFor(field);
    if (column == null) return;
    await SupabaseService()
        .client
        .rpc('bump_usage', params: {'p_field': column, 'p_amount': amount});
  }

  /// Clear all user documents from storage
  Future<void> _clearUserDocuments(String uid) async {
    // Best-effort, as before: submission proceeds even if cleanup partly fails.
    await _store.deleteTree(DatabasePaths.userDocuments(uid));
  }

  /// Recursively convert Firebase Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _convertToStringDynamicMap(value));
        } else if (value is List) {
          return MapEntry(key.toString(), _convertList(value));
        } else {
          return MapEntry(key.toString(), value);
        }
      });
    }
    return {};
  }

  /// Recursively convert List items
  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToStringDynamicMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Save tradesman registration data to Firestore
  @override
  Future<void> submitTradesmanRegistration({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    required String phoneNumber,
    required AddressModel address,
    required String nationalInsuranceNumber,
    required DocumentType documentType,
    required VerificationStatus verificationStatus,
    required AccountCategoryType accountCategoryType,
    required String? rejectionReason,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? passportImagePath,
    String? idCardFrontImagePath,
    String? idCardBackImagePath,
    String? driverLicenseFrontImagePath,
    String? driverLicenseBackImagePath,
    String? selfieImagePath,
    String? trade,
    required WorkStatus workStatus,
    Map<String, String>? qualificationFiles,
    bool hasCompany = false,
    String? companyName,
    String? companiesHouseNumber,
    String? companyEmail,
    String? companyLandline,
    String? companyLogoImagePath,
  }) async {
    try {
      print('🔐 Checking user authentication...');

      final user = currentUser;
      if (user == null) {
        print('❌ User not authenticated!');
        throw CustomException(message: 'User not authenticated');
      }

      print('✓ User authenticated: ${user.uid}');
      print('📧 Email: ${user.email}');

      // Clear existing documents to prevent mix-ups
      await _clearUserDocuments(user.uid);

      // Upload images and get download URLs
      print('🖼️  Starting image uploads...');

      String? passportUrl;
      String? idCardFrontUrl;
      String? idCardBackUrl;
      String? driverLicenseFrontUrl;
      String? driverLicenseBackUrl;
      String? selfieUrl;

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      if (passportImagePath != null) {
        print('📄 Uploading passport image...');
        passportUrl = await _uploadImage(
          localPath: passportImagePath,
          storagePath: DatabasePaths.passportImage(user.uid, timestamp),
          imageType: 'identity',
        );
      } else {
        print('⏭️  Passport image not provided');
      }

      if (idCardFrontImagePath != null) {
        print('🪪 Uploading ID Card front image...');
        idCardFrontUrl = await _uploadImage(
          localPath: idCardFrontImagePath,
          storagePath: DatabasePaths.idCardFrontImage(user.uid, timestamp),
          imageType: 'identity',
        );
      }

      if (idCardBackImagePath != null) {
        print('🪪 Uploading ID Card back image...');
        idCardBackUrl = await _uploadImage(
          localPath: idCardBackImagePath,
          storagePath: DatabasePaths.idCardBackImage(user.uid, timestamp),
          imageType: 'identity',
        );
      }

      if (driverLicenseFrontImagePath != null) {
        print('🚗 Uploading Driver License front image...');
        driverLicenseFrontUrl = await _uploadImage(
          localPath: driverLicenseFrontImagePath,
          storagePath: DatabasePaths.driverLicenseFrontImage(
            user.uid,
            timestamp,
          ),
          imageType: 'identity',
        );
      }

      if (driverLicenseBackImagePath != null) {
        print('🚗 Uploading Driver License back image...');
        driverLicenseBackUrl = await _uploadImage(
          localPath: driverLicenseBackImagePath,
          storagePath: DatabasePaths.driverLicenseBackImage(
            user.uid,
            timestamp,
          ),
          imageType: 'identity',
        );
      }

      if (selfieImagePath != null) {
        print('🤳 Uploading selfie image...');
        selfieUrl = await _uploadImage(
          localPath: selfieImagePath,
          storagePath: DatabasePaths.selfieImage(user.uid, timestamp),
          imageType: 'selfie',
        );
      } else {
        print('❌ ERROR: Selfie image is required but not provided!');
        throw CustomException(message: 'Selfie image is required');
      }

      // Upload company logo if provided
      String? companyLogoUrl;
      if (hasCompany && companyLogoImagePath != null) {
        print('🏢 Uploading company logo...');
        companyLogoUrl = await _uploadImage(
          localPath: companyLogoImagePath,
          storagePath: DatabasePaths.companyLogo(user.uid, timestamp),
          imageType: 'logo',
        );
      }

      // Upload trade qualification files if provided
      Map<String, String> qualificationUrls = {};
      if (qualificationFiles != null && qualificationFiles.isNotEmpty) {
        print('📜 Uploading ${qualificationFiles.length} trade qualification files...');
        for (final entry in qualificationFiles.entries) {
          final reqId = entry.key;
          final localPath = entry.value;
          final ext = ImageValidator.getFileExtension(localPath);
          final qualTimestamp = DateTime.now().millisecondsSinceEpoch.toString();

          print('  📄 Uploading qualification: $reqId');
          final isImage = ImageValidator.isImageFile(localPath);
          final qualUrl = await _uploadImage(
            localPath: localPath,
            storagePath: DatabasePaths.storageTradeQualification(
              user.uid,
              reqId,
              qualTimestamp,
              ext,
            ),
            imageType: isImage ? 'identity' : null,
          );
          qualificationUrls[reqId] = qualUrl;
        }
        print('✓ All qualification files uploaded');
      }

      print('✓ All image uploads completed');

      // Collect all document URLs
      List<String> documentUrls = [];
      if (passportUrl != null) documentUrls.add(passportUrl);
      if (idCardFrontUrl != null) documentUrls.add(idCardFrontUrl);
      if (idCardBackUrl != null) documentUrls.add(idCardBackUrl);
      if (driverLicenseFrontUrl != null) {
        documentUrls.add(driverLicenseFrontUrl);
      }
      if (driverLicenseBackUrl != null) documentUrls.add(driverLicenseBackUrl);

      // Prepare updates for Realtime Database
      // We use a Map to update specific fields at the root level (users/{uid})
      // matching UserDetailsModel structure
      final Map<String, dynamic> updates = {
        'uid': uid,
        'email': email
            .toLowerCase(), // Store email in lowercase for case-insensitive search
        'firstName': firstName,
        'lastName': lastName,
        // Date of birth is no longer collected (App Store Guideline
        // 5.1.1(v)); only written if a legacy value is still supplied.
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
        'phoneNumber': phoneNumber,
        'address': address.toJson(),
        'nationalInsuranceNumber': nationalInsuranceNumber,
        'documentType': documentType.name,
        'documentUrls': documentUrls,
        'selfieUrl': selfieUrl,
        'trade': trade,
        'verificationStatus': verificationStatus.name,
        'rejectionReason': rejectionReason,
        'accountType': accountCategoryType.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'subscription': UserSubscriptionContainerModel(
          member: MemberSubscriptionModel(
            subscriptionId: 0,
            name: 'Standard Free',
            price: 0,
            billingCycle: BillingCycle.monthly,
            planType: PlanType.standard,
            accountType: AccountCategoryType.tradesman,
            startDate: DateTime.now(),
            status: SubscriptionStatus.active,
          ),
        ).toJson(),
        'workStatus': workStatus.name,
      };

      // Save company details if provided
      if (hasCompany &&
          companyName != null &&
          companyName.isNotEmpty) {
        updates['companyDetails'] = CompanyDetailsModel(
          companyName: companyName,
          companiesHouseNumber: companiesHouseNumber ?? '',
          companyLogoUrl: companyLogoUrl,
          companyEmail: companyEmail ?? '',
          companyLandline: companyLandline,
        ).toJson();
      }

      // Also set registeredAt if needed, but UserDetailsModel uses createdAt/updatedAt.
      // We can add a specific field for tradesman registration time if we want.
      updates['registeredAt'] = DateTime.now().toIso8601String();

      await _store.updateProfile(
          user.uid,
          ProfileMapper.modelJsonToRow(updates, partial: true),
        );

      // Save trade qualification metadata
      if (qualificationUrls.isNotEmpty) {
        print('💾 Saving trade qualification metadata...');
        for (final entry in qualificationUrls.entries) {
          final reqId = entry.key;
          final qualData = {
            'requirementId': reqId,
            'documentUrl': entry.value,
            'isMandatory': true,
            'uploadedAt': DateTime.now().toIso8601String(),
            'verificationStatus': 'pending',
          };
          await _store.insert('trade_qualifications', {
            'name': qualData['name'] ?? reqId,
            'url': qualData['url'],
            'storage_path': qualData['storagePath'],
            'file_size': qualData['fileSize'] ?? 0,
            'verification_status': qualData['verificationStatus'],
          });
        }
        print('✓ Trade qualification metadata saved');
      }

      // Ensure role is set (though accountType handles it in model, this might be for other logic)
      await _store.updateProfile(user.uid, {'role': 'tradesman'});
    } catch (e) {
      print('❌ Failed to submit registration: $e');
      print('Stack trace: $e');
      throw CustomException(message: 'Failed to submit registration: $e');
    }
  }

  /// Get tradesman registration data
  /// Note: This now fetches from the root user node and maps it to TradesmanRegistrationModel
  /// for backward compatibility with the UI that expects this model.
  @override
  Future<TradesmanModel?> getTradesmanRegistration() async {
    try {
      final user = currentUser;
      if (user == null) {
        return null;
      }

      print('🔍 Fetching registration data for user: ${user.uid}');

      final profileRow = await _store.readProfile(user.uid);

      if (profileRow == null) {
        print('❌ No user data found');
        return null;
      }

      // Back to the camelCase shape the model reads.
      final data = ProfileMapper.rowToModelJson(profileRow);

      // Check if this user is actually a tradesman or has registration data
      if (data['accountType'] != 'tradesman' &&
          data['nationalInsuranceNumber'] == null) {
        print('❌ Not a tradesman or no registration data');
        return null;
      }

      print('✓ Registration data found');

      // Map flat structure back to nested TradesmanRegistrationModel
      // This is a bit of a hack to keep the UI working without refactoring all screens immediately
      // Ideally, we should switch the UI to use UserDetailsModel

      // Helper to find doc in list (naive approach since we lost the keys)
      // In a real app, we might want to store a map of document types to URLs if we need to distinguish them later
      // For now, we just put them back in slots if possible, or just rely on the list.
      // The UI might expect specific fields.
      // Since we flattened it, we can't easily distinguish passport vs ID card just from the URL list
      // unless we saved that metadata.
      // However, for the purpose of "viewing" the registration, we might just need the data.

      return TradesmanModel(
        uid: data['uid'] as String? ?? '',
        email: data['email'] as String? ?? '',
        firstName: data['firstName'] as String? ?? '',
        lastName: data['lastName'] as String? ?? '',
        phoneNumber: data['phoneNumber'] as String? ?? '',
        accountType: AccountCategoryType.tradesman,

        address: AddressModel(
          addressLine1: data['addressLine1'] as String? ?? '',
          addressLine2: data['addressLine2'] as String? ?? '',
          city: data['city'] as String? ?? '',
          county: data['county'] as String? ?? '',
          postcode: data['postcode'] as String? ?? '',
        ),

        dateOfBirth:
            (data['dateOfBirth'] is String && data['dateOfBirth'] != '')
            ? DateTime.tryParse(data['dateOfBirth'])
            : null,

        nationalInsuranceNumber:
            data['nationalInsuranceNumber'] as String? ?? '',
        trade: data['trade'] as String? ?? '',
        documentType: data['documentType'] as String? ?? '',

        documentUrls: (data['documentUrls'] is List)
            ? List<String>.from(data['documentUrls'])
            : [],

        selfieUrl: data['selfieUrl'] as String?,

        verificationStatus: (data['verificationStatus'] is String)
            ? VerificationStatus.values.firstWhere(
                (e) => e.name == data['verificationStatus'],
                orElse: () => VerificationStatus.waiting,
              )
            : VerificationStatus.waiting,

        rejectionReason: data['rejectionReason'] as String? ?? '',

        createdAt: (data['createdAt'] is String)
            ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
            : DateTime.now(),

        updatedAt: (data['updatedAt'] is String)
            ? DateTime.tryParse(data['updatedAt']) ?? DateTime.now()
            : DateTime.now(),

        subscription: data['subscription'],
        workStatus: (data['workStatus'] is String)
            ? WorkStatus.values.firstWhere(
                (e) => e.name == data['workStatus'],
                orElse: () => WorkStatus.available,
              )
            : WorkStatus.available,
      );
    } catch (e) {
      print('❌ Error retrieving registration: $e');
      throw CustomException(message: 'Failed to retrieve registration: $e');
    }
  }

  @override
  Future<String?> getVerificationStatus() async {
    try {
      final user = currentUser;
      if (user == null) {
        return null;
      }

      final row = await _store.readProfile(user.uid, 'verification_status');

      if (row == null) {
        print('Verification status not found');
        return null;
      }

      final status = row['verification_status'];
      print('Current verification status: $status');
      return status?.toString();
    } catch (e) {
      print('❌ Error getting verification status: $e');
      throw CustomException(message: 'Failed to get verification status: $e');
    }
  }

  @override
  Future<String?> getRejectionReason() async {
    try {
      final user = currentUser;
      if (user == null) {
        return null;
      }

      final row = await _store.readProfile(user.uid, 'rejection_reason');
      return row?['rejection_reason']?.toString();
    } catch (e) {
      print('Error getting rejection reason: $e');
      return null;
    }
  }

  @override
  Future<void> deleteRegistrationData() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw CustomException(message: 'User not authenticated');
      }

      print('🗑️  Deleting registration data...');

      // Clear all documents
      await _clearUserDocuments(user.uid);

      // Delete registration data fields from Realtime Database
      // We don't want to delete the whole user, just the tradesman specific fields?
      // Or if this is "re-apply", maybe we do want to clear most things.
      // Let's clear the tradesman specific fields.
      final Map<String, dynamic> updates = {
        'verificationStatus': null,
        'rejectionReason': null,
        'documentUrls': null,
        'documentType': null,
        'nationalInsuranceNumber': null,
        // Keep address and profile info? Or clear them too?
        // If we are re-applying, we probably want to keep profile info but clear verification stuff.
      };
      await _store.updateProfile(
          user.uid,
          ProfileMapper.modelJsonToRow(updates, partial: true),
        );
      print('✓ Registration data deleted from database');

      print('✅ All registration data deleted');
    } catch (e) {
      print('❌ Error deleting registration: $e');
      throw CustomException(message: 'Failed to delete registration data: $e');
    }
  }

  // ============================================
  // Company Details Management
  // ============================================

  @override
  Future<void> updateCompanyDetails({
    required String companyName,
    required String companiesHouseNumber,
    required String companyEmail,
    String? companyLandline,
    String? companyLogoImagePath,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🏢 Updating company details...');

      String? companyLogoUrl;

      // Upload new logo if provided
      if (companyLogoImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        companyLogoUrl = await _uploadImage(
          localPath: companyLogoImagePath,
          storagePath: DatabasePaths.companyLogo(user.uid, timestamp),
          imageType: 'logo',
        );
      } else {
        // Preserve existing logo URL
        final row = await _store.readProfile(user.uid, 'company_logo_url');
        companyLogoUrl = row?['company_logo_url'] as String?;
      }

      final companyDetails = CompanyDetailsModel(
        companyName: companyName,
        companiesHouseNumber: companiesHouseNumber,
        companyLogoUrl: companyLogoUrl,
        companyEmail: companyEmail,
        companyLandline: companyLandline,
      );

      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(
          {'companyDetails': companyDetails.toJson()},
          partial: true,
        ),
      );

      // Update the updatedAt timestamp
      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        }, partial: true),
      );

      print('✓ Company details updated successfully');
    } catch (e) {
      print('❌ Failed to update company details: $e');
      throw CustomException(message: 'Failed to update company details: $e');
    }
  }

  /// Save the business-profile section used by the Company Details settings
  /// screen. Updates the companyDetails subtree in a single write, uploads a
  /// new logo if [logoImagePath] is provided, and updates the user's phone
  /// number on the same transaction.
  Future<void> saveBusinessProfile({
    required String companyName,
    required String phoneNumber,
    String? website,
    required bool vatRegistered,
    String? vatNumber,
    String? logoImagePath,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      // Load the existing companyDetails so we preserve fields the Company
      // Details screen doesn't touch (companiesHouseNumber, companyEmail).
      final existingRow = await _store.readProfile(user.uid);
      final existingCompany = existingRow == null
          ? null
          : ProfileMapper.rowToModelJson(existingRow)['companyDetails'];
      CompanyDetailsModel existing;
      if (existingCompany is Map) {
        existing = CompanyDetailsModel.fromJson(
          Map<String, dynamic>.from(existingCompany),
        );
      } else {
        existing = const CompanyDetailsModel(
          companyName: '',
          companiesHouseNumber: '',
          companyEmail: '',
        );
      }

      String? logoUrl = existing.companyLogoUrl;
      if (logoImagePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        logoUrl = await _uploadImage(
          localPath: logoImagePath,
          storagePath: DatabasePaths.companyLogo(user.uid, timestamp),
          imageType: 'logo',
        );
      }

      final updated = existing.copyWith(
        companyName: companyName,
        companyLogoUrl: logoUrl,
        companyLandline: phoneNumber,
        website: website,
        vatRegistered: vatRegistered,
        vatNumber: vatNumber,
      );

      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(
          {'companyDetails': updated.toJson()},
          partial: true,
        ),
      );

      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(<String, dynamic>{
        'phoneNumber': phoneNumber,
        'updatedAt': DateTime.now().toIso8601String(),
        }, partial: true),
      );
    } catch (e) {
      throw CustomException(message: 'Failed to save business profile: $e');
    }
  }

  /// Write the bank-details subtree under `companyDetails/bankDetails`.
  /// Leaves every other company field alone.
  Future<void> saveBankDetails({
    required String bankName,
    required String accountNumber,
    required String sortCode,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }
    try {
      await _store.updateProfile(user.uid, {
        'bank_name': bankName,
        'bank_account_number': accountNumber,
        'bank_sort_code': sortCode,
      });
      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        }, partial: true),
      );
    } catch (e) {
      throw CustomException(message: 'Failed to save bank details: $e');
    }
  }

  @override
  Future<void> removeCompanyDetails() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🗑️ Removing company details...');

      // Get existing logo URL to delete from storage
      final row = await _store.readProfile(user.uid, 'company_logo_url');

      if (row != null) {
        final logoUrl = row['company_logo_url'] as String?;

        if (logoUrl != null && logoUrl.isNotEmpty) {
          try {
            // The stored value is a signed URL; the object key is recovered
            // from it rather than resolving the URL itself.
            await _store.deleteObject(_objectKeyFromUrl(logoUrl));
            print('✓ Company logo deleted from storage');
          } catch (e) {
            print('⚠️ Warning: Failed to delete company logo: $e');
          }
        }
      }

      // Company details are columns on `profiles`, not a removable node, so
      // clearing them means nulling the columns.
      await _store.updateProfile(user.uid, {
        'company_name': null,
        'companies_house_number': null,
        'company_logo_url': null,
        'company_email': null,
        'company_landline': null,
        'company_website': null,
        'vat_registered': false,
        'vat_number': null,
      });

      // Update the updatedAt timestamp
      await _store.updateProfile(
        user.uid,
        ProfileMapper.modelJsonToRow(<String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        }, partial: true),
      );

      print('✓ Company details removed successfully');
    } catch (e) {
      print('❌ Failed to remove company details: $e');
      throw CustomException(message: 'Failed to remove company details: $e');
    }
  }

  @override
  Future<void> updateVerificationStatus(String userId, bool? isVerified) async {
    try {
      // Moderation action. `verification_status` is server-owned — the
      // profiles_guard_server_columns trigger refuses a client write, which is
      // the point: a tradesman must not be able to verify themselves.
      //
      // The Edge Function only lets a caller reset or submit THEIR OWN
      // profile; approving or rejecting someone else needs an admin surface
      // that does not exist in this client. Calls that target another user, or
      // try to set 'verified'/'rejected', are refused here rather than failing
      // opaquely at the database.
      if (userId != _uid) {
        throw CustomException(
          message:
              'Verification status for another user must be set by an admin.',
          code: 'verification-requires-admin',
        );
      }
      if (isVerified != null) {
        throw CustomException(
          message: 'Approving or rejecting verification requires an admin.',
          code: 'verification-requires-admin',
        );
      }

      print('⚙️  Submitting verification for review: $userId');
      await SupabaseService().client.functions.invoke(
            'tradesman-verification',
            body: {'action': 'submit'},
          );
      print('✓ Verification submitted');
    } catch (e) {
      print('❌ Error updating verification status: $e');
      throw CustomException(
        message: 'Failed to update verification status: $e',
      );
    }
  }

  @override
  Future<void> updateRejectionReason(String userId, String reason) async {
    try {
      // Same reasoning as updateVerificationStatus: rejecting a registration
      // is a moderation action and cannot come from the client.
      print('📝 Rejection requested for $userId: $reason');
      throw CustomException(
        message: 'Rejecting a registration requires an admin.',
        code: 'verification-requires-admin',
      );
    } catch (e) {
      print('❌ Error updating rejection reason: $e');
      throw CustomException(message: 'Failed to update rejection reason: $e');
    }
  }

  @override
  Stream<String?> streamVerificationStatus() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    print('👂 Listening to verification status changes...');

    return _store
        .streamProfileField(user.uid, 'verification_status')
        .map((status) {
          print('📡 Verification status changed: $status');
          return status?.toString();
        });
  }

  @override
  Future<String> uploadTemplateLogo({
    required String templateId,
    required String localPath,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    // Delete existing logo for this template first
    await deleteTemplateLogoByTemplateId(templateId);

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final storagePath = DatabasePaths.templateLogo(
      user.uid,
      templateId,
      timestamp,
    );

    return await _uploadImage(localPath: localPath, storagePath: storagePath, imageType: 'logo');
  }

  @override
  Future<void> deleteTemplateLogo(String logoUrl) async {
    try {
      if (logoUrl.isEmpty) return;

      print('🗑️  Deleting template logo...');
      await _store.deleteObject(_objectKeyFromUrl(logoUrl));
      print('✓ Template logo deleted');
    } catch (e) {
      print('⚠️ Warning: Failed to delete template logo: $e');
      // Don't throw - deletion failure shouldn't block new upload
    }
  }

  @override
  Future<void> deleteTemplateLogoByTemplateId(String templateId) async {
    final user = currentUser;
    if (user == null) return;

    try {
      print('🗑️  Deleting existing logos for template: $templateId');
      final templateLogoPath =
          '${DatabasePaths.userDocuments(user.uid)}/template/$templateId';
      await _store.deleteTree(templateLogoPath);
      print('✓ Template logos cleared');
    } catch (e) {
      print('⚠️ Warning: Failed to delete template logos: $e');
      // Don't throw - deletion failure shouldn't block new upload
    }
  }

  // ============================================
  // Trade Qualifications Management
  // ============================================

  @override
  Future<List<TradeQualificationDoc>> getTradeQualifications() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📂 Fetching trade qualifications for user: ${user.uid}');

      final rows = await _store.list('trade_qualifications');

      if (rows.isEmpty) {
        print('✓ No trade qualifications found');
        return [];
      }

      final qualifications = <TradeQualificationDoc>[];
      for (final row in rows) {
        try {
          qualifications.add(
            TradeQualificationDoc.fromJson(_qualificationToJson(row)),
          );
        } catch (e) {
          print('⚠️ Error parsing qualification ${row['id']}: $e');
        }
      }

      print('✓ Found ${qualifications.length} trade qualifications');
      return qualifications;
    } catch (e) {
      print('❌ Failed to get trade qualifications: $e');
      throw CustomException(message: 'Failed to get qualifications: $e');
    }
  }

  @override
  Future<void> uploadTradeQualification({
    required String requirementId,
    required String localPath,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📄 Uploading trade qualification: $requirementId');

      final ext = ImageValidator.getFileExtension(localPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final storagePath = DatabasePaths.storageTradeQualification(
        user.uid,
        requirementId,
        timestamp,
        ext,
      );

      final isImage = ImageValidator.isImageFile(localPath);
      final downloadUrl = await _uploadImage(
        localPath: localPath,
        storagePath: storagePath,
        imageType: isImage ? 'identity' : null,
      );

      final qualData = {
        'requirementId': requirementId,
        'documentUrl': downloadUrl,
        'isMandatory': true,
        'uploadedAt': DateTime.now().toIso8601String(),
        'verificationStatus': 'pending',
        'rejectionReason': null,
      };

      // One row per requirement per user, upserted on the same unique key the
      // RTDB child key expressed.
      await SupabaseService().client.from('trade_qualifications').upsert({
        'owner_id': user.uid,
        'requirement_id': requirementId,
        'name': requirementId,
        'url': qualData['documentUrl'],
        'storage_path': storagePath,
        'is_mandatory': qualData['isMandatory'] ?? true,
        'uploaded_at': qualData['uploadedAt'],
      }, onConflict: 'owner_id,requirement_id');

      print('✓ Trade qualification uploaded successfully');
    } catch (e) {
      print('❌ Failed to upload trade qualification: $e');
      throw CustomException(message: 'Failed to upload qualification: $e');
    }
  }

  @override
  Stream<List<TradeQualificationDoc>> streamTradeQualifications() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    print('👂 Streaming trade qualifications for user: ${user.uid}');

    return _store
        .watch('trade_qualifications')
        .map((rows) {
          final qualifications = <TradeQualificationDoc>[];

          for (final entry in rows.map(
            (r) => MapEntry(r['id']?.toString() ?? '', _qualificationToJson(r)),
          )) {
            try {
              final docData = Map<String, dynamic>.from(entry.value as Map);
              qualifications.add(TradeQualificationDoc.fromJson(docData));
            } catch (e) {
              print('⚠️ Error parsing qualification ${entry.key}: $e');
            }
          }

          return qualifications;
        });
  }

  // ============================================
  // Trade Card Management
  // ============================================

  @override
  Future<TradeCardModel> uploadTradeCard({
    required String localPath,
    required String cardScheme,
    required String cardColor,
    required String qualificationLevel,
    required String mappedTrade,
    String? registrationNumber,
    DateTime? expiryDate,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🪪 Uploading trade card...');

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      // Get file size
      final fileSize = await file.length();
      print('✓ File size: ${ImageValidator.formatFileSize(fileSize)}');

      final ext = ImageValidator.getFileExtension(localPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload image to storage
      final storagePath = DatabasePaths.storageTradeCard(
        user.uid,
        timestamp,
        ext,
      );
      final isImage = ImageValidator.isImageFile(localPath);
      final downloadUrl = await _uploadImage(
        localPath: localPath,
        storagePath: storagePath,
        imageType: isImage ? 'identity' : null,
      );

      // Create model
      final now = DateTime.now();
      final card = TradeCardModel(
        id: timestamp,
        cardScheme: cardScheme,
        cardColor: cardColor,
        qualificationLevel: qualificationLevel,
        registrationNumber: registrationNumber,
        expiryDate: expiryDate,
        imageUrl: downloadUrl,
        mappedTrade: mappedTrade,
        uploadedAt: now,
        updatedAt: now,
        verificationStatus: 'pending',
        fileSize: fileSize,
      );

      // Save metadata. trade_cards is keyed by owner_id — one card per user,
      // which is what the single RTDB node expressed.
      await _store.upsertOwned('trade_cards', _tradeCardToRow(card.toJson())
        ..['storage_path'] = storagePath);

      print('✓ Trade card uploaded successfully');
      return card;
    } catch (e) {
      print('❌ Failed to upload trade card: $e');
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to upload trade card: $e');
    }
  }

  @override
  Future<TradeCardModel?> getTradeCard() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      final row = await _store.readOwned('trade_cards');
      if (row == null) return null;
      return TradeCardModel.fromJson(_tradeCardToJson(row));
    } catch (e) {
      print('❌ Failed to get trade card: $e');
      throw CustomException(message: 'Failed to get trade card: $e');
    }
  }

  @override
  Future<void> updateTradeCard({
    String? cardScheme,
    String? cardColor,
    String? qualificationLevel,
    String? registrationNumber,
    DateTime? expiryDate,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📝 Updating trade card...');

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (cardScheme != null) updates['cardScheme'] = cardScheme;
      if (cardColor != null) updates['cardColor'] = cardColor;
      if (qualificationLevel != null) {
        updates['qualificationLevel'] = qualificationLevel;
      }
      if (registrationNumber != null) {
        updates['registrationNumber'] = registrationNumber;
      }
      if (expiryDate != null) {
        updates['expiryDate'] = expiryDate.toIso8601String();
      }

      await _store.upsertOwned('trade_cards', _tradeCardToRow(updates));

      print('✓ Trade card updated successfully');
    } catch (e) {
      print('❌ Failed to update trade card: $e');
      throw CustomException(message: 'Failed to update trade card: $e');
    }
  }

  @override
  Future<void> deleteTradeCard() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🗑️ Deleting trade card...');

      // Get existing card data to delete image from storage
      final row = await _store.readOwned('trade_cards');

      if (row != null) {
        // Prefer the stored object key; fall back to parsing the URL.
        final imageUrl = (row['storage_path'] ?? row['image_url']) as String?;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            // The stored value is a signed URL; the object key is recovered
            // from it rather than resolving the URL itself.
            await _store.deleteObject(_objectKeyFromUrl(imageUrl));
            print('✓ Trade card image deleted from storage');
          } catch (e) {
            print('⚠️ Warning: Failed to delete image from storage: $e');
          }
        }
      }

      // Delete metadata from database
      await _store.deleteOwned('trade_cards');

      print('✓ Trade card deleted successfully');
    } catch (e) {
      print('❌ Failed to delete trade card: $e');
      throw CustomException(message: 'Failed to delete trade card: $e');
    }
  }

  // ============================================
  // Extra Documents Management
  // ============================================

  @override
  Future<ExtraDocumentModel> uploadExtraDocument({
    required String localPath,
    required String name,
    required ExtraDocumentType type,
    String? description,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📄 Uploading extra document: $name');

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      // Get file size
      final fileSize = await file.length();
      print('✓ File size: ${ImageValidator.formatFileSize(fileSize)}');

      // Get extension
      final extension = ImageValidator.getFileExtension(localPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final documentId = timestamp;

      // Upload to storage
      final storagePath = DatabasePaths.extraDocument(
        user.uid,
        timestamp,
        extension,
      );
      final isImage = ImageValidator.isImageFile(localPath);
      final downloadUrl = await _uploadImage(
        localPath: localPath,
        storagePath: storagePath,
        imageType: isImage ? 'extra' : null,
      );

      // Create document model
      final now = DateTime.now();
      final document = ExtraDocumentModel(
        id: documentId,
        name: name,
        url: downloadUrl,
        type: type,
        description: description,
        fileSize: fileSize,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _store.insert('extra_documents', {
        'id': documentId,
        ..._extraDocToRow(document.toJson()),
        'storage_path': storagePath,
      });

      print('✓ Extra document uploaded successfully');
      return document;
    } catch (e) {
      print('❌ Failed to upload extra document: $e');
      throw CustomException(message: 'Failed to upload document: $e');
    }
  }

  @override
  Future<List<ExtraDocumentModel>> getExtraDocuments() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📂 Fetching extra documents for user: ${user.uid}');

      final rows = await _store.list('extra_documents');

      if (rows.isEmpty) {
        print('✓ No extra documents found');
        return [];
      }

      final documents = <ExtraDocumentModel>[];

      for (final row in rows) {
        try {
          documents.add(ExtraDocumentModel.fromJson(_extraDocToJson(row)));
        } catch (e) {
          print('⚠️ Error parsing document ${row['id']}: $e');
        }
      }

      print('✓ Found ${documents.length} extra documents');
      return documents..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Failed to get extra documents: $e');
      throw CustomException(message: 'Failed to get documents: $e');
    }
  }

  @override
  Stream<List<ExtraDocumentModel>> streamExtraDocuments() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    print('👂 Streaming extra documents for user: ${user.uid}');

    return _store
        .watch('extra_documents')
        .map((rows) {
          final documents = <ExtraDocumentModel>[];

          for (final entry in rows.map(
            (r) => MapEntry(r['id']?.toString() ?? '', _extraDocToJson(r)),
          )) {
            try {
              final docData = entry.value;
              documents.add(ExtraDocumentModel.fromJson(docData));
            } catch (e) {
              print('⚠️ Error parsing document ${entry.key}: $e');
            }
          }

          return documents..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }

  @override
  Future<void> updateExtraDocument({
    required String documentId,
    String? name,
    ExtraDocumentType? type,
    String? description,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📝 Updating extra document: $documentId');

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (type != null) updates['type'] = type.name;
      if (description != null) updates['description'] = description;

      await _store.updateById(
        'extra_documents',
        documentId,
        _extraDocToRow(updates),
      );

      print('✓ Extra document updated successfully');
    } catch (e) {
      print('❌ Failed to update extra document: $e');
      throw CustomException(message: 'Failed to update document: $e');
    }
  }

  @override
  Future<void> deleteExtraDocument(String documentId) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🗑️ Deleting extra document: $documentId');

      // Get document data first to get the storage key
      final row = await _store.findById('extra_documents', documentId);

      if (row != null) {
        // Prefer the stored object key; fall back to parsing the URL.
        final url = (row['storage_path'] ?? row['url']) as String?;

        // Delete from storage if URL exists
        if (url != null && url.isNotEmpty) {
          try {
            // The stored value is a signed URL; the object key is recovered
            // from it rather than resolving the URL itself.
            await _store.deleteObject(_objectKeyFromUrl(url));
            print('✓ Deleted from storage');
          } catch (e) {
            print('⚠️ Warning: Failed to delete from storage: $e');
          }
        }
      }

      // Delete from database
      await _store.deleteById('extra_documents', documentId);

      print('✓ Extra document deleted successfully');
    } catch (e) {
      print('❌ Failed to delete extra document: $e');
      throw CustomException(message: 'Failed to delete document: $e');
    }
  }

  // ============================================
  // Portfolio Management (Images & Videos)
  // ============================================

  @override
  Future<PortfolioMediaModel> uploadPortfolioImage({
    required String localPath,
    String? title,
    String? description,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🖼️ Uploading portfolio image...');

      // Check photo upload limit before proceeding
      final canUpload = await canUploadPhoto();
      if (!canUpload) {
        throw CustomException(
          message:
              'Photo upload limit reached. Please upgrade your plan to upload more photos.',
        );
      }

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      final fileSize = await file.length();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final mediaId = timestamp;

      // Upload to storage
      final storagePath = DatabasePaths.portfolioImage(user.uid, timestamp);
      final downloadUrl = await _uploadImage(
        localPath: localPath,
        storagePath: storagePath,
        imageType: 'portfolio',
      );

      // Create media model
      final now = DateTime.now();
      final media = PortfolioMediaModel(
        id: mediaId,
        url: downloadUrl,
        type: PortfolioMediaType.image,
        title: title,
        description: description,
        fileSize: fileSize,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _store.insert('portfolio_media', {
        'id': mediaId,
        'kind': 'image',
        ..._portfolioToRow(media.toJson()),
        'storage_path': storagePath,
      });

      // Update usage count
      await _incrementMediaCount(user.uid, 'photoUploadCount');

      print('✓ Portfolio image uploaded successfully');
      return media;
    } catch (e) {
      print('❌ Failed to upload portfolio image: $e');
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to upload image: $e');
    }
  }

  @override
  Future<PortfolioMediaModel> uploadPortfolioVideo({
    required String localPath,
    String? title,
    String? description,
    int? durationSeconds,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🎬 Uploading portfolio video...');

      // Check video upload limit before proceeding
      final canUpload = await canUploadVideo();
      if (!canUpload) {
        throw CustomException(
          message:
              'Video upload limit reached. Please upgrade your plan to upload more videos.',
        );
      }

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      final fileSize = await file.length();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final mediaId = timestamp;

      // Upload to storage
      final storagePath = DatabasePaths.portfolioVideo(user.uid, timestamp);
      final downloadUrl = await _uploadVideo(
        localPath: localPath,
        storagePath: storagePath,
      );

      // Create media model
      final now = DateTime.now();
      final media = PortfolioMediaModel(
        id: mediaId,
        url: downloadUrl,
        type: PortfolioMediaType.video,
        title: title,
        description: description,
        fileSize: fileSize,
        durationSeconds: durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _store.insert('portfolio_media', {
        'id': mediaId,
        'kind': 'video',
        ..._portfolioToRow(media.toJson()),
        'storage_path': storagePath,
      });

      // Update usage count
      await _incrementMediaCount(user.uid, 'videoUploadCount');

      print('✓ Portfolio video uploaded successfully');
      return media;
    } catch (e) {
      print('❌ Failed to upload portfolio video: $e');
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to upload video: $e');
    }
  }

  @override
  Future<PortfolioMediaModel> uploadJobVideo({
    required String localPath,
    required String jobId,
    String? jobTitle,
    String? title,
    String? description,
    int? durationSeconds,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🎬 Uploading job video for job: $jobId...');

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      final fileSize = await file.length();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final mediaId = '${jobId}_$timestamp';

      // Upload to storage
      final storagePath = DatabasePaths.jobVideo(user.uid, jobId, timestamp);
      final downloadUrl = await _uploadVideo(
        localPath: localPath,
        storagePath: storagePath,
      );

      // Create media model
      final now = DateTime.now();
      final media = PortfolioMediaModel(
        id: mediaId,
        url: downloadUrl,
        type: PortfolioMediaType.jobVideo,
        title: title,
        description: description,
        jobId: jobId,
        jobTitle: jobTitle,
        fileSize: fileSize,
        durationSeconds: durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _store.insert('portfolio_media', {
        'id': mediaId,
        'kind': 'job_video',
        ..._portfolioToRow(media.toJson()),
        'storage_path': storagePath,
      });

      // Update usage count
      await _incrementMediaCount(user.uid, 'videoUploadCount');

      print('✓ Job video uploaded successfully');
      return media;
    } catch (e) {
      print('❌ Failed to upload job video: $e');
      throw CustomException(message: 'Failed to upload job video: $e');
    }
  }

  /// Upload video to Firebase Storage
  Future<String> _uploadVideo({
    required String localPath,
    required String storagePath,
  }) async {
    try {
      print('🎬 Uploading video to: $storagePath');

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'Video file does not exist: $localPath');
      }

      print('✓ File exists, size: ${file.lengthSync()} bytes');

      final downloadUrl = await _store.uploadImage(
        localPath: localPath,
        storagePath: storagePath,
      );
      print('✓ Download URL obtained');

      return downloadUrl;
    } catch (e) {
      print('❌ Video upload failed: $e');
      throw CustomException(message: 'Failed to upload video: $e');
    }
  }

  // ============================================
  // Limit Checking Methods
  // ============================================

  /// Check if user can upload more photos based on subscription limits
  Future<bool> canUploadPhoto() async => true;

  /// Check if user can upload more videos based on subscription limits
  Future<bool> canUploadVideo() async => true;

  /// Get current photo upload count and limit
  Future<Map<String, int>> getPhotoUploadStatus() async {
    return {'current': 0, 'limit': -1, 'remaining': -1};
  }

  /// Get current video upload count and limit
  Future<Map<String, int>> getVideoUploadStatus() async {
    return {'current': 0, 'limit': -1, 'remaining': -1};
  }

  // ============================================
  // Media Count Management
  // ============================================

  /// Increment media upload count
  Future<void> _incrementMediaCount(String uid, String field) async {
    try {
      await _bumpUsage(field, 1);
    } catch (e) {
      print('⚠️ Warning: Failed to increment $field: $e');
    }
  }

  /// Decrement media upload count
  Future<void> _decrementMediaCount(String uid, String field) async {
    try {
      // bump_usage floors at zero inside one statement, so the old
      // read-compare-write (and its race) is gone.
      await _bumpUsage(field, -1);
    } catch (e) {
      print('⚠️ Warning: Failed to decrement $field: $e');
    }
  }

  @override
  Future<List<PortfolioMediaModel>> getPortfolioImages() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      final rows = await _store.list('portfolio_media', kind: 'image');

      if (rows.isEmpty) {
        return [];
      }

      final images = <PortfolioMediaModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final mediaData = entry.value;
          images.add(PortfolioMediaModel.fromJson(mediaData));
        } catch (e) {
          print('⚠️ Error parsing image ${entry.key}: $e');
        }
      }

      return images..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Failed to get portfolio images: $e');
      throw CustomException(message: 'Failed to get images: $e');
    }
  }

  @override
  Future<List<PortfolioMediaModel>> getPortfolioVideos() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      final rows = await _store.list('portfolio_media', kind: 'video');

      if (rows.isEmpty) {
        return [];
      }

      final videos = <PortfolioMediaModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final mediaData = entry.value;
          videos.add(PortfolioMediaModel.fromJson(mediaData));
        } catch (e) {
          print('⚠️ Error parsing video ${entry.key}: $e');
        }
      }

      return videos..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Failed to get portfolio videos: $e');
      throw CustomException(message: 'Failed to get videos: $e');
    }
  }

  @override
  Future<List<PortfolioMediaModel>> getJobVideos() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      final rows = await _store.list('portfolio_media', kind: 'job_video');

      if (rows.isEmpty) {
        return [];
      }

      final videos = <PortfolioMediaModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final mediaData = entry.value;
          videos.add(PortfolioMediaModel.fromJson(mediaData));
        } catch (e) {
          print('⚠️ Error parsing job video ${entry.key}: $e');
        }
      }

      return videos..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Failed to get job videos: $e');
      throw CustomException(message: 'Failed to get job videos: $e');
    }
  }

  @override
  Stream<List<PortfolioMediaModel>> streamPortfolioImages() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    return _store
        .watch('portfolio_media', kind: 'image')
        .map((rows) {
                    final images = <PortfolioMediaModel>[];

          for (final entry in rows.map(
            (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
          )) {
            try {
              final mediaData = entry.value;
              images.add(PortfolioMediaModel.fromJson(mediaData));
            } catch (e) {
              print('⚠️ Error parsing image ${entry.key}: $e');
            }
          }

          return images..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }

  @override
  Stream<List<PortfolioMediaModel>> streamPortfolioVideos() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    return _store
        .watch('portfolio_media', kind: 'video')
        .map((rows) {
                    final videos = <PortfolioMediaModel>[];

          for (final entry in rows.map(
            (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
          )) {
            try {
              final mediaData = entry.value;
              videos.add(PortfolioMediaModel.fromJson(mediaData));
            } catch (e) {
              print('⚠️ Error parsing video ${entry.key}: $e');
            }
          }

          return videos..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }

  @override
  Stream<List<PortfolioMediaModel>> streamJobVideos() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    return _store.watch('portfolio_media', kind: 'job_video').map((rows) {
            final videos = <PortfolioMediaModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final mediaData = entry.value;
          videos.add(PortfolioMediaModel.fromJson(mediaData));
        } catch (e) {
          print('⚠️ Error parsing job video ${entry.key}: $e');
        }
      }

      return videos..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<void> updatePortfolioMedia({
    required String mediaId,
    required PortfolioMediaType type,
    String? title,
    String? description,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📝 Updating portfolio media: $mediaId');

      String dbPath;
      // All three media types share `portfolio_media`; `kind` already
      // distinguishes them, so the row id alone identifies the record.
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;

      await _store.updateById(
        'portfolio_media',
        mediaId,
        _portfolioToRow(updates),
      );

      print('✓ Portfolio media updated successfully');
    } catch (e) {
      print('❌ Failed to update portfolio media: $e');
      throw CustomException(message: 'Failed to update media: $e');
    }
  }

  @override
  Future<void> deletePortfolioMedia({
    required String mediaId,
    required PortfolioMediaType type,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🗑️ Deleting portfolio media: $mediaId');

      // All three media types live in `portfolio_media`, so only the counter
      // still varies by type.
      final String countField;
      switch (type) {
        case PortfolioMediaType.image:
          countField = 'photoUploadCount';
          break;
        case PortfolioMediaType.video:
        case PortfolioMediaType.jobVideo:
          countField = 'videoUploadCount';
          break;
      }

      // Get media data first to get the storage key
      final row = await _store.findById('portfolio_media', mediaId);

      if (row != null) {
        // Prefer the stored object key; fall back to parsing the URL.
        final url = (row['storage_path'] ?? row['url']) as String?;

        // Delete from storage if URL exists
        if (url != null && url.isNotEmpty) {
          try {
            // The stored value is a signed URL; the object key is recovered
            // from it rather than resolving the URL itself.
            await _store.deleteObject(_objectKeyFromUrl(url));
            print('✓ Deleted from storage');
          } catch (e) {
            print('⚠️ Warning: Failed to delete from storage: $e');
          }
        }
      }

      // Delete from database
      await _store.deleteById('portfolio_media', mediaId);

      // Update usage count
      await _decrementMediaCount(user.uid, countField);

      print('✓ Portfolio media deleted successfully');
    } catch (e) {
      print('❌ Failed to delete portfolio media: $e');
      throw CustomException(message: 'Failed to delete media: $e');
    }
  }

  // ============================================
  // Highlights Management (Instagram-style story highlights)
  // ============================================

  @override
  Future<PortfolioHighlightModel> createHighlight({
    required String title,
    required String localPath,
    required bool isVideo,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('✨ Creating highlight: $title');

      final file = File(localPath);
      if (!file.existsSync()) {
        throw CustomException(message: 'File does not exist: $localPath');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final highlightId = timestamp;

      // Upload media to storage
      final storagePath = DatabasePaths.highlightMedia(user.uid, timestamp);
      String downloadUrl;
      if (isVideo) {
        downloadUrl = await _uploadVideo(
          localPath: localPath,
          storagePath: storagePath,
        );
      } else {
        downloadUrl = await _uploadImage(
          localPath: localPath,
          storagePath: storagePath,
          imageType: 'portfolio',
        );
      }

      // Create highlight model
      final now = DateTime.now();
      final highlight = PortfolioHighlightModel(
        id: highlightId,
        title: title,
        coverUrl: downloadUrl,
        mediaUrl: downloadUrl,
        isVideo: isVideo,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      await _store.insert('portfolio_media', {
        'id': highlightId,
        'kind': 'highlight',
        ..._portfolioToRow(highlight.toJson()),
        'storage_path': storagePath,
      });

      print('✓ Highlight created successfully');
      return highlight;
    } catch (e) {
      print('❌ Failed to create highlight: $e');
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to create highlight: $e');
    }
  }

  @override
  Future<PortfolioHighlightModel> createHighlightFromExisting({
    required String title,
    required String mediaUrl,
    String? thumbnailUrl,
    required bool isVideo,
    int? durationSeconds,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('✨ Creating highlight from existing media: $title');

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final highlightId = timestamp;

      // Create highlight model using existing media URL
      final now = DateTime.now();
      final highlight = PortfolioHighlightModel(
        id: highlightId,
        title: title,
        coverUrl: thumbnailUrl ?? mediaUrl,
        mediaUrl: mediaUrl,
        isVideo: isVideo,
        durationSeconds: durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

      // Save to database
      // Built from media that is already uploaded, so there is no new object
      // key to record — the highlight points at the existing one.
      await _store.insert('portfolio_media', {
        'id': highlightId,
        'kind': 'highlight',
        ..._portfolioToRow(highlight.toJson()),
      });

      print('✓ Highlight created from existing media successfully');
      return highlight;
    } catch (e) {
      print('❌ Failed to create highlight from existing: $e');
      if (e is CustomException) rethrow;
      throw CustomException(message: 'Failed to create highlight: $e');
    }
  }

  @override
  Future<List<PortfolioHighlightModel>> getHighlights() async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      final rows = await _store.list('portfolio_media', kind: 'highlight');

      if (rows.isEmpty) {
        return [];
      }

      final highlights = <PortfolioHighlightModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final highlightData = entry.value;
          highlights.add(PortfolioHighlightModel.fromJson(highlightData));
        } catch (e) {
          print('⚠️ Error parsing highlight ${entry.key}: $e');
        }
      }

      return highlights..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('❌ Failed to get highlights: $e');
      throw CustomException(message: 'Failed to get highlights: $e');
    }
  }

  @override
  Stream<List<PortfolioHighlightModel>> streamHighlights() {
    final user = currentUser;
    if (user == null) {
      return Stream.error(CustomException(message: 'User not authenticated'));
    }

    return _store.watch('portfolio_media', kind: 'highlight').map((rows) {
            final highlights = <PortfolioHighlightModel>[];

      for (final entry in rows.map(
        (r) => MapEntry(r['id']?.toString() ?? '', _portfolioToJson(r)),
      )) {
        try {
          final highlightData = entry.value;
          highlights.add(PortfolioHighlightModel.fromJson(highlightData));
        } catch (e) {
          print('⚠️ Error parsing highlight ${entry.key}: $e');
        }
      }

      return highlights..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<void> updateHighlight({
    required String highlightId,
    required String title,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('📝 Updating highlight: $highlightId');

      await _store.updateById('portfolio_media', highlightId, {
        'title': title,
      });

      print('✓ Highlight updated successfully');
    } catch (e) {
      print('❌ Failed to update highlight: $e');
      throw CustomException(message: 'Failed to update highlight: $e');
    }
  }

  @override
  Future<void> deleteHighlight({required String highlightId}) async {
    final user = currentUser;
    if (user == null) {
      throw CustomException(message: 'User not authenticated');
    }

    try {
      print('🗑️ Deleting highlight: $highlightId');

      // Get highlight data first to get the storage key
      final row = await _store.findById('portfolio_media', highlightId);

      if (row != null) {
        // Prefer the stored object key; fall back to parsing the URL.
        final url = (row['storage_path'] ?? row['media_url']) as String?;

        // Delete from storage if URL exists
        if (url != null && url.isNotEmpty) {
          try {
            // The stored value is a signed URL; the object key is recovered
            // from it rather than resolving the URL itself.
            await _store.deleteObject(_objectKeyFromUrl(url));
            print('✓ Deleted from storage');
          } catch (e) {
            print('⚠️ Warning: Failed to delete from storage: $e');
          }
        }
      }

      // Delete from database
      await _store.deleteById('portfolio_media', highlightId);

      print('✓ Highlight deleted successfully');
    } catch (e) {
      print('❌ Failed to delete highlight: $e');
      throw CustomException(message: 'Failed to delete highlight: $e');
    }
  }
}
