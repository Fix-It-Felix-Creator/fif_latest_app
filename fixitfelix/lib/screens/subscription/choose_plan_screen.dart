import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/config/config_models.dart';
import '../../services/subscription_config_service.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF7F7F8);

/// The three homeowner tiers.
///
/// Display only, and honestly so. The customer app has no in-app purchase
/// wiring — no product ids, no store products, nothing to charge against — so
/// this screen shows what each tier includes and says plainly that buying is
/// not open yet. A button that looked live and then failed would be worse than
/// no button.
///
/// Every word and number comes from `subscription_plans` via
/// `app_config.subscriptions`, the same document the Pro app reads, so a price
/// changed in the admin panel changes this screen at its next launch.
class ChoosePlanScreen extends StatefulWidget {
  const ChoosePlanScreen({super.key});

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  List<SubscriptionPlanConfigModel> _plans = const [];
  bool _yearly = false;
  bool _loading = true;

  /// Its own controller, and primary: false below.
  ///
  /// IndexedStack builds every tab at once, so this list exists at the same
  /// time as the ones on Home and Profile. A vertical ListView with no
  /// controller attaches to the ambient PrimaryScrollController, and three
  /// ScrollPositions on one controller is exactly what Scrollbar asserts
  /// against — "The provided ScrollController is attached to more than one
  /// ScrollPosition." Owning the controller keeps this list to itself.
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await SubscriptionConfigService().customerPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        // Material 3 tints the bar with surfaceTintColor once content scrolls
        // under it, which turned a near-white bar peach the moment the list
        // moved. The page is one flat colour by design, so both are off.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Plans'),
      ),
      body: RefreshIndicator(
        // The document is cached for half an hour, so a pull is the only way
        // to see a change made in the admin panel a minute ago.
        onRefresh: () async {
          final plans =
              await SubscriptionConfigService().customerPlans(forceRefresh: true);
          if (mounted) setState(() => _plans = plans);
        },
        child: ListView(
          controller: _scrollCtrl,
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Choose how you use Fix It Felix',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Invoicing, contracts, quoting, scheduling and reviews are '
                'included on every package.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 18),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_plans.isEmpty)
              // Says which of the two it is. "Nothing to show" leaves a
              // support agent guessing between a bad config and a dead network.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
                child: Column(
                  children: [
                    Icon(LucideIcons.wifiOff, size: 28, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'Plans could not be loaded',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else ...[
              if (_plans.any((p) => !p.isFreePlan)) ...[
                _BillingCycleToggle(
                  yearly: _yearly,
                  onChanged: (v) => setState(() => _yearly = v),
                ),
                const SizedBox(height: 14),
              ],
              for (final plan in _plans) ...[
                _PlanCard(plan: plan, yearly: _yearly),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.yearly});

  final SubscriptionPlanConfigModel plan;
  final bool yearly;

  @override
  Widget build(BuildContext context) {
    final featured = plan.isFeatured;
    final saving = _yearlySaving(plan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: featured ? _brand : Colors.grey.shade300,
          width: featured ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (plan.badge != null && plan.badge!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: featured ? _brand : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: featured ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.priceLabel(yearly: yearly).replaceAll(RegExp(r'/(mo|yr)$'), ''),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              if (!plan.isFreePlan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    yearly ? '/ year' : '/ month',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (yearly && saving > 0) ...[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SAVE $saving%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (plan.tagline != null && plan.tagline!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.tagline!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          ...plan.features.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.check, size: 16, color: _brand),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              plan.isFreePlan ? 'Included with your account' : 'Coming soon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingCycleToggle extends StatelessWidget {
  const _BillingCycleToggle({required this.yearly, required this.onChanged});

  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Monthly',
              selected: !yearly,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Annually',
              selected: yearly,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// Whole percent saved by paying yearly, or 0 when there is nothing to claim.
int _yearlySaving(SubscriptionPlanConfigModel plan) {
  final monthlyTotal = plan.monthlyPrice * 12;
  if (monthlyTotal <= 0 || plan.yearlyPrice <= 0) return 0;
  if (plan.yearlyPrice >= monthlyTotal) return 0;
  return (((monthlyTotal - plan.yearlyPrice) / monthlyTotal) * 100).round();
}
