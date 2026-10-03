import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/in_app_notification.dart';

const _brand = Color(0xFFF64C13);

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final InAppNotification notification;

  String? get _imageUrl {
    final p = notification.payload;
    if (p == null) return null;
    final v = p['imageUrl'] ?? p['image_url'] ?? p['image'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Notification'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: _brand),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.imageOff,
                    size: 32,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            notification.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(notification.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SelectableText(
            notification.body,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime t) {
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
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month]} ${t.year}, $h:$m';
  }
}
