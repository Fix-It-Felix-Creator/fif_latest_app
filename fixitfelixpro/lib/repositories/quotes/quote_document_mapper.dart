import '../../core/enum.dart';
import '../../models/customer.dart';
import '../../models/pricing_item.dart';
import '../../models/quote_line_draft.dart';
import '../../models/quote_staff_draft.dart';
import '../../models/quote_term_model.dart';
import '../../models/staff.dart';
import '../../models/tools/tool_file.dart';
import '../../models/tools/tool_note.dart';
import '../../models/tools/tool_photo.dart';
import '../../models/tools/tool_video.dart';
import '../base/owned_collection_repository.dart';

/// Shared row mapping for the two document types that have identical child
/// shapes: quotes and invoices.
///
/// RTDB denormalised the FULL `PricingItem` and `Staff` objects into every
/// line so a saved quote survived the source record changing or being deleted.
/// The normalised tables keep only what a document actually needs —
/// `item_name` / `item_code` / rate, and `staff_name` / rate — plus a nullable
/// FK back to the source.
///
/// Verified that is lossless from the UI's point of view: across every screen,
/// widget and PDF service the only fields read off these nested objects are
/// `.item.name` (12 sites) and `.staff.name` (10 sites). Nothing reads a
/// staff member's email or an item's unit cost from a saved document.
class QuoteDocumentMapper {
  const QuoteDocumentMapper._();

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  /// `line_total` is deliberately absent: it is a GENERATED ALWAYS column
  /// computed by Postgres from rate/markup/discount/quantity, using the same
  /// formula as [QuoteLineDraft.lineTotal].
  static Map<String, dynamic> lineToJson(QuoteLineDraft l) => {
        'kind': l.kind.wire,
        'pricing_item_id': _uuidOrNull(l.item.id),
        'item_name': l.item.name,
        'item_code': l.item.itemCode,
        'rate': l.rate,
        'unit_markup': l.unitMarkup,
        'discount': l.discount,
        'quantity': l.quantity,
      };

