import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Tradesman bottom-nav Tools tab. A 4-tile picker that pushes into
/// each tool's own list (notes / photos / videos / files).
///
/// No back button — this is a tab, not a pushed route. Tap a tile →
/// the tool's list screen pushes onto the navigator inside the tab.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool(
        icon: LucideIcons.notepadText,
        label: 'Notes',
        subtitle: 'Quick titled notes',
        color: const Color(0xFF6366F1),
        route: '/tools/notes',
      ),
      _Tool(
        icon: LucideIcons.image,
        label: 'Photos',
        subtitle: 'Job photos',
        color: const Color(0xFF8B5CF6),
        route: '/tools/photos',
      ),
      _Tool(
        icon: LucideIcons.video,
        label: 'Videos',
        subtitle: 'Recorded clips',
        color: const Color(0xFFF43F5E),
        route: '/tools/videos',
      ),
      _Tool(
        icon: LucideIcons.fileText,
        label: 'Files',
        subtitle: 'PDFs and documents',
        color: const Color(0xFF14B8A6),
        route: '/tools/files',
      ),
    ];

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Tools'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tools.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (_, i) => _ToolCard(tool: tools[i]),
      ),
    );
  }
}

class _Tool {
  const _Tool({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(tool.route),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tool.icon, size: 22, color: tool.color),
              ),
              const Spacer(),
              Text(
                tool.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _brand,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: _brand,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
