import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/data/tradesman_services.dart';
import 'leads_application.dart';
import 'leads_coverage_screen.dart';
import 'leads_ui.dart';

/// Registration numbers for the trades that legally need one.
///
/// Its own step rather than fields crammed under a 4-wide grid. Only appears
/// when a gated trade was actually picked — most applications skip straight
/// past it.
class LeadsRegistrationsScreen extends StatefulWidget {
  const LeadsRegistrationsScreen({super.key, required this.draft});

  final LeadsApplicationDraft draft;

  @override
  State<LeadsRegistrationsScreen> createState() =>
      _LeadsRegistrationsScreenState();
}

class _LeadsRegistrationsScreenState extends State<LeadsRegistrationsScreen> {
  final _controllers = <String, TextEditingController>{};
  late final _waste =
      TextEditingController(text: widget.draft.wasteCarrierNumber);

  LeadsApplicationDraft get draft => widget.draft;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _waste.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String id) =>
      _controllers.putIfAbsent(
        id,
        () => TextEditingController(text: draft.registrations[id] ?? ''),
      );

  String _nameFor(String key) {
    for (final s in tradesmanServices) {
      if (s.key == key) return s.name;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    // Catalogue order, so the cards do not reshuffle between visits.
    final gated = [
      for (final s in tradesmanServices)
        if (draft.services.contains(s.key) &&
            leadsGatedServices.containsKey(s.key))
          s.key,
    ];
    final missing = draft.missingRequiredRegistrations.length;

    return LeadsStepScaffold(
      step: draft.stepRegistrations,
      totalSteps: draft.totalSteps,
      title: 'Your registrations',
      subtitle: 'Some of this is required by law and some is what customers '
          'expect. We check every number you give us.',
      actionLabel: 'Continue',
      footnote: missing > 0
          ? (missing == 1
              ? 'One required number still to add.'
              : '$missing required numbers still to add.')
          : (draft.mayMoveWaste && draft.movesWaste == null)
              ? 'Tell us whether you take waste away.'
              : (draft.movesWaste == true &&
                      draft.wasteCarrierNumber.trim().isEmpty)
                  ? 'Add your waste carrier number.'
                  : null,
      onAction: draft.registrationsComplete
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadsCoverageScreen(draft: draft),
                ),
              )
          : null,
      child: Column(
        children: [
          // Required first. Someone who cannot send the application without
          // these should meet them before the optional ones.
          if (gated.any((k) => leadsGatedServices[k]!.isBlocking)) ...[
            const LeadsCaption('Required by law'),
            for (final key in gated)
              if (leadsGatedServices[key]!.isBlocking)
                _RegistrationCard(
                  trade: _nameFor(key),
                  gate: leadsGatedServices[key]!,
                  controller: _controllerFor(key),
                  onChanged: (v) => setState(() {
                    draft.registrations[key] = v;
                    draft.touch();
                  }),
                ),
          ],

          if (gated.any((k) => !leadsGatedServices[k]!.isBlocking)) ...[
            const LeadsCaption('Expected, but optional'),
            const LeadsNotice(
              icon: LucideIcons.info,
              tone: LeadsNoticeTone.locked,
              text: 'Leaving these blank will not stop your application. '
                  'Filling them in makes it stronger, and customers see them.',
            ),
            for (final key in gated)
              if (!leadsGatedServices[key]!.isBlocking)
                _RegistrationCard(
                  trade: _nameFor(key),
                  gate: leadsGatedServices[key]!,
                  controller: _controllerFor(key),
                  onChanged: (v) => setState(() {
                    draft.registrations[key] = v;
                    draft.touch();
                  }),
                ),
          ],

          // The one that catches more trades than all the schemes above put
          // together, and the one people have never heard of.
          if (draft.mayMoveWaste) ...[
            const LeadsCaption('Taking waste away'),
            LeadsCard(
              children: [
                _WasteChoice(
                  label: 'I take waste away from the job',
                  selected: draft.movesWaste == true,
                  onTap: () => setState(() {
                    draft.movesWaste = true;
                    draft.touch();
                  }),
                ),
                const LeadsDivider(),
                _WasteChoice(
                  label: 'The customer deals with their own waste',
                  selected: draft.movesWaste == false,
                  onTap: () => setState(() {
                    draft.movesWaste = false;
                    draft.wasteCarrierNumber = '';
                    _waste.clear();
                    draft.touch();
                  }),
                ),
              ],
            ),
            if (draft.movesWaste == true) ...[
              LeadsCard(
                children: [
                  LeadsField(
                    label: 'Waste carrier registration',
                    hint: 'e.g. CBDU123456',
                    controller: _waste,
                    onChanged: (v) => setState(() {
                      draft.wasteCarrierNumber = v;
                      draft.touch();
                    }),
                  ),
                ],
              ),
              const LeadsNotice(
                icon: LucideIcons.triangleAlert,
                tone: LeadsNoticeTone.warning,
                text: 'Carrying someone else’s waste without being registered '
                    'is an offence. Registering with the Environment Agency is '
                    'quick and we can check it automatically.',
              ),
            ],
          ],

          const LeadsNotice(
            icon: LucideIcons.shieldCheck,
            text: 'We verify these against the scheme’s own register. A number '
                'that does not check out is the most common reason an '
                'application comes back.',
          ),
        ],
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.trade,
    required this.gate,
    required this.controller,
    required this.onChanged,
  });

  final String trade;
  final LeadsGate gate;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled
              ? const Color(0xFFA7F3D0)
              : gate.isBlocking
                  ? const Color(0xFFFDE68A)
                  : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: filled
                  ? const Color(0xFFECFDF5)
                  : gate.isBlocking
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  filled ? LucideIcons.circleCheck : LucideIcons.badgeCheck,
                  size: 15,
                  color: filled
                      ? const Color(0xFF047857)
                      : gate.isBlocking
                          ? const Color(0xFF92400E)
                          : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trade,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: filled
                          ? const Color(0xFF047857)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
                if (!gate.isBlocking && !filled)
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gate.why,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  gate.scheme,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: gate.hint,
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 15, letterSpacing: 0.3),
                ),
                const SizedBox(height: 6),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: filled ? const Color(0xFFA7F3D0) : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteChoice extends StatelessWidget {
  const _WasteChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleDot : LucideIcons.circle,
              size: 19,
              color: selected ? leadsBrand : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
