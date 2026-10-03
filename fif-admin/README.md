# Fix It Felix Admin

A staff-facing operations panel over both Fix It Felix apps. Next.js App Router,
Tailwind v4, hand-written shadcn tokens, Supabase.

Built to `docs/admin-panel-dashboard-spec.md` in this repo, and to the design
spec at `BELVL_APP/belvl-admin/DESIGN_PROMPT.md`.

## Both apps, one project

The spec's biggest open question (§2.4 — does the customer app get its own
backend?) was answered by the Supabase migration: it did not. Both apps live in
one project and `profiles.account_type` is the whole difference.

| `account_type`         | App          | What they have                                        |
| ---------------------- | ------------ | ----------------------------------------------------- |
| `tradesman`,`business` | Pro app      | Jobs, quotes, invoices, a client book, staff, a plan   |
| `customer`             | Customer app | A name, a phone number, an address, devices            |

So there is no app switcher. **Tradespeople** and **Customers** are two pages
with different columns and different tabs, because a single list holding both
would be three-quarters dashes on every customer row.

Two tables are easy to confuse and are named apart in the UI:

- **Customers** (`/customers`) — `profiles` where `account_type = 'customer'`.
  Real accounts; people sign in.
- **Client book** (`/client-book`) — the `customers` table. Address-book entries
  a tradesperson typed in or imported from their phone. Nobody signs in as one,
  and it has no relationship to the page above.

## Running it

```bash
cp .env.example .env.local   # then fill in the keys
npm install
npm run dev                  # http://localhost:3007
```

`SUPABASE_SERVICE_ROLE_KEY` is required. Every read in this panel crosses users,
every policy in the schema is `auth.uid() = owner_id`, so nothing works without
it. Find it under Project settings → API keys in the Supabase dashboard.

### One deployment per environment

Staging and production are **two separate Supabase projects**, not a flag:

| Env        | Project ref            |
| ---------- | ---------------------- |
| staging    | `mjteytegbjvemuxoimlq` |
| production | `nhghuurzmwoirnjkpvaa` |

`.env.local` picks one. The sidebar footer names it, and production tints the
top bar red and says so on the login page, the broadcast confirmation and the
grant-access form.

This is deliberate rather than a switcher: a switcher means both projects'
service-role keys in one process, and a staging window that can reach
production data is the one failure a panel like this must not have. To work on
production, deploy a second instance with the production keys.

`FIF_API_BASE_URL` must point at the **same project**. It is used for exactly
one call — `POST /notifications/send` — because that route owns the FCM service
account and the stale-token cleanup.

## Before it works: the migration

`supabase/migrations/20260914090000_phase9_admin_panel.sql` adds three things
the schema did not have. Apply it per project:

```bash
supabase link --project-ref mjteytegbjvemuxoimlq   # or the production ref
supabase db push
```

| What                      | Why                                                                              |
| ------------------------- | -------------------------------------------------------------------------------- |
| `admin_audit_log`         | Spec §5.9. A panel that can disable an account without a trace is not shippable.  |
| Five roles on `admin_roles` | Spec §4.2. Widens the CHECK constraint; existing rows are untouched.            |
| `admin_dashboard_stats()` | Money. Counts come from head requests; sums need Postgres to do the summing.      |

The panel degrades rather than breaking if it has not been applied: the
dashboard renders every count and says which card is waiting, the audit page
names the file, and actions still succeed — they just report that they were not
recorded.

### Granting staff access

`scripts/admin.sh` is the whole flow — pick the project, pick a role, give an
email. If that email has no account it asks for a password and creates one; if
it already has one, the password is left completely alone.

```bash
cd fif-admin
./scripts/admin.sh          # grant access
./scripts/admin.sh --list   # just see who has it
```

It asks which project every time and never defaults silently, and production
needs the word PRODUCTION typed before it will go further — the two projects
hold separate rosters, and "I added them" meaning staging when the ticket was
about production is the mistake that ordering prevents.

It needs the Supabase CLI logged in (`supabase login`); it reads the
service-role key from there rather than from `.env.local`, so it works against
production without you repointing the panel.

Use it once, for the first super admin. After that `/admins` inside the panel
grants and revokes by email and nobody needs the script again — it exists only
because the page that hands out roles is itself behind a role.

There is no way to create an app user from any of this, and that is deliberate:
tradespeople and customers sign up in the apps.

## Deployed

| | |
| --- | --- |
| Staging | https://fif-admin-dev.vercel.app |
| Vercel project | `fif-admin-dev` (namesh-kushanthas-projects) |
| Reads | `mjteytegbjvemuxoimlq` |

```bash
cd fif-admin
vercel deploy --prod     # env vars are already set on the project
```

There is no production deployment yet. When there is, it must be a **separate
Vercel project** with its own env vars — the whole point of one deployment per
environment is that neither holds a credential that reaches the other's
database.

