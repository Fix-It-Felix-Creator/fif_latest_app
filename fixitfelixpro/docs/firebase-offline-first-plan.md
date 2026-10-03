# Plan: Offline-first SQLite mirror + delta sync

_Branch: `feature/firebase-cost-optimization` · Status: PLAN ONLY — no code changed_

## The idea (refined)

Use a local **SQLite** database as the source of truth the UI reads from.
Firebase becomes a sync backend, not a live feed.

Why this saves money — the precise mechanism:

- RTDB bills on **bandwidth**, not operations. Writes are cheap.
- The waste is **broad `onValue` listeners**: when one job changes, RTDB
  re-streams the *entire* `jobs/{uid}` node to every connected device, all
  session long. ~16 such listeners exist.
- So the saving comes from **removing the broad listeners**, not from
  "writing on edit". SQLite serves the UI; we sync only **deltas**.

## Target architecture

```
        ┌─────────────┐   reactive query    ┌──────────────┐
  UI ◄──┤ BLoC / Repo  ├────────────────────►│   SQLite     │  (source of truth)
        └─────┬───────┘                       └─────┬────────┘
              │ add/edit/delete (optimistic)        │
              ▼                                     │ dirty rows
        ┌─────────────┐  write-through (online)     │
        │ Sync Engine ├─────────────────────────────┘
        └─────┬───────┘
              │  - flush dirty rows  → RTDB write
              │  - delta pull        ← RTDB query (updatedAt > lastSync)
              ▼
        ┌─────────────────────────────────────────────┐
        │  RTDB:  collections + meta/{uid}/collVersions │
        └─────────────────────────────────────────────┘
```

### 1. Local store
- `drift` (recommended — gives reactive `Stream` queries out of the box) or `sqflite`.
- One table per collection: jobs, quotes, invoices, customers, staff, pricing,
  todos, notes, journalEvents, notifications, userTools-metadata.
- Each row: `id`, payload (typed cols or JSON), `updatedAt`,
  `dirty` (needs push), `deleted` (tombstone), `syncedAt`.

### 2. Read path
- Repos/BLoCs query SQLite. UI streams from SQLite.
- **Zero broad `onValue` on big nodes.** This is the cost win.

### 3. Write path (write-through, optimistic)
- add/edit/delete → write SQLite immediately (instant UI) → mark `dirty`.
- Sync Engine flushes dirty rows to RTDB when online; on success clears `dirty`.
- Delete = tombstone locally + soft-delete in RTDB (`deleted:true`).

### 4. Delta pull — how we still see server changes cheaply
We must still learn about changes from: another device, Cloud Functions
(verificationStatus, subscription), admin notifications.

- Maintain `meta/{uid}/collVersions/{collection}` = `ServerValue.timestamp`,
  bumped on every write (by client writes **and** by Cloud Function triggers).
- Client keeps **ONE tiny `onValue` listener on `meta/{uid}/collVersions`**
  (a few dozen bytes total — vs. megabytes today).
- When a collection's version changes → fetch only the delta:
  `ref(collection).orderByChild('updatedAt').startAt(lastSyncTs)`.
- Net: ~16 full-node listeners → **1 tiny listener + bounded delta reads**.

> **v1 simpler variant:** drop even the tiny listener — pull deltas on app
> foreground + on screen open, throttled (≤ once / 60s per collection).
> Slightly less "instant" cross-device, even cheaper, much less code.

### 5. Keep narrow listeners only where real-time truly matters
Small single-record paths stay on direct listeners (cheap):
`users/{uid}/subscription`, `users/{uid}/verificationStatus`, force-logout
device flag. Everything list-shaped goes through SQLite + delta.

### 6. Conflict policy
Last-write-wins by server `updatedAt` (`ServerValue.timestamp`). Acceptable for
this app (single primary user per account; rare concurrent edits).

## Server-side prerequisites (need a deploy)
- Every repo write must set `updatedAt: ServerValue.timestamp` and bump
  `meta/{uid}/collVersions/{collection}`.
- Cloud Function triggers that mutate user data must do the same, else clients
  won't see server changes.
- `database.rules.json`: add `.indexOn: ["updatedAt"]` per collection.
- One-time backfill: existing rows lack `updatedAt`. Treat missing as epoch →
  first delta pull fetches everything once (capped by `.limitToLast(N)`), then
  incremental forever.
- Soft-delete + a scheduled purge function to physically remove old tombstones
  (also covers the notifications/journal retention finding).

## Rollout phases

| Phase | Work | Risk | Behaviour change |
|---|---|---|---|
| 0 | Add SQLite + Sync Engine infra behind a flag; wire nothing | none | none |
| 1 | Add `updatedAt` + `collVersions` to all writes (client + functions) + rules/index + deploy | low | none (additive) |
| 2 | Migrate ONE low-risk collection (e.g. `pricing` or `todos`) to SQLite+delta; measure cost in Firebase console | low | invisible if correct |
| 3 | Migrate remaining collections; delete broad `onValue` listeners | med | invisible if correct |
| 4 | Add server-side retention/tombstone purge; per-user media quota | low | none |

## Risks & gotchas
- **First run / new device:** one full initial pull per collection is
  unavoidable — cap with `.limitToLast(N)` + lazy-load older.
- **Server clock required:** LWW needs `ServerValue.timestamp`, never device clock.
- **RTDB persistence already on (10 MB):** it caches but does NOT stop `onValue`
  re-streaming — SQLite still wins. Consider disabling RTDB persistence on
  migrated paths to avoid double caching.
- **Functions must bump versions** or cross-device/server updates go unseen.
- **Local DB schema migrations** needed across app upgrades.
- Storage cost (media) is separate — unaffected by this; still needs Phase 4.

## Expected impact
RTDB bandwidth **−60–80%**, far fewer reads, plus offline-first UX (app works
with no signal, instant optimistic edits). Effort: **L** (multi-week, phased).

## Decision points for you
- **Scope:** full live-sync (tiny version listener) vs. v1 pull-on-foreground only?
- **Local lib:** `drift` (reactive, more codegen) vs `sqflite` (manual streams)?
- **First collection** to pilot in Phase 2?
- Lighter alternative if SQLite feels too big: keep RTDB but just add
  `.limitToLast(N)` + pagination + caching (the original audit plan) — ~50–70%
  saving, days not weeks, no new datastore.
