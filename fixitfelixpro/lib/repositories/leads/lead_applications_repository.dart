import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../models/lead_application.dart';
import '../../screens/leads/leads_application.dart';

/// An application and the plan it will be judged against, read together.
///
/// They travel as a pair because every screen in the flow needs both, and
/// reading them from two places is how the banner ends up saying "approved,
/// upgrade to start" a second after the upgrade went through.
typedef LeadsSnapshot = ({LeadApplication? application, LeadsPlan plan});

/// Sending, watching and withdrawing a leads application.
class LeadApplicationsRepository {
  String? get _uid => SupabaseService().auth.currentUser?.id;

  /// Uploads one local file into the private `user-documents` bucket.
  ///
  /// The uid is the SECOND path segment because the bucket's policies key on
  /// `storage.foldername(name)[2]`. Get that wrong and every upload is refused
  /// by RLS with a message about permissions rather than about paths.
  ///
  /// Timestamped, so re-applying after a rejection does not overwrite the
  /// photographs the previous decision was made against.
  Future<String?> _upload(String localPath, String slot) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;
      final name = localPath.split('/').last;
      final dot = name.lastIndexOf('.');
      final ext = dot <= 0 ? '.jpg' : name.substring(dot).toLowerCase();
      final objectPath =
          'verification/$uid/$slot-${DateTime.now().millisecondsSinceEpoch}$ext';
      await SupabaseService()
          .client
          .storage
          .from('user-documents')
          .upload(objectPath, file);
      return objectPath;
    } catch (e) {
      debugPrint('LeadApplicationsRepository._upload($slot) failed: $e');
      return null;
    }
  }

  /// Sends the draft, returning the created row.
  ///
  /// The status is not passed: the column defaults to 'submitted' and the
  /// insert policy refuses anything else, so an applicant cannot approve
  /// themselves even if this method were changed to try.
  Future<LeadApplication?> submit(LeadsApplicationDraft draft) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      // Uploaded before the row is written, so an application never exists
      // claiming documents that are not in the bucket.
      final documentPaths = <String>[];
      for (final entry in draft.documentPaths.entries) {
        final path = await _upload(entry.value, entry.key.name);
        if (path == null) return null;
        documentPaths.add(path);
      }

      String? selfiePath;
      if (draft.selfiePath != null) {
        selfiePath = await _upload(draft.selfiePath!, 'selfie');
        if (selfiePath == null) return null;
      }

      final row = await SupabaseService().client
          .from('lead_applications')
          .insert({
            'owner_id': uid,
            'applicant_type': draft.isSolo ? 'solo' : 'business',
            'services': draft.services.toList(),
            'registrations': {
              for (final e in draft.registrations.entries)
                if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
            },
            'moves_waste': draft.mayMoveWaste ? draft.movesWaste : null,
            'waste_carrier_number': draft.movesWaste == true
                ? draft.wasteCarrierNumber.trim()
                : null,
            'base_address': (draft.baseAddress ?? '').trim(),
            'base_latitude': draft.latitude,
            'base_longitude': draft.longitude,
            'working_days': draft.workingDays.toList()..sort(),
            'takes_emergencies': draft.takesEmergencies,
            'has_own_insurance': !draft.hasNoInsurance,
            'insurer': draft.hasNoInsurance ? null : draft.insurer.trim(),
            'policy_number':
                draft.hasNoInsurance ? null : draft.policyNumber.trim(),
            'cover_amount':
                draft.hasNoInsurance ? null : draft.coverAmount.trim(),
            'policy_expires_at': draft.hasNoInsurance
                ? null
                : draft.policyExpiry?.toIso8601String().split('T').first,
            'document_type': draft.documentType?.wire,
            'document_paths': documentPaths,
            'selfie_path': selfiePath,
            'headline': draft.headline.trim(),
            'about': draft.about.trim(),
            'years_experience': draft.yearsExperience,
          })
          .select()
          .single();
      // Bind the identity to the ACCOUNT, not just to the application. The
      // profile is who this person is; the application is a snapshot of what
      // one reviewer looked at. Without this the Verification tab on their
      // detail page shows nothing while a passport sits in the bucket.
      await _bindIdentityToProfile(
        uid: uid,
        documentType: draft.documentType?.wire,
        documentPaths: documentPaths,
        selfiePath: selfiePath,
        latitude: draft.latitude,
        longitude: draft.longitude,
      );

      return LeadApplication.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('LeadApplicationsRepository.submit failed: $e');
      return null;
    }
  }

  /// Copies what the application proved onto the profile.
  ///
  /// Never throws outward. By this point the application is written and
  /// accepted; failing the whole submission because a secondary write missed
  /// would lose somebody's work for the sake of tidiness.
  Future<void> _bindIdentityToProfile({
    required String uid,
    required String? documentType,
    required List<String> documentPaths,
    required String? selfiePath,
    required double? latitude,
    required double? longitude,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (documentType != null) 'document_type': documentType,
        if (documentPaths.isNotEmpty) 'document_urls': documentPaths,
        if (selfiePath != null) 'selfie_url': selfiePath,
      };

      // Coordinates only when the profile has none. The application's base is
      // where somebody works FROM, which is not necessarily where they live.
      if (latitude != null && longitude != null) {
        final existing = await SupabaseService().client
            .from('profiles')
            .select('latitude')
            .eq('id', uid)
            .maybeSingle();
        if (existing == null || existing['latitude'] == null) {
          patch['latitude'] = latitude;
          patch['longitude'] = longitude;
        }
      }

      if (patch.isEmpty) return;
      await SupabaseService()
          .client
          .from('profiles')
          .update(patch)
          .eq('id', uid);
    } catch (e) {
      debugPrint('LeadApplicationsRepository._bindIdentityToProfile: $e');
    }
  }

  /// The application that counts right now, or null if there has never been
  /// one.
  ///
  /// Newest first and take one. A live application is always the newest, and
  /// when there is no live one the newest historical row is what the status
  /// screen should show — a rejection from last week is the answer to "what
  /// happened to my application", not an empty screen.
  Future<LeadApplication?> current() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final rows = await SupabaseService().client
          .from('lead_applications')
          .select()
          .eq('owner_id', uid)
          .order('submitted_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return null;
      return LeadApplication.fromRow(list.first);
    } catch (e) {
      debugPrint('LeadApplicationsRepository.current failed: $e');
      rethrow;
    }
  }

  /// Which tier this account is on right now.
  ///
  /// Anything that is not recognisably Pro or Advance counts as Standard.
  /// `PlanType` carries `plus` and `vip` that the leads model has never heard
  /// of, and an unknown plan should fail towards fewer entitlements, not more
  /// — guessing generously here would hand out paid leads for free.
  Future<LeadsPlan> currentPlan() async {
    final uid = _uid;
    if (uid == null) return const LeadsPlan.standard();
    try {
      final row = await SupabaseService().client
          .from('subscriptions')
          .select('plan_type, status')
          .eq('owner_id', uid)
          .maybeSingle();
      if (row == null) return const LeadsPlan.standard();

      final status = (row['status'] ?? '').toString();
      if (status != 'active' && status != 'trial') {
        return const LeadsPlan.standard();
      }

      final planType = (row['plan_type'] ?? '').toString();
      final tier = switch (planType) {
        'pro' => LeadsPlanTier.pro,
        'advance' => LeadsPlanTier.advance,
        _ => LeadsPlanTier.standard,
      };

      // The radius comes from the plan row, not from the tier. Anything not
      // recognisably a number falls back to 0 — an unknown plan should fail
      // towards fewer entitlements, not more.
      //
      // Not `maybeSingle()`: `subscription_plans` holds one row per plan_type
      // PER ACCOUNT TYPE, so 'standard' matches both the customer row and the
      // tradesman row. maybeSingle() treats two matches as an error, the
      // error lands in the catch below, and every tradesperson silently
      // becomes radius 0 — a board that is empty for a reason nobody can see.
      final plans = await SupabaseService().client
          .from('subscription_plans')
          .select('account_type, tradesman_limits, business_limits')
          .eq('plan_type', planType)
          .neq('account_type', 'customer');

      Map<String, dynamic>? limits;
      for (final p in plans) {
        final m = (p['tradesman_limits'] ?? p['business_limits']);
        if (m is Map && m['serviceRadiusMiles'] != null) {
          limits = Map<String, dynamic>.from(m);
          break;
        }
      }
      final radius =
          int.tryParse('${limits?['serviceRadiusMiles'] ?? 0}') ?? 0;

      return LeadsPlan(tier: tier, radiusMiles: radius);
    } catch (e) {
      debugPrint('LeadApplicationsRepository.currentPlan failed: $e');
      return const LeadsPlan.standard();
    }
  }

  /// Live view of both, so an approval — or an upgrade — lands while they are
  /// looking at the screen that describes it.
  Stream<LeadsSnapshot> watch() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(
        (application: null, plan: const LeadsPlan.standard()),
      );
    }

    final controller = StreamController<LeadsSnapshot>();
    StreamSubscription? sub;
    StreamSubscription? planSub;
    var inFlight = false;
    var pending = false;

    Future<void> refresh() async {
      if (inFlight) {
        pending = true;
        return;
      }
      inFlight = true;
      try {
        // Both in one pass. Fetched together they cannot disagree; fetched
        // separately the screen briefly shows one of them stale.
        final results = await Future.wait([current(), currentPlan()]);
        if (!controller.isClosed) {
          controller.add((
            application: results[0] as LeadApplication?,
            plan: results[1] as LeadsPlan,
          ));
        }
      } catch (e) {
        // Surfaced rather than swallowed: a status screen that cannot read the
        // status must say so, not spin.
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
          .from('lead_applications')
          .stream(primaryKey: const ['id'])
          .eq('owner_id', uid)
          .listen(
            (_) => unawaited(refresh()),
            // Realtime failing costs live updates, not the row — the read
            // above still works.
            onError: (Object e) => debugPrint('lead_applications stream: $e'),
          );
      // Upgrading is the other thing that changes what these screens say, and
      // it happens on a different table entirely.
      planSub = SupabaseService().client
          .from('subscriptions')
          .stream(primaryKey: const ['owner_id'])
          .eq('owner_id', uid)
          .listen(
            (_) => unawaited(refresh()),
            onError: (Object e) => debugPrint('subscriptions stream: $e'),
          );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await planSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Takes an application back.
  ///
  /// Allowed from submitted AND approved — withdrawing an approval is how
  /// somebody stops receiving leads without cancelling their subscription. The
  /// RLS policy allows exactly this transition and nothing else.
  Future<bool> withdraw(String id) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await SupabaseService().client
          .from('lead_applications')
          .update({'status': 'withdrawn'})
          .eq('id', id)
          .eq('owner_id', uid);
      return true;
    } catch (e) {
      debugPrint('LeadApplicationsRepository.withdraw failed: $e');
      return false;
    }
  }
}
