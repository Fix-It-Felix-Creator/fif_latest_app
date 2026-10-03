# Admin Panel — Functional Specification

Status: proposal / design doc (nothing in this file is built yet, except where marked **[existing]**).
Audience: whoever builds the Next.js admin panel for Fix It Felix — covers both the Pro app (live) and the Customer app (in development).
Companion doc: `docs/admin-panel-notifications.md` (notifications module is already fully specced and partially built — see §6).

## 1. Purpose

Fix It Felix ships as **two apps**:

- **Pro app** (`fixitfelixpro`, this repo) — two account types, **business owners** and **tradesmen** — live in production. Backed by the `fifcloud` Firebase project (RTDB + Cloud Functions + Auth), split into staging/production RTDB instances (§2.1).
- **Customer app** (`fixitfelix` — homeowners who book/hire tradespeople) — **currently in development**, not yet released. A prior build of this app exists at `old_apps/fixitfelix_mobile` on a **separate Firebase project** (`fixitfelix`, bundle `com.techkushx.fixitfelix`) — a different project from the Pro app's `fifcloud`, not just a different environment within it. Whether the new build keeps its own Firebase project or gets unified into `fifcloud` is an open decision (§2.4) that materially affects the panel's architecture, so this spec is written to support either outcome without a rework.

There is currently no staff-facing tool to manage users, review tradesman verification, inspect subscriptions, adjust config, or send notifications outside of raw Firebase Console access and one gated HTTP endpoint. This doc specifies a **Next.js admin panel** — internal-only, used by founders/support/ops — that gives staff a safe, role-gated way to do all of that **across both apps**, once the customer app exists. Everything specified here is buildable against the Pro app today; the customer app is designed in as a second "app adapter" to be wired in when it ships (§6.5, Phase 4 in §8), not bolted on later.

## 2. System recap (what the panel is built on)

### 2.1 Two environments, two databases

Staging and production are **not** a flag inside one database — they are two separate RTDB instances under the same Firebase project (`fifcloud`):

| Environment | RTDB instance | HTTP API base |
|---|---|---|
| Staging | `fifcloud-default-rtdb.europe-west1.firebasedatabase.app` | `.../api` |
| Production | `fifcloud-production.europe-west1.firebasedatabase.app` | `.../apiProd` |

Both Cloud Functions (`api`, `apiProd`) are the same Express app, bound to a different env at request time (`functions/src/lib/env.ts`). **The panel must do the same** — every screen operates against one explicit environment, selected via a switcher, never both at once (see §5.1).

### 2.2 No client-SDK path — server-side only

RTDB security rules lock every collection to `auth.uid === $uid`. There is no rule that grants an "admin" role elevated client-SDK access. This is intentional and should stay that way. The panel therefore **must** be a server-rendered/API app using the **Firebase Admin SDK** with a service account (one per environment, or one multi-project credential scoped per env) — never the Firebase client SDK for cross-user reads/writes. This mirrors the existing pattern in `functions/src/lib/admin.ts`.

### 2.3 Existing platform-admin primitive **[existing]**

```
/config/admin/systemRoles/{uid}
  role:     "admin" | "superAdmin"
  isActive: true
```
Checked by `functions/src/lib/admin.ts` (`isAdmin`, `requireAdmin`), currently gating exactly one endpoint (`POST /notifications/send`). No UI manages this node today — it's edited by hand per environment. This is the seed of the panel's auth/RBAC model (§4) but needs to grow beyond a binary flag.

Do not confuse this with `BusinessRole` (`owner | admin | customerSupport`) on a `/users/{uid}` record — that's a business's own in-app team hierarchy, visible to end users, and irrelevant to platform staff permissions.

### 2.4 The customer app dimension (open decision, design for both outcomes)

The panel needs to operate over **app × environment**, not just environment. Two possible shapes for the customer app, both plausible until the team decides:

