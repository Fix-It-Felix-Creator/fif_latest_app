import 'package:equatable/equatable.dart';

class BankDetailsModel extends Equatable {
  final String bankName;
  final String accountNumber; // 8 digits, stored as-is
  final String sortCode; // 6 digits, stored without dashes

  const BankDetailsModel({
    this.bankName = '',
    this.accountNumber = '',
    this.sortCode = '',
  });

  bool get isEmpty =>
      bankName.isEmpty && accountNumber.isEmpty && sortCode.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Sort code formatted as `12-34-56`.
  String get sortCodeFormatted {
    final d = sortCode;
    if (d.length != 6) return d;
    return '${d.substring(0, 2)}-${d.substring(2, 4)}-${d.substring(4, 6)}';
  }

  BankDetailsModel copyWith({
    String? bankName,
    String? accountNumber,
    String? sortCode,
  }) {
    return BankDetailsModel(
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      sortCode: sortCode ?? this.sortCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'accountNumber': accountNumber,
    'sortCode': sortCode,
  };

  factory BankDetailsModel.fromJson(Map<String, dynamic> json) {
    return BankDetailsModel(
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      sortCode: (json['sortCode'] as String? ?? '').replaceAll('-', ''),
    );
  }

  @override
  List<Object?> get props => [bankName, accountNumber, sortCode];
}
