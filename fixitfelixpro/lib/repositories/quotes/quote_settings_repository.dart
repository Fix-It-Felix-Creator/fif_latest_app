import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/cache_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/quote_settings_model.dart';
import '../../models/quote_term_model.dart';
import '../base/owned_collection_repository.dart';

/// Reusable Terms & Conditions templates.
///
/// Was `/quoteTerms/{uid}/{termId}`; now the `term_library` table. Named
/// `term_library` rather than `quote_terms` because `quote_terms` holds the
/// terms attached to one specific quote — these are the saved templates those
/// are copied from.
class _TermStore extends OwnedCollectionRepository<QuoteTerm> {
  @override
  String get table => 'term_library';

  @override
  String get cacheBox => CacheBoxes.settings;

  @override
  String idOf(QuoteTerm t) => t.id;

  @override
  int compare(QuoteTerm a, QuoteTerm b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  Map<String, dynamic> toRow(QuoteTerm t) => {
        if (t.id.isNotEmpty) 'id': t.id,
        'name': t.name,
        'details': t.details,
      };

  @override
  QuoteTerm fromRow(Map<String, dynamic> row) => QuoteTerm(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        details: row['details']?.toString() ?? '',
        createdAt: OwnedCollectionRepository.parseTsOr(
            row['created_at'], DateTime.now()),
        updatedAt: OwnedCollectionRepository.parseTsOr(
            row['updated_at'], DateTime.now()),
      );
}

/// Per-user quote & invoice settings plus reusable Terms & Conditions
/// templates.
///
/// Postgres layout:
///   quote_settings  — one row per user, keyed by owner_id
///   term_library    — the saved T&C templates
class QuoteSettingsRepository {
  final _TermStore _terms = _TermStore();

  String? get _uid => SupabaseService().auth.currentUser?.id;

  Stream<QuoteSettings> watchSettings() {
    final uid = _uid;
    if (uid == null) return Stream.value(QuoteSettings.empty);
    return SupabaseService()
        .client
        .from('quote_settings')
        .stream(primaryKey: const ['owner_id'])
        .eq('owner_id', uid)
        .map((rows) {
          // No row yet simply means the user has never opened settings.
          if (rows.isEmpty) return QuoteSettings.empty;
          final r = rows.first;
          return QuoteSettings(
            autoGenerateNumber: r['auto_generate_number'] as bool? ?? true,
            prefix: r['prefix']?.toString() ?? '',
          );
        })
        .handleError((Object e) {
          debugPrint('QuoteSettingsRepository.watchSettings error: $e');
        });
  }

  Future<bool> updateSettings(QuoteSettings s) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // upsert, because the row is created lazily on first save — there is no
      // trigger seeding one at signup.
      await SupabaseService().client.from('quote_settings').upsert({
        'owner_id': uid,
        'auto_generate_number': s.autoGenerateNumber,
        'prefix': s.prefix,
      }, onConflict: 'owner_id');
      return true;
    } catch (e) {
      debugPrint('QuoteSettingsRepository.updateSettings failed: $e');
      return false;
    }
  }

  Stream<List<QuoteTerm>> watchTerms() => _terms.watchAll();

  Future<String?> createTerm(QuoteTerm t) => _terms.create(t);

  Future<bool> updateTerm(QuoteTerm t) => _terms.update(t);

  Future<bool> deleteTerm(String id) => _terms.delete(id);
}
