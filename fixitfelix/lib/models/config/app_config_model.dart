import 'package:equatable/equatable.dart';

import '../../core/enum.dart';
import 'commission_rates_model.dart';
import 'image_limits_config_model.dart';
import 'subscription_plan_config_model.dart';
import 'video_limits_config_model.dart';

/// Top-level app config fetched once at startup from Firebase RTDB path `config/`.
/// Aggregates subscriptions, commission rates, image limits and video limits so
/// any screen can read from a single in-memory snapshot.
class AppConfigModel extends Equatable {
  /// subscriptions[accountType][planId] → plan config
  final Map<String, Map<String, SubscriptionPlanConfigModel>> subscriptions;
  final CommissionRatesModel commissionRates;
  final ImageLimitsConfigModel imageLimits;
  final VideoLimitsConfigModel videoLimits;

  const AppConfigModel({
    this.subscriptions = const {},
    this.commissionRates = CommissionRatesModel.defaultRates,
    this.imageLimits = const ImageLimitsConfigModel(),
    this.videoLimits = const VideoLimitsConfigModel(),
  });

  static const AppConfigModel empty = AppConfigModel();

  /// All plans for an account type (tradesman | business | customer).
  Map<String, SubscriptionPlanConfigModel> plansFor(String accountType) =>
      subscriptions[accountType] ?? const {};

  /// Find a plan by account type + plan type. Returns null if not configured.
  SubscriptionPlanConfigModel? plan(String accountType, PlanType planType) {
    final plans = plansFor(accountType);
    for (final p in plans.values) {
      if (p.planType == planType) return p;
    }
    return null;
  }

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    final subs = <String, Map<String, SubscriptionPlanConfigModel>>{};
    final rawSubs = json['subscriptions'];
    if (rawSubs is Map) {
      for (final entry in rawSubs.entries) {
        final accountType = entry.key.toString();
        final plansMap = <String, SubscriptionPlanConfigModel>{};
        final plansJson = entry.value;
        if (plansJson is Map) {
          for (final p in plansJson.entries) {
            final planId = p.key.toString();
            final planData = _asStringMap(p.value);
            if (planData != null) {
              plansMap[planId] =
                  SubscriptionPlanConfigModel.fromJson(planData);
            }
          }
        }
        subs[accountType] = plansMap;
      }
    }

    return AppConfigModel(
      subscriptions: subs,
      commissionRates: CommissionRatesModel.fromJson(
        _asStringMap(json['commissionRates']) ?? const {},
      ),
      imageLimits: ImageLimitsConfigModel.fromJson(
        _asStringMap(json['imageLimits']) ?? const {},
      ),
      videoLimits: VideoLimitsConfigModel.fromJson(
        _asStringMap(json['videoLimits']) ?? const {},
      ),
    );
  }

  /// Firebase RTDB returns `Map<Object?, Object?>`; convert recursively to
  /// `Map<String, dynamic>` so downstream `fromJson` constructors work.
  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((key, val) {
        if (val is Map) {
          return MapEntry(key.toString(), _asStringMap(val));
        }
        if (val is List) {
          return MapEntry(key.toString(), _convertList(val));
        }
        return MapEntry(key.toString(), val);
      });
    }
    return null;
  }

  static List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) return _asStringMap(item);
      if (item is List) return _convertList(item);
      return item;
    }).toList();
  }

  @override
  List<Object?> get props => [
        subscriptions,
        commissionRates,
        imageLimits,
        videoLimits,
      ];
}
