import 'package:equatable/equatable.dart';

import '../../models/quote_settings_model.dart';
import '../../models/quote_term_model.dart';

abstract class QuoteSettingsEvent extends Equatable {
  const QuoteSettingsEvent();

  @override
  List<Object?> get props => const [];
}

class QuoteSettingsStartWatching extends QuoteSettingsEvent {
  const QuoteSettingsStartWatching();
}

class QuoteSettingsStopWatching extends QuoteSettingsEvent {
  const QuoteSettingsStopWatching();
}

class QuoteSettingsConfigUpdated extends QuoteSettingsEvent {
  const QuoteSettingsConfigUpdated(this.settings);
  final QuoteSettings settings;

  @override
  List<Object?> get props => [settings];
}

class QuoteSettingsTermsUpdated extends QuoteSettingsEvent {
  const QuoteSettingsTermsUpdated(this.terms);
  final List<QuoteTerm> terms;

  @override
  List<Object?> get props => [terms];
}

class QuoteSettingsSaveRequested extends QuoteSettingsEvent {
  const QuoteSettingsSaveRequested(this.settings);
  final QuoteSettings settings;

  @override
  List<Object?> get props => [settings];
}

class QuoteSettingsTermDeleteRequested extends QuoteSettingsEvent {
  const QuoteSettingsTermDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
