class License {
  final String title;
  final String text;

  const License({required this.title, required this.text});

  factory License.fromJson(Map<String, dynamic> json) {
    return License(title: json['title'] ?? '', text: json['text'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'text': text};
  }
}
