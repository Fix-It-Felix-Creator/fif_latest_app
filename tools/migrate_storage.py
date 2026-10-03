#!/usr/bin/env python3
"""
Copy Firebase Storage objects into Supabase Storage.

    python3 tools/migrate_storage.py --target dev [--dry-run]

Path remapping
--------------
Firebase keys embed the FIREBASE uid:

    users/{firebase_uid}/tools/photos/{id}/{file}

The Supabase storage policies scope a user to their own prefix by comparing
the second path segment to `auth.uid()`, which is the SUPABASE uuid. Copying
the keys verbatim would therefore upload files the owner cannot read — the
policy would deny them their own photos.

So every key is rewritten to the migrated uuid, and the matching `tool_assets`
row is updated to point at the new key and a fresh signed URL. The old
`firebasestorage.googleapis.com` URLs stop working once the Firebase project
is retired, so leaving them in place would silently break the images.
"""

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DATA = Path('.migration-data')
BUCKET = 'user-tools'
TEN_YEARS = 60 * 60 * 24 * 365 * 10


def req(method, url, key, body=None, headers=None, raw=False):
    r = urllib.request.Request(url, method=method, data=body)
    r.add_header('apikey', key)
    r.add_header('Authorization', f'Bearer {key}')
    for k, v in (headers or {}).items():
        r.add_header(k, v)
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            data = resp.read()
            if raw:
                return data
            return json.loads(data.decode()) if data else None
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {url} -> {e.code}: {e.read().decode()[:300]}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--target', choices=['dev', 'prod'], required=True)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    base = os.environ.get(f'SUPABASE_{args.target.upper()}_URL')
    key = os.environ.get(f'SUPABASE_{args.target.upper()}_SERVICE_KEY')
    if not base or not key:
        sys.exit(f'set SUPABASE_{args.target.upper()}_URL and _SERVICE_KEY')
    base = base.rstrip('/')

    uid_map = json.loads((DATA / f'uid-map-{args.target}.json').read_text())
    rtdb = json.loads((DATA / 'rtdb-production.json').read_text())

    # Collect (firebase_path, download_url) pairs from the tool assets.
    jobs = []
    for fb_uid, groups in (rtdb.get('userTools') or {}).items():
        sid = uid_map.get(fb_uid)
        if not sid:
            continue
        for group in ('photos', 'videos', 'files'):
            for asset_key, it in (groups.get(group) or {}).items():
                if not isinstance(it, dict):
                    continue
                for path_field, url_field in (
                    ('storagePath', 'url'),
                    ('thumbnailStoragePath', 'thumbnailUrl'),
                ):
                    old = it.get(path_field)
                    url = it.get(url_field)
                    if not old or not url:
                        continue
                    # users/{fb_uid}/... -> users/{supabase_uuid}/...
                    new = old.replace(f'users/{fb_uid}/', f'users/{sid}/', 1)
                    jobs.append({
                        'fb_uid': fb_uid, 'sid': sid, 'group': group,
                        'asset_key': asset_key, 'old': old, 'new': new,
                        'url': url, 'is_thumb': path_field.startswith('thumb'),
                    })

    print(f'== {"DRY RUN" if args.dry_run else "LIVE"} -> {args.target} ==')
    print(f'{len(jobs)} object(s) to copy\n')

    copied = failed = 0
    for j in jobs:
        print(f'  {j["old"][:70]}...')
        print(f'    -> {j["new"][:70]}...')
        if args.dry_run:
            copied += 1
            continue

        try:
            blob = req('GET', j['url'], key, raw=True)
        except Exception as e:
            print(f'    DOWNLOAD FAILED: {e}')
            failed += 1
            continue

        ctype = mimetypes.guess_type(j['new'])[0] or 'application/octet-stream'
        up = f'{base}/storage/v1/object/{BUCKET}/{urllib.parse.quote(j["new"])}'
        try:
            # x-upsert so a re-run replaces rather than erroring on a
            # duplicate — the whole script must stay idempotent.
            req('POST', up, key, blob, {
                'Content-Type': ctype, 'x-upsert': 'true'})
        except Exception as e:
            print(f'    UPLOAD FAILED: {e}')
            failed += 1
            continue

        # Point the row at the new key and a fresh signed URL. The old
        # firebasestorage URL dies with the Firebase project.
        try:
            signed = req(
                'POST',
                f'{base}/storage/v1/object/sign/{BUCKET}/{urllib.parse.quote(j["new"])}',
                key, json.dumps({'expiresIn': TEN_YEARS}).encode(),
                {'Content-Type': 'application/json'})
            signed_url = base + '/storage/v1' + signed['signedURL']

            import uuid as _uuid
            ns = _uuid.UUID('6f1a1c3e-1f2b-4a5c-9d7e-000000000001')
            row_id = str(_uuid.uuid5(
                ns, '|'.join(['tool', j['sid'], j['group'], j['asset_key']])))

            patch = ({'thumbnail_storage_path': j['new'],
                      'thumbnail_url': signed_url}
                     if j['is_thumb'] else
                     {'storage_path': j['new'], 'url': signed_url})
            req('PATCH',
                f'{base}/rest/v1/tool_assets?id=eq.{row_id}',
                key, json.dumps(patch).encode(),
                {'Content-Type': 'application/json',
                 'Prefer': 'return=minimal'})
        except Exception as e:
            print(f'    ROW UPDATE FAILED: {e}')
            failed += 1
            continue

        copied += 1
        print('    ok')

    print(f'\ncopied {copied}, failed {failed}')
    if args.dry_run:
        print('DRY RUN — nothing was written.')


if __name__ == '__main__':
    main()