| Option | Shape | Panel implication |
|---|---|---|
| **A — Separate project** (matches the old `fixitfelix_mobile` build) | Customer app keeps its own Firebase project (`fixitfelix` or a fresh one), own Auth pool, own RTDB/Firestore, likely its own staging/prod split. | Panel needs a second Admin SDK credential set (per environment) and its own `systemRoles`-equivalent or a shared one at the panel layer (see below). A "customer" who books a job is a fully separate identity from a Pro-app user — no automatic user-record linkage unless built deliberately (e.g. matching by email/phone). |
| **B — Unified into `fifcloud`** | Customer app is added as a third `accountType` inside the *same* `fifcloud` project/RTDB instances, reusing existing Auth. This is plausible because `AccountCategoryType.customer` **already exists** on the Pro app's `UserDetailsModel` — the Pro app's own auth layer explicitly blocks `customer` accounts from signing in (`AuthRepository._validateAccountType()`), which reads like a placeholder for exactly this. | Panel just adds `customer` to the existing `accountType` filter in user management (§5.3) — no second credential set, no separate app switcher, jobs/quotes/customers records may even cross-reference the same uid. Much less admin-panel work. |

**Recommendation**: confirm with the team before building the multi-app parts of the panel (Phase 4, §8) — it's a one-line question ("is the customer app getting its own Firebase project or joining `fifcloud`?") that changes whether the panel needs a second credential set and a top-level app switcher, or just one more filter value. Until answered, build Phases 1–3 against the Pro app only (fully specified below) and keep the panel's data-access layer behind an adapter interface (§6.5) so either outcome is a config change, not a rewrite.

## 3. Who uses this panel and what they need

| Persona | Needs |
|---|---|
| **Founder / Super Admin** | Everything below, plus manage other admins' access and edit platform config (commission rates, subscription plan definitions). |
| **Support / Ops (Manager)** | Look up a user, see their profile/verification/subscription/jobs, resolve a support ticket (e.g. "why can't I see my quote", "my trial didn't activate"), send a targeted notification, action account deletion/recovery. Should **not** be able to grant admin access to others or edit commission/billing config. |
| **Verification reviewer** | Just the tradesman verification queue — approve/reject ID + selfie submissions. Narrowest role. |
| **Read-only / Analyst** | Dashboards and reports only, no mutating actions. |

This maps to four roles the panel should support (§4.2) — richer than today's binary `admin`/`superAdmin`.

## 4. Roles & permissions model

### 4.1 Panel login (who can even open the panel)

Panel staff sign in with their own Firebase Auth account (email/password or Google) — separate from app end-user accounts. A user who is only an app end-user (business/tradesman/customer) and not in `systemRoles` gets a 403, never a blank/broken screen.

A staff identity is expected to be **global across both apps** (the same founder/support person manages Pro and Customer users) even though the underlying `systemRoles` check is per Firebase project/environment (§4.3). Practically: the panel's own staff-account table (or a lightweight `/panelUsers/{email}` mapping, panel-owned, not per-app) holds the human identity and role once; per-app/per-environment `systemRoles` entries are how that identity is authorized to actually touch each backend, and can lag behind (e.g. a new hire granted panel access before their `fixitfelix` production `systemRoles` entry is seeded) — the panel should show which app/environment combinations a staff member currently has vs. lacks, rather than silently 403ing with no explanation.

### 4.2 Proposed role set (extends the existing node, backward compatible)

