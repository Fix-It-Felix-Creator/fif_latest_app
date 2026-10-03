import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/journal/journal_bloc.dart';
import '../../../blocs/journal/journal_event.dart' as j;
import '../../../blocs/journal/journal_state.dart';
import '../../../models/journal_entry.dart';
import 'journal_event_edit_screen.dart';

const _brand = Color(0xFFF64C13);
const _brandTint = Color(0xFFFFF4EE);

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static final DateTime _anchor = DateTime(2000, 1, 1);
  late final PageController _pageController;

  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _pageController = PageController(initialPage: _monthToIndex(_visibleMonth));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JournalBloc>().add(const j.JournalStartWatching());
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _monthToIndex(DateTime month) =>
      (month.year - _anchor.year) * 12 + (month.month - _anchor.month);

  DateTime _indexToMonth(int index) =>
      DateTime(_anchor.year, _anchor.month + index);

  void _goToMonth(DateTime month) {
    _pageController.animateToPage(
      _monthToIndex(month),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).pushNamed(
      '/journalEdit',
      arguments: JournalEditArgs(initialDate: _selectedDay),
    );
  }

  Future<void> _openEdit(JournalEntry entry) async {
    await Navigator.of(context).pushNamed(
      '/journalEdit',
      arguments: JournalEditArgs(existing: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text('Journal'),
        actions: [
          IconButton(
            tooltip: 'Add entry',
            icon: const Icon(LucideIcons.plus),
            onPressed: _openAdd,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<JournalBloc, JournalState>(
        builder: (context, state) {
          final dots = state.datesWithEntries;
          final events = state.entriesOn(_selectedDay);
          return SingleChildScrollView(
            primary: false,
            child: Column(
              children: [
                _MonthHeader(
                  month: _visibleMonth,
                  onPrev: () => _goToMonth(
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1),
                  ),
                  onNext: () => _goToMonth(
                    DateTime(_visibleMonth.year, _visibleMonth.month + 1),
                  ),
                  onTodayTap: () {
                    final now = DateTime.now();
                    setState(() =>
                        _selectedDay = DateTime(now.year, now.month, now.day));
                    _goToMonth(DateTime(now.year, now.month));
                  },
                ),
                const _WeekdayStrip(),
                SizedBox(
                  height: 264,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      setState(() => _visibleMonth = _indexToMonth(i));
                    },
                    itemBuilder: (_, i) => _MonthGrid(
                      month: _indexToMonth(i),
                      selectedDay: _selectedDay,
                      entryDates: dots,
                      onDayTap: (d) => setState(() => _selectedDay = d),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _EventList(
                  selectedDay: _selectedDay,
                  events: events,
                  onTapEntry: _openEdit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onTodayTap,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTodayTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTodayTap,
              child: Center(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m];
}

class _WeekdayStrip extends StatelessWidget {
  const _WeekdayStrip();

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.entryDates,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<String> entryDates;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: 44,
        ),
        itemCount: 42,
        itemBuilder: (_, i) {
          final day = gridStart.add(Duration(days: i));
          final inMonth = day.month == month.month;
          final isSelected = _sameDay(day, selectedDay);
          final isToday = _sameDay(day, DateTime.now());
          final hasEvent = entryDates.contains(JournalEntry.dateKey(day));
          return _DayCell(
            day: day,
            inMonth: inMonth,
            isSelected: isSelected,
            isToday: isToday,
            hasEvent: hasEvent,
            onTap: () => onDayTap(DateTime(day.year, day.month, day.day)),
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isSelected,
    required this.isToday,
    required this.hasEvent,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isSelected;
  final bool isToday;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color? bg;
    final Border? border;

    if (isSelected) {
      textColor = Colors.white;
      bg = _brand;
      border = null;
    } else if (isToday) {
      textColor = _brand;
      bg = _brandTint;
      border = Border.all(color: _brand.withValues(alpha: 0.4));
    } else if (!inMonth) {
      textColor = Colors.grey.shade400;
      bg = null;
      border = null;
    } else {
      textColor = Colors.black87;
      bg = null;
      border = null;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.zero,
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasEvent && inMonth
                      ? (isSelected ? Colors.white : _brand)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.selectedDay,
    required this.events,
    required this.onTapEntry,
  });

  final DateTime selectedDay;
  final List<JournalEntry> events;
  final ValueChanged<JournalEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No events',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            _dateLabel(selectedDay),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.shade200,
                  indent: 16,
                  endIndent: 16,
                ),
              _EventTile(
                entry: events[i],
                onTap: () => onTapEntry(events[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _dateLabel(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return '${weekdays[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.entry,
    required this.onTap,
  });
  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final past = entry.isPast;
    final accentColor = past ? Colors.grey.shade400 : _brand;
    final titleColor = past ? Colors.grey.shade500 : Colors.black87;
    final subtleColor =
        past ? Colors.grey.shade400 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 36, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: subtleColor),
                      const SizedBox(width: 4),
                      Text(
                        _timeLabel(entry),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtleColor,
                        ),
                      ),
                      if (past) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Past',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      decoration:
                          past ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.grey.shade400,
                    ),
                  ),
                  if (entry.customerName != null ||
                      (entry.location?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (entry.customerName != null) entry.customerName!,
                        if (entry.location?.isNotEmpty ?? false)
                          entry.location!,
                      ].join(' • '),
                      style: TextStyle(fontSize: 12, color: subtleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(JournalEntry e) {
    if (e.allDay) return 'All day';
    final s = e.startAtObj;
    final en = e.endAtObj;
    if (s == null) return 'All day';
    final sh = s.hour.toString().padLeft(2, '0');
    final sm = s.minute.toString().padLeft(2, '0');
    if (en == null) return '$sh:$sm';
    final eh = en.hour.toString().padLeft(2, '0');
    final em = en.minute.toString().padLeft(2, '0');
    return '$sh:$sm – $eh:$em';
  }
}

