import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../blocs/todos/todo_bloc.dart';
import '../../blocs/todos/todo_event.dart';
import '../../blocs/todos/todo_state.dart';
import '../../models/todo_item.dart';
import '../../repositories/todos/todo_reminder_repository.dart';
import '../../services/todo_reminder_service.dart';
import 'todo_edit_screen.dart';
import 'todo_reminder_settings_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late final ShadTabsController<String> _tabsCtrl;

  @override
  void initState() {
    super.initState();
    _tabsCtrl = ShadTabsController<String>(value: 'todo');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TodoBloc>().add(const TodoStartWatching());
      _ensureReminderScheduled();
    });
  }

  /// Boots the local-notification plugin and re-arms the daily reminder if
  /// the user has one enabled in their prefs. Safe to call repeatedly.
  Future<void> _ensureReminderScheduled() async {
    await TodoReminderService.instance.initialise();
    final prefs = await TodoReminderRepository().load();
    if (prefs.enabled) {
      await TodoReminderService.instance.schedule(
        hour: prefs.hour,
        minute: prefs.minute,
        title: prefs.title,
        body: prefs.body,
      );
    } else {
      await TodoReminderService.instance.cancel();
    }
  }

  Future<void> _openReminderSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TodoReminderSettingsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _tabsCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TodoEditScreen()),
    );
  }

  Future<void> _openEdit(TodoItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TodoEditScreen(existing: item)),
    );
  }

  void _toggle(TodoItem item) {
    context.read<TodoBloc>().add(
      TodoToggleCompleted(id: item.id, completed: !item.completed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoBloc, TodoState>(
      builder: (context, state) {
        final pending = state.pending;
        final done = state.done;

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
            title: const Text('To-Do List'),
            actions: [
              IconButton(
                tooltip: 'Reminder settings',
                icon: const Icon(LucideIcons.settings),
                onPressed: _openReminderSettings,
              ),
              IconButton(
                tooltip: 'Add to-do',
                icon: const Icon(LucideIcons.plus, color: _brand),
                onPressed: _openAdd,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ShadTabs<String>(
                  controller: _tabsCtrl,
                  tabs: [
                    ShadTab(
                      value: 'todo',
                      content: const SizedBox.shrink(),
                      child: Text('To-Do (${pending.length})'),
                    ),
                    ShadTab(
                      value: 'done',
                      content: const SizedBox.shrink(),
                      child: Text('Done (${done.length})'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: ListenableBuilder(
            listenable: _tabsCtrl,
            builder: (context, _) {
              final showPending = _tabsCtrl.selected == 'todo';
              final items = showPending ? pending : done;
              final emptyLabel =
                  showPending ? 'No to-dos yet' : 'Nothing done yet';
              return _TodoList(
                items: items,
                emptyLabel: emptyLabel,
                onToggle: _toggle,
                onTap: _openEdit,
              );
            },
          ),
        );
      },
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.items,
    required this.emptyLabel,
    required this.onToggle,
    required this.onTap,
  });

  final List<TodoItem> items;
  final String emptyLabel;
  final ValueChanged<TodoItem> onToggle;
  final ValueChanged<TodoItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _EmptyState(label: emptyLabel);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.grey.shade200,
        indent: 60,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return _TodoTile(
          item: item,
          onToggle: () => onToggle(item),
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.onToggle,
    required this.onTap,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = item.dueDate;
    final subtitle = _buildSubtitle(item);

    final tag = item.tagColor != null ? Color(item.tagColor!) : null;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _Checkbox(
        checked: item.completed,
        onTap: onToggle,
        tagColor: tag,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: item.completed ? Colors.grey.shade500 : Colors.black,
          decoration: item.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: _isOverdue(due, item.completed)
                    ? Colors.red.shade600
                    : Colors.grey.shade600,
              ),
            ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: Colors.grey.shade400,
      ),
    );
  }

  String _buildSubtitle(TodoItem item) {
    final parts = <String>[];
    if (item.dueDate != null) parts.add(_dueLabel(item.dueDate!));
    if (item.notes != null && item.notes!.isNotEmpty) parts.add(item.notes!);
    return parts.join(' • ');
  }

  static bool _isOverdue(DateTime? due, bool completed) {
    if (completed || due == null) return false;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final thatDay = DateTime(due.year, due.month, due.day);
    return thatDay.isBefore(todayKey);
  }

  static String _dueLabel(DateTime d) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final thatDay = DateTime(d.year, d.month, d.day);
    final diff = thatDay.difference(todayKey).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    const months = [
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
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.checked,
    required this.onTap,
    this.tagColor,
  });

  final bool checked;
  final VoidCallback onTap;
  final Color? tagColor;

  @override
  Widget build(BuildContext context) {
    final accent = tagColor ?? _brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? accent : Colors.transparent,
            border: Border.all(
              color: checked ? accent : (tagColor ?? Colors.grey.shade400),
              width: 2,
            ),
          ),
          child: checked
              ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      ),
    );
  }
}
