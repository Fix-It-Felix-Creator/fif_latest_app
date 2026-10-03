import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../models/tools/tool_file.dart';
import '../../../repositories/tools/files_repository.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

final _hintStyle = TextStyle(
  fontSize: 14,
  color: Colors.black.withValues(alpha: 0.28),
);

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  File? _picked;
  String? _pickedFileName;
  String? _pickedMimeType;

  bool _uploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    if (f.path == null) {
      if (!mounted) return;
      CommonToasts.error(context, 'Could not read the selected file');
      return;
    }
    setState(() {
      _picked = File(f.path!);
      _pickedFileName = f.name;
      _pickedMimeType = _guessMime(f.name);
    });
  }

  String _guessMime(String fileName) {
    final n = fileName.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.doc')) return 'application/msword';
    if (n.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (n.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.txt')) return 'text/plain';
    if (n.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  bool get _canUpload =>
      !_uploading && _picked != null && _titleCtrl.text.trim().isNotEmpty;

  Future<void> _upload() async {
    if (!_canUpload) return;
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    final repo = FilesRepository();
    final result = await repo.upload(
      file: _picked!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      fileName: _pickedFileName ?? _picked!.path.split('/').last,
      mimeType: _pickedMimeType ?? 'application/octet-stream',
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result == null) {
      CommonToasts.error(context, 'Could not upload the file');
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    if (!_uploading &&
        _picked == null &&
        _titleCtrl.text.isEmpty &&
        _descCtrl.text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    bool discard = false;
    await CommonDialogs.showWarningBox(
      context,
      title: 'Discard file?',
      message: 'You haven\'t uploaded yet.',
      icon: LucideIcons.triangleAlert,
      yesText: 'Discard',
      noText: 'Keep editing',
      onConfirm: () => discard = true,
    );
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final size = _picked == null ? 0 : _picked!.lengthSync();
    final fakePreview = _picked == null
        ? null
        : ToolFile(
            id: 'preview',
            title: '',
            description: '',
            url: '',
            storagePath: '',
            fileName: _pickedFileName ?? '',
            mimeType: _pickedMimeType ?? '',
            sizeBytes: size,
            createdAt: DateTime.now(),
          );
    return PopScope(
      canPop: !_uploading && _picked == null && _titleCtrl.text.isEmpty,
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
            onPressed: _uploading ? null : _confirmDiscard,
          ),
          title: const Text('New file'),
          actions: [
            TextButton(
              onPressed: _canUpload ? _upload : null,
              child: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brand,
                      ),
                    )
                  : Text(
                      'Upload',
                      style: TextStyle(
                        color: _canUpload ? _brand : Colors.grey.shade400,
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
            children: [
              InkWell(
                onTap: _uploading ? null : _pick,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: _picked == null
                      ? Row(
                          children: [
                            Icon(
                              LucideIcons.filePlus,
                              size: 28,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Tap to choose a file',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _iconFor(fakePreview!),
                                color: const Color(0xFF14B8A6),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFileName ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtSize(size),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_uploading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: _brand,
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
              const SizedBox(height: 14),
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
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  enabled: !_uploading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: _hintStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                  controller: _descCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  enabled: !_uploading,
                  minLines: 3,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
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

  IconData _iconFor(ToolFile f) {
    switch (f.family) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'image':
        return LucideIcons.fileImage;
      case 'doc':
        return LucideIcons.fileText;
      case 'sheet':
        return LucideIcons.fileSpreadsheet;
      case 'archive':
        return LucideIcons.fileArchive;
      default:
        return LucideIcons.file;
    }
  }
}
