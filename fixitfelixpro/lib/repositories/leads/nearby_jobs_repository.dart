import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../models/nearby_job.dart';

/// Jobs near enough to be worth looking at.
class NearbyJobsRepository {
  /// Open jobs inside the caller's plan radius, nearest first.
  ///
  /// An RPC rather than a select: there is no RLS policy letting a
  /// tradesperson read job_requests they have not accepted, and there should
  /// not be — one would expose every homeowner's address to every signed-in
  /// account. The function decides per caller what they may see, and at what
  /// precision.
  Future<List<NearbyJob>> nearby({int limit = 50}) async {
    try {
      final rows = await SupabaseService()
          .client
          .rpc('nearby_job_requests', params: {'in_limit': limit});
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((r) => NearbyJob.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('NearbyJobsRepository.nearby failed: $e');
      rethrow;
    }
  }
}
