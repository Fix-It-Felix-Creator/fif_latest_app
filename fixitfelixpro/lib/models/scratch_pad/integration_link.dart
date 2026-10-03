enum IntegrationType {
  calendar,
  email,
  maps,
  phone,
  custom,
}

class IntegrationLink {
  final String id;
  final String title;
  final String subtitle;
  final IntegrationType type;
  final String url;
  final int colorValue;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IntegrationLink({
    required this.id,
    this.title = '',
    this.subtitle = '',
    this.type = IntegrationType.custom,
    this.url = '',
    this.colorValue = 0xFF8B5CF6,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool matchesSearch(String query) {
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        subtitle.toLowerCase().contains(lower) ||
        type.name.toLowerCase().contains(lower);
  }

  IntegrationLink copyWith({
    String? id,
    String? title,
    String? subtitle,
    IntegrationType? type,
    String? url,
    int? colorValue,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IntegrationLink(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      url: url ?? this.url,
      colorValue: colorValue ?? this.colorValue,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type.name,
        'url': url,
        'colorValue': colorValue,
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IntegrationLink.fromJson(Map<String, dynamic> json) =>
      IntegrationLink(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        type: IntegrationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => IntegrationType.custom,
        ),
        url: json['url'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF8B5CF6,
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
