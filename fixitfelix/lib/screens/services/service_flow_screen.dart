import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/services/service_catalog.dart';
import '../../widgets/inset_group.dart';
import 'job_summary_screen.dart';
import 'service_tile.dart';

const _pageBg = Color(0xFFF5F5F7);

/// Walks a service's question tree.
///
/// One screen for every level rather than one per depth: the tree nests up to
/// three deep and each level is the same interaction — read a question, pick
/// one of these, go deeper or finish. A screen per level would be three
/// near-identical widgets and a router that has to know how deep it is.
///
/// The trail of picks is kept as a stack, so Back genuinely steps back up the
/// tree and the breadcrumb is just that stack rendered.
class ServiceFlowScreen extends StatefulWidget {
  const ServiceFlowScreen({super.key, required this.service});

  final ServiceSummary service;

  @override
  State<ServiceFlowScreen> createState() => _ServiceFlowScreenState();
}

class _ServiceFlowScreenState extends State<ServiceFlowScreen> {
  ServiceFlow? _flow;
  bool _loading = true;

  /// Every pick so far, outermost first. Empty means the first question.
  final List<FlowOption> _trail = [];

  @override
  void initState() {
    super.initState();
    ServiceFlow.load(widget.service.id).then((flow) {
      if (!mounted) return;
      setState(() {
        _flow = flow;
        _loading = false;
      });
    });
  }

  /// The options to show now: the top-level categories, or the children of
  /// the last thing picked.
  List<FlowOption> get _current =>
      _trail.isEmpty ? (_flow?.categories ?? const []) : _trail.last.options;

  void _pick(FlowOption option) {
    if (option.hasChildren) {
      setState(() => _trail.add(option));
      return;
    }
    // A leaf ends the flow. The trail plus this pick is the description of
    // the job, and the summary is where it gets confirmed.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobSummaryScreen(
          service: widget.service,
          selections: [..._trail, option],
        ),
      ),
    );
  }

  void _back() {
    if (_trail.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() => _trail.removeLast());
    }
  }

  /// One group of options, hairline-separated. The divider starts under the
  /// text so it does not cut the icon tile in half.
  List<Widget> _options(List<FlowOption> options) {
    final out = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      if (i > 0) out.add(const HairlineDivider(indent: 64));
      out.add(_OptionRow(
        option: options[i],
        accent: optionAccent(i),
        onTap: () => _pick(options[i]),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final options = _current;

    return PopScope(
      // Back should climb the tree, not leave the service. Only once the trail
      // is empty does it close the screen.
      canPop: _trail.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _back,
          ),
          title: Text(widget.service.name),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : flow == null
                ? _Missing(service: widget.service)
                : ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: [
                      if (_trail.isNotEmpty) _Breadcrumb(trail: _trail),
                      // The question, aligned to the same 24pt gutter the
                      // section captions use, so the page has one left edge
                      // rather than two.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trail.isEmpty ? flow.title : _trail.last.name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.3,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _trail.isEmpty
                                  ? flow.subtitle
                                  : (_trail.last.description ?? 'Choose one'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (options.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Text('Nothing to choose here.'),
                        )
                      else ...[
                        SectionHeader(
                          options.length == 1
                              ? 'One option'
                              : '${options.length} options',
                        ),
                        InsetGroup(children: _options(options)),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.trail});

  final List<FlowOption> trail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < trail.length; i++) ...[
            if (i > 0)
              Icon(LucideIcons.chevronRight, size: 12, color: Colors.grey.shade400),
            Text(
              trail[i].name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One option as a row inside an [InsetGroup].
///
/// Flat, like the catalogue's service rows: the group is the card. An urgent
/// option keeps its red icon and gains a badge — the old red border round the
/// whole card has nowhere to go in a grouped list, and a badge says the same
/// thing without it.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.accent,
    required this.onTap,
  });

  final FlowOption option;

  /// Colour of this row's icon tile. Cycled down the list — see
  /// [optionAccent]. An urgent option overrides it with red.
  final Color accent;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = option.urgent;
    final tint = urgent ? const Color(0xFFDC2626) : accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                urgent ? LucideIcons.triangleAlert : serviceIcon(option.icon),
                size: 18,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          option.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (urgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((option.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.description!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              // A chevron means "deeper"; an arrow means "this is the last
              // question and the next screen is the summary".
              option.hasChildren
                  ? LucideIcons.chevronRight
                  : LucideIcons.arrowRight,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.service});

  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileQuestion, size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              '${service.name} has no question flow yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing was loaded for this service, so there is nothing to ask.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
