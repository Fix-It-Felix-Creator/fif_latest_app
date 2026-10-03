import 'package:equatable/equatable.dart';

/// Labour line on a quote or invoice (Firebase: `labourLines` array).
class LabourLine extends Equatable {
  final String memberId;
  final String displayName;
  final double hours;
  final double ratePerHour;

  const LabourLine({
    required this.memberId,
    required this.displayName,
    required this.hours,
    required this.ratePerHour,
  });

  double get lineTotal => hours * ratePerHour;

  factory LabourLine.fromJson(Map<String, dynamic> json) {
    return LabourLine(
      memberId: json['memberId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'memberId': memberId,
        'displayName': displayName,
        'hours': hours,
        'ratePerHour': ratePerHour,
      };

  @override
  List<Object?> get props => [memberId, displayName, hours, ratePerHour];
}
