import 'dart:ui';

class StrokePoint {
  final double x;
  final double y;

  const StrokePoint({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );
}

class DrawingStroke {
  final List<StrokePoint> points;
  final int colorValue;
  final double strokeWidth;
  final bool isEraser;

  const DrawingStroke({
    this.points = const [],
    this.colorValue = 0xFF000000,
    this.strokeWidth = 3.0,
    this.isEraser = false,
  });

  Color get color => Color(colorValue);

  DrawingStroke copyWith({
    List<StrokePoint>? points,
    int? colorValue,
    double? strokeWidth,
    bool? isEraser,
  }) {
    return DrawingStroke(
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
        points: (json['points'] as List?)
                ?.map((p) =>
                    StrokePoint.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList() ??
            [],
        colorValue: json['colorValue'] as int? ?? 0xFF000000,
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
        isEraser: json['isEraser'] as bool? ?? false,
      );
}

class ScratchDrawing {
  final String id;
  final String title;
  final List<DrawingStroke> strokes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScratchDrawing({
    required this.id,
    this.title = '',
    this.strokes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ScratchDrawing copyWith({
    String? id,
    String? title,
    List<DrawingStroke>? strokes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScratchDrawing(
      id: id ?? this.id,
      title: title ?? this.title,
      strokes: strokes ?? this.strokes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScratchDrawing.fromJson(Map<String, dynamic> json) => ScratchDrawing(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        strokes: (json['strokes'] as List?)
                ?.map((s) =>
                    DrawingStroke.fromJson(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
