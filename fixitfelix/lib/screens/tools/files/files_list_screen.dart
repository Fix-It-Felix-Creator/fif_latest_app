import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blocs/tools/files/files_bloc.dart';
import '../../../core/utils/common_dialogs.dart';
import '../../../core/utils/common_toasts.dart';
import '../../../models/tools/tool_file.dart';
import '../../shared/webview_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class FilesListScreen extends StatefulWidget {
  const FilesListScreen({super.key});

  @override
  State<FilesListScreen> createState() => _FilesListScreenState();
}

class _FilesListScreenState extends State<FilesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FilesBloc>().add(const FilesStartWatching());
    });
  }

  Future<void> _add() async {
    await Navigator.of(context).pushNamed('/tools/files/upload');
  }

  Future<void> _open(ToolFile f) async {
    // PDFs render fine inline in the existing WebView; everything
    // else hands off to the OS so the user can choose a viewer
    // (Numbers, Pages, etc.) from the share sheet.
    if (f.family == 'pdf') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WebViewScreen(
            url: f.url,
            title: f.title.isEmpty ? f.fileName : f.title,
          ),
        ),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(f.url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      CommonToasts.error(context, 'No app available to open this file');
    }
  }

  Future<void> _confirmDelete(ToolFile f) async {
    bool confirmed = false;
    await CommonDialogs.showErrorBox(
      context,
      title: 'Delete file?',
      message: '"${f.fileName}" will be removed permanently.',
      icon: LucideIcons.trash2,
      yesText: 'Delete',
      noText: 'Cancel',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    context.read<FilesBloc>().add(FileDeleteRequested(f));
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Files'),
        actions: [
          IconButton(
            tooltip: 'Upload file',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _add,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<FilesBloc, FilesState>(
        builder: (context, state) {
          if (state.status == FilesStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (state.items.isEmpty) {
            return _EmptyState(onTap: _add);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: state.items.length,
            itemBuilder: (_, i) {
              final f = state.items[i];
              return Dismissible(
                key: ValueKey('file-${f.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _confirmDelete(f);
                  return false;
                },
                background: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  child: const Icon(LucideIcons.trash2, color: Colors.white),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(f),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
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
                              _iconFor(f),
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
                                  f.title.trim().isEmpty
                                      ? f.fileName
                                      : f.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (f.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    f.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '${f.fileName}  ·  ${_fmtSize(f.sizeBytes)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.fileText, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No files yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to upload your first',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Upload file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand,
              side: const BorderSide(color: _brand),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
