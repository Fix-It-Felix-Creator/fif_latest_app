import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../models/job_request.dart';

/// Posting jobs, and watching the ones you posted.
///
/// Every query is filtered on `customer_id` even though RLS already does it.
/// The policy is the thing that makes it safe; the filter is what makes the
/// query fast and what makes the intent readable at the call site.
class JobRequestsRepository {
  String? get _uid => SupabaseService().auth.currentUser?.id;

  /// Posts a job and returns its id, or null if it could not be written.
  ///
  /// The coordinates are part of the payload, not an afterthought: a request
  /// without them cannot be offered to anyone by distance, which is the only
  /// way a tradesperson ever hears about it.
  Future<String?> post({
    required String? serviceId,
    required String serviceName,
    required List<JobRequestSelection> selections,
    required String description,
    required JobUrgency urgency,
    required String formattedAddress,
    String? line1,
    String? line2,
    String? city,
    String? county,
    String? postcode,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await SupabaseService().client
          .from('job_requests')
          .insert({
            'customer_id': uid,
            'service_id': serviceId,
            'service_name': serviceName,
            'selections': selections.map((s) => s.toJson()).toList(),
            'description': description,
            'urgency': urgency.wire,
            'formatted_address': formattedAddress,
            'address_line1': line1,
            'address_line2': line2,
            'city': city,
            'county': county,
            'postcode': postcode,
            'latitude': latitude,
            'longitude': longitude,
          })
          .select('id')
          .single();
      return (row['id'] ?? '').toString();
    } catch (e) {
      debugPrint('JobRequestsRepository.post failed: $e');
      return null;
    }
  }

  /// Live list of the customer's own requests, newest first.
  ///
  /// The realtime stream is the change signal and a select is the read, rather
  /// than trusting the stream's own payload: `stream()` cannot order or embed,
  /// and a list that arrives in insert order is not the list the Jobs tab
  /// wants.
  Stream<List<JobRequest>> watchMine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <JobRequest>[]);

    final controller = StreamController<List<JobRequest>>();
    StreamSubscription? sub;
    var inFlight = false;
    var pending = false;

    Future<void> refresh() async {
      // Coalesce: a burst of row events should produce one read, not one per
      // event, and the last one must still win.
      if (inFlight) {
        pending = true;
        return;
      }
      inFlight = true;
      try {
        final rows = await SupabaseService().client
            .from('job_requests')
            .select()
            .eq('customer_id', uid)
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(
            List<Map<String, dynamic>>.from(rows)
                .map(JobRequest.fromRow)
                .toList(),
          );
        }
      } catch (e) {
        debugPrint('JobRequestsRepository.watchMine refresh failed: $e');
        // Surfaced, not just logged. Swallowing this is what left the Jobs
        // tab spinning forever when the table was not published to realtime:
        // the controller emitted nothing at all, so the bloc could not tell
        // "still loading" from "this will never arrive".
        if (!controller.isClosed) controller.addError(e);
      } finally {
        inFlight = false;
        if (pending) {
          pending = false;
          unawaited(refresh());
        }
      }
    }

    controller.onListen = () {
      unawaited(refresh());
      sub = SupabaseService().client
          .from('job_requests')
          .stream(primaryKey: const ['id'])
          .eq('customer_id', uid)
          .listen(
            (_) => unawaited(refresh()),
            // Deliberately NOT forwarded to the controller. Realtime failing
            // costs live updates, not the list — the read above still works,
            // and blanking a good list because the socket dropped would be a
            // worse outcome than a list that needs a reopen to refresh.
            onError: (Object e) =>
                debugPrint('JobRequestsRepository.watchMine stream error: $e'),
          );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Cancels a request the customer posted.
  ///
  /// Only from a status that can still be cancelled — the check is here as
  /// well as in the UI because a stale list is exactly how someone taps
  /// Cancel on a job that finished while they were looking at it.
  Future<bool> cancel(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService().client
          .from('job_requests')
          .update({'status': 'cancelled'})
          .eq('id', id)
          .eq('customer_id', uid)
          .not('status', 'in', '("completed","cancelled")');
      return true;
    } catch (e) {
      debugPrint('JobRequestsRepository.cancel failed: $e');
      return false;
    }
  }
}
