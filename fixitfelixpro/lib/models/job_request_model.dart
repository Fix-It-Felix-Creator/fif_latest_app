import '../core/enum.dart';

/// Safely cast a value to a String-keyed map.
/// Firebase Realtime Database returns untyped maps which need conversion.
Map<String, dynamic> _castMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

/// Helper function to parse DateTime from various formats (int timestamp or string)
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Helper function to parse DateTime with fallback to now
DateTime _parseDateTimeOrNow(dynamic value) {
  return _parseDateTime(value) ?? DateTime.now();
}

/// Job Request Model — the central data object for the entire job lifecycle.
///
/// ## Current Flow (Customer → Tradesman):
/// 1. Customer creates a job via the app (service type, location, description)
/// 2. Job is saved to user-scoped storage AND the shared job pool
/// 3. Tradesmen browse the pool, express interest, and get matched
/// 4. Once accepted, the job progresses through statuses until completion
///
/// ## Planned Feature (Tradesman → Customer):
/// A 3-step wizard where a tradesman creates a job on behalf of a customer:
///   Step 1 — Select a customer (from tradesman's customer list)
///   Step 2 — Enter a job title (e.g. "Bathroom Repair @ 37 Talbot")
///   Step 3 — Enter an optional job description
/// Then lands on the Job Detail screen with tabs: Overview, Quotes, Balance, Expenses.
///
/// ## Key relationships:
/// - [userId] — the customer who owns/requested the job
/// - [acceptedById] — the tradesman/owner who accepted the job
/// - [assignedStaffId] — staff member delegated by a business owner
/// - [location] — site address (auto-populated from customer in the wizard)
/// - [userDetails] — customer contact info snapshot at time of creation
class JobRequest {
  final String id;
  final String userId;
  final String serviceType;
  final String serviceCategory;
  final List<String> selections;
  final String description;
  final JobLocation location;
  final JobUserDetails userDetails;
  final JobStatus status;
  final JobUrgency urgency;
  final String? preferredDate;
  final String? preferredTime;
  final String? additionalNotes;
  final List<String>? images;
  final double? estimatedBudget;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Scheduled job start date/time (required)
  final DateTime? scheduledDateTime;

  // Acceptance fields
  final String? acceptedById; // Owner/Tradesman who accepted the job
  final String? acceptedByName;
  final DateTime? acceptedAt;

  // Staff assignment fields (for business owners)
  final String? assignedStaffId; // Staff member assigned to this job
  final String? assignedStaffName;
  final String? assignedStaffStatus; // pending, accepted, rejected
  final String? mainTradesmanId; // Main tradesman for payment routing
  final DateTime? assignedAt;
  final DateTime? staffAcceptedAt;

  // Progress tracking fields
  final DateTime? startedAt; // When tradesman started working on the job

  // Quoted amount from invoice shared in chat
  final double? quotedAmount;

  // Payment fields
  final PaymentMethod? paymentMethod;
  final PaymentStatus? paymentStatus;
  final double? finalAmount;
  final DateTime? completedAt;
  final DateTime? paymentConfirmedAt;

  // Review fields
  final String? reviewId;
  final DateTime? reviewedAt;

  // Cancellation fields
  final double? cancellationFee;
  final DateTime? cancelledAt;

  // Visit confirmation fields (both parties must confirm before contact unlock)
  final bool customerConfirmedVisit;
  final bool tradesmanConfirmedVisit;
  final DateTime? visitConfirmedAt;

  // Chat phase tracking
  final ChatPhase chatPhase;

