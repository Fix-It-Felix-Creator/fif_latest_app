class ChecklistItem {
  final String id;
  final String text;
  final bool isChecked;

  const ChecklistItem({
    required this.id,
    this.text = '',
    this.isChecked = false,
  });

  ChecklistItem copyWith({String? id, String? text, bool? isChecked}) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isChecked': isChecked,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        isChecked: json['isChecked'] as bool? ?? false,
      );
}

class ScratchChecklist {
  final String id;
  final String title;
  final List<ChecklistItem> items;
  final List<String> tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScratchChecklist({
    required this.id,
    this.title = '',
    this.items = const [],
    this.tags = const [],
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalItems => items.length;
  int get checkedItems => items.where((i) => i.isChecked).length;
  double get progress => totalItems == 0 ? 0 : checkedItems / totalItems;

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        items.any((i) => i.text.toLowerCase().contains(lower)) ||
        tags.any((t) => t.toLowerCase().contains(lower));
  }

  ScratchChecklist copyWith({
    String? id,
    String? title,
    List<ChecklistItem>? items,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScratchChecklist(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((i) => i.toJson()).toList(),
        'tags': tags,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScratchChecklist.fromJson(Map<String, dynamic> json) =>
      ScratchChecklist(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        items: (json['items'] as List?)
                ?.map((i) =>
                    ChecklistItem.fromJson(Map<String, dynamic>.from(i as Map)))
                .toList() ??
            [],
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
