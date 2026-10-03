import 'package:equatable/equatable.dart';

/// One completed clock-in → clock-out session on a job. The live,
/// currently-running session is tracked separately by `Job.clockInAt`;
/// only closed sessions land here.
class JobTimeEntry extends Equatable {
  const JobTimeEntry({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration {
    final d = end.difference(start);
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toRtdb() => {
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      };

  static JobTimeEntry fromRtdb(Map<dynamic, dynamic> raw) => JobTimeEntry(
        start: DateTime.fromMillisecondsSinceEpoch(
          (raw['start'] as num?)?.toInt() ?? 0,
        ),
        end: DateTime.fromMillisecondsSinceEpoch(
          (raw['end'] as num?)?.toInt() ?? 0,
        ),
      );

  @override
  List<Object?> get props => [start, end];
}