  JobRequest({
    required this.id,
    required this.userId,
    required this.serviceType,
    required this.serviceCategory,
    required this.selections,
    required this.description,
    required this.location,
    required this.userDetails,
    this.status = JobStatus.pending,
    this.urgency = JobUrgency.normal,
    this.preferredDate,
    this.preferredTime,
    this.additionalNotes,
    this.images,
    this.estimatedBudget,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.scheduledDateTime,
    this.acceptedById,
    this.acceptedByName,
    this.acceptedAt,
    this.assignedStaffId,
    this.assignedStaffName,
    this.assignedStaffStatus,
    this.mainTradesmanId,
    this.assignedAt,
    this.staffAcceptedAt,
    this.startedAt,
    this.quotedAmount,
    this.paymentMethod,
    this.paymentStatus,
    this.finalAmount,
    this.completedAt,
    this.paymentConfirmedAt,
    this.reviewId,
    this.reviewedAt,
    this.cancellationFee,
    this.cancelledAt,
    this.customerConfirmedVisit = false,
    this.tradesmanConfirmedVisit = false,
    this.visitConfirmedAt,
    this.chatPhase = ChatPhase.interest,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Check if both customer and tradesman have confirmed the visit
  bool get isBothVisitConfirmed => customerConfirmedVisit && tradesmanConfirmedVisit;

  /// Check if job is already accepted
  bool get isAccepted => acceptedById != null && acceptedById!.isNotEmpty;

  /// Check if job has staff assigned
  bool get hasStaffAssigned =>
      assignedStaffId != null && assignedStaffId!.isNotEmpty;

  /// Check if staff assignment is pending acceptance
  bool get isStaffAssignmentPending => assignedStaffStatus == 'pending';

  /// Check if staff has accepted the assignment
  bool get isStaffAssignmentAccepted => assignedStaffStatus == 'accepted';

  /// Check if staff has rejected the assignment
  bool get isStaffAssignmentRejected => assignedStaffStatus == 'rejected';

  /// Check if staff has started the job
  bool get isStaffJobStarted => assignedStaffStatus == 'startJob';

  /// Check if staff has marked the job as complete
  bool get isStaffJobCompleted => assignedStaffStatus == 'completeJob';

  factory JobRequest.fromJson(Map<String, dynamic> json, String id) {
    return JobRequest(
      id: id,
      userId: json['userId'] ?? '',
      serviceType: json['serviceType'] ?? '',
      serviceCategory: json['serviceCategory'] ?? '',
      selections:
          (json['selections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] ?? '',
      location: JobLocation.fromJson(_castMap(json['location'])),
      userDetails: JobUserDetails.fromJson(_castMap(json['userDetails'])),
      status: JobStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => JobStatus.pending,
      ),
      urgency: JobUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => JobUrgency.normal,
      ),
      preferredDate: json['preferredDate'],
      preferredTime: json['preferredTime'],
      additionalNotes: json['additionalNotes'],
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      estimatedBudget: json['estimatedBudget']?.toDouble(),
      createdAt: _parseDateTimeOrNow(json['createdAt']),
      updatedAt: _parseDateTimeOrNow(json['updatedAt']),
      scheduledDateTime: _parseDateTime(json['scheduledDateTime']),
      acceptedById: json['acceptedById'],
      acceptedByName: json['acceptedByName'],
      acceptedAt: _parseDateTime(json['acceptedAt']),
      assignedStaffId: json['assignedStaffId'],
      assignedStaffName: json['assignedStaffName'],
      assignedStaffStatus: json['assignedStaffStatus'],
      mainTradesmanId: json['mainTradesmanId'],
      assignedAt: _parseDateTime(json['assignedAt']),
      staffAcceptedAt: _parseDateTime(json['staffAcceptedAt']),
      startedAt: _parseDateTime(json['startedAt']),
      quotedAmount: json['quotedAmount']?.toDouble(),
      paymentMethod: json['paymentMethod'] != null
          ? PaymentMethod.values.firstWhere(
              (e) => e.name == json['paymentMethod'],
              orElse: () => PaymentMethod.cash,
            )
          : null,
      paymentStatus: json['paymentStatus'] != null
          ? PaymentStatus.values.firstWhere(
              (e) => e.name == json['paymentStatus'],
              orElse: () => PaymentStatus.pending,
            )
          : null,
      finalAmount: json['finalAmount']?.toDouble(),
      completedAt: _parseDateTime(json['completedAt']),
      paymentConfirmedAt: _parseDateTime(json['paymentConfirmedAt']),
      reviewId: json['reviewId'],
      reviewedAt: _parseDateTime(json['reviewedAt']),
      cancellationFee: json['cancellationFee']?.toDouble(),
      cancelledAt: _parseDateTime(json['cancelledAt']),
      customerConfirmedVisit: json['customerConfirmedVisit'] ?? false,
      tradesmanConfirmedVisit: json['tradesmanConfirmedVisit'] ?? false,
      visitConfirmedAt: _parseDateTime(json['visitConfirmedAt']),
      chatPhase: ChatPhase.values.firstWhere(
        (e) => e.name == json['chatPhase'],
        orElse: () => ChatPhase.interest,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'serviceType': serviceType,
      'serviceCategory': serviceCategory,
      'selections': selections,
      'description': description,
      'location': location.toJson(),
      'userDetails': userDetails.toJson(),
      'status': status.name,
      'urgency': urgency.name,
      'preferredDate': preferredDate,
      'preferredTime': preferredTime,
      'additionalNotes': additionalNotes,
      'images': images,
      'estimatedBudget': estimatedBudget,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'scheduledDateTime': scheduledDateTime?.toIso8601String(),
      'acceptedById': acceptedById,
      'acceptedByName': acceptedByName,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'assignedStaffId': assignedStaffId,
      'assignedStaffName': assignedStaffName,
      'assignedStaffStatus': assignedStaffStatus,
      'mainTradesmanId': mainTradesmanId,
      'assignedAt': assignedAt?.toIso8601String(),
      'staffAcceptedAt': staffAcceptedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'quotedAmount': quotedAmount,
      'paymentMethod': paymentMethod?.name,
      'paymentStatus': paymentStatus?.name,
      'finalAmount': finalAmount,
      'completedAt': completedAt?.toIso8601String(),
      'paymentConfirmedAt': paymentConfirmedAt?.toIso8601String(),
      'reviewId': reviewId,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'cancellationFee': cancellationFee,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'customerConfirmedVisit': customerConfirmedVisit,
      'tradesmanConfirmedVisit': tradesmanConfirmedVisit,
      'visitConfirmedAt': visitConfirmedAt?.toIso8601String(),
      'chatPhase': chatPhase.name,
    };
  }

  JobRequest copyWith({
    String? id,
    String? userId,
    String? serviceType,
    String? serviceCategory,
    List<String>? selections,
    String? description,
    JobLocation? location,
    JobUserDetails? userDetails,
    JobStatus? status,
    JobUrgency? urgency,
    String? preferredDate,
    String? preferredTime,
    String? additionalNotes,
    List<String>? images,
    double? estimatedBudget,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledDateTime,
    String? acceptedById,
    String? acceptedByName,
    DateTime? acceptedAt,
    String? assignedStaffId,
    String? assignedStaffName,
    String? assignedStaffStatus,
    String? mainTradesmanId,
    DateTime? assignedAt,
    DateTime? staffAcceptedAt,
    DateTime? startedAt,
    double? quotedAmount,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    double? finalAmount,
    DateTime? completedAt,
    DateTime? paymentConfirmedAt,
    String? reviewId,
    DateTime? reviewedAt,
    double? cancellationFee,
    DateTime? cancelledAt,
    bool? customerConfirmedVisit,
    bool? tradesmanConfirmedVisit,
    DateTime? visitConfirmedAt,
    ChatPhase? chatPhase,
  }) {
    return JobRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serviceType: serviceType ?? this.serviceType,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      selections: selections ?? this.selections,
      description: description ?? this.description,
      location: location ?? this.location,
      userDetails: userDetails ?? this.userDetails,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTime: preferredTime ?? this.preferredTime,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      images: images ?? this.images,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      acceptedById: acceptedById ?? this.acceptedById,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      assignedStaffStatus: assignedStaffStatus ?? this.assignedStaffStatus,
      mainTradesmanId: mainTradesmanId ?? this.mainTradesmanId,
      assignedAt: assignedAt ?? this.assignedAt,
      staffAcceptedAt: staffAcceptedAt ?? this.staffAcceptedAt,
      startedAt: startedAt ?? this.startedAt,
      quotedAmount: quotedAmount ?? this.quotedAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      finalAmount: finalAmount ?? this.finalAmount,
      completedAt: completedAt ?? this.completedAt,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      reviewId: reviewId ?? this.reviewId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      customerConfirmedVisit: customerConfirmedVisit ?? this.customerConfirmedVisit,
      tradesmanConfirmedVisit: tradesmanConfirmedVisit ?? this.tradesmanConfirmedVisit,
      visitConfirmedAt: visitConfirmedAt ?? this.visitConfirmedAt,
      chatPhase: chatPhase ?? this.chatPhase,
    );
  }

  /// Check if job has been reviewed
  bool get hasReview => reviewId != null && reviewId!.isNotEmpty;
}

/// Job site location — where the work will be performed.
///
/// In the planned tradesman-side wizard, this is auto-populated from the
/// selected customer's address (Step 1). The customer picks a person from
/// their list, and [address], [latitude], [longitude], [city], [postalCode]
/// are copied from that customer's record.
class JobLocation {
  final String address;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? postalCode;

  JobLocation({
    required this.address,
    this.latitude,
    this.longitude,
    this.city,
    this.postalCode,
  });

  factory JobLocation.fromJson(Map<String, dynamic> json) {
    return JobLocation(
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      city: json['city'],
      postalCode: json['postalCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'postalCode': postalCode,
    };
  }
}

/// Snapshot of the customer's contact info at the time the job was created.
///
/// This is denormalized (copied from the customer record) so the job detail
/// screen can display customer name, email, phone, and profile image without
/// an extra database lookup. In the planned tradesman wizard, these fields
/// are filled automatically when the tradesman selects a customer in Step 1.
class JobUserDetails {
  final String name;
  final String email;
  final String phone;
  final String? profileImage;

  JobUserDetails({
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
  });

  factory JobUserDetails.fromJson(Map<String, dynamic> json) {
    return JobUserDetails(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
    };
  }
}

extension JobStatusExtension on JobStatus {
  String get displayName {
    switch (this) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.matching:
        return 'Finding Tradesman';
      case JobStatus.negotiating:
        return 'Negotiating';
      case JobStatus.accepted:
        return 'Accepted';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.pendingPayment:
        return 'Pending Payment';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
    }
  }
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.confirmed:
        return 'Confirmed';
      case PaymentStatus.disputed:
        return 'Disputed';
    }
  }
}

extension JobUrgencyExtension on JobUrgency {
  String get displayName {
    switch (this) {
      case JobUrgency.low:
        return 'Low';
      case JobUrgency.normal:
        return 'Normal';
      case JobUrgency.high:
        return 'High';
      case JobUrgency.emergency:
        return 'Emergency';
    }
  }
}
