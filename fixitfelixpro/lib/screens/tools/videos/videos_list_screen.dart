import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/tools/videos/videos_bloc.dart';
import '../../../models/tools/tool_video.dart';
import 'video_player_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class VideosListScreen extends StatefulWidget {
  const VideosListScreen({super.key});

  @override
  State<VideosListScreen> createState() => _VideosListScreenState();
}

class _VideosListScreenState extends State<VideosListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VideosBloc>().add(const VideosStartWatching());
    });
  }

  Future<void> _add() async {
    await Navigator.of(context).pushNamed('/tools/videos/upload');
  }

  void _open(int index) {
    final items = context.read<VideosBloc>().state.items;
    Navigator.of(context).pushNamed(
      '/tools/videos/view',
      arguments: VideoPlayerArgs(videos: items, initialIndex: index),
    );
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
        title: const Text('Videos'),
        actions: [
          IconButton(
            tooltip: 'Upload video',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _add,
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
            return _EmptyState(onTap: _add);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: state.items.length,
            itemBuilder: (_, i) {
              final v = state.items[i];
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        _Thumb(video: v),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title.trim().isEmpty
                                    ? 'Untitled'
                                    : v.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              if (v.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  v.description,
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
                                _fmtSize(v.sizeBytes),
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
              );
            },
          );
        },
      ),
    );
  }
}

/// Row thumbnail. Renders the first-frame poster when available
/// (newer uploads), falls back to a play-icon tile for legacy rows
/// where `thumbnailUrl` was never recorded. The play badge sits on
/// top of the poster either way so users immediately recognise
/// these as videos rather than photos.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.video});
  final ToolVideo video;

  static const _accent = Color(0xFFF43F5E);

  @override
  Widget build(BuildContext context) {
    final url = video.thumbnailUrl;
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: _accent.withValues(alpha: 0.12),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: _accent.withValues(alpha: 0.12),
                ),
              )
            else
              Container(color: _accent.withValues(alpha: 0.12)),
            // Centred play badge — semi-opaque pill so the icon
            // stays legible against any underlying frame.
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.play,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
            'Tap + to upload your first',
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
