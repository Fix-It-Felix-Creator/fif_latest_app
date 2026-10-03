#!/usr/bin/env python3
"""
Firebase -> Supabase data migration.

Reads the Firebase exports in .migration-data/ and loads them into a Supabase
project. Idempotent: every write is an upsert keyed on a stable id, so a
partial run can simply be re-run.

    python3 tools/migrate_to_supabase.py --target dev  --dry-run
    python3 tools/migrate_to_supabase.py --target dev
    python3 tools/migrate_to_supabase.py --target prod

Identity
--------
Firebase uids are 28-char strings; auth.users.id is a UUID. Rather than
inventing a mapping table, each Firebase user becomes a Supabase user whose
`profiles.firebase_uid` records where it came from. That column is also what
makes this script re-runnable: an already-migrated user is found by it.

Passwords
---------
Firebase scrypt hashes cannot be imported. Users are created WITHOUT a
password; the `auth-bridge` Edge Function verifies the old password against
Firebase on first sign-in and sets the Supabase one. Google users need nothing
— they re-link by email.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DATA = Path('.migration-data')
# Product prices, mirroring PRODUCT_PLANS in the Edge Function. Used only to
# fill the NOT NULL `price` column for records migrated from RTDB, which
# stored the plan but not its cost.
PLAN_PRICES = {
    ('standard', 'monthly'): 12.99,
    ('standard', 'yearly'): 129.99,
}

UUID_RE = re.compile(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------

class Supa:
    def __init__(self, url, service_key, dry_run=False):
        self.url = url.rstrip('/')
        self.key = service_key
        self.dry_run = dry_run
        self.writes = 0
        self._emails = None

    def _req(self, method, path, body=None, headers=None):
        req = urllib.request.Request(
            f'{self.url}{path}', method=method,
            data=json.dumps(body).encode() if body is not None else None)
        req.add_header('apikey', self.key)
        req.add_header('Authorization', f'Bearer {self.key}')
        req.add_header('Content-Type', 'application/json')
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read().decode()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode()[:400]
            raise RuntimeError(f'{method} {path} -> {e.code}: {detail}') from None

    def select(self, table, query):
        return self._req('GET', f'/rest/v1/{table}?{query}') or []

    def upsert(self, table, rows, on_conflict=None):
        """Upsert rows. Returns the number written (0 in dry-run)."""
        rows = [r for r in rows if r]
        if not rows:
            return 0
        if self.dry_run:
            return len(rows)
        path = f'/rest/v1/{table}'
        if on_conflict:
            path += f'?on_conflict={on_conflict}'
        self._req('POST', path, rows, {
            'Prefer': 'resolution=merge-duplicates,return=minimal'})
        self.writes += len(rows)
        return len(rows)

    def rpc(self, fn, params):
        if self.dry_run:
            return None
        return self._req('POST', f'/rest/v1/rpc/{fn}', params)

    # --- auth admin ---
    def email_index(self):
        """
        email (lowercased) -> user, built once by paging the admin list.

        The admin API's `filter` param does a fuzzy search rather than an exact
        match, so relying on it silently missed existing users and the create
        then failed with email_exists. Paging the whole list is exact, and at
        this scale it is one or two requests.
        """
        if self._emails is not None:
            return self._emails
        index, page = {}, 1
        while True:
            res = self._req(
                'GET', f'/auth/v1/admin/users?page={page}&per_page=200')
            users = (res or {}).get('users', [])
            if not users:
                break
            for u in users:
                em = (u.get('email') or '').lower()
                if em:
                    index[em] = u
            if len(users) < 200:
                break
            page += 1
        self._emails = index
        return index

    def find_user_by_email(self, email):
        return self.email_index().get((email or '').lower())

    def create_user(self, email, metadata, email_confirmed):
        if self.dry_run:
            return {'id': f'dry-{email}'}
        return self._req('POST', '/auth/v1/admin/users', {
            'email': email,
            'email_confirm': email_confirmed,
            'user_metadata': metadata,
        })


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def ms_to_iso(v):
    """RTDB stored timestamps as epoch millis OR ISO strings, inconsistently."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        # Values below this are seconds, not millis (a few legacy records).
        ms = v if v > 1e11 else v * 1000
        return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(ms / 1000))
    s = str(v)
    return s if s else None


