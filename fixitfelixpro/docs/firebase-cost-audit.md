# Firebase Cost Audit — Fix It Felix Pro

_Branch: `feature/firebase-cost-optimization` · Date: 2026-05-18_

## TL;DR

The app uses **Realtime Database (RTDB)**, not Firestore. This matters for cost:

> **RTDB is billed on BANDWIDTH ($1/GB downloaded) + STORAGE ($5/GB stored), NOT per-operation.**

So the single biggest cost driver is **broad `onValue` listeners on growing nodes**:
every time *one* job/quote/invoice changes, RTDB re-downloads the **entire node** to
**every connected device**. A user with 200 jobs (~2 MB node) editing one job pushes
2 MB down the wire — repeatedly, all session long.

Cloud Storage (portfolio photos/videos) is the second driver: unbounded per-user,
$0.026/GB stored + $0.12/GB egress.

## Rough cost per active user / month

| Component | Driver | Light user | Heavy user | Notes |
|---|---|---|---|---|
| RTDB bandwidth | Listener re-syncs | ~$0.03 | ~$0.40+ | Dominated by un-limited `onValue` on growing collections |
| RTDB storage | Structured data/user | ~$0.01 | ~$0.03 | Small (~100 KB/user). Notifications/journal grow unbounded |
| Cloud Storage | Portfolio media | ~$0.05 | ~$0.60+ | Videos/photos, no quota |
| Cloud Functions | Stripe/email/notify | ~$0.01 | ~$0.05 | On-demand only, no cron — healthy |
| FCM / Auth | — | ~$0 | ~$0 | Free tier |
| **Total** | | **~$0.10** | **~$1.10+** | |

**Realistic target after optimization: $0.05–0.30 per active user/month.**
The optimizations below cut RTDB bandwidth by an estimated **60–80%**.

A safe budgeting rule: **budget ~$0.30/active user/month today**, aim for
**~$0.15** after fixes. For 1,000 active users that's ~$150/mo today → ~$75/mo.

## Findings by severity

### 🔴 CRITICAL — RTDB bandwidth (biggest spend)

1. **Unbounded `onValue` listeners with no `.limitToLast()` / filter** — ~16 listeners
   stream entire growing nodes and re-download the whole node on *any* child change:
   - `jobs/{uid}`, `quotes/{uid}`, `invoices/{uid}`, `customers/{uid}`,
     `journalEvents/{uid}`, `todos/{uid}`, `notifications/{uid}`,
     `userTools/{uid}/{photos,videos,files,notes}`, `staff/{uid}`, `pricing/{uid}`
   - Files: `lib/repositories/*/`*_repository.dart` (the `.onValue.map(...)` lines)
   - **Fix:** add `.orderByChild('updatedAt').limitToLast(N)` (or equivalent) +
     pagination for older records. Biggest single win.

2. **`usage_repository.dart` reads full `users/{uid}` ~13 times** for fields it only
   needs once (`accountType`, `subscription.member.planType`). No caching.
   - **Fix:** read once, cache in-memory for the session; or read only the needed
     child paths (`users/{uid}/accountType`).

3. **Config re-read every session, sometimes fully**
   (`config/subscriptions`, `config/videoLimits`, `config` whole tree) —
   `subscription_config_service.dart:64,204`, `app_config_service.dart:48`.
   - **Fix:** cache for whole app session (config changes rarely); read narrow paths.

### 🟠 HIGH — leaking / always-on listeners

4. **`PushNotificationsService` has no `dispose()`** — `onTokenRefresh`,
   `authStateChanges`, `onMessageOpenedApp` listeners never cancelled
   (`lib/services/push_notifications_service.dart:61,65,72`).

5. **`subscription_listener_service.dart`** — two `onValue` listeners on
   `users/{uid}/subscription/*`; `stopListening()` exists but isn't guaranteed on
   logout. Verify it's wired to sign-out.

6. **Storage upload listeners** (`task.snapshotEvents.listen(...)`) in
   files/photos/videos repos are not stored/cancelled
   (`*_repository.dart` ~line 54/56/62).

7. **Session writes on every foreground/background** — `device_info_repository.dart`
   `setSessionActive()`/`setSessionInactive()` do 2 writes per app-state change.
   - **Fix:** throttle (e.g. skip if last write < N minutes ago).

### 🟡 MEDIUM — storage growth / retention

8. **No retention policy:** `notifications/{uid}`, `journalEvents/{uid}` grow forever
   → bigger listener payloads + storage. Add server-side TTL/cleanup (Cloud Function).
9. **No per-user media quota** for portfolio photos/videos in Cloud Storage.
10. **FCM stale tokens** only cleaned reactively during admin broadcast.

## Good practices already in place ✅

- `setPersistenceEnabled(true)` + 10 MB cache (`database_service.dart:45`)
- No `keepSynced` anywhere (would force constant sync)
- No scheduled/cron functions (no idle burn)
- Restrictive security + storage rules, `.indexOn` on `quoteId`/`invoiceId`
- RTDB not Firestore (right call for this realtime app)
- Separate staging/prod instances

## Recommended action plan (priority order)

| # | Action | Effort | Est. saving |
|---|---|---|---|
| 1 | Add `.limitToLast(N)` + pagination to growing-collection listeners | M | 50–70% RTDB BW |
| 2 | Cache config reads for the session | S | 5–10% |
| 3 | Cache user doc in `usage_repository`; read narrow paths | S | 5–10% |
| 4 | Add `dispose()` to PushNotificationsService; cancel storage upload subs | S | leak fix |
| 5 | Throttle session activity writes | S | write reduction |
| 6 | Server-side retention for notifications/journal (Cloud Function) | M | storage + BW |
| 7 | Per-user media quota enforcement | M | storage |