```
/config/admin/systemRoles/{uid}
  role:       "superAdmin" | "admin" | "support" | "verifier" | "analyst"
  isActive:   boolean
  displayName: string          // for audit log readability
  createdAt, createdBy, updatedAt
```
`admin` keeps existing meaning (today's de facto "can send notifications" role) and superAdmin gains it too. Legacy records with only `role`+`isActive` still parse fine — `displayName`/timestamps are additive.

| Capability | superAdmin | admin | support | verifier | analyst |
|---|---|---|---|---|---|
| View dashboards/reports | ✅ | ✅ | ✅ | ✅ | ✅ |
| View user profile/detail | ✅ | ✅ | ✅ | ✅ (verification tab only) | — |
| Disable/enable a user account | ✅ | ✅ | ✅ | — | — |
| Force account deletion/recovery | ✅ | ✅ | ✅ | — | — |
| Approve/reject tradesman verification | ✅ | ✅ | ✅ | ✅ | — |
| Send notification (single/broadcast) | ✅ | ✅ | ✅ (single only) | — | — |
| Edit commission rates / subscription plan config | ✅ | — | — | — | — |
| Manage other admins (`systemRoles`) | ✅ | — | — | — | — |
| Switch environment (staging ↔ production) | ✅ | ✅ | ✅ (staging default) | — | — |

Enforce this server-side (API route middleware), not just by hiding UI — mirror `requireAdmin` but parametrized by minimum role.

### 4.3 Per-environment (and, later, per-app) seeding

Because `systemRoles` lives inside each RTDB instance, a person must be granted access **separately in staging and in production**. The panel's "Manage admins" screen (superAdmin only) should make this explicit — two lists, one per environment, with a clear warning when adding someone to production. Once the customer app ships, if it's on a separate Firebase project (§2.4 Option A), this becomes a 2×2 grid (Pro-staging, Pro-prod, Customer-staging, Customer-prod) rather than a 1×2 list — design the "Manage admins" screen as a grid from the start so adding the customer app later is a new column, not a redesign.

## 5. Modules / functions

### 5.1 App & environment switcher (global, always visible)

Two independent, always-visible selectors in the shell chrome, not per-screen: **App** (Pro / Customer — the latter disabled/greyed out with a "coming soon" tooltip until the customer app actually ships, see §2.4 and §8 Phase 4) and **Environment** (staging / production). Switching either re-fetches the current screen's data against the corresponding backend. Production should be visually distinct (e.g. red/amber banner) to prevent an admin acting on prod by mistake, and the banner should always state both dimensions together ("Pro app · Production") so a switch in one dimension is never misread as still being in the other app/environment. Every mutating action's confirmation dialog restates both ("Disable this user in **Pro app, production**?").

Building the switcher as two dimensions from day one — even while the Customer option is inert — is what makes Phase 4 (§8) additive rather than a rework of every screen's data-fetching.

### 5.2 Dashboard / overview

At-a-glance KPIs, computed server-side (Admin SDK aggregation, cached — RTDB has no native aggregation queries, so this likely means a scheduled Cloud Function that writes rollups to `/adminStats/{date}` rather than scanning `/users` live on every page load):
- Total users, split business vs tradesman, new signups (7d/30d)
- Active subscriptions by plan/provider (apple/google/trial), trial conversions
- Tradesman verification queue depth (waiting count)
- Jobs/quotes/invoices created (7d/30d) as a rough activity signal
- Notification sends (7d) — volume + push failure rate

### 5.3 User management

List + detail view over `/users/{uid}`, filterable by `accountType` (business/tradesman today), `verificationStatus`, `accountStatus`, subscription state, signup date.

`AccountCategoryType` already includes a third value, `customer` — currently blocked at the Pro app's own auth layer, not something this panel will ever see there. Once the customer app ships: if it unifies into `fifcloud` (§2.4 Option B), `customer` becomes a normal third filter value in this same screen with its own detail-tab set (bookings/reviews rather than jobs/quotes/invoices — shape TBD, customer app is still being built); if it stays a separate project (Option A), customer users get their own list/detail screen under the "Customer" app selector (§5.1) rather than a filter here, since they're a different Auth pool entirely. Don't build customer-specific fields into this screen speculatively — the account-type filter and the app switcher are the two extension points, and which one gets used depends on §2.4's resolution.

Detail view shows:
- Profile fields (§ model in research: name, email, phone, address, business/company details or trade/verification fields)
- **Subscription tab**: `/users/{uid}/subscription/member` — plan, status, provider, autoRenew/cancelAtPeriodEnd, period dates, `isPaid`. **Read-mostly** — see §5.5, there is no cancel/refund button possible from here.
- **Usage tab**: `/usages/{uid}` counters vs. their plan's limits (`config/subscriptions/{accountType}/{planType}/limits`) — useful for "why am I blocked from adding another customer" support tickets.
- **Verification tab** (tradesman only): documents/selfie, `verificationStatus`, `rejectionReason`, approve/reject actions (writes `verificationStatus` + triggers the existing `onVerificationStatusChanged` email trigger — no new function needed, just an Admin-SDK write).
- **Activity tab**: counts/links into jobs, quotes, invoices, customers, staff owned by this uid (read-only drill-down, not full CRUD — see §5.6).
- **Account actions**: disable / re-enable (`accountStatus: "disabled"` — currently no Cloud Function sets this; the panel's backend should add one rather than have the panel touch RTDB unguarded, so the action is audited and validated), force deletion-pending / force recovery (wrap existing `POST /account/request-deletion` / `/account/recover` semantics via an admin-invoked Cloud Function, since the current endpoints are user-token-scoped), view GDPR export (`GET /account/export-data` equivalent for staff, unredacted).

This is the module with the highest blast radius — every mutating action needs a confirmation dialog and an audit log entry (§5.9).

### 5.4 Tradesman verification queue

A focused, high-throughput view for the `verifier` role: a filtered list of `verificationStatus === "waiting"` tradesmen, showing uploaded documents + selfie side by side, with Approve / Reject (+ reason) actions. This is likely the single highest-frequency panel action once the app has volume, so it deserves its own screen rather than being buried in general user management.

### 5.5 Subscriptions & billing (read-mostly, by design)

Billing moved from Stripe to native IAP (StoreKit 2 / Play Billing) — see `docs/inapp-purchase-migration.md`. There is no server-side "cancel" or "refund" capability; that only exists in App Store Connect / Google Play Console. The panel's role here is **visibility and troubleshooting**, not control:
- List/search subscriptions across users, filter by plan/status/provider, flag anomalies (e.g. `status: active` but `endDate` in the past — sync lag or webhook failure)
- Surface the reverse-lookup indexes (`/iap/appleOriginalTxnToUid`, `/iap/googleTokenToUid`) for support cases where a customer quotes a transaction ID
- Deep-link to App Store Connect / Play Console for the actual refund/cancel action (external link, not built here)
- **Commission rates editor** (`/config/commissionRates` — `tradesmanCommission`, `businessCommission`, `emergencyJobPremium`): currently write-locked from every client with no writer at all. This is a clean, low-risk first "admin edits config" feature — superAdmin only, with an `updatedBy`/`updatedAt` stamp already in the model.
- **Subscription plan config viewer/editor** (`config/subscriptions/{accountType}/{planId}`) — note only the `standard` plan is actually sold today; `plus/advance/vip` are legacy/unused, the panel should label them as such rather than presenting four live tiers.

### 5.6 Jobs / Quotes / Invoices / Customers oversight

Read-only drill-down for support purposes (e.g. "customer says their invoice link is broken" → look up the invoice, check its `shareToken`/`status`). Not a full CRUD replacement for the app. Useful fields to surface per the researched models: status, dates, totals, share tokens (to regenerate/debug the public `/q/:token` and `/i/:token` links), linked customer.

### 5.7 Notifications **[mostly existing — see companion doc]**

`docs/admin-panel-notifications.md` already specs this in full: schema, `POST /notifications/send` (admin-gated, single or broadcast), FCM fan-out with stale-token cleanup, a ready TS snippet for calling it from a web panel, and a suggested compose UI (recipient picker, type dropdown, live preview). Build the panel screen against that doc directly. Two gaps it flags that matter for this panel:
- No audit log of admin sends yet (`/notifications_admin_log/{pushKey}` proposed, unbuilt) — needed if support-role sends are to be reviewable.
- `toAll: true` scans the entire `/users` node — the panel should show a hard confirmation with the live recipient count before a broadcast, not just a checkbox.

### 5.8 Admin & role management (superAdmin only)

CRUD over `/config/admin/systemRoles/{uid}` per environment (§4.3): invite by email → resolve to uid via Firebase Auth Admin SDK → write role. Deactivate (`isActive: false`) rather than delete, to preserve audit history. List view shows role, environment(s) granted, last-active.

### 5.9 Audit log (needs to be built — no existing equivalent)

Every mutating action from the panel (disable user, approve/reject verification, edit commission rates, send notification, grant/revoke admin role) should write to `/adminAuditLog/{entryId}`: `{actorUid, actorEmail, action, targetUid?, env, before?, after?, timestamp}`. This doesn't exist anywhere in the current codebase and is the backbone of making the panel trustworthy for a founder who isn't the one clicking the buttons.

### 5.10 System health

- Cloud Functions logs/errors (surface via Firebase Admin SDK or link to Cloud Logging) — particularly IAP webhook failures and notification push failures, since both fail silently to the end user.
- **Known gap to flag, not silently fix**: account-deletion purge (hard-delete after `personalDataRetentionDays`, default 90) is referenced in code comments but no scheduled Cloud Function implementing it was found. Until it's built, the panel should at minimum surface a list of accounts past their `personalDataRetainedUntil` so staff can catch this manually.

## 6. Technical architecture

- **Frontend**: Next.js (App Router), server components for data fetching, no client-side Firebase SDK for admin data — only for the staff login itself (Firebase Auth client SDK to get an ID token, then every subsequent read/write goes through Next.js API routes / server actions using the Admin SDK).
- **Backend**: Next.js API routes (or a thin Cloud Functions layer reusing `functions/src/lib/admin.ts`-style middleware) holding one Firebase Admin app instance per environment (two service accounts or one multi-database-aware credential), selected by the request's environment header/cookie.
- **Auth**: staff sign in with Firebase Auth; every API route verifies the ID token, then re-checks `/config/admin/systemRoles/{uid}` in **the currently selected environment's RTDB** (not just any environment) before allowing the request — a support agent granted access in staging only should get 403s against production, not silently see stale/wrong data.
- **RBAC middleware**: parametrize by minimum role per route, analogous to today's `requireAdmin` but checking `role` against an ordered list (`analyst < verifier < support < admin < superAdmin`) rather than a fixed pair.
- **Aggregation for dashboards**: don't scan `/users` on every page view. Either add a scheduled Cloud Function that writes daily rollups to `/adminStats/{env}/{date}`, or compute on-demand with a visible "as of" timestamp and cache aggressively.

### 6.5 App adapter pattern (what makes Phase 4 additive, not a rewrite)

Build the panel's data-access layer behind a small interface per app — roughly `{ getUser(uid), listUsers(filters), getSubscription(uid), sendNotification(...), ... }` — with a `ProAppAdapter` as the only implementation for Phases 1–3. Each adapter owns its own Admin SDK credential(s) (keyed by environment, §2.1) and knows its own RTDB/Firestore shape; screens call the interface, never a hardcoded `fifcloud` reference. When the customer app ships and §2.4 is resolved, either:
- a `CustomerAppAdapter` is added pointing at a second Firebase project (Option A), or
- the existing `ProAppAdapter` grows an `accountType: "customer"` branch (Option B) —

and in both cases existing Pro-app screens are untouched. This is the single most important structural decision in this doc for avoiding rework once the customer app's backend shape is finalized.

## 7. Data model additions this panel introduces

| Path | Purpose | Status |
|---|---|---|
| `/config/admin/systemRoles/{uid}` (extended fields) | Role, backward compatible | existing, extended |
| `/adminAuditLog/{entryId}` | Every mutating panel action | new |
| `/adminStats/{date}` | Dashboard rollups | new |
| `/notifications_admin_log/{pushKey}` | Broadcast/send history | new (already proposed in companion doc) |

## 8. Rollout plan

1. **Phase 1 (MVP, Pro app only)**: staff login + role check, app/environment switcher (Customer side inert, §5.1), data layer built behind the adapter interface (§6.5) even though only `ProAppAdapter` exists yet, user list/detail (read-only) + disable/enable, tradesman verification queue, notifications compose (reuse existing endpoint), audit log wired to every mutation from day one.
2. **Phase 2 (Pro app)**: subscription/usage visibility, commission rates editor, admin/role management UI (replacing hand-edited `systemRoles`).
3. **Phase 3 (Pro app)**: dashboards/reporting rollups, jobs/quotes/invoices read-only drill-down, system health surface (function logs, purge-job gap).
4. **Phase 4 (Customer app integration, blocked until the customer app's backend is finalized)**: resolve §2.4 (separate Firebase project vs. unified into `fifcloud`), then either stand up a `CustomerAppAdapter` or extend `ProAppAdapter` with the `customer` account type; add the Customer column to "Manage admins" (§4.3); enable the Customer option in the app switcher; build out customer-specific user detail tabs (bookings/reviews/whatever the customer app's domain model turns out to be — not yet known, don't guess ahead of the build) and extend notification broadcast to reach customer users. Scope this phase properly once the customer app is further along rather than speculatively building screens against a data model that's still moving.

## 9. Open questions for the team

- **Customer app Firebase project**: does it stay separate (`fixitfelix` or a new project) or unify into `fifcloud` as a third `accountType`? (§2.4) — blocks all of Phase 4's architecture, doesn't block Phases 1–3.
- Should `support` role be allowed to force account deletion/recovery, or is that superAdmin/admin only given it touches GDPR timelines? (Table in §4.2 currently says yes — confirm.)
- Is the account-deletion purge job actually meant to exist, or is 90-day retention currently enforced manually/never? This changes whether §5.10's gap is P0 or informational.
- Where should staff service-account credentials live for a Next.js deploy (Vercel env vars, GCP Secret Manager) — out of scope for this doc but blocks Phase 1 implementation.
