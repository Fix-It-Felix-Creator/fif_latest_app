enum HandoffType {
  techToTech,
  techToClient,
  jobSummary,
}

class HandoffDoc {
  final String id;
  final String title;
  final String content;
  final HandoffType type;
  final String? jobId;
  final String recipientName;
  final List<String> attachmentIds;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HandoffDoc({
    required this.id,
    this.title = '',
    this.content = '',
    this.type = HandoffType.jobSummary,
    this.jobId,
    this.recipientName = '',
    this.attachmentIds = const [],
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        content.toLowerCase().contains(lower) ||
        recipientName.toLowerCase().contains(lower) ||
        type.name.toLowerCase().contains(lower);
  }

  HandoffDoc copyWith({
    String? id,
    String? title,
    String? content,
    HandoffType? type,
    String? jobId,
    String? recipientName,
    List<String>? attachmentIds,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HandoffDoc(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      jobId: jobId ?? this.jobId,
      recipientName: recipientName ?? this.recipientName,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'jobId': jobId,
        'recipientName': recipientName,
        'attachmentIds': attachmentIds,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HandoffDoc.fromJson(Map<String, dynamic> json) => HandoffDoc(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: HandoffType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => HandoffType.jobSummary,
        ),
        jobId: json['jobId'] as String?,
        recipientName: json['recipientName'] as String? ?? '',
        attachmentIds:
            (json['attachmentIds'] as List?)?.cast<String>() ?? [],
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
