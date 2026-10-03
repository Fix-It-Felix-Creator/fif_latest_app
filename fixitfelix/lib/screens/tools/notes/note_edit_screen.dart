import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../models/tools/tool_note.dart';
import '../../../repositories/tools/notes_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

/// Route argument for `/tools/notes/edit`. `existing` makes it open
/// in edit mode and pre-fills the fields.
class NoteEditArgs {
  const NoteEditArgs({this.existing});
  final ToolNote? existing;
}

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.existing});

  final ToolNote? existing;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _bodyCtrl.text = existing.body;
    }
    _titleCtrl.addListener(() => setState(() {}));
    _bodyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final existing = widget.existing;
    if (existing == null) {
      return _titleCtrl.text.trim().isNotEmpty ||
          _bodyCtrl.text.trim().isNotEmpty;
    }
    return _titleCtrl.text != existing.title ||
        _bodyCtrl.text != existing.body;
  }

  bool get _canSave =>
      !_saving &&
      _hasChanges &&
      (_titleCtrl.text.trim().isNotEmpty ||
          _bodyCtrl.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final repo = NotesRepository();
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final existing = widget.existing;
    final ok = existing == null
        ? (await repo.create(title: title, body: body)) != null
        : await repo.update(existing.copyWith(
            title: title,
            body: body,
            updatedAt: DateTime.now(),
          ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      CommonToasts.error(context, 'Could not save the note');
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    bool discard = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes on this note.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  Future<void> _onBack() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmDiscard();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _hasChanges;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: _onBack,
          ),
          title: Text(widget.existing == null ? 'New note' : 'Edit note'),
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brand,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _canSave ? _brand : Colors.grey.shade400,
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _titleCtrl,
                  focusNode: _titleFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _bodyFocus.requestFocus(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: _hintStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _bodyCtrl,
                  focusNode: _bodyFocus,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 8,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Note',
                    hintStyle: _hintStyle,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
