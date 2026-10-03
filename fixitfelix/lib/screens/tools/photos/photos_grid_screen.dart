import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../blocs/tools/photos/photos_bloc.dart';
import '../../../blocs/tools/photos/photos_event.dart';
import '../../../blocs/tools/photos/photos_state.dart';
import 'photo_viewer_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

class PhotosGridScreen extends StatefulWidget {
  const PhotosGridScreen({super.key});

  @override
  State<PhotosGridScreen> createState() => _PhotosGridScreenState();
}

class _PhotosGridScreenState extends State<PhotosGridScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PhotosBloc>().add(const PhotosStartWatching());
    });
  }

  Future<void> _add() async {
    await Navigator.of(context).pushNamed('/tools/photos/upload');
  }

  void _open(int index) {
    final items = context.read<PhotosBloc>().state.items;
    Navigator.of(context).pushNamed(
      '/tools/photos/view',
      arguments: PhotoViewerArgs(photos: items, initialIndex: index),
    );
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
        title: const Text('Photos'),
        actions: [
          IconButton(
            tooltip: 'Upload photo',
            icon: const Icon(LucideIcons.plus, color: _brand),
            onPressed: _add,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<PhotosBloc, PhotosState>(
        builder: (context, state) {
          if (state.status == PhotosStatus.loading && state.items.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }
          if (state.items.isEmpty) {
            return _EmptyState(onTap: _add);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: state.items.length,
            itemBuilder: (_, i) {
              final p = state.items[i];
              return InkWell(
                onTap: () => _open(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: p.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          LucideIcons.imageOff,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (p.title.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Color(0xCC000000),
                                ],
                              ),
                            ),
                            child: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
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
          Icon(LucideIcons.image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No photos yet',
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
            label: const Text('Upload photo'),
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
