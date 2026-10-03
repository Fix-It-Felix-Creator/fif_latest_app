import { admin, callerIp, json, rateLimit } from '../lib/context.ts';

/**
 * Streams an attachment belonging to a shared quote/invoice, rather than
 * handing the customer a raw storage URL.
 *
 * The share token in the URL is the only auth — the same model as the viewer
 * pages. The asset id MUST appear on that document's attachments; otherwise
 * it is a 404. That is what keeps the rest of the tradesperson's storage tree
 * (other quotes' attachments, unrelated notes) unreachable through this
 * endpoint, and it is the reason the lookup below joins through the document
 * instead of querying the asset directly.
 *
 * Two URL shapes, preserved from the original:
 *   /q/:token/v/:kind/:id — inline, used by <img> / <video> srcs
 *   /q/:token/d/:kind/:id — Content-Disposition: attachment
 */

type Kind = 'photo' | 'video' | 'file' | 'thumb';

const BUCKETS = ['user-tools', 'user-documents'];

export async function sharedAsset(
  req: Request,
  token: string,
  mode: string,
  kind: string,
  assetId: string,
  docKind: 'quote' | 'invoice',
): Promise<Response> {
  if (mode !== 'v' && mode !== 'd') {
    return json({ message: 'Not found' }, 404);
  }

  if (!await rateLimit(`asset:${callerIp(req)}`, 240)) {
    return json({ message: 'Too many requests' }, 429);
  }

  try {
    const idCol = docKind === 'quote' ? 'quote_id' : 'invoice_id';
    const attachTable = docKind === 'quote'
      ? 'quote_attachments'
      : 'invoice_attachments';

    const { data: share } = await admin()
      .from('document_shares')
      .select(`owner_id, ${idCol}, deleted_at`)
      .eq('token', token)
      .maybeSingle();

    if (!share || share.deleted_at) return json({ message: 'Not found' }, 404);

    const docId = (share as Record<string, unknown>)[idCol];
    if (!docId) return json({ message: 'Not found' }, 404);

    // Scoped to THIS document: an attachment id from another quote will not
    // match, which is the whole access control here.
    const wantKind: Kind = kind === 'thumb' ? 'video' : (kind as Kind);
    const { data: asset } = await admin()
      .from(attachTable)
      .select('kind, title, file_name, mime_type, storage_path, thumbnail_storage_path')
      .eq(idCol, docId)
      .eq('tool_asset_id', assetId)
      .eq('kind', wantKind)
      .maybeSingle();

    if (!asset) return json({ message: 'Not found' }, 404);

    const path = kind === 'thumb'
      ? asset.thumbnail_storage_path as string | null
      : asset.storage_path as string | null;

    if (!path) return json({ message: 'Not found' }, 404);

    // The object may live in either bucket depending on how it was attached
    // (Tools upload vs profile document), and the row does not record which.
    let blob: Blob | null = null;
    for (const bucket of BUCKETS) {
      const { data } = await admin().storage.from(bucket).download(path);
      if (data) {
        blob = data;
        break;
      }
    }

    if (!blob) return json({ message: 'Not found' }, 404);

    const filename = (asset.file_name as string) ??
      (asset.title as string) ?? 'attachment';
    const contentType = (asset.mime_type as string) ??
      blob.type ?? 'application/octet-stream';

    return new Response(blob, {
      status: 200,
      headers: {
        'Content-Type': kind === 'thumb' ? 'image/jpeg' : contentType,
        'Content-Disposition': mode === 'd'
          ? `attachment; filename="${filename.replace(/"/g, '')}"`
          : 'inline',
        // Immutable: an attachment id maps to one object for the life of the
        // share, so the customer's browser need not re-fetch it.
        'Cache-Control': 'private, max-age=3600',
      },
    });
  } catch (err) {
    console.error('sharedAsset failed', token, String(err));
    return json({ message: 'Not found' }, 404);
  }
}