  static QuoteLineDraft lineFromRow(Map<String, dynamic> row) {
    final kind = PricingKindX.fromWire(row['kind']?.toString());
    return QuoteLineDraft(
      id: row['id']?.toString() ?? OwnedCollectionRepository.newId(),
      kind: kind,
      // Rebuilt from the columns the document stores. `unitCost` mirrors the
      // line's rate, which is what the source item contributed.
      item: PricingItem(
        id: row['pricing_item_id']?.toString() ?? '',
        kind: kind,
        name: row['item_name']?.toString() ?? '',
        unitCost: (row['rate'] as num?)?.toDouble() ?? 0,
        unitMarkup: (row['unit_markup'] as num?)?.toDouble() ?? 0,
        itemCode: row['item_code']?.toString() ?? '',
      ),
      rate: (row['rate'] as num?)?.toDouble() ?? 0,
      unitMarkup: (row['unit_markup'] as num?)?.toDouble() ?? 0,
      discount: (row['discount'] as num?)?.toDouble() ?? 0,
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Labour lines
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> labourToJson(QuoteStaffDraft s) => {
        'staff_id': _uuidOrNull(s.staff.id),
        'staff_name': s.staff.name,
        'pay_type': s.payType.wire,
        'rate_type': s.rateType.wire,
        'rate': s.rate,
        'quantity': s.quantity,
      };

  static QuoteStaffDraft labourFromRow(Map<String, dynamic> row) =>
      QuoteStaffDraft(
        id: row['id']?.toString() ?? OwnedCollectionRepository.newId(),
        payType: StaffPayTypeX.fromWire(row['pay_type']?.toString()),
        rateType: LabourRateTypeX.fromWire(row['rate_type']?.toString()),
        rate: (row['rate'] as num?)?.toDouble() ?? 0,
        quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        staff: Staff(
          id: row['staff_id']?.toString() ?? '',
          name: row['staff_name']?.toString() ?? '',
          defaultPayType: StaffPayTypeX.fromWire(row['pay_type']?.toString()),
          rate: (row['rate'] as num?)?.toDouble() ?? 0,
        ),
      );

  // ---------------------------------------------------------------------------
  // Terms
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> termToJson(QuoteTerm t) => {
        'term_id': _uuidOrNull(t.id),
        'name': t.name,
        'details': t.details,
      };

  static QuoteTerm termFromRow(Map<String, dynamic> row) => QuoteTerm(
        id: row['term_id']?.toString() ?? row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        details: row['details']?.toString() ?? '',
        createdAt: OwnedCollectionRepository.parseTsOr(
            row['created_at'], DateTime.now()),
        updatedAt: OwnedCollectionRepository.parseTsOr(
            row['created_at'], DateTime.now()),
      );

  // ---------------------------------------------------------------------------
  // Attachments — the four Tools kinds share one child table
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> photoToJson(ToolPhoto p) => {
        'kind': 'photo',
        'tool_asset_id': _uuidOrNull(p.id),
        'title': p.title,
        'description': p.description,
        'url': p.url,
        'storage_path': p.storagePath,
        'size_bytes': p.sizeBytes,
      };

  static Map<String, dynamic> videoToJson(ToolVideo v) => {
        'kind': 'video',
        'tool_asset_id': _uuidOrNull(v.id),
        'title': v.title,
        'description': v.description,
        'url': v.url,
        'storage_path': v.storagePath,
        'size_bytes': v.sizeBytes,
        'thumbnail_url': v.thumbnailUrl,
        'thumbnail_storage_path': v.thumbnailStoragePath,
      };

  static Map<String, dynamic> fileToJson(ToolFile f) => {
        'kind': 'file',
        'tool_asset_id': _uuidOrNull(f.id),
        'title': f.title,
        'description': f.description,
        'url': f.url,
        'storage_path': f.storagePath,
        'file_name': f.fileName,
        'mime_type': f.mimeType,
        'size_bytes': f.sizeBytes,
      };

  static Map<String, dynamic> noteToJson(ToolNote n) => {
        'kind': 'note',
        'tool_asset_id': _uuidOrNull(n.id),
        'title': n.title,
        'body': n.body,
      };

  static ToolPhoto photoFromRow(Map<String, dynamic> r) => ToolPhoto(
        id: r['tool_asset_id']?.toString() ?? r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        url: r['url']?.toString() ?? '',
        storagePath: r['storage_path']?.toString() ?? '',
        sizeBytes: (r['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: OwnedCollectionRepository.parseTsOr(
            r['created_at'], DateTime.now()),
      );

  static ToolVideo videoFromRow(Map<String, dynamic> r) => ToolVideo(
        id: r['tool_asset_id']?.toString() ?? r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        url: r['url']?.toString() ?? '',
        storagePath: r['storage_path']?.toString() ?? '',
        sizeBytes: (r['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: OwnedCollectionRepository.parseTsOr(
            r['created_at'], DateTime.now()),
        thumbnailUrl: r['thumbnail_url']?.toString(),
        thumbnailStoragePath: r['thumbnail_storage_path']?.toString(),
      );

  static ToolFile fileFromRow(Map<String, dynamic> r) => ToolFile(
        id: r['tool_asset_id']?.toString() ?? r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        url: r['url']?.toString() ?? '',
        storagePath: r['storage_path']?.toString() ?? '',
        fileName: r['file_name']?.toString() ?? '',
        mimeType: r['mime_type']?.toString() ?? '',
        sizeBytes: (r['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: OwnedCollectionRepository.parseTsOr(
            r['created_at'], DateTime.now()),
      );

  static ToolNote noteFromRow(Map<String, dynamic> r) => ToolNote(
        id: r['tool_asset_id']?.toString() ?? r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        body: r['body']?.toString() ?? '',
        createdAt: OwnedCollectionRepository.parseTsOr(
            r['created_at'], DateTime.now()),
        updatedAt: OwnedCollectionRepository.parseTsOr(
            r['created_at'], DateTime.now()),
      );

  // ---------------------------------------------------------------------------
  // Customer snapshot — still denormalised, because a quote must survive its
  // customer being edited or deleted, and the whole record is displayed.
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> customerToJson(Customer c) => {
        'id': c.id,
        ...c.toJson(),
      };

  static Customer? customerFromSnapshot(Object? raw, String fallbackId) {
    if (raw is! Map) return null;
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    return Customer.fromJson(json, json['id']?.toString() ?? fallbackId);
  }

  /// FK columns are `uuid`; RTDB ids were push keys and drafts use synthetic
  /// microsecond ids, neither of which is a UUID. Anything that isn't one is
  /// stored as null so the insert cannot fail — the human-readable name and
  /// code are kept alongside regardless.
  static String? _uuidOrNull(String? id) {
    if (id == null || id.isEmpty) return null;
    final re = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return re.hasMatch(id) ? id : null;
  }
}
