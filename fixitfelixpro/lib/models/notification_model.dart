import 'package:equatable/equatable.dart';

/// Types of notifications
enum NotificationType {
  staffInvitation,
  staffInvitationSent,
  staffInvitationResponse,
  jobAccepted,
  jobStarted,
  jobCompleted,
  jobUpdate,
  jobOffer, // Customer sent job to tradesman
  jobOfferAccepted, // Tradesman accepted job offer
  jobOfferDeclined, // Tradesman declined job offer
  tradesmanInterested, // Tradesman expressed interest in job
  interestAccepted, // Customer accepted tradesman interest
  newMessage, // New chat message
  subscriptionUpdate,
  paymentSuccess,
  paymentFailed,
  subscriptionRenewal,
  subscriptionExpiring,
  staffJobAssignment, // Owner assigned staff to a job
  staffJobAssignmentAccepted, // Staff accepted job assignment
  staffJobAssignmentRejected, // Staff rejected job assignment
  staffJobCompleted, // Staff completed assigned job - owner should collect payment
  general,
}

/// Status of notification
enum NotificationStatus { unread, read, actioned }

/// Notification model for in-app notifications
class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationStatus status;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.status = NotificationStatus.unread,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  bool get isUnread => status == NotificationStatus.unread;
  bool get isRead => status == NotificationStatus.read;
  bool get isActioned => status == NotificationStatus.actioned;

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    NotificationStatus? status,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'data': data,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      status: NotificationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NotificationStatus.unread,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    title,
    message,
    status,
    createdAt,
    readAt,
    data,
  ];
}
