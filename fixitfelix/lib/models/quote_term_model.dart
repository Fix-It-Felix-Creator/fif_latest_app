import 'package:equatable/equatable.dart';

class QuoteTerm extends Equatable {
  final String id;
  final String name;
  final String details;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuoteTerm({
    required this.id,
    required this.name,
    this.details = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  QuoteTerm copyWith({
    String? id,
    String? name,
    String? details,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuoteTerm(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, details, createdAt, updatedAt];
}
