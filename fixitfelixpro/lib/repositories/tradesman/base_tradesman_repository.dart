
import '../../core/config/environment_variables.dart';
import '../../models/app_user.dart';
import '../../core/enum.dart';
import '../../models/address_model.dart';
import '../../models/extra_document_model.dart';
import '../../models/portfolio_media_model.dart';
import '../../models/trade_card_model.dart';
import '../../models/trade_requirement.dart';
import '../../models/tradesman_model.dart';

abstract class BaseTradesmanRepository {
  // ============================================
  // Configuration
  // ============================================
  void setENVConfig(EnvironmentVariables envData);

  // ============================================
  // Authentication
  // ============================================
  AppUser? get currentUser;

  // ============================================
  // Registration
  // ============================================
  Future<void> submitTradesmanRegistration({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    required String phoneNumber,
    required AddressModel address,
    required AccountCategoryType accountCategoryType,
    required String nationalInsuranceNumber,
    required DocumentType documentType,
    required VerificationStatus verificationStatus,
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
  });

  Future<TradesmanModel?> getTradesmanRegistration();
  Future<void> deleteRegistrationData();

  // ============================================
  // Company Details Management
  // ============================================
  Future<void> updateCompanyDetails({
    required String companyName,
    required String companiesHouseNumber,
    required String companyEmail,
    String? companyLandline,
    String? companyLogoImagePath,
  });
  Future<void> removeCompanyDetails();

  // ============================================
  // Verification Status
  // ============================================
  Future<String?> getVerificationStatus();
  Future<String?> getRejectionReason();
  Future<void> updateVerificationStatus(String userId, bool? isVerified);
  Future<void> updateRejectionReason(String userId, String reason);
  Stream<String?> streamVerificationStatus();

  // ============================================
  // Template Logo Management
  // ============================================
  Future<String> uploadTemplateLogo({
    required String templateId,
    required String localPath,
  });
  Future<void> deleteTemplateLogo(String logoUrl);
  Future<void> deleteTemplateLogoByTemplateId(String templateId);

  // ============================================
  // Trade Qualifications Management
  // ============================================
  Future<List<TradeQualificationDoc>> getTradeQualifications();
  Future<void> uploadTradeQualification({
    required String requirementId,
    required String localPath,
  });
  Stream<List<TradeQualificationDoc>> streamTradeQualifications();

  // ============================================
  // Trade Card Management
  // ============================================
  Future<TradeCardModel> uploadTradeCard({
    required String localPath,
    required String cardScheme,
    required String cardColor,
    required String qualificationLevel,
    required String mappedTrade,
    String? registrationNumber,
    DateTime? expiryDate,
  });
  Future<TradeCardModel?> getTradeCard();
  Future<void> updateTradeCard({
    String? cardScheme,
    String? cardColor,
    String? qualificationLevel,
    String? registrationNumber,
    DateTime? expiryDate,
  });
  Future<void> deleteTradeCard();

  // ============================================
  // Extra Documents Management (Certificates, Licenses, etc.)
  // ============================================
  Future<ExtraDocumentModel> uploadExtraDocument({
    required String localPath,
    required String name,
    required ExtraDocumentType type,
    String? description,
  });
  Future<List<ExtraDocumentModel>> getExtraDocuments();
  Stream<List<ExtraDocumentModel>> streamExtraDocuments();
  Future<void> updateExtraDocument({
    required String documentId,
    String? name,
    ExtraDocumentType? type,
    String? description,
  });
  Future<void> deleteExtraDocument(String documentId);

  // ============================================
  // Portfolio Management (Images & Videos)
  // ============================================
  Future<PortfolioMediaModel> uploadPortfolioImage({
    required String localPath,
    String? title,
    String? description,
  });
  Future<PortfolioMediaModel> uploadPortfolioVideo({
    required String localPath,
    String? title,
    String? description,
    int? durationSeconds,
  });
  Future<PortfolioMediaModel> uploadJobVideo({
    required String localPath,
    required String jobId,
    String? jobTitle,
    String? title,
    String? description,
    int? durationSeconds,
  });
  Future<List<PortfolioMediaModel>> getPortfolioImages();
  Future<List<PortfolioMediaModel>> getPortfolioVideos();
  Future<List<PortfolioMediaModel>> getJobVideos();
  Stream<List<PortfolioMediaModel>> streamPortfolioImages();
  Stream<List<PortfolioMediaModel>> streamPortfolioVideos();
  Stream<List<PortfolioMediaModel>> streamJobVideos();
  Future<void> updatePortfolioMedia({
    required String mediaId,
    required PortfolioMediaType type,
    String? title,
    String? description,
  });
  Future<void> deletePortfolioMedia({
    required String mediaId,
    required PortfolioMediaType type,
  });

  // ============================================
  // Highlights Management (Instagram-style story highlights)
  // ============================================
  Future<PortfolioHighlightModel> createHighlight({
    required String title,
    required String localPath,
    required bool isVideo,
  });
  Future<PortfolioHighlightModel> createHighlightFromExisting({
    required String title,
    required String mediaUrl,
    String? thumbnailUrl,
    required bool isVideo,
    int? durationSeconds,
  });
  Future<List<PortfolioHighlightModel>> getHighlights();
  Stream<List<PortfolioHighlightModel>> streamHighlights();
  Future<void> updateHighlight({
    required String highlightId,
    required String title,
  });
  Future<void> deleteHighlight({required String highlightId});
}
