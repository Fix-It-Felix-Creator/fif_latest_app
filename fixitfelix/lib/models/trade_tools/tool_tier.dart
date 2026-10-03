import '../../core/enum.dart';

/// Tier level for trade calculators
enum ToolTier {
  /// Free for all users
  defaultTier,

  /// Requires Plus, Advance, or VIP subscription
  proTier,
}

extension ToolTierExtension on ToolTier {
  /// Whether the user can access this tier based on their plan
  bool isAccessibleBy(PlanType planType) {
    switch (this) {
      case ToolTier.defaultTier:
        return true;
      case ToolTier.proTier:
        return planType != PlanType.standard;
    }
  }

  String get label {
    switch (this) {
      case ToolTier.defaultTier:
        return 'Free';
      case ToolTier.proTier:
        return 'Pro';
    }
  }
}
