import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/quote_settings_model.dart';
import '../../models/quote_term_model.dart';
import '../../repositories/quotes/quote_settings_repository.dart';
import 'quote_settings_event.dart';
import 'quote_settings_state.dart';

class QuoteSettingsBloc extends Bloc<QuoteSettingsEvent, QuoteSettingsState> {
  QuoteSettingsBloc({required QuoteSettingsRepository repository})
    : _repository = repository,
      super(QuoteSettingsState.initial) {
    on<QuoteSettingsStartWatching>(_onStart);
    on<QuoteSettingsStopWatching>(_onStop);
    on<QuoteSettingsConfigUpdated>(_onConfigUpdated);
    on<QuoteSettingsTermsUpdated>(_onTermsUpdated);
    on<QuoteSettingsSaveRequested>(_onSave);
    on<QuoteSettingsTermDeleteRequested>(_onDeleteTerm);
  }

  final QuoteSettingsRepository _repository;
  StreamSubscription<QuoteSettings>? _configSub;
  StreamSubscription<List<QuoteTerm>>? _termsSub;

  void _onStart(
    QuoteSettingsStartWatching _,
    Emitter<QuoteSettingsState> emit,
  ) {
    _configSub?.cancel();
    _termsSub?.cancel();
    emit(state.copyWith(
      status: QuoteSettingsStatus.loading,
      clearError: true,
    ));
    _configSub = _repository.watchSettings().listen(
      (s) => add(QuoteSettingsConfigUpdated(s)),
      onError: (err) {
        debugPrint('QuoteSettingsBloc config error: $err');
        add(const QuoteSettingsConfigUpdated(QuoteSettings.empty));
      },
    );
    _termsSub = _repository.watchTerms().listen(
      (t) => add(QuoteSettingsTermsUpdated(t)),
      onError: (err) {
        debugPrint('QuoteSettingsBloc terms error: $err');
        add(const QuoteSettingsTermsUpdated(<QuoteTerm>[]));
      },
    );
  }

  void _onStop(
    QuoteSettingsStopWatching _,
    Emitter<QuoteSettingsState> emit,
  ) {
    _configSub?.cancel();
    _termsSub?.cancel();
    _configSub = null;
    _termsSub = null;
    emit(QuoteSettingsState.initial);
  }

  void _onConfigUpdated(
    QuoteSettingsConfigUpdated event,
    Emitter<QuoteSettingsState> emit,
  ) {
    emit(state.copyWith(
      status: QuoteSettingsStatus.loaded,
      settings: event.settings,
      clearError: true,
    ));
  }

  void _onTermsUpdated(
    QuoteSettingsTermsUpdated event,
    Emitter<QuoteSettingsState> emit,
  ) {
    emit(state.copyWith(
      status: QuoteSettingsStatus.loaded,
      terms: event.terms,
      clearError: true,
    ));
  }

  Future<void> _onSave(
    QuoteSettingsSaveRequested event,
    Emitter<QuoteSettingsState> emit,
  ) async {
    emit(state.copyWith(settings: event.settings));
    await _repository.updateSettings(event.settings);
  }

  Future<void> _onDeleteTerm(
    QuoteSettingsTermDeleteRequested event,
    Emitter<QuoteSettingsState> emit,
  ) async {
    emit(state.copyWith(
      terms: state.terms.where((t) => t.id != event.id).toList(),
    ));
    await _repository.deleteTerm(event.id);
  }

  @override
  Future<void> close() {
    _configSub?.cancel();
    _termsSub?.cancel();
    _configSub = null;
    _termsSub = null;
    return super.close();
  }
}
