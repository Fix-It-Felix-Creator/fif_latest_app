import 'package:equatable/equatable.dart';

/// Payroll-style rate card for a team member (price list tab).
/// Stored at `services/{uid}/teamMembers/{id}` in Realtime Database.
class TeamMemberRateModel extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String email;
  /// e.g. Hour, Day, Job
  final String defaultPayType;
  final double rate;
  final double unitMarkup;

  const TeamMemberRateModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.defaultPayType = 'Hour',
    this.rate = 0,
    this.unitMarkup = 0,
  });

  double get totalRate => rate + unitMarkup;

  factory TeamMemberRateModel.fromJson(Map<String, dynamic> json, String id) {
    return TeamMemberRateModel(
      id: id,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      defaultPayType: json['defaultPayType'] as String? ?? 'Hour',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      unitMarkup: (json['unitMarkup'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'defaultPayType': defaultPayType,
      'rate': rate,
      'unitMarkup': unitMarkup,
    };
  }

  TeamMemberRateModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? defaultPayType,
    double? rate,
    double? unitMarkup,
  }) {
    return TeamMemberRateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      defaultPayType: defaultPayType ?? this.defaultPayType,
      rate: rate ?? this.rate,
      unitMarkup: unitMarkup ?? this.unitMarkup,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    defaultPayType,
    rate,
    unitMarkup,
  ];
}
