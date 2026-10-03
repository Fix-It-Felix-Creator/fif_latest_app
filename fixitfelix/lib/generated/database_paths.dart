import '../core/config/config_service.dart';

/// Paths for Firebase Storage and Firebase Realtime Database
///
/// This file is organized into two main sections:
/// 1. STORAGE PATHS (Firebase Storage) - File uploads, images, videos
/// 2. DATABASE PATHS (Firebase Realtime Database) - Data records
///
/// Storage paths are determined by APP_TYPE in .env:
/// - DEVELOPMENT: uses 'users/'
/// - PRODUCTION: uses 'pod_users/'
///
/// Database paths are shared across all environments.
class DatabasePaths {
  static final ConfigService _config = ConfigService();

  // ############################################################################
  // #                                                                          #
  // #                     SECTION 1: STORAGE PATHS                             #
  // #                     (Firebase Storage - Files)                           #
  // #                                                                          #
  // ############################################################################

  // ============================================
  // Storage Root (Dynamic based on APP_TYPE)
  // ============================================

  /// Storage users root: 'users' for dev, 'pod_users' for prod
  static String get storageUsers =>
      _config.isProduction ? 'pod_users' : 'users';

  // ============================================
  // User Documents Storage
  // ============================================

  /// User documents root: {storageUsers}/{uid}/documents
  static String storageUserDocuments(String uid) =>
      '$storageUsers/$uid/documents';

  /// Passport image: {storageUsers}/{uid}/documents/passport/{timestamp}.jpg
  static String storagePassportImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/passport/$timestamp.jpg';

  /// ID Card front: {storageUsers}/{uid}/documents/idcard/front/{timestamp}.jpg
  static String storageIdCardFrontImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/idcard/front/$timestamp.jpg';

  /// ID Card back: {storageUsers}/{uid}/documents/idcard/back/{timestamp}.jpg
  static String storageIdCardBackImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/idcard/back/$timestamp.jpg';

  /// Driver license front: {storageUsers}/{uid}/documents/driver_license/front/{timestamp}.jpg
  static String storageDriverLicenseFrontImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/driver_license/front/$timestamp.jpg';

  /// Driver license back: {storageUsers}/{uid}/documents/driver_license/back/{timestamp}.jpg
  static String storageDriverLicenseBackImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/driver_license/back/$timestamp.jpg';

  /// Selfie image: {storageUsers}/{uid}/documents/selfie/{timestamp}.jpg
  static String storageSelfieImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/selfie/$timestamp.jpg';

