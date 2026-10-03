import 'package:equatable/equatable.dart';

enum ProjectStatus { planning, inProgress, onHold, completed, cancelled }

class ProjectModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? customerId;
  final String? customerName;
  final String? propertyId;
  final String? propertyName;
  final ProjectStatus status;
  final double progress;
  final int totalTasks;
  final int completedTasks;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    this.customerId,
    this.customerName,
    this.propertyId,
    this.propertyName,
    this.status = ProjectStatus.planning,
    this.progress = 0.0,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? customerId,
    String? customerName,
    String? propertyId,
    String? propertyName,
    ProjectStatus? status,
    double? progress,
    int? totalTasks,
    int? completedTasks,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      propertyId: propertyId ?? this.propertyId,
      propertyName: propertyName ?? this.propertyName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'customerId': customerId,
      'customerName': customerName,
      'propertyId': propertyId,
      'propertyName': propertyName,
      'status': status.name,
      'progress': progress,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json, String id) {
    return ProjectModel(
      id: id,
      name: json['name'] ?? '',
      description: json['description'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      propertyId: json['propertyId'],
      propertyName: json['propertyName'],
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProjectStatus.planning,
      ),
      progress: (json['progress'] ?? 0.0).toDouble(),
      totalTasks: json['totalTasks'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory ProjectModel.empty() {
    final now = DateTime.now();
    return ProjectModel(id: '', name: '', createdAt: now, updatedAt: now);
  }

  String get statusDisplayName {
    switch (status) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != ProjectStatus.completed &&
      status != ProjectStatus.cancelled;

  int get daysLeft =>
      dueDate != null ? dueDate!.difference(DateTime.now()).inDays : 0;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    customerId,
    customerName,
    propertyId,
    propertyName,
    status,
    progress,
    totalTasks,
    completedTasks,
    dueDate,
    createdAt,
    updatedAt,
  ];
}
