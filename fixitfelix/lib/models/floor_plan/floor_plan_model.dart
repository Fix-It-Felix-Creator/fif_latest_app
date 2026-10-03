import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum RoomType {
  bedroom, bathroom, kitchen, livingRoom, diningRoom, hallway, other;

  String get displayName {
    switch (this) {
      case RoomType.bedroom: return 'Bedroom';
      case RoomType.bathroom: return 'Bathroom';
      case RoomType.kitchen: return 'Kitchen';
      case RoomType.livingRoom: return 'Living Room';
      case RoomType.diningRoom: return 'Dining Room';
      case RoomType.hallway: return 'Hallway';
      case RoomType.other: return 'Room';
    }
  }

  Color get color {
    switch (this) {
      case RoomType.bedroom: return const Color(0xFF6366F1);
      case RoomType.bathroom: return const Color(0xFF3B82F6);
      case RoomType.kitchen: return const Color(0xFFF59E0B);
      case RoomType.livingRoom: return const Color(0xFF10B981);
      case RoomType.diningRoom: return const Color(0xFF8B5CF6);
      case RoomType.hallway: return const Color(0xFF94A3B8);
      case RoomType.other: return const Color(0xFF64748B);
    }
  }
}

enum FurnitureType {
  bed, sofa, table, chair, desk, door, window, sink, toilet,
  bathtub, shower, stove, refrigerator;

  String get displayName {
    switch (this) {
      case FurnitureType.bed: return 'Bed';
      case FurnitureType.sofa: return 'Sofa';
      case FurnitureType.table: return 'Table';
      case FurnitureType.chair: return 'Chair';
      case FurnitureType.desk: return 'Desk';
      case FurnitureType.door: return 'Door';
      case FurnitureType.window: return 'Window';
      case FurnitureType.sink: return 'Sink';
      case FurnitureType.toilet: return 'Toilet';
      case FurnitureType.bathtub: return 'Bathtub';
      case FurnitureType.shower: return 'Shower';
      case FurnitureType.stove: return 'Stove';
      case FurnitureType.refrigerator: return 'Fridge';
    }
  }

  Size get defaultSize {
    switch (this) {
      case FurnitureType.bed: return const Size(60, 80);
      case FurnitureType.sofa: return const Size(80, 40);
      case FurnitureType.table: return const Size(60, 60);
      case FurnitureType.chair: return const Size(30, 30);
      case FurnitureType.desk: return const Size(60, 30);
      case FurnitureType.door: return const Size(40, 8);
      case FurnitureType.window: return const Size(40, 6);
      case FurnitureType.sink: return const Size(30, 25);
      case FurnitureType.toilet: return const Size(25, 35);
      case FurnitureType.bathtub: return const Size(70, 35);
      case FurnitureType.shower: return const Size(40, 40);
      case FurnitureType.stove: return const Size(30, 30);
      case FurnitureType.refrigerator: return const Size(30, 35);
    }
  }
}

class RoomElement extends Equatable {
  final String id;
  final RoomType type;
  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int colorValue;

  const RoomElement({
    required this.id,
    this.type = RoomType.other,
    this.label = '',
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.colorValue = 0xFF6366F1,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  RoomElement copyWith({
    String? id,
    RoomType? type,
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? colorValue,
  }) {
    return RoomElement(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'x': x, 'y': y, 'width': width, 'height': height,
    'rotation': rotation,
    'colorValue': colorValue,
  };

  factory RoomElement.fromJson(Map<String, dynamic> json, String id) {
    return RoomElement(
      id: id,
      type: RoomType.values.firstWhere(
          (e) => e.name == json['type'], orElse: () => RoomType.other),
      label: json['label'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      colorValue: json['colorValue'] as int? ?? 0xFF6366F1,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, label, x, y, width, height, rotation, colorValue];
}

class FurnitureElement extends Equatable {
  final String id;
  final FurnitureType type;
  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  const FurnitureElement({
    required this.id,
    required this.type,
    this.label = '',
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  FurnitureElement copyWith({
    String? id,
    FurnitureType? type,
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) {
    return FurnitureElement(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'label': label,
    'x': x, 'y': y, 'width': width, 'height': height,
    'rotation': rotation,
  };

  factory FurnitureElement.fromJson(Map<String, dynamic> json, String id) {
    return FurnitureElement(
      id: id,
      type: FurnitureType.values.firstWhere(
          (e) => e.name == json['type'], orElse: () => FurnitureType.table),
      label: json['label'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, label, x, y, width, height, rotation];
}

class DimensionLabel extends Equatable {
  final String id;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String text;

  const DimensionLabel({
    required this.id,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.text = '',
  });

  Map<String, dynamic> toJson() => {
    'startX': startX, 'startY': startY,
    'endX': endX, 'endY': endY,
    'text': text,
  };

  factory DimensionLabel.fromJson(Map<String, dynamic> json, String id) {
    return DimensionLabel(
      id: id,
      startX: (json['startX'] as num).toDouble(),
      startY: (json['startY'] as num).toDouble(),
      endX: (json['endX'] as num).toDouble(),
      endY: (json['endY'] as num).toDouble(),
      text: json['text'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, startX, startY, endX, endY, text];
}

class FloorPlan extends Equatable {
  final String id;
  final String title;
  final List<RoomElement> rooms;
  final List<FurnitureElement> furniture;
  final List<DimensionLabel> dimensions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloorPlan({
    required this.id,
    required this.title,
    this.rooms = const [],
    this.furniture = const [],
    this.dimensions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  FloorPlan copyWith({
    String? id,
    String? title,
    List<RoomElement>? rooms,
    List<FurnitureElement>? furniture,
    List<DimensionLabel>? dimensions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      rooms: rooms ?? this.rooms,
      furniture: furniture ?? this.furniture,
      dimensions: dimensions ?? this.dimensions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final roomsMap = <String, dynamic>{};
    for (final r in rooms) {
      roomsMap[r.id] = r.toJson();
    }
    final furnitureMap = <String, dynamic>{};
    for (final f in furniture) {
      furnitureMap[f.id] = f.toJson();
    }
    final dimensionsMap = <String, dynamic>{};
    for (final d in dimensions) {
      dimensionsMap[d.id] = d.toJson();
    }

    return {
      'title': title,
      'rooms': roomsMap,
      'furniture': furnitureMap,
      'dimensions': dimensionsMap,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FloorPlan.fromJson(Map<String, dynamic> json, String id) {
    final roomsMap = json['rooms'] as Map? ?? {};
    final furnitureMap = json['furniture'] as Map? ?? {};
    final dimensionsMap = json['dimensions'] as Map? ?? {};

    return FloorPlan(
      id: id,
      title: json['title'] as String? ?? 'Untitled Plan',
      rooms: roomsMap.entries
          .map((e) => RoomElement.fromJson(
              Map<String, dynamic>.from(e.value as Map), e.key))
          .toList(),
      furniture: furnitureMap.entries
          .map((e) => FurnitureElement.fromJson(
              Map<String, dynamic>.from(e.value as Map), e.key))
          .toList(),
      dimensions: dimensionsMap.entries
          .map((e) => DimensionLabel.fromJson(
              Map<String, dynamic>.from(e.value as Map), e.key))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, rooms, furniture, dimensions, createdAt, updatedAt];
}
