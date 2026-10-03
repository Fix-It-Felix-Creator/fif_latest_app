import 'package:equatable/equatable.dart';

class QuoteSettings extends Equatable {
  const QuoteSettings({
    this.autoGenerateNumber = true,
    this.prefix = '',
  });

  final bool autoGenerateNumber;
  final String prefix;

  static const empty = QuoteSettings();

  QuoteSettings copyWith({bool? autoGenerateNumber, String? prefix}) {
    return QuoteSettings(
      autoGenerateNumber: autoGenerateNumber ?? this.autoGenerateNumber,
      prefix: prefix ?? this.prefix,
    );
  }

  Map<String, dynamic> toRtdb() => {
    'autoGenerateNumber': autoGenerateNumber,
    'prefix': prefix,
  };

  factory QuoteSettings.fromRtdb(Map<dynamic, dynamic>? raw) {
    if (raw == null) return QuoteSettings.empty;
    return QuoteSettings(
      autoGenerateNumber: raw['autoGenerateNumber'] == true,
      prefix: raw['prefix']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [autoGenerateNumber, prefix];
}
