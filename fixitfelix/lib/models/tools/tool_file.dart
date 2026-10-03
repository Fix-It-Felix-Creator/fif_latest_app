import 'package:equatable/equatable.dart';

/// A single uploaded file (PDF, doc, spreadsheet, etc.) in the Files
/// tool. RTDB metadata at `/userTools/{uid}/files/{fileId}` and
/// binary at Firebase Storage `users/{uid}/tools/files/{fileId}/{fileName}`.
class ToolFile extends Equatable {
  const ToolFile({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  Map<String, dynamic> toRtdb() => {
    'title': title,
    'description': description,
    'url': url,
    'storagePath': storagePath,
    'fileName': fileName,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ToolFile.fromRtdb(String id, Map<dynamic, dynamic> raw) {
    return ToolFile(
      id: id,
      title: raw['title']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      url: raw['url']?.toString() ?? '',
      storagePath: raw['storagePath']?.toString() ?? '',
      fileName: raw['fileName']?.toString() ?? '',
      mimeType: raw['mimeType']?.toString() ?? '',
      sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Crude family for icon picking — actual download/open uses
  /// the full mimeType.
  String get family {
    final m = mimeType.toLowerCase();
    if (m.contains('pdf')) return 'pdf';
    if (m.contains('image')) return 'image';
    if (m.contains('word') || fileName.toLowerCase().endsWith('.docx')) {
      return 'doc';
    }
    if (m.contains('sheet') ||
        m.contains('excel') ||
        fileName.toLowerCase().endsWith('.xlsx')) {
      return 'sheet';
    }
    if (m.contains('zip') ||
        fileName.toLowerCase().endsWith('.zip')) {
      return 'archive';
    }
    return 'file';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        url,
        storagePath,
        fileName,
        mimeType,
        sizeBytes,
        createdAt,
      ];
}
