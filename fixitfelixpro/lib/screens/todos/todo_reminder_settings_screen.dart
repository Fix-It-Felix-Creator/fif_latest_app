import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_toasts.dart';
import '../../repositories/todos/todo_reminder_repository.dart';
import '../../services/todo_reminder_service.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class TodoReminderSettingsScreen extends StatefulWidget {
  const TodoReminderSettingsScreen({super.key});

  @override
  State<TodoReminderSettingsScreen> createState() =>
      _TodoReminderSettingsScreenState();
}

class _TodoReminderSettingsScreenState
    extends State<TodoReminderSettingsScreen> {
  final _repo = TodoReminderRepository();

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 21, minute: 0);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await _repo.load();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.enabled;
      _time = TimeOfDay(hour: prefs.hour, minute: prefs.minute);
      _titleCtrl.text = prefs.title;
      _bodyCtrl.text = prefs.body;
      _loading = false;
    });
  }

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleCtrl.text.trim().isEmpty
        ? TodoReminderPrefs.defaults.title
        : _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim().isEmpty
        ? TodoReminderPrefs.defaults.body
        : _bodyCtrl.text.trim();

    setState(() => _saving = true);
    final prefs = TodoReminderPrefs(
      enabled: _enabled,
      hour: _time.hour,
      minute: _time.minute,
      title: title,
      body: body,
    );

    final ok = await _repo.save(prefs);
    if (!ok) {
      if (!mounted) return;
      setState(() => _saving = false);
      CommonToasts.error(context, 'Could not save reminder');
      return;
    }

    final service = TodoReminderService.instance;
    if (_enabled) {
      await service.schedule(
        hour: _time.hour,
        minute: _time.minute,
        title: title,
        body: body,
      );
    } else {
      await service.cancel();
    }

    if (!mounted) return;
    setState(() => _saving = false);
    CommonToasts.success(context, 'Reminder updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Reminder'),
        actions: [
          TextButton(
            onPressed: (_saving || _loading) ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: (_saving || _loading) ? Colors.grey : _brand,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // Toggle + time
                  _Group(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ToggleRow(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                        if (_enabled)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey.shade200,
                            indent: 16,
                          ),
                        if (_enabled)
                          _TimeRow(time: _time, onTap: _pickTime),
                      ],
                    ),
                  ),

                  // Title
                  _Group(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: TextField(
                        controller: _titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  // Message
                  _Group(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: TextField(
                        controller: _bodyCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 2,
                        maxLines: 4,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(240),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            LucideIcons.bell,
            size: 18,
            color: value ? _brand : Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Daily reminder',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ShadSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.onTap});
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _format(time);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.clock, size: 18, color: _brand),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(TimeOfDay t) {
    final h = t.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hour12:$mm $ampm';
  }
}
