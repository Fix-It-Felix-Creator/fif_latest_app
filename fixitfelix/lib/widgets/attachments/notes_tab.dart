import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/tools/tool_note.dart';

const _brand = Color(0xFFF64C13);

/// Notes tab body shared by quote + invoice screens. Shows attached
/// note snapshots with an "Add" button that opens [NotesPickerScreen].
class NotesTab extends StatelessWidget {
  const NotesTab({
    super.key,
    required this.notes,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ToolNote> notes;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        Row(
          children: [
            const Icon(LucideIcons.notebookPen, size: 18, color: _brand),
            const SizedBox(width: 8),
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '(${notes.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const Spacer(),
            if (!readOnly)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16, color: _brand),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.notebookPen,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attach notes from your Tools section.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final n in notes) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title.isEmpty ? 'Untitled' : n.title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (n.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            n.body.trim(),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!readOnly) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () => onRemove(n.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
