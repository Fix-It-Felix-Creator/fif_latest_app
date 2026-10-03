import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/job_model.dart';
import '../../models/job_time_entry.dart';
import '../../widgets/jobs/job_clock.dart';

const _brand = Color(0xFFF64C13);
const _running = Color(0xFF16A34A);
const _pageBg = Color(0xFFF5F5F7);

/// Read-only clock-in / clock-out history for a single job. The running
/// total sits at the top; each closed session (and any live one) is
/// listed below, newest first.
class JobTimeLogScreen extends StatefulWidget {
  const JobTimeLogScreen({super.key, required this.job});

  final Job job;

  @override
  State<JobTimeLogScreen> createState() => _JobTimeLogScreenState();
}

class _JobTimeLogScreenState extends State<JobTimeLogScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.job.isClockedIn) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtClock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final sessions = [...job.timeEntries]
      ..sort((a, b) => b.start.compareTo(a.start));
    final total = jobElapsed(job);
    final count = sessions.length + (job.isClockedIn ? 1 : 0);

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Time log'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          // Total — always at the top of the log.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatJobDuration(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count session${count == 1 ? '' : 's'}'
                  '${job.isClockedIn ? ' · running now' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (count == 0)
            _empty()
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'Sessions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            if (job.isClockedIn) _runningRow(job.clockInAt!),
            for (final s in sessions) _sessionRow(s),
          ],
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: child,
      );

  Widget _runningRow(DateTime start) {
    final elapsed = DateTime.now().difference(start);
    return _shell(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _running,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(start),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtClock(start)} – now',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            formatJobClock(elapsed),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _running,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(JobTimeEntry s) {
    return _shell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtDate(s.start),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtClock(s.start)} – ${_fmtClock(s.end)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            formatJobDuration(s.duration),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(LucideIcons.timer, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              'No time logged yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Clock in to start tracking time.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
}
