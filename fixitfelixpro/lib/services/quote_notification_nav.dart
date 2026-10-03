import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/quotes/quotes_bloc.dart';
import '../core/utils/common_toasts.dart';
import '../globals.dart';
import '../models/quote_model.dart';
import '../repositories/quotes/quotes_repository.dart';
import '../screens/quotes/new_quote_screen.dart';

/// Quote-related notification types fanned out by the Cloud Functions
/// (see `viewSharedQuote.ts` / `respondToShare.ts`).
const _quoteNotificationTypes = {'quote_opened', 'quote_responded'};

bool isQuoteNotificationType(String? type) =>
    type != null && _quoteNotificationTypes.contains(type.toLowerCase());

/// Resolves the quote referenced by a notification payload and opens
/// its details screen. If the quote no longer exists (deleted, perms,
/// or just missing payload), no navigation happens — instead a brief
/// toast tells the user, and they stay where they were. We don't
/// fall back to the list because tapping a notification for a deleted
/// quote and ending up somewhere unrelated is more disorienting than
/// not moving at all.
Future<void> openQuoteFromNotificationPayload(
  Map<String, dynamic>? payload,
) async {
  final quoteId = payload?['quoteId']?.toString();
  if (quoteId == null || quoteId.isEmpty) {
    _showMissingToast();
    return;
  }
  await openQuoteById(quoteId);
}

Future<void> openQuoteById(String quoteId) async {
  final navigator = globalNavigatorKey.currentState;
  if (navigator == null) return;

  // Prefer the bloc's live state — it streams every update from RTDB,
  // so by the time a "quote accepted" push arrives, the bloc has the
  // fresh `respondedAt` / `status: accepted` we need to render the
  // locked details view. The one-shot `findById` is a cold-start
  // fallback (terminated-state push tap before the stream has
  // attached).
  Quote? quote = _findInBloc(quoteId);
  if (quote == null) {
    try {
      quote = await QuotesRepository().findById(quoteId);
    } catch (e) {
      debugPrint('openQuoteById: findById failed: $e');
    }
  }
  if (quote == null) {
    _showMissingToast();
    return;
  }

  // Push the list first so the back arrow lands somewhere sensible,
  // then drop the user straight into the quote details.
  navigator.pushNamed('/quotes');
  navigator.pushNamed(
    '/quotes/new',
    arguments: NewQuoteArgs(existing: quote),
  );
}

Quote? _findInBloc(String quoteId) {
  final ctx = globalNavigatorKey.currentContext;
  if (ctx == null) return null;
  try {
    final state = BlocProvider.of<QuotesBloc>(ctx, listen: false).state;
    for (final q in state.items) {
      if (q.id == quoteId) return q;
    }
  } catch (_) {
    // BlocProvider not in scope yet (cold start before MaterialApp
    // mounts) — fall through to the repo lookup.
  }
  return null;
}

void _showMissingToast() {
  final ctx = globalNavigatorKey.currentContext;
  if (ctx == null) return;
  CommonToasts.info(ctx, 'This quote is no longer available');
}
