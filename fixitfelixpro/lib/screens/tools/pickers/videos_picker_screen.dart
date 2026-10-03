import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/tools/videos/videos_bloc.dart';
import '../../../models/tools/tool_video.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Multi-select picker over the user's existing Videos tool. Pop
/// returns the chosen [ToolVideo] snapshots.
class VideosPickerScreen extends StatefulWidget {
  const VideosPickerScreen({super.key, this.initialSelectedIds = const {}});

  final Set<String> initialSelectedIds;

  @override
  State<VideosPickerScreen> createState() => _VideosPickerScreenState();
}

class _VideosPickerScreenState extends State<VideosPickerScreen> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelectedIds};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VideosBloc>().add(const VideosStartWatching());
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _addNew() async {
    await Navigator.of(context).pushNamed('/tools/videos/upload');
  }

  void _confirm(List<ToolVideo> all) {
    final picked = all.where((v) => _selected.contains(v.id)).toList();
    Navigator.of(context).pop<List<ToolVideo>>(picked);
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
        title: const Text('Attach videos'),
        actions: [
          IconButton(
            tooltip: 'Upload new',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _addNew,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<VideosBloc, VideosState>(
        builder: (context, state) {
          if (state.status == VideosStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (state.items.isEmpty) {
            return _EmptyState(onTap: _addNew);
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = state.items[i];
                    return _VideoTile(
                      video: v,
                      selected: _selected.contains(v.id),
                      onTap: () => _toggle(v.id),
                    );
                  },
                ),
              ),
              _ConfirmBar(
                count: _selected.length,
                onTap: () => _confirm(state.items),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final ToolVideo video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _brand : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 60,
                child: video.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: Icon(
                            LucideIcons.play,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: Center(
                          child: Icon(
                            LucideIcons.play,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isEmpty ? 'Untitled' : video.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      video.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CheckBadge(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _brand : Colors.transparent,
        border: Border.all(
          color: selected ? _brand : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              count == 0 ? 'Done' : 'Attach ($count)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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
          Icon(LucideIcons.video, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No videos yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload one to attach it',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Upload video'),
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
