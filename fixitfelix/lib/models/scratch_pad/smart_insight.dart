enum InsightType {
  tip,
  summary,
  suggestion,
  alert,
}

class SmartInsight {
  final String id;
  final String title;
  final String content;
  final InsightType type;
  final String? actionLabel;
  final bool isDismissed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmartInsight({
    required this.id,
    this.title = '',
    this.content = '',
    this.type = InsightType.tip,
    this.actionLabel,
    this.isDismissed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        content.toLowerCase().contains(lower) ||
        type.name.toLowerCase().contains(lower);
  }

  SmartInsight copyWith({
    String? id,
    String? title,
    String? content,
    InsightType? type,
    String? actionLabel,
    bool? isDismissed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      actionLabel: actionLabel ?? this.actionLabel,
      isDismissed: isDismissed ?? this.isDismissed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'actionLabel': actionLabel,
        'isDismissed': isDismissed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SmartInsight.fromJson(Map<String, dynamic> json) => SmartInsight(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: InsightType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => InsightType.tip,
        ),
        actionLabel: json['actionLabel'] as String?,
        isDismissed: json['isDismissed'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
