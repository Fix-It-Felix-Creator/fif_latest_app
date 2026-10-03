enum FollowUpStatus {
  pending,
  done,
  overdue,
  snoozed,
}

enum FollowUpPriority {
  low,
  medium,
  high,
}

class FollowUp {
  final String id;
  final String title;
  final String description;
  final FollowUpStatus status;
  final FollowUpPriority priority;
  final DateTime? dueDate;
  final String clientName;
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FollowUp({
    required this.id,
    this.title = '',
    this.description = '',
    this.status = FollowUpStatus.pending,
    this.priority = FollowUpPriority.medium,
    this.dueDate,
    this.clientName = '',
    this.isRecurring = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOverdue =>
      status == FollowUpStatus.pending &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        description.toLowerCase().contains(lower) ||
        clientName.toLowerCase().contains(lower);
  }

  FollowUp copyWith({
    String? id,
    String? title,
    String? description,
    FollowUpStatus? status,
    FollowUpPriority? priority,
    DateTime? dueDate,
    String? clientName,
    bool? isRecurring,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FollowUp(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      clientName: clientName ?? this.clientName,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.name,
        'priority': priority.name,
        'dueDate': dueDate?.toIso8601String(),
        'clientName': clientName,
        'isRecurring': isRecurring,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FollowUp.fromJson(Map<String, dynamic> json) => FollowUp(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: FollowUpStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => FollowUpStatus.pending,
        ),
        priority: FollowUpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => FollowUpPriority.medium,
        ),
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        clientName: json['clientName'] as String? ?? '',
        isRecurring: json['isRecurring'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
