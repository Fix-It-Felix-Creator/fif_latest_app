enum TemplateCategory {
  quote,
  jobDescription,
  checklist,
  communication,
  other,
}

class ScratchTemplate {
  final String id;
  final String title;
  final String content;
  final TemplateCategory category;
  final List<String> placeholders;
  final bool isBuiltIn;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScratchTemplate({
    required this.id,
    this.title = '',
    this.content = '',
    this.category = TemplateCategory.other,
    this.placeholders = const [],
    this.isBuiltIn = false,
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        content.toLowerCase().contains(lower) ||
        category.name.toLowerCase().contains(lower);
  }

  ScratchTemplate copyWith({
    String? id,
    String? title,
    String? content,
    TemplateCategory? category,
    List<String>? placeholders,
    bool? isBuiltIn,
    int? useCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScratchTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      placeholders: placeholders ?? this.placeholders,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category.name,
        'placeholders': placeholders,
        'isBuiltIn': isBuiltIn,
        'useCount': useCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScratchTemplate.fromJson(Map<String, dynamic> json) =>
      ScratchTemplate(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        category: TemplateCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => TemplateCategory.other,
        ),
        placeholders: (json['placeholders'] as List?)?.cast<String>() ?? [],
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        useCount: json['useCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
