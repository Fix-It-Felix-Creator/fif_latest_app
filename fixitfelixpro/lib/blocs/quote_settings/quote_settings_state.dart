import 'package:equatable/equatable.dart';

import '../../models/quote_settings_model.dart';
import '../../models/quote_term_model.dart';

enum QuoteSettingsStatus { initial, loading, loaded, error }

class QuoteSettingsState extends Equatable {
  const QuoteSettingsState({
    this.status = QuoteSettingsStatus.initial,
    this.settings = QuoteSettings.empty,
    this.terms = const [],
    this.errorMessage,
  });

  final QuoteSettingsStatus status;
  final QuoteSettings settings;
  final List<QuoteTerm> terms;
  final String? errorMessage;

  static const initial = QuoteSettingsState();

  QuoteSettingsState copyWith({
    QuoteSettingsStatus? status,
    QuoteSettings? settings,
    List<QuoteTerm>? terms,
    String? errorMessage,
    bool clearError = false,
  }) {
    return QuoteSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      terms: terms ?? this.terms,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, settings, terms, errorMessage];
}