  /// Profile image: {storageUsers}/{uid}/documents/profile/{timestamp}.jpg
  static String storageProfileImage(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/profile/$timestamp.jpg';

  /// Template logo: {storageUsers}/{uid}/documents/template/{tempId}/logo_{timestamp}.png
  static String storageTemplateLogo(
    String uid,
    String tempId,
    String timestamp,
  ) => '${storageUserDocuments(uid)}/template/$tempId/logo_$timestamp.png';

  /// Company logo: {storageUsers}/{uid}/documents/company_logo/{timestamp}.jpg
  static String storageCompanyLogo(String uid, String timestamp) =>
      '${storageUserDocuments(uid)}/company_logo/$timestamp.jpg';

  /// Extra document: {storageUsers}/{uid}/documents/extraDocument/{timestamp}.{extension}
  static String storageExtraDocument(
    String uid,
    String timestamp,
    String extension,
  ) => '${storageUserDocuments(uid)}/extraDocument/$timestamp.$extension';

  // ============================================
  // Portfolio Storage
  // ============================================

  /// Portfolio root: {storageUsers}/{uid}/documents/portfolio
  static String storagePortfolioRoot(String uid) =>
      '${storageUserDocuments(uid)}/portfolio';

  /// Portfolio image: {storageUsers}/{uid}/documents/portfolio/images/{timestamp}.jpg
  static String storagePortfolioImage(String uid, String timestamp) =>
      '${storagePortfolioRoot(uid)}/images/$timestamp.jpg';

  /// Portfolio video: {storageUsers}/{uid}/documents/portfolio/videos/{timestamp}.mp4
  static String storagePortfolioVideo(String uid, String timestamp) =>
      '${storagePortfolioRoot(uid)}/videos/$timestamp.mp4';

  /// Job video: {storageUsers}/{uid}/documents/portfolio/job_videos/{jobId}_{timestamp}.mp4
  static String storageJobVideo(String uid, String jobId, String timestamp) =>
      '${storagePortfolioRoot(uid)}/job_videos/${jobId}_$timestamp.mp4';

  /// Highlight media: {storageUsers}/{uid}/documents/portfolio/highlights/{timestamp}
  static String storageHighlightMedia(String uid, String timestamp) =>
      '${storagePortfolioRoot(uid)}/highlights/$timestamp';

  // ============================================
  // Legacy Storage Aliases (for backward compatibility)
  // ============================================

  static String userDocuments(String uid) => storageUserDocuments(uid);
  static String passportImage(String uid, String timestamp) =>
      storagePassportImage(uid, timestamp);
  static String idCardFrontImage(String uid, String timestamp) =>
      storageIdCardFrontImage(uid, timestamp);
  static String idCardBackImage(String uid, String timestamp) =>
      storageIdCardBackImage(uid, timestamp);
  static String driverLicenseFrontImage(String uid, String timestamp) =>
      storageDriverLicenseFrontImage(uid, timestamp);
  static String driverLicenseBackImage(String uid, String timestamp) =>
      storageDriverLicenseBackImage(uid, timestamp);
  static String selfieImage(String uid, String timestamp) =>
      storageSelfieImage(uid, timestamp);
  static String profileImage(String uid, String timestamp) =>
      storageProfileImage(uid, timestamp);
  static String templateLogo(String uid, String tempId, String timestamp) =>
      storageTemplateLogo(uid, tempId, timestamp);
  static String extraDocument(String uid, String timestamp, String extension) =>
      storageExtraDocument(uid, timestamp, extension);
  static String companyLogo(String uid, String timestamp) =>
      storageCompanyLogo(uid, timestamp);
  static String portfolioRoot(String uid) => storagePortfolioRoot(uid);
  static String portfolioImage(String uid, String timestamp) =>
      storagePortfolioImage(uid, timestamp);
  static String portfolioVideo(String uid, String timestamp) =>
      storagePortfolioVideo(uid, timestamp);
  static String jobVideo(String uid, String jobId, String timestamp) =>
      storageJobVideo(uid, jobId, timestamp);
  static String highlightMedia(String uid, String timestamp) =>
      storageHighlightMedia(uid, timestamp);

  // ############################################################################
  // #                                                                          #
  // #                     SECTION 2: DATABASE PATHS                            #
  // #                     (Firebase Realtime Database)                         #
  // #                                                                          #
  // ############################################################################

  // ============================================
  // Database Root Collections (Shared across all environments)
  // ============================================

  static const String users = 'users';
  static const String invoices = 'invoices';
  static const String templates = 'templates';
  static const String services = 'services';
  static const String customers = 'customers';
  static const String quotations = 'quotations';
  static const String jobs = 'jobs';
  static const String staff = 'staff';
  static const String notifications = 'notifications';
  static const String devices = 'devices';
  static const String sessions = 'sessions';
  static const String paymentMethods = 'paymentMethods';
  static const String paymentHistory = 'paymentHistory';
  static const String stripeCustomers = 'stripeCustomers';
  static const String addresses = 'addresses';
  static const String usages = 'usages';
  static const String subscriptionsLimits = 'subscriptions';
  static const String config = 'config';
  static const String subscriptions = 'subscriptions';
  static const String properties = 'properties';
  static const String projects = 'projects';

  // ============================================
  // User Database Paths (Root: users/{uid})
  // ============================================

  /// User root: users/{uid}
  static String user(String uid) => '$users/$uid';

  /// User role: users/{uid}/role
  static String userRole(String uid) => '$users/$uid/role';

  /// User verification status: users/{uid}/verificationStatus
  static String userVerificationStatus(String uid) =>
      '$users/$uid/verificationStatus';

  /// User rejection reason: users/{uid}/rejectionReason
  static String userRejectionReason(String uid) =>
      '$users/$uid/rejectionReason';

  /// User subscription: users/{uid}/subscription
  static String userSubscription(String uid) => '$users/$uid/subscription';

  /// User member subscription: users/{uid}/subscription/member
  static String userMemberSubscription(String uid) =>
      '${userSubscription(uid)}/member';

  /// User tool subscription: users/{uid}/subscription/tool
  static String userToolSubscription(String uid) =>
      '${userSubscription(uid)}/tool';

  /// User extra documents metadata: users/{uid}/extraDocuments
  static String userExtraDocuments(String uid) => '$users/$uid/extraDocuments';

  /// Single extra document metadata: users/{uid}/extraDocuments/{documentId}
  static String userExtraDocument(String uid, String documentId) =>
      '${userExtraDocuments(uid)}/$documentId';

  /// User portfolio metadata: users/{uid}/portfolio
  static String userPortfolio(String uid) => '$users/$uid/portfolio';

  /// Portfolio images metadata: users/{uid}/portfolio/images
  static String userPortfolioImages(String uid) =>
      '${userPortfolio(uid)}/images';

  /// Single portfolio image metadata: users/{uid}/portfolio/images/{imageId}
  static String userPortfolioImage(String uid, String imageId) =>
      '${userPortfolioImages(uid)}/$imageId';

  /// Portfolio videos metadata: users/{uid}/portfolio/videos
  static String userPortfolioVideos(String uid) =>
      '${userPortfolio(uid)}/videos';

  /// Single portfolio video metadata: users/{uid}/portfolio/videos/{videoId}
  static String userPortfolioVideo(String uid, String videoId) =>
      '${userPortfolioVideos(uid)}/$videoId';

  /// Job videos metadata: users/{uid}/portfolio/job_videos
  static String userJobVideos(String uid) => '${userPortfolio(uid)}/job_videos';

  /// Single job video metadata: users/{uid}/portfolio/job_videos/{videoId}
  static String userJobVideo(String uid, String videoId) =>
      '${userJobVideos(uid)}/$videoId';

  /// Highlights metadata: users/{uid}/portfolio/highlights
  static String userHighlights(String uid) =>
      '${userPortfolio(uid)}/highlights';

  /// Single highlight metadata: users/{uid}/portfolio/highlights/{highlightId}
  static String userHighlight(String uid, String highlightId) =>
      '${userHighlights(uid)}/$highlightId';

  /// Company details: users/{uid}/companyDetails
  static String userCompanyDetails(String uid) =>
      '$users/$uid/companyDetails';

  /// Notification preferences: users/{uid}/notificationPreferences
  static String userNotificationPreferences(String uid) =>
      '$users/$uid/notificationPreferences';

  // ============================================
  // Invoice Database Paths (Root: invoices/{uid})
  // ============================================

  /// Invoices root: invoices/{uid}
  static String invoicesRoot(String uid) => '$invoices/$uid';

  /// All invoices: invoices/{uid}/invoices
  static String userInvoices(String uid) => '${invoicesRoot(uid)}/invoices';

  /// Single invoice: invoices/{uid}/invoices/{invoiceId}
  static String invoice(String uid, String invoiceId) =>
      '${userInvoices(uid)}/$invoiceId';

  /// Invoice counter: invoices/{uid}/counter
  static String invoiceCounter(String uid) => '${invoicesRoot(uid)}/counter';

  /// Invoice settings: invoices/{uid}/settings
  static String invoiceSettings(String uid) => '${invoicesRoot(uid)}/settings';

  // ============================================
  // Template Database Paths (Root: templates/{uid})
  // ============================================

  /// Templates root: templates/{uid}
  static String templatesRoot(String uid) => '$templates/$uid';

  /// Invoice templates: templates/{uid}/invoiceTemplates
  static String invoiceTemplates(String uid) =>
      '${templatesRoot(uid)}/invoiceTemplates';

  /// Single invoice template: templates/{uid}/invoiceTemplates/{templateId}
  static String invoiceTemplate(String uid, String templateId) =>
      '${invoiceTemplates(uid)}/$templateId';

  /// Quotation templates: templates/{uid}/quotationTemplates
  static String quotationTemplates(String uid) =>
      '${templatesRoot(uid)}/quotationTemplates';

  // ============================================
  // Services Database Paths (Root: services/{uid})
  // ============================================

  /// Services root: services/{uid}
  static String servicesRoot(String uid) => '$services/$uid';

  /// All services: services/{uid}/services
  static String userServices(String uid) => '${servicesRoot(uid)}/services';

  /// Single service: services/{uid}/services/{serviceId}
  static String service(String uid, String serviceId) =>
      '${userServices(uid)}/$serviceId';

  /// All materials: services/{uid}/materials
  static String userMaterials(String uid) => '${servicesRoot(uid)}/materials';

  /// Single material: services/{uid}/materials/{materialId}
  static String material(String uid, String materialId) =>
      '${userMaterials(uid)}/$materialId';

  /// Team member rates: services/{uid}/teamMembers
  static String userTeamMembers(String uid) =>
      '${servicesRoot(uid)}/teamMembers';

  /// Single team member row: services/{uid}/teamMembers/{memberId}
  static String teamMember(String uid, String memberId) =>
      '${userTeamMembers(uid)}/$memberId';

  // ============================================
  // Customers Database Paths (Root: customers/{uid})
  // ============================================

  /// Customers root: customers/{uid}
  static String customersRoot(String uid) => '$customers/$uid';

  /// All customers: customers/{uid}/customers
  static String userCustomers(String uid) => '${customersRoot(uid)}/customers';

  /// Single customer: customers/{uid}/customers/{customerId}
  static String customer(String uid, String customerId) =>
      '${userCustomers(uid)}/$customerId';

  // ============================================
  // Quotation Database Paths (Root: quotations/{uid})
  // ============================================

  /// Quotations root: quotations/{uid}
  static String quotationsRoot(String uid) => '$quotations/$uid';

  /// All quotations: quotations/{uid}/quotations
  static String userQuotations(String uid) =>
      '${quotationsRoot(uid)}/quotations';

  /// Single quotation: quotations/{uid}/quotations/{quotationId}
  static String quotation(String uid, String quotationId) =>
      '${userQuotations(uid)}/$quotationId';

  /// Quotation counter: quotations/{uid}/counter
  static String quotationCounter(String uid) =>
      '${quotationsRoot(uid)}/counter';

  // ============================================
  // Jobs Database Paths (Root: jobs/{uid})
  // Customer's own jobs - user-scoped storage
  // ============================================

  /// Jobs root: jobs/{uid}
  static String jobsRoot(String uid) => '$jobs/$uid';

  /// All jobs: jobs/{uid}/jobs
  static String userJobs(String uid) => '${jobsRoot(uid)}/jobs';

  /// Single job: jobs/{uid}/jobs/{jobId}
  static String job(String uid, String jobId) => '${userJobs(uid)}/$jobId';

  // ============================================
  // Job Pool Database Paths (Root: jobPool/)
  // Flat structure for tradesman job discovery
  // ============================================

  /// Job pool root collection
  static const String jobPool = 'jobPool';

  /// Single job in pool: jobPool/{jobId}
  static String poolJob(String jobId) => '$jobPool/$jobId';

  /// Job pool visibility: jobPool/{jobId}/poolVisible
  static String poolJobVisible(String jobId) => '${poolJob(jobId)}/poolVisible';

  /// Job pool interests: jobPool/{jobId}/interests
  static String poolJobInterests(String jobId) => '${poolJob(jobId)}/interests';

  /// Single interest: jobPool/{jobId}/interests/{odId}
  static String poolJobInterest(String jobId, String odId) =>
      '${poolJobInterests(jobId)}/$odId';

  /// Job pool sent invitations: jobPool/{jobId}/sentTo
  static String poolJobSentTo(String jobId) => '${poolJob(jobId)}/sentTo';

  /// Single sent invitation: jobPool/{jobId}/sentTo/{odId}
  static String poolJobSentToUser(String jobId, String odId) =>
      '${poolJobSentTo(jobId)}/$odId';

  /// Job pool connections: jobPool/{jobId}/connections
  static String poolJobConnections(String jobId) =>
      '${poolJob(jobId)}/connections';

  /// Single connection: jobPool/{jobId}/connections/{odId}
  static String poolJobConnection(String jobId, String odId) =>
      '${poolJobConnections(jobId)}/$odId';

  // ============================================
  // Staff Database Paths (Root: staff/{uid})
  // ============================================

  /// Staff root: staff/{uid}
  static String staffRoot(String uid) => '$staff/$uid';

  /// Staff members: staff/{uid}/members
  static String staffMembers(String uid) => '${staffRoot(uid)}/members';

  /// Single staff member: staff/{uid}/members/{staffId}
  static String staffMember(String uid, String staffId) =>
      '${staffMembers(uid)}/$staffId';

  /// Staff invitations: staff/{uid}/invitations
  static String staffInvitations(String uid) => '${staffRoot(uid)}/invitations';

  /// Single invitation: staff/{uid}/invitations/{invitationId}
  static String staffInvitation(String uid, String invitationId) =>
      '${staffInvitations(uid)}/$invitationId';

  // ============================================
  // Notifications Database Paths (Root: notifications/{uid})
  // ============================================

  /// All notifications: notifications/{uid}
  static String userNotifications(String uid) => '$notifications/$uid';

  /// Single notification: notifications/{uid}/{notificationId}
  static String userNotification(String uid, String notificationId) =>
      '${userNotifications(uid)}/$notificationId';

  // ============================================
  // Devices Database Paths (Root: devices/{uid})
  // ============================================

  /// All devices: devices/{uid}
  static String userDevices(String uid) => '$devices/$uid';

  /// Single device: devices/{uid}/{deviceId}
  static String userDevice(String uid, String deviceId) =>
      '${userDevices(uid)}/$deviceId';

  /// Active device: devices/{uid}/active
  static String userActiveDevice(String uid) => '${userDevices(uid)}/active';

  // ============================================
  // Sessions Database Paths (Root: sessions/{uid})
  // ============================================

  /// All sessions: sessions/{uid}
  static String userSessions(String uid) => '$sessions/$uid';

  /// Single session: sessions/{uid}/{sessionId}
  static String userSession(String uid, String sessionId) =>
      '${userSessions(uid)}/$sessionId';

  /// Active sessions: sessions/{uid}/active
  static String userActiveSessions(String uid) => '${userSessions(uid)}/active';

  /// Session history: sessions/{uid}/history
  static String userSessionHistory(String uid) =>
      '${userSessions(uid)}/history';

  /// Single session history: sessions/{uid}/history/{sessionId}
  static String userSessionHistoryItem(String uid, String sessionId) =>
      '${userSessionHistory(uid)}/$sessionId';

  // ============================================
  // Payment Methods Database Paths (Root: paymentMethods/{uid})
  // ============================================

  /// All payment methods: paymentMethods/{uid}
  static String userPaymentMethods(String uid) => '$paymentMethods/$uid';

  /// Single payment method: paymentMethods/{uid}/{paymentMethodId}
  static String userPaymentMethod(String uid, String paymentMethodId) =>
      '${userPaymentMethods(uid)}/$paymentMethodId';

  // ============================================
  // Payment History Database Paths (Root: paymentHistory/{uid})
  // ============================================

  /// All payment history: paymentHistory/{uid}
  static String userPaymentHistory(String uid) => '$paymentHistory/$uid';

  /// Single payment record: paymentHistory/{uid}/{paymentId}
  static String userPaymentRecord(String uid, String paymentId) =>
      '${userPaymentHistory(uid)}/$paymentId';

  // ============================================
  // Stripe Customers Database Paths (Root: stripeCustomers/{uid})
  // ============================================

  /// Stripe customer: stripeCustomers/{uid}
  static String stripeCustomer(String uid) => '$stripeCustomers/$uid';

  // ============================================
  // Addresses Database Paths (Root: addresses/{uid})
  // ============================================

  /// All addresses: addresses/{uid}/address
  static String userAddresses(String uid) => '$addresses/$uid/address';

  /// Single address: addresses/{uid}/address/{addressId}
  static String userAddress(String uid, String addressId) =>
      '${userAddresses(uid)}/$addressId';

  // ============================================
  // Usage Tracking Database Paths (Root: usages/{uid})
  // ============================================

  /// User usage: usages/{uid}
  static String userUsage(String uid) => '$usages/$uid';

  /// Usage field: usages/{uid}/{field}
  static String userUsageField(String uid, String field) =>
      '${userUsage(uid)}/$field';

  // ============================================
  // Reviews Database Paths (Root: reviews/)
  // Customer reviews for tradesmen
  // ============================================

  static const String reviews = 'reviews';

  /// Reviews root for customer: reviews/{customerId}
  static String reviewsRoot(String uid) => '$reviews/$uid';

  /// All reviews by customer: reviews/{customerId}/reviews
  static String userReviews(String uid) => '${reviewsRoot(uid)}/reviews';

  /// Single review: reviews/{customerId}/reviews/{reviewId}
  static String review(String uid, String reviewId) =>
      '${userReviews(uid)}/$reviewId';

  /// Tradesman received reviews root: reviews/received/{tradesmanId}
  static String tradesmanReviewsRoot(String tradesmanId) =>
      '$reviews/received/$tradesmanId';

  /// All reviews received by tradesman: reviews/received/{tradesmanId}/reviews
  static String tradesmanReceivedReviews(String tradesmanId) =>
      '${tradesmanReviewsRoot(tradesmanId)}/reviews';

  /// Single received review: reviews/received/{tradesmanId}/reviews/{reviewId}
  static String tradesmanReceivedReview(String tradesmanId, String reviewId) =>
      '${tradesmanReceivedReviews(tradesmanId)}/$reviewId';

  /// Tradesman rating summary: reviews/received/{tradesmanId}/summary
  static String tradesmanRatingSummary(String tradesmanId) =>
      '${tradesmanReviewsRoot(tradesmanId)}/summary';

  // ============================================
  // Customer Reviews Database Paths
  // Tradesman reviews for customers
  // ============================================

  /// Customer reviews root: reviews/customers/{customerId}
  static String customerReviewsRoot(String customerId) =>
      '$reviews/customers/$customerId';

  /// All reviews received by customer: reviews/customers/{customerId}/reviews
  static String customerReceivedReviews(String customerId) =>
      '${customerReviewsRoot(customerId)}/reviews';

  /// Single customer review: reviews/customers/{customerId}/reviews/{reviewId}
  static String customerReceivedReview(String customerId, String reviewId) =>
      '${customerReceivedReviews(customerId)}/$reviewId';

  /// Customer rating summary: reviews/customers/{customerId}/summary
  static String customerRatingSummary(String customerId) =>
      '${customerReviewsRoot(customerId)}/summary';

  /// Tradesman's given reviews (to customers): reviews/given/{tradesmanId}
  static String tradesmanGivenReviewsRoot(String tradesmanId) =>
      '$reviews/given/$tradesmanId';

  /// All reviews given by tradesman: reviews/given/{tradesmanId}/reviews
  static String tradesmanGivenReviews(String tradesmanId) =>
      '${tradesmanGivenReviewsRoot(tradesmanId)}/reviews';

  /// Single given review: reviews/given/{tradesmanId}/reviews/{reviewId}
  static String tradesmanGivenReview(String tradesmanId, String reviewId) =>
      '${tradesmanGivenReviews(tradesmanId)}/$reviewId';

  // ============================================
  // Properties Database Paths (Root: properties/{uid})
  // Owner-side property management
  // ============================================

  /// Properties root: properties/{uid}
  static String propertiesRoot(String uid) => '$properties/$uid';

  /// All properties: properties/{uid}/properties
  static String userProperties(String uid) =>
      '${propertiesRoot(uid)}/properties';

  /// Single property: properties/{uid}/properties/{propertyId}
  static String property(String uid, String propertyId) =>
      '${userProperties(uid)}/$propertyId';

  // ============================================
  // Projects Database Paths (Root: projects/{uid})
  // Owner and Tradesman project management
  // ============================================

  /// Projects root: projects/{uid}
  static String projectsRoot(String uid) => '$projects/$uid';

  /// All projects: projects/{uid}/projects
  static String userProjects(String uid) => '${projectsRoot(uid)}/projects';

  /// Single project: projects/{uid}/projects/{projectId}
  static String project(String uid, String projectId) =>
      '${userProjects(uid)}/$projectId';

  // ============================================
  // Config Database Paths (Root: config/)
  // ============================================

  /// Subscription config: config/subscriptions
  static String subscriptionConfig() => '$config/$subscriptions';

  /// Subscription plans: config/subscriptions/{accountType}
  static String subscriptionPlans(String accountType) =>
      '${subscriptionConfig()}/$accountType';

  /// Single subscription plan: config/subscriptions/{accountType}/{planId}
  static String subscriptionPlan(String accountType, String planId) =>
      '${subscriptionPlans(accountType)}/$planId';

  /// Subscription plan limits: config/subscriptions/{accountType}/{planId}/limits
  static String subscriptionPlanLimits(String accountType, String planId) =>
      '${subscriptionPlan(accountType, planId)}/limits';

  /// Image limits config: config/imageLimits
  static String imageLimitsConfig() => '$config/imageLimits';

  /// Commission rates config: config/commissionRates
  static String commissionRatesConfig() => '$config/commissionRates';

  // ============================================
  // Subscriptions Limits Database Paths (Root: subscriptions/)
  // ============================================

  /// Subscriptions limits root
  static String subscriptionsLimitsRoot() => subscriptionsLimits;

  /// Subscriptions by user type: subscriptions/{userType}
  static String subscriptionsByUserType(String userType) =>
      '$subscriptionsLimits/$userType';

  /// Subscription plan data: subscriptions/{userType}/{planId}
  static String subscriptionPlanData(String userType, String planId) =>
      '${subscriptionsByUserType(userType)}/$planId';

  /// Subscription limits: subscriptions/{userType}/{planId}/limits
  static String subscriptionLimits(String userType, String planId) =>
      '${subscriptionPlanData(userType, planId)}/limits';

  // ── Photo Documentation ──────────────────────────────────────────

  /// Photos root: photos/{uid}
  static String userPhotos(String uid) => 'photos/$uid/photos';

  /// Single photo: photos/{uid}/photos/{photoId}
  static String userPhoto(String uid, String photoId) =>
      '${userPhotos(uid)}/$photoId';

  /// Photo collections: photos/{uid}/collections
  static String userPhotoCollections(String uid) =>
      'photos/$uid/collections';

  /// Single collection: photos/{uid}/collections/{collectionId}
  static String userPhotoCollection(String uid, String collectionId) =>
      '${userPhotoCollections(uid)}/$collectionId';

  // ── Trade Qualifications ──────────────────────────────────────────

  /// Trade qualifications root: users/{uid}/tradeQualifications
  static String userTradeQualifications(String uid) =>
      '$users/$uid/tradeQualifications';

  /// Single trade qualification: users/{uid}/tradeQualifications/{reqId}
  static String userTradeQualification(String uid, String reqId) =>
      '${userTradeQualifications(uid)}/$reqId';

  /// Trade qualification storage: {storageUsers}/{uid}/documents/qualifications/{reqId}/{timestamp}.{ext}
  static String storageTradeQualification(
    String uid,
    String reqId,
    String timestamp,
    String ext,
  ) => '${storageUserDocuments(uid)}/qualifications/$reqId/$timestamp.$ext';

  // ── Trade Card ─────────────────────────────────────────────────

  /// Trade card metadata: users/{uid}/tradeCard
  static String userTradeCard(String uid) => '$users/$uid/tradeCard';

  /// Trade card storage: {storageUsers}/{uid}/documents/trade_card/{timestamp}.{ext}
  static String storageTradeCard(String uid, String timestamp, String ext) =>
      '${storageUserDocuments(uid)}/trade_card/$timestamp.$ext';

  // ── Chat Media Storage ─────────────────────────────────────────

  /// Chat media root: {storageUsers}/{uid}/chat_media
  static String storageChatMediaRoot(String uid) =>
      '$storageUsers/$uid/chat_media';

  /// Chat image: {storageUsers}/{uid}/chat_media/images/{jobId}_{timestamp}.jpg
  static String storageChatImage(String uid, String jobId, String timestamp) =>
      '${storageChatMediaRoot(uid)}/images/${jobId}_$timestamp.jpg';

  /// Chat document: {storageUsers}/{uid}/chat_media/documents/{jobId}_{timestamp}.{ext}
  static String storageChatDocument(
    String uid,
    String jobId,
    String timestamp,
    String ext,
  ) => '${storageChatMediaRoot(uid)}/documents/${jobId}_$timestamp.$ext';

  /// Chat video: {storageUsers}/{uid}/chat_media/videos/{jobId}_{timestamp}.mp4
  static String storageChatVideo(String uid, String jobId, String timestamp) =>
      '${storageChatMediaRoot(uid)}/videos/${jobId}_$timestamp.mp4';

  /// Chat thumbnail: {storageUsers}/{uid}/chat_media/thumbnails/{jobId}_{timestamp}.jpg
  static String storageChatThumbnail(
    String uid,
    String jobId,
    String timestamp,
  ) => '${storageChatMediaRoot(uid)}/thumbnails/${jobId}_$timestamp.jpg';

  // ── Floor Plans ──────────────────────────────────────────────────

  /// Floor plans root: floorPlans/{uid}/plans
  static String userFloorPlans(String uid) => 'floorPlans/$uid/plans';

  /// Single floor plan: floorPlans/{uid}/plans/{planId}
  static String userFloorPlan(String uid, String planId) =>
      '${userFloorPlans(uid)}/$planId';
}
