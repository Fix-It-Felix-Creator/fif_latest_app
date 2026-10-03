import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_dialogs.dart';
import '../../models/job_model.dart';

const _brand = Color(0xFFF64C13);
const _running = Color(0xFF16A34A); // green — a live session

/// Ask before ending a running clock session. Calls [onConfirm] only if
/// the tradesperson confirms.
Future<void> confirmClockOut(BuildContext context, VoidCallback onConfirm) {
  return CommonDialogs.showWarningBox(
    context,
    title: 'Clock out?',
    message: 'This stops the timer and logs the time worked on this job.',
    icon: LucideIcons.timer,
    yesText: 'Clock out',
    noText: 'Keep running',
    onConfirm: onConfirm,
  );
}

/// Compact "1h 23m" / "45m" label for logged / summary totals. Seconds
/// are intentionally omitted here.
String formatJobDuration(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Live "MM:SS" / "H:MM:SS" clock for a currently-running session, so the
/// counter is visibly ticking.
String formatJobClock(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final h = total.inHours;
  final m = total.inMinutes % 60;
  final s = total.inSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

/// Total tracked time for a job = closed sessions + any running session.
Duration jobElapsed(Job job) {
  final start = job.clockInAt;
  final running =
      start == null ? Duration.zero : DateTime.now().difference(start);
  return job.loggedDuration + running;
}

String _fmtClock(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Ticks a rebuild every second so the live running clock counts up
/// visibly. Cheap — it only ever rebuilds the small timer subtree.
mixin _SecondTicker<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Clock in / clock out control shown on the job's Details tab.
class JobClockControl extends StatefulWidget {
  const JobClockControl({
    super.key,
    required this.job,
    required this.busy,
    required this.onToggle,
    this.enabled = true,
    this.disabledMessage,
  });

  final Job job;
  final bool busy;
  final VoidCallback onToggle;

  /// When false the control is inert — e.g. the job is completed or
  /// cancelled, so no new time may be tracked.
  final bool enabled;
  final String? disabledMessage;

  @override
  State<JobClockControl> createState() => _JobClockControlState();
}

class _JobClockControlState extends State<JobClockControl>
    with _SecondTicker {
  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final enabled = widget.enabled;
    final running = job.isClockedIn;
    final elapsed = jobElapsed(job);
    final accent =
        !enabled ? Colors.grey.shade400 : (running ? _running : _brand);

    final String subtitle;
    if (!enabled) {
      subtitle = widget.disabledMessage ?? 'Time tracking unavailable';
    } else if (running) {
      subtitle =
          'In progress · ${formatJobClock(elapsed)} · since ${_fmtClock(job.clockInAt!)}';
    } else if (job.loggedDuration > Duration.zero) {
      subtitle = 'Logged ${formatJobDuration(job.loggedDuration)}';
    } else {
      subtitle = 'Not started';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled && running
              ? _running.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              !enabled
                  ? LucideIcons.lock
                  : (running ? LucideIcons.timer : LucideIcons.play),
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time tracking',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: !enabled
                        ? Colors.grey.shade500
                        : (running ? _running : Colors.grey.shade600),
                    fontWeight:
                        (enabled && running) ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (enabled)
            SizedBox(
              height: 34,
              child: running
                  ? ShadButton.outline(
                      onPressed: widget.busy
                          ? null
                          : () => confirmClockOut(context, widget.onToggle),
                      child: widget.busy
                          ? const _MiniSpinner()
                          : const Text('Clock out'),
                    )
                  : ShadButton(
                      onPressed: widget.busy ? null : widget.onToggle,
                      child: widget.busy
                          ? const _MiniSpinner(color: Colors.white)
                          : const Text('Clock in'),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Home-tab section listing every job with a running clock. A single job
/// shows one row; two or more collapse behind an expandable header.
class HomeActiveJobs extends StatefulWidget {
  const HomeActiveJobs({
    super.key,
    required this.jobs,
    required this.onClockOut,
    this.onTapJob,
    this.margin = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  });

  /// Jobs that are currently clocked in.
  final List<Job> jobs;
  final void Function(Job job) onClockOut;
  final void Function(Job job)? onTapJob;
  final EdgeInsetsGeometry margin;

  @override
  State<HomeActiveJobs> createState() => _HomeActiveJobsState();
}

class _HomeActiveJobsState extends State<HomeActiveJobs> with _SecondTicker {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final jobs = widget.jobs;
    if (jobs.isEmpty) return const SizedBox.shrink();

    final multiple = jobs.length > 1;
    final visible = !multiple || _expanded ? jobs : [jobs.first];

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: multiple ? () => setState(() => _expanded = !_expanded) : null,
            child: Row(
              children: [
                _PulseDot(),
                const SizedBox(width: 8),
                Text(
                  multiple ? '${jobs.length} jobs in progress' : 'In progress',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                if (multiple)
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final job in visible)
            _JobTimerRow(
              job: job,
              onClockOut: () => widget.onClockOut(job),
              onTap: widget.onTapJob == null
                  ? null
                  : () => widget.onTapJob!(job),
            ),
          if (multiple && !_expanded)
            InkWell(
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '+${jobs.length - 1} more working — tap to view',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JobTimerRow extends StatelessWidget {
  const _JobTimerRow({
    required this.job,
    required this.onClockOut,
    this.onTap,
  });

  final Job job;
  final VoidCallback onClockOut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = job.title.isEmpty ? job.reference : job.title;
    final who = job.customer?.name ?? '';
    final started = job.clockInAt != null ? 'since ${_fmtClock(job.clockInAt!)}' : '';
    final sub = [who, started].where((s) => s.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatJobClock(jobElapsed(job)),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _running,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 30,
              child: ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => confirmClockOut(context, onClockOut),
                child: const Text('Clock out', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: _running,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner({this.color = _brand});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 15,
      height: 15,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