### Deployment protection, and its catch

Vercel Authentication sits in front of the panel: the sign-in screen is not
reachable without a Vercel login first. Two independent gates on a page that
reads every user's data.

This needed a change from Vercel's default. New projects ship as
`all_except_custom_domains`, which protects generated deployment URLs and
previews but leaves the **production domain public** — so
`fif-admin-dev.vercel.app` was serving the login page to anyone until it was
set to `all`:

```bash
curl -X PATCH "https://api.vercel.com/v9/projects/$PRJ?teamId=$TEAM" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"ssoProtection":{"deploymentType":"all"}}'
```

**The catch:** this account is on the Hobby plan, which has no team members. So
Vercel Authentication currently means *only this account* can reach the panel —
there is no way to let a colleague past the Vercel gate without upgrading to
Pro. If someone else needs access before then, the choice is Pro, or dropping
back to `all_except_custom_domains` and relying on the panel's own login plus
an empty-by-default `admin_roles`.

## Roles

`lib/roles.ts` is the whole matrix, and the only place the mapping exists — the
database stores just the role name. `/admins` renders the matrix, so it cannot
drift from what the code does.

| Role       | Sees                                                                   |
| ---------- | ---------------------------------------------------------------------- |
| superAdmin | Everything, including the roster and app config.                        |
| admin      | Everything except handing out roles and editing config.                 |
| support    | A person, their account, their work. Sends to named recipients only.    |
| verifier   | The verification queue. Nothing else.                                   |
| analyst    | Dashboards, money, the audit log. No route to one person.               |

Permissions are checked in the page **and** again inside every server action. A
server action is a public endpoint; "the button only rendered for a super admin"
is not a check.

The `api` edge function keeps its own narrower list (`superAdmin`, `admin`,
`support`) for sending notifications. The panel names that overlap in
`API_SEND_ROLES` so the compose screen can explain a 403 before it happens.

## What it can change

Everything the panel writes is a column `profiles_guard_server_columns` reserves
for the service role — which is the reason this is a server app at all.

- **Verification** — approve, reject with a reason, send back to the queue.
- **Account status** — disable, re-enable.
- **Deletion** — start the same clock the user's own request sets (recovery
  window, then retention), and cancel it. Nothing hard-deletes: the recovery
  window only works while they can still sign in.
- **Notifications** — to named recipients, or everyone (superAdmin/admin, behind
  a typed confirmation and a live recipient count).
- **App config** — the jsonb both apps read at launch. superAdmin only.
- **Admin roles** — grant and revoke.

Billing is read-only by necessity: entitlements live in StoreKit and Play
Billing, and there is no server-side cancel or refund to expose. The
subscriptions page links out to both consoles and flags rows that say active
past their period end.

## Things this panel surfaces that nothing else does

- **Subscriptions out of sync** — `status = 'active'` with `current_period_end`
  in the past. A renewal that never landed; invisible from any one user's page.
  `/subscriptions?anomaly=stale`.
- **Accounts past their retention date** — nothing in the codebase purges them
  (spec §5.10 flags the job as missing). `/deletions?tab=retention` is the only
  place that promise is visible.
- **Share tombstones** — a link in somebody's inbox pointing at a deleted
  document. `/shares`.
- **Customers holding Pro-app records** — shown as a warning on the customer's
  own page; it means an account type was flipped.
- **Push switched on with no token** — the account cannot receive a push and
  nothing else would say so.

## Two fixes this work required

Both are in `supabase/functions/` and need a redeploy
(`supabase functions deploy api tradesman-verification`):

1. **`tradesman-verification` wrote `verification_status: 'pending'`**, which
   `profiles_verification_status_check` rejects — the constraint and the app's
   `VerificationStatus` enum both say `waiting`. Self-submissions were failing,
   so nothing reached the review queue. Now writes `waiting`.
2. **`isAdmin()` accepted only `admin` and `superAdmin`.** Widened to include
   `support`, which the spec gives single-recipient sends.

## Layout

```
app/(panel)/          every page; the layout resolves the admin once
app/(panel)/_actions  server actions shared by both people pages
app/(panel)/_components  action UI shared by both people pages
components/ui/        the eight primitives, written not installed
lib/queries.ts        every cross-user read, in one file on purpose
lib/roles.ts          the permission matrix
lib/auth.ts           the only door to the service-role client
```

`lib/queries.ts` is one file so the review question — what can the panel see? —
has one answer, and a page that wants a new table has to come here rather than
reaching for the key itself.

## Conventions

- **Search, filters and pagination write to the URL**, never to client state.
  The tables page over thousands of rows; a URL is a result you can send to a
  colleague.
- **Filter options come from the data**, so a value added upstream appears here
  without an edit.
- **A null renders as an em dash, never disappears.** Absence is an answer.
- **Errors show the real message.** Whoever is looking at an admin panel is the
  person who can act on it.
