import 'package:flutter/material.dart';

import 'notification_model.dart';

/// Notification categories for grouping and handling
enum NotificationCategory {
  /// Job-related notifications (offers, updates, completion)
  job,

  /// Chat/message notifications
  chat,

  /// Staff/team notifications
  staff,

  /// Payment/subscription notifications
  payment,

  /// System notifications (general, verification)
  system,
}

/// Navigation action types for notifications
enum NotificationAction {
  /// Open job offers tab (tradesman)
  openJobOffers,

  /// Open job details
  openJobDetails,

  /// Open chat screen
  openChat,

  /// Open staff/team screen
  openStaff,

  /// Open customer jobs tab
  openCustomerJobs,

  /// Open subscription screen
  openSubscription,

  /// Open notifications list
  openNotifications,

  /// No action (just dismiss)
  none,
}

/// Configuration for a notification category
class NotificationCategoryConfig {
  final NotificationCategory category;
  final NotificationAction action;
  final String? route;
  final Map<String, dynamic>? routeArguments;
  final IconData icon;
  final Color color;

  const NotificationCategoryConfig({
    required this.category,
    required this.action,
    this.route,
    this.routeArguments,
    required this.icon,
    required this.color,
  });
}

/// Helper class for notification categorization and actions
class NotificationCategoryHelper {
  /// Get category for a notification type
  static NotificationCategory getCategory(NotificationType type) {
    switch (type) {
      // Job category
      case NotificationType.jobOffer:
      case NotificationType.jobOfferAccepted:
      case NotificationType.jobOfferDeclined:
      case NotificationType.tradesmanInterested:
      case NotificationType.interestAccepted:
      case NotificationType.jobAccepted:
      case NotificationType.jobStarted:
      case NotificationType.jobCompleted:
      case NotificationType.jobUpdate:
        return NotificationCategory.job;

      // Chat category
      case NotificationType.newMessage:
        return NotificationCategory.chat;

      // Staff category
      case NotificationType.staffInvitation:
      case NotificationType.staffInvitationSent:
      case NotificationType.staffInvitationResponse:
      case NotificationType.staffJobAssignment:
      case NotificationType.staffJobAssignmentAccepted:
      case NotificationType.staffJobAssignmentRejected:
      case NotificationType.staffJobCompleted:
        return NotificationCategory.staff;

      // Payment category
      case NotificationType.subscriptionUpdate:
      case NotificationType.paymentSuccess:
      case NotificationType.paymentFailed:
      case NotificationType.subscriptionRenewal:
      case NotificationType.subscriptionExpiring:
        return NotificationCategory.payment;

      // System category
      case NotificationType.general:
        return NotificationCategory.system;
    }
  }

  /// Get navigation action for a notification type
  static NotificationAction getAction(NotificationType type) {
    switch (type) {
      // Job offer notifications -> Open offers tab
      case NotificationType.jobOffer:
        return NotificationAction.openJobOffers;

      // Job acceptance notifications -> Open job details or chat
      case NotificationType.jobOfferAccepted:
      case NotificationType.interestAccepted:
        return NotificationAction.openChat;

      // Job declined -> Open job details
      case NotificationType.jobOfferDeclined:
        return NotificationAction.openJobDetails;

      // Tradesman interested -> Open notifications (customer app removed)
      case NotificationType.tradesmanInterested:
        return NotificationAction.openNotifications;

      // Job status updates -> Open job details
      case NotificationType.jobAccepted:
      case NotificationType.jobStarted:
      case NotificationType.jobCompleted:
      case NotificationType.jobUpdate:
        return NotificationAction.openJobDetails;

      // Chat notifications -> Open chat
      case NotificationType.newMessage:
        return NotificationAction.openChat;

      // Staff notifications -> Open staff screen
      case NotificationType.staffInvitation:
      case NotificationType.staffInvitationSent:
      case NotificationType.staffInvitationResponse:
        return NotificationAction.openStaff;

      // Staff job assignment notifications -> Open job details
      case NotificationType.staffJobAssignment:
      case NotificationType.staffJobAssignmentAccepted:
      case NotificationType.staffJobAssignmentRejected:
      case NotificationType.staffJobCompleted:
        return NotificationAction.openJobDetails;

      // Payment notifications -> Open subscription or job details
      case NotificationType.subscriptionUpdate:
      case NotificationType.subscriptionRenewal:
      case NotificationType.subscriptionExpiring:
        return NotificationAction.openSubscription;

      // Job payment notifications -> Open job details
      case NotificationType.paymentSuccess:
      case NotificationType.paymentFailed:
        return NotificationAction.openJobDetails;

      // System notifications -> Open notifications list
      case NotificationType.general:
        return NotificationAction.openNotifications;
    }
  }