def date_only(v):
    iso = ms_to_iso(v)
    return iso[:10] if iso else None


def uuid_or_none(v):
    return v if v and UUID_RE.match(str(v)) else None


def stable_uuid(*parts):
    """
    Deterministic UUIDv5 from the Firebase key.

    Deterministic rather than random so re-running the migration maps the same
    RTDB record to the same row instead of duplicating it, and so foreign keys
    between documents (a quote's customer, a job's linked quote) still line up.
    """
    import uuid
    ns = uuid.UUID('6f1a1c3e-1f2b-4a5c-9d7e-000000000001')
    return str(uuid.uuid5(ns, '|'.join(str(p) for p in parts)))


# ---------------------------------------------------------------------------
# migration
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--target', choices=['dev', 'prod'], required=True)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    url = os.environ.get(f'SUPABASE_{args.target.upper()}_URL')
    key = os.environ.get(f'SUPABASE_{args.target.upper()}_SERVICE_KEY')
    if not url or not key:
        sys.exit(f'set SUPABASE_{args.target.upper()}_URL and _SERVICE_KEY')

    supa = Supa(url, key, args.dry_run)
    auth = json.load(open(DATA / 'auth-users.json'))
    rtdb = json.load(open(DATA / 'rtdb-production.json'))

    mode = 'DRY RUN' if args.dry_run else 'LIVE'
    print(f'== {mode} -> {args.target} ({url}) ==\n')

    stats = {}

    # -- 1. users -----------------------------------------------------------
    # uid_map: firebase uid -> supabase uuid. Everything downstream needs it.
    uid_map = {}
    created = reused = skipped = 0

    for u in auth.get('users', []):
        fb_uid = u.get('localId')
        email = u.get('email')
        if not fb_uid or not email:
            skipped += 1
            continue

        # Already migrated? firebase_uid is the idempotency key.
        existing = supa.select(
            'profiles', f'firebase_uid=eq.{fb_uid}&select=id')
        if existing:
            uid_map[fb_uid] = existing[0]['id']
            reused += 1
            continue

        # Or present by email from an earlier partial run / manual signup.
        by_email = supa.find_user_by_email(email)
        if by_email:
            uid_map[fb_uid] = by_email['id']
            reused += 1
        else:
            name = u.get('displayName') or ''
            new = supa.create_user(email, {
                'full_name': name,
                'migrated_from_firebase': True,
            }, bool(u.get('emailVerified')))
            uid_map[fb_uid] = new['id']
            if self_index := supa._emails:
                self_index[email.lower()] = new
            created += 1

        if not args.dry_run:
            # Stamp provenance immediately so a crash mid-run is recoverable.
            supa.upsert('profiles', [{
                'id': uid_map[fb_uid],
                'firebase_uid': fb_uid,
                'email': email,
            }], on_conflict='id')

    stats['auth users'] = f'{created} created, {reused} reused, {skipped} skipped'

    # -- 2. profiles --------------------------------------------------------
    profiles, subs, tokens = [], [], []
    for fb_uid, p in (rtdb.get('users') or {}).items():
        sid = uid_map.get(fb_uid)
        if not sid or not isinstance(p, dict):
            continue

        addr = p.get('address') or {}
        loc = p.get('location') or {}
        company = p.get('companyDetails') or {}
        bank = company.get('bankDetails') or {}
        notif = p.get('notificationPreferences') or {}

        profiles.append({
            'id': sid,
            'firebase_uid': fb_uid,
            'email': p.get('email'),
            'first_name': p.get('firstName'),
            'last_name': p.get('lastName'),
            'phone': p.get('phoneNumber'),
            'account_type': p.get('accountType') or 'tradesman',
            'address_line1': addr.get('addressLine1'),
            'address_line2': addr.get('addressLine2'),
            'city': addr.get('city'),
            'county': addr.get('county'),
            'postcode': addr.get('postcode'),
            'formatted_address': loc.get('address'),
            'latitude': loc.get('latitude'),
            'longitude': loc.get('longitude'),
            'last_address_updated_at': ms_to_iso(p.get('lastAddressUpdatedAt')),
            'business_name': p.get('businessName'),
            'business_email': p.get('businessEmail'),
            'business_registration_id': p.get('businessRegistrationId'),
            'bio': p.get('bio'),
            'introduction_bio': p.get('introductionBio'),
            'currency': p.get('currency') or 'GBP',
            'work_status': p.get('workStatus'),
            'role': p.get('role'),
            'trade': p.get('trade') if isinstance(p.get('trade'), list) else None,
            'links': p.get('links') if isinstance(p.get('links'), list) else None,
            'profile_image_url': p.get('profileImage'),
            'national_insurance_number': p.get('nationalInsuranceNumber'),
            'document_type': p.get('documentType'),
            'document_urls': p.get('documentUrls')
                if isinstance(p.get('documentUrls'), list) else None,
            'selfie_url': p.get('selfieUrl'),
            'subscription_plan_selected': p.get('subscriptionPlanSelected'),
            'company_name': company.get('companyName'),
            'companies_house_number': company.get('companiesHouseNumber'),
            'company_email': company.get('companyEmail'),
            'company_landline': company.get('companyLandline'),
            'company_website': company.get('website'),
            'company_logo_url': company.get('companyLogoUrl'),
            'vat_registered': bool(company.get('vatRegistered')),
            'vat_number': company.get('vatNumber'),
            'bank_name': bank.get('bankName'),
            'bank_account_number': bank.get('accountNumber'),
            'bank_sort_code': bank.get('sortCode'),
            'push_enabled': notif.get('pushEnabled', True),
            'email_enabled': notif.get('emailEnabled', True),
            'sms_enabled': notif.get('smsEnabled', True),
            # verification_status / account_status are server-owned and
            # guarded; the service role may set them, and they carry real
            # meaning, so they are migrated.
            'verification_status': p.get('verificationStatus'),
            'account_status': p.get('accountStatus') or 'active',
        })

        member = ((p.get('subscription') or {}).get('member')) or {}
        if member:
            # `price` is NOT NULL, but RTDB member records never carried one —
            # it lived in the plan config. Derive it from the plan so the row
            # keeps its meaning instead of defaulting everyone to 0.
            plan_price = PLAN_PRICES.get(
                (member.get('planType') or 'standard',
                 member.get('billingCycle') or 'monthly'))
            subs.append({
                'owner_id': sid,
                'status': member.get('status') or 'expired',
                'plan_type': member.get('planType') or 'standard',
                'billing_cycle': member.get('billingCycle') or 'monthly',
                'provider': member.get('provider'),
                'name': member.get('name'),
                'price': member.get('price') if member.get('price') is not None
                    else (plan_price if plan_price is not None else 0),
                'product_id': member.get('productId'),
                'original_transaction_id': member.get('originalTransactionId'),
                'auto_renew': member.get('autoRenew', True),
                'cancel_at_period_end': member.get('cancelAtPeriodEnd', False),
                'current_period_start': ms_to_iso(member.get('currentPeriodStart')),
                'current_period_end': ms_to_iso(member.get('currentPeriodEnd')),
            })

        for entry in (p.get('fcmTokens') or {}).values():
            if isinstance(entry, dict) and entry.get('token'):
                tokens.append({
                    'owner_id': sid,
                    'token': entry['token'],
                    'platform': entry.get('platform'),
                    'last_seen_at': ms_to_iso(entry.get('lastSeenAt')),
                })

    stats['profiles'] = supa.upsert('profiles', profiles, 'id')
    stats['subscriptions'] = supa.upsert('subscriptions', subs, 'owner_id')
    stats['fcm_tokens'] = supa.upsert('fcm_tokens', tokens, 'owner_id,token')

    # -- 3. simple owner-scoped collections ---------------------------------
    def simple(node, table, fn):
        rows = []
        for fb_uid, items in (rtdb.get(node) or {}).items():
            sid = uid_map.get(fb_uid)
            if not sid or not isinstance(items, dict):
                continue
            for key, it in items.items():
                if isinstance(it, dict):
                    r = fn(sid, key, it)
                    if r:
                        rows.append(r)
        stats[table] = supa.upsert(table, rows, 'id')

    simple('customers', 'customers', lambda sid, k, c: {
        'id': stable_uuid('customer', sid, k),
        'owner_id': sid,
        'name': c.get('name') or '',
        'email': c.get('email'),
        'phone': c.get('phone'),
        'company': c.get('company'),
        'notes': c.get('notes'),
        'address_line1': c.get('addressLine1'),
        'address_line2': c.get('addressLine2'),
        'city': c.get('city'),
        'county': c.get('county'),
        'postcode': c.get('postcode'),
        'formatted_address': c.get('formattedAddress'),
        'latitude': c.get('latitude'),
        'longitude': c.get('longitude'),
        'created_at': ms_to_iso(c.get('createdAt')),
    })

    simple('staff', 'staff', lambda sid, k, s: {
        'id': stable_uuid('staff', sid, k),
        'owner_id': sid,
        'name': s.get('name') or '',
        'email': s.get('email'),
        'phone': s.get('phone'),
        'default_pay_type': s.get('defaultPayType') or 'day',
        'rate': s.get('rate') or 0,
        'weekend_rate': s.get('weekendRate') or 0,
        'emergency_rate': s.get('emergencyRate') or 0,
        'sociable_rate': s.get('sociableRate') or 0,
        'created_at': ms_to_iso(s.get('createdAt')),
    })

    simple('pricing', 'pricing_items', lambda sid, k, i: {
        'id': stable_uuid('pricing', sid, k),
        'owner_id': sid,
        'kind': i.get('kind') or 'material',
        'name': i.get('name') or '',
        'unit_cost': i.get('unitCost') or 0,
        'unit_markup': i.get('unitMarkup') or 0,
        'item_code': i.get('itemCode'),
        'created_at': ms_to_iso(i.get('createdAt')),
    })

    simple('todos', 'todos', lambda sid, k, t: {
        'id': stable_uuid('todo', sid, k),
        'owner_id': sid,
        'title': t.get('title') or '',
        'notes': t.get('notes'),
        'due_at': ms_to_iso(t.get('dueAt')),
        'completed': bool(t.get('completed')),
        'completed_at': ms_to_iso(t.get('completedAt')),
        'tag_color': t.get('tagColor'),
        'created_at': ms_to_iso(t.get('createdAt')),
    })

    simple('journalEvents', 'journal_entries', lambda sid, k, e: {
        'id': stable_uuid('journal', sid, k),
        'owner_id': sid,
        'title': e.get('title') or '',
        'entry_date': e.get('date') or date_only(e.get('createdAt')),
        'all_day': bool(e.get('allDay', True)),
        'start_at': ms_to_iso(e.get('startAt')),
        'end_at': ms_to_iso(e.get('endAt')),
        'customer_id': None,
        'customer_name': e.get('customerName'),
        'location': e.get('location'),
        'notes': e.get('notes'),
        'created_at': ms_to_iso(e.get('createdAt')),
    })

    simple('notifications', 'notifications', lambda sid, k, n: {
        'id': stable_uuid('notification', sid, k),
        'owner_id': sid,
        'type': n.get('type') or 'general',
        'title': n.get('title') or '',
        'body': n.get('body') or '',
        'read': bool(n.get('read')),
        'read_at': ms_to_iso(n.get('readAt')),
        'payload': n.get('payload'),
        'created_at': ms_to_iso(n.get('createdAt')),
    })

    # quoteSettings is one row per user, not a collection.
    qs = []
    for fb_uid, s in (rtdb.get('quoteSettings') or {}).items():
        sid = uid_map.get(fb_uid)
        if sid and isinstance(s, dict):
            qs.append({
                'owner_id': sid,
                'auto_generate_number': s.get('autoGenerateNumber', True),
                'prefix': s.get('prefix') or '',
            })
    stats['quote_settings'] = supa.upsert('quote_settings', qs, 'owner_id')

    simple('quoteTerms', 'term_library', lambda sid, k, t: {
        'id': stable_uuid('term', sid, k),
        'owner_id': sid,
        'name': t.get('name') or '',
        'details': t.get('details') or '',
        'created_at': ms_to_iso(t.get('createdAt')),
    })

    # -- 4. userTools -------------------------------------------------------
    tool_rows = []
    KINDS = {'notes': 'note', 'photos': 'photo',
             'videos': 'video', 'files': 'file'}
    for fb_uid, groups in (rtdb.get('userTools') or {}).items():
        sid = uid_map.get(fb_uid)
        if not sid or not isinstance(groups, dict):
            continue
        for group, kind in KINDS.items():
            for key, it in (groups.get(group) or {}).items():
                if not isinstance(it, dict):
                    continue
                tool_rows.append({
                    'id': stable_uuid('tool', sid, group, key),
                    'owner_id': sid,
                    'kind': kind,
                    'title': it.get('title') or '',
                    'description': it.get('description') or '',
                    'body': it.get('body'),
                    'url': it.get('url'),
                    'storage_path': it.get('storagePath'),
                    'file_name': it.get('fileName'),
                    'mime_type': it.get('mimeType'),
                    'size_bytes': it.get('sizeBytes') or 0,
                    'thumbnail_url': it.get('thumbnailUrl'),
                    'thumbnail_storage_path': it.get('thumbnailStoragePath'),
                    'created_at': ms_to_iso(it.get('createdAt')),
                })
    stats['tool_assets'] = supa.upsert('tool_assets', tool_rows, 'id')

    # -- 5. documents (quotes / invoices / jobs) ----------------------------
    migrated_docs = set()

    for node, table, date_col in (
        ('quotes', 'quotes', 'quote_date'),
        ('invoices', 'invoices', 'invoice_date'),
    ):
        parents, lines, labour, terms, attachments = [], [], [], [], []
        for fb_uid, docs in (rtdb.get(node) or {}).items():
            sid = uid_map.get(fb_uid)
            if not sid or not isinstance(docs, dict):
                continue
            for key, doc in docs.items():
                if not isinstance(doc, dict):
                    continue
                did = stable_uuid(node, sid, key)
                migrated_docs.add(did)
                cust = doc.get('customer') or {}
                parent = {
                    'id': did,
                    'owner_id': sid,
                    'reference': doc.get('reference') or '',
                    'title': doc.get('title') or '',
                    'status': doc.get('status') or 'draft',
                    date_col: date_only(doc.get('date')),
                    'total': doc.get('total') or 0,
                    'customer_id': None,
                    'customer_snapshot': cust or None,
                    'share_token': doc.get('shareToken'),
                    'sent_at': ms_to_iso(doc.get('sentAt')),
                    'viewed_at': ms_to_iso(doc.get('viewedAt')),
                    'created_at': ms_to_iso(doc.get('createdAt')),
                }
                if node == 'quotes':
                    parent['expiry'] = doc.get('expiry') or 'days14'
                    parent['responded_at'] = ms_to_iso(doc.get('respondedAt'))
                else:
                    parent['due_date'] = date_only(doc.get('dueDate')) \
                        or date_only(doc.get('date'))
                    parent['payment_method'] = doc.get('paymentMethod') or 'cash'
                    parent['bank_snapshot'] = doc.get('bankSnapshot')
                    parent['paid_at'] = ms_to_iso(doc.get('paidAt'))
                parents.append(parent)

                prefix = 'quote' if node == 'quotes' else 'invoice'
                for i, l in enumerate(doc.get('lines') or []):
                    if not isinstance(l, dict):
                        continue
                    item = l.get('item') or {}
                    lines.append({
                        'id': stable_uuid(prefix, 'line', did, i),
                        f'{prefix}_id': did,
                        'sort_order': i,
                        'kind': l.get('kind') or 'material',
                        'pricing_item_id': None,
                        'item_name': item.get('name') or '',
                        'item_code': item.get('itemCode'),
                        'rate': l.get('rate') or 0,
                        'unit_markup': l.get('unitMarkup') or 0,
                        'discount': l.get('discount') or 0,
                        'quantity': l.get('quantity') or 1,
                        # line_total is GENERATED — never sent.
                    })
                for i, s in enumerate(doc.get('staff') or []):
                    if not isinstance(s, dict):
                        continue
                    st = s.get('staff') or {}
                    labour.append({
                        'id': stable_uuid(prefix, 'labour', did, i),
                        f'{prefix}_id': did,
                        'sort_order': i,
                        'staff_id': None,
                        'staff_name': st.get('name') or '',
                        'pay_type': s.get('payType') or 'day',
                        'rate_type': s.get('rateType') or 'standard',
                        'rate': s.get('rate') or 0,
                        'quantity': s.get('quantity') or 0,
                    })
                for i, t in enumerate(doc.get('terms') or []):
                    if not isinstance(t, dict):
                        continue
                    terms.append({
                        'id': stable_uuid(prefix, 'term', did, i),
                        f'{prefix}_id': did,
                        'sort_order': i,
                        'term_id': None,
                        'name': t.get('name') or '',
                        'details': t.get('details') or '',
                    })
                n = 0
                for group, kind in (('attachedPhotos', 'photo'),
                                    ('attachedVideos', 'video'),
                                    ('attachedFiles', 'file'),
                                    ('attachedNotes', 'note')):
                    for a in doc.get(group) or []:
                        if not isinstance(a, dict):
                            continue
                        attachments.append({
                            'id': stable_uuid(prefix, 'att', did, n),
                            f'{prefix}_id': did,
                            'sort_order': n,
                            'kind': kind,
                            'tool_asset_id': None,
                            'title': a.get('title') or '',
                            'description': a.get('description') or '',
                            'body': a.get('body'),
                            'url': a.get('url'),
                            'storage_path': a.get('storagePath'),
                            'file_name': a.get('fileName'),
                            'mime_type': a.get('mimeType'),
                            'size_bytes': a.get('sizeBytes') or 0,
                            'thumbnail_url': a.get('thumbnailUrl'),
                            'thumbnail_storage_path': a.get('thumbnailStoragePath'),
                        })
                        n += 1

        stats[table] = supa.upsert(table, parents, 'id')
        p = 'quote' if node == 'quotes' else 'invoice'
        stats[f'{p}_lines'] = supa.upsert(f'{p}_lines', lines, 'id')
        stats[f'{p}_labour_lines'] = supa.upsert(f'{p}_labour_lines', labour, 'id')
        stats[f'{p}_terms'] = supa.upsert(f'{p}_terms', terms, 'id')
        stats[f'{p}_attachments'] = supa.upsert(f'{p}_attachments', attachments, 'id')

    # jobs
    jobs, jexp, jtime, jatt = [], [], [], []
    for fb_uid, docs in (rtdb.get('jobs') or {}).items():
        sid = uid_map.get(fb_uid)
        if not sid or not isinstance(docs, dict):
            continue
        for key, j in docs.items():
            if not isinstance(j, dict):
                continue
            jid = stable_uuid('job', sid, key)
            jobs.append({
                'id': jid,
                'owner_id': sid,
                'reference': j.get('reference') or '',
                'title': j.get('title') or '',
                'description': j.get('description') or '',
                'status': j.get('status') or 'draft',
                'start_date': date_only(j.get('startDate')),
                'customer_id': None,
                'customer_snapshot': j.get('customer'),
                'clock_in_at': ms_to_iso(j.get('clockInAt')),
                'created_at': ms_to_iso(j.get('createdAt')),
            })
            for i, e in enumerate(j.get('expenses') or []):
                if isinstance(e, dict):
                    jexp.append({
                        'id': stable_uuid('jobexp', jid, i),
                        'job_id': jid,
                        'title': e.get('title') or '',
                        'amount': e.get('amount') or 0,
                        'expense_date': date_only(e.get('date')),
                        'description': e.get('description') or '',
                        'receipt_snapshot': e.get('receipt'),
                    })
            for i, t in enumerate(j.get('timeEntries') or []):
                if isinstance(t, dict) and t.get('start') and t.get('end'):
                    jtime.append({
                        'id': stable_uuid('jobtime', jid, i),
                        'job_id': jid,
                        'started_at': ms_to_iso(t.get('start')),
                        'ended_at': ms_to_iso(t.get('end')),
                    })
    stats['jobs'] = supa.upsert('jobs', jobs, 'id')
    stats['job_expenses'] = supa.upsert('job_expenses', jexp, 'id')
    stats['job_time_entries'] = supa.upsert('job_time_entries', jtime, 'id')

    # -- 6. share index -----------------------------------------------------
    shares, orphan_shares = [], []
    for node, col, doc_node in (('quoteShares', 'quote_id', 'quotes'),
                                ('invoiceShares', 'invoice_id', 'invoices')):
        for token, idx in (rtdb.get(node) or {}).items():
            if not isinstance(idx, dict):
                continue
            sid = uid_map.get(idx.get('uid'))
            doc_key = idx.get('quoteId') or idx.get('invoiceId')
            if not sid or not doc_key:
                continue

            doc_id = stable_uuid(doc_node, sid, doc_key)

            # Skip shares whose document no longer exists. Production has an
            # invoiceShares entry pointing at an invoice that was deleted
            # (the invoices node is empty), and the FK would reject it. The
            # customer-facing behaviour is unchanged: an unknown token 404s,
            # which is what that link already does today.
            if doc_id not in migrated_docs:
                orphan_shares.append(token)
                continue

            shares.append({
                'token': token,
                'owner_id': sid,
                col: doc_id,
                'created_at': ms_to_iso(idx.get('createdAt')),
                'viewed_at': ms_to_iso(idx.get('viewedAt')),
                'responded_at': ms_to_iso(idx.get('respondedAt')),
                'responded_action': idx.get('respondedAction'),
                'deleted_at': ms_to_iso(idx.get('deletedAt')),
            })
    stats['document_shares'] = supa.upsert('document_shares', shares, 'token')
    if orphan_shares:
        stats['shares skipped (orphan)'] = len(orphan_shares)

    # -- 7. app_config ------------------------------------------------------
    cfg = rtdb.get('config') or {}
    cfg_rows = [{'key': k, 'value': v} for k, v in cfg.items()
                if isinstance(v, (dict, list))]
    stats['app_config'] = supa.upsert('app_config', cfg_rows, 'key')

    # -- report -------------------------------------------------------------
    print(f'{"table":<24} {"rows":>8}')
    print('-' * 34)
    for k, v in stats.items():
        print(f'{k:<24} {str(v):>8}')
    print('-' * 34)
    print(f'{"total writes":<24} {supa.writes:>8}')
    if args.dry_run:
        print('\nDRY RUN — nothing was written.')

    # The uid map is what makes a re-run safe, so it must never be written
    # from a dry run (the ids are placeholders) and must be namespaced per
    # target — dev and prod assign different uuids to the same Firebase user.
    if args.dry_run:
        print('\nuid map NOT written (dry run — ids are placeholders)')
    else:
        out = DATA / f'uid-map-{args.target}.json'
        out.write_text(json.dumps(uid_map, indent=2))
        print(f'\nuid map -> {out} ({len(uid_map)} users)')


if __name__ == '__main__':
    import urllib.parse
    main()
