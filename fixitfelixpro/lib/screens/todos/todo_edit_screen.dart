import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/common_dialogs.dart';
import '../../core/utils/common_toasts.dart';
import '../../models/todo_item.dart';
import '../../repositories/todos/todo_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Approximate word-count cap for the notes field (~500 words).
const _notesMaxChars = 3000;

class TodoEditScreen extends StatefulWidget {
  const TodoEditScreen({super.key, this.existing});

  final TodoItem? existing;

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();

  DateTime? _dueDate;
  int? _tagColor;
  bool _completed = false;
  bool _saving = false;
  bool _deleting = false;
  bool _focusScheduled = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    if (_isEditing) {
      _dueDate = widget.existing!.dueDate;
      _tagColor = widget.existing!.tagColor;
      _completed = widget.existing!.completed;
    } else {
      // Default new to-dos to today.
      final now = DateTime.now();
      _dueDate = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Focus the title field only AFTER the page-transition animation
    // completes. Raising the keyboard mid-animation makes the push feel
    // sluggish on iOS.
    if (_focusScheduled || _isEditing) return;
    _focusScheduled = true;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(onStatus);
        if (mounted) _titleFocus.requestFocus();
      }
    }
    animation.addStatusListener(onStatus);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      CommonToasts.error(context, 'Enter a title');
      return;
    }

    setState(() => _saving = true);
    final notes = _notesCtrl.text.trim();
    final repo = context.read<TodoRepository>();
    bool ok;
    if (_isEditing) {
      ok = await repo.update(
        id: widget.existing!.id,
        title: title,
        notes: notes.isEmpty ? null : notes,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        tagColor: _tagColor,
        clearTagColor: _tagColor == null,
      );
      if (ok && _completed != widget.existing!.completed) {
        await repo.setCompleted(
          id: widget.existing!.id,
          completed: _completed,
        );
      }
    } else {
      final id = await repo.create(
        title: title,
        notes: notes.isEmpty ? null : notes,
        dueDate: _dueDate,
        tagColor: _tagColor,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      CommonToasts.error(context, 'Could not save');
    }
  }

  Future<void> _confirmDelete() async {
    if (!_isEditing || _deleting) return;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete to-do?',
      message: '"${widget.existing!.title}" will be removed.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: _delete,
    );
  }

  Future<void> _delete() async {
    if (!mounted) return;
    setState(() => _deleting = true);
    final ok = await context.read<TodoRepository>().delete(widget.existing!.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      CommonToasts.error(context, 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _wordCount(_notesCtrl.text);

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_isEditing ? 'Edit to-do' : 'New to-do'),
        actions: [
          TextButton(
            onPressed: (_saving || _deleting) ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: (_saving || _deleting) ? Colors.grey : _brand,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // Title
            _Group(
              child: TextField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _notesFocus.requestFocus(),
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // Due date
            _Group(
              child: _DueDateRow(
                dueDate: _dueDate,
                onTap: _pickDate,
                onClear: () => setState(() => _dueDate = null),
              ),
            ),

            // Status toggle (edit mode only)
            if (_isEditing)
              _Group(
                child: _StatusToggleRow(
                  completed: _completed,
                  onChanged: (v) => setState(() => _completed = v),
                ),
              ),

            // Tag color swatches
            _Group(
              child: _TagColorRow(
                selected: _tagColor,
                onPick: (value) => setState(() => _tagColor = value),
              ),
            ),

            // Notes (optional)
            _Group(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _notesCtrl,
                      focusNode: _notesFocus,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 4,
                      maxLines: 10,
                      maxLength: _notesMaxChars,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_notesMaxChars),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Notes (optional)',
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$wordCount / 500 words',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed:
                      (_saving || _deleting) ? null : _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(
                    _deleting ? 'Deleting...' : 'Delete to-do',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
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

class _DueDateRow extends StatelessWidget {
  const _DueDateRow({
    required this.dueDate,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? dueDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = dueDate == null ? 'Due date (optional)' : _format(dueDate!);
    final chosen = dueDate != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                LucideIcons.calendarDays,
                size: 18,
                color: chosen ? _brand : Colors.grey.shade500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: chosen ? Colors.black : Colors.grey.shade500,
                    fontWeight:
                        chosen ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (chosen)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              else
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

  static String _format(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _StatusToggleRow extends StatelessWidget {
  const _StatusToggleRow({
    required this.completed,
    required this.onChanged,
  });

  final bool completed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            completed ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 18,
            color: completed ? _brand : Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              completed ? 'Done' : 'To do',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: completed ? _brand : Colors.black,
              ),
            ),
          ),
          ShadSwitch(value: completed, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Preset palette for to-do tag colours.
/// null = no color (default grey).
const List<Color?> _todoColorPalette = [
  null,
  Color(0xFFEF4444), // red
  Color(0xFFF64C13), // brand orange
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // green
  Color(0xFF14B8A6), // teal
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
  Color(0xFFEC4899), // pink
];

class _TagColorRow extends StatelessWidget {
  const _TagColorRow({required this.selected, required this.onPick});

  final int? selected;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.tag, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Tag colour',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _todoColorPalette)
                _ColorSwatch(
                  color: color,
                  selected: (color?.toARGB32()) == selected
                      || (color == null && selected == null),
                  onTap: () => onPick(color?.toARGB32()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.grey.shade100,
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: color == null
            ? Icon(LucideIcons.ban, size: 14, color: Colors.grey.shade500)
            : (selected
                ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                : null),
      ),
    );
  }
}