  /// Get category config with icon and color
  static NotificationCategoryConfig getConfig(NotificationType type) {
    final category = getCategory(type);
    final action = getAction(type);

    switch (category) {
      case NotificationCategory.job:
        return NotificationCategoryConfig(
          category: category,
          action: action,
          icon: Icons.work_outline,
          color: const Color(0xFF3B82F6), // Blue
        );

      case NotificationCategory.chat:
        return NotificationCategoryConfig(
          category: category,
          action: action,
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF10B981), // Green
        );

      case NotificationCategory.staff:
        return NotificationCategoryConfig(
          category: category,
          action: action,
          icon: Icons.people_outline,
          color: const Color(0xFF8B5CF6), // Purple
        );

      case NotificationCategory.payment:
        return NotificationCategoryConfig(
          category: category,
          action: action,
          icon: Icons.payment_outlined,
          color: const Color(0xFFF59E0B), // Amber
        );

      case NotificationCategory.system:
        return NotificationCategoryConfig(
          category: category,
          action: action,
          icon: Icons.notifications_outlined,
          color: const Color(0xFF6B7280), // Gray
        );
    }
  }

  /// Check if notification should show local notification
  static bool shouldShowLocalNotification(NotificationType type) {
    switch (type) {
      case NotificationType.jobOffer:
      case NotificationType.jobOfferAccepted:
      case NotificationType.jobOfferDeclined:
      case NotificationType.tradesmanInterested:
      case NotificationType.interestAccepted:
      case NotificationType.newMessage:
      case NotificationType.staffInvitation:
      case NotificationType.staffInvitationResponse:
      case NotificationType.paymentSuccess:
      case NotificationType.paymentFailed:
      case NotificationType.subscriptionExpiring:
        return true;
      default:
        return false;
    }
  }

  /// Get route and arguments for navigation action
  static ({String? route, Map<String, dynamic>? args}) getRouteForAction(
    NotificationAction action,
    Map<String, dynamic>? notificationData,
  ) {
    switch (action) {
      case NotificationAction.openJobOffers:
        return (
          route: '/tradesmanHome',
          args: {
            'tabIndex': 1, // Jobs tab
            'jobsTabIndex': 3, // Offers inner tab
          },
        );

      case NotificationAction.openJobDetails:
        final jobId = notificationData?['jobId'] as String?;
        return (route: '/jobDetails', args: {'jobId': jobId});

      case NotificationAction.openChat:
        final jobId = notificationData?['jobId'] as String?;
        final recipientId =
            notificationData?['senderId'] as String? ??
            notificationData?['tradesmanId'] as String? ??
            notificationData?['customerId'] as String?;
        return (
          route: '/chat',
          args: {'jobId': jobId, 'recipientId': recipientId},
        );

      case NotificationAction.openCustomerJobs:
        // Customer app removed — redirect to notifications
        return (route: '/notifications', args: null);

      case NotificationAction.openStaff:
        return (route: '/staff', args: null);

      case NotificationAction.openSubscription:
        return (route: '/subscription', args: null);

      case NotificationAction.openNotifications:
        return (route: '/notifications', args: null);

      case NotificationAction.none:
        return (route: null, args: null);
    }
  }
}
