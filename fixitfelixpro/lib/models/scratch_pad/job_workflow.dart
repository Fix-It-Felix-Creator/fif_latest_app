class WorkflowStep {
  final String id;
  final String text;
  final bool isCompleted;
  final String note;
  final int order;

  const WorkflowStep({
    required this.id,
    this.text = '',
    this.isCompleted = false,
    this.note = '',
    this.order = 0,
  });

  WorkflowStep copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    String? note,
    int? order,
  }) {
    return WorkflowStep(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isCompleted': isCompleted,
        'note': note,
        'order': order,
      };

  factory WorkflowStep.fromJson(Map<String, dynamic> json) => WorkflowStep(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        note: json['note'] as String? ?? '',
        order: json['order'] as int? ?? 0,
      );
}

class JobWorkflow {
  final String id;
  final String title;
  final String jobType;
  final String description;
  final List<WorkflowStep> steps;
  final List<String> tags;
  final bool isPinned;
  final String? linkedJobId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobWorkflow({
    required this.id,
    this.title = '',
    this.jobType = '',
    this.description = '',
    this.steps = const [],
    this.tags = const [],
    this.isPinned = false,
    this.linkedJobId,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalSteps => steps.length;
  int get completedSteps => steps.where((s) => s.isCompleted).length;
  double get progress => totalSteps == 0 ? 0 : completedSteps / totalSteps;

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        jobType.toLowerCase().contains(lower) ||
        description.toLowerCase().contains(lower) ||
        steps.any((s) => s.text.toLowerCase().contains(lower)) ||
        tags.any((t) => t.toLowerCase().contains(lower));
  }

  JobWorkflow copyWith({
    String? id,
    String? title,
    String? jobType,
    String? description,
    List<WorkflowStep>? steps,
    List<String>? tags,
    bool? isPinned,
    String? linkedJobId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobWorkflow(
      id: id ?? this.id,
      title: title ?? this.title,
      jobType: jobType ?? this.jobType,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      linkedJobId: linkedJobId ?? this.linkedJobId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'jobType': jobType,
        'description': description,
        'steps': steps.map((s) => s.toJson()).toList(),
        'tags': tags,
        'isPinned': isPinned,
        'linkedJobId': linkedJobId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JobWorkflow.fromJson(Map<String, dynamic> json) => JobWorkflow(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        jobType: json['jobType'] as String? ?? '',
        description: json['description'] as String? ?? '',
        steps: (json['steps'] as List?)
                ?.map((s) =>
                    WorkflowStep.fromJson(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        isPinned: json['isPinned'] as bool? ?? false,
        linkedJobId: json['linkedJobId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
