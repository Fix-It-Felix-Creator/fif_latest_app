# Custom domains for share links (`/q/:token`, `/i/:token`)

## Why this is needed

Supabase **rewrites any GET response of `text/html` to `text/plain`** on the
default `*.supabase.co` functions domain, and attaches
`content-security-policy: default-src 'none'; sandbox`. It is an anti-phishing
measure on their shared domain, and it is documented:

> Serving of HTML content is only supported with custom domains (otherwise GET
> requests that return `text/html` will be rewritten to `text/plain`).
> — https://supabase.com/docs/guides/functions/limits

`html()` in `supabase/functions/api/lib/context.ts:109` is correct and always
has been — the header never survives the gateway, so the customer sees page
source instead of the invoice. Because the rewritten header carries no
`charset`, UTF-8 also mojibakes (`Invoice 0001 â€" Namesh Kushantha`).

**No application code changes are required.** `PUBLIC_SHARE_BASE_URL` is
already read by `routes/documents.ts:17` and `routes/email.ts:19`; it is simply
unset on both projects.

## The two environments

| | Production | Development |
|---|---|---|
| Supabase project | `fif-pro-production` | `fif-pro-development` |
| Project ref | `nhghuurzmwoirnjkpvaa` | `mjteytegbjvemuxoimlq` |
| Custom hostname | `share.fixitfelixsoftwaresolutions.com` | `share-dev.fixitfelixsoftwaresolutions.com` |
| CNAME target | `nhghuurzmwoirnjkpvaa.supabase.co.` | `mjteytegbjvemuxoimlq.supabase.co.` |
| Add-on cost | $10/mo | $10/mo |

Both projects are in the **FixItFelix** org (`pegtkckgqnfhnokhrknn`), so both
add-ons are billed there. The add-on is **per project** — enabling it on
production does nothing for development.

Neither project has a vanity subdomain configured (checked: `not-used`), which
matters because Supabase treats vanity subdomains and custom domains as
mutually exclusive.

## Step 1 — Enable the add-on (dashboard, per project)

Currently neither project has the entitlement; the CLI refuses with:

    Custom domains require the Custom Domain add-on, available on the Pro plan
    and above.

Enable Pro on the org, then the **Custom Domain** add-on on *each* project:

    https://supabase.com/dashboard/project/nhghuurzmwoirnjkpvaa/settings/addons
    https://supabase.com/dashboard/project/mjteytegbjvemuxoimlq/settings/addons

Everything below fails until this is done.

## Step 2 — Register both hostnames

    supabase domains create \
      --project-ref nhghuurzmwoirnjkpvaa \
      --custom-hostname share.fixitfelixsoftwaresolutions.com

    supabase domains create \
      --project-ref mjteytegbjvemuxoimlq \
      --custom-hostname share-dev.fixitfelixsoftwaresolutions.com

Each prints its **own** `_acme-challenge` TXT value. They are not
interchangeable — keep them straight.

## Step 3 — DNS

The zone `fixitfelixsoftwaresolutions.com` is on **Google Cloud DNS**
(`ns-cloud-e1..e4.googledomains.com`) → Google Cloud Console → Network
Services → Cloud DNS → that zone.

Add four records. Use a low TTL (60s) while setting up; raise it afterwards.

| Type  | Name                      | Value                                |
|-------|---------------------------|--------------------------------------|
| CNAME | `share`                   | `nhghuurzmwoirnjkpvaa.supabase.co.`  |
| TXT   | `_acme-challenge.share`     | token printed by the prod `create`   |
| CNAME | `share-dev`               | `mjteytegbjvemuxoimlq.supabase.co.`  |
| TXT   | `_acme-challenge.share-dev` | token printed by the dev `create`    |

Three things that bite here:

  - **Google Cloud DNS auto-appends the zone name.** Enter `share`, not the
    FQDN, or you get `share.fixitfelixsoftwaresolutions.com.fixitfelixsoftwaresolutions.com`.
  - **Trailing dot on the CNAME value** — Cloud DNS requires the target to be
    fully qualified.
  - **Do not touch the existing records.** The apex `A` (216.198.79.1) and
    `www` CNAME point the marketing site at Vercel; `MX` is Google Workspace
    and the SPF `TXT` is Resend, which sends the invoice emails. Adding two new
    subdomains does not disturb any of them.

## Step 4 — Verify + activate

    supabase domains reverify --project-ref nhghuurzmwoirnjkpvaa
    supabase domains reverify --project-ref mjteytegbjvemuxoimlq

Repeat until each passes — DNS propagation plus SSL issuance can take up to
30 minutes. Then:

    supabase domains activate --project-ref nhghuurzmwoirnjkpvaa
    supabase domains activate --project-ref mjteytegbjvemuxoimlq

Check progress independently of the CLI with:

    dig +short share.fixitfelixsoftwaresolutions.com
    dig +short TXT _acme-challenge.share.fixitfelixsoftwaresolutions.com

## Step 5 — Point new links at the custom domains

    supabase secrets set --project-ref nhghuurzmwoirnjkpvaa \
      PUBLIC_SHARE_BASE_URL=https://share.fixitfelixsoftwaresolutions.com/functions/v1/api

    supabase secrets set --project-ref mjteytegbjvemuxoimlq \
      PUBLIC_SHARE_BASE_URL=https://share-dev.fixitfelixsoftwaresolutions.com/functions/v1/api

Then redeploy so the running instances pick the secret up rather than waiting
for a cold start:

    supabase functions deploy api --project-ref nhghuurzmwoirnjkpvaa
    supabase functions deploy api --project-ref mjteytegbjvemuxoimlq

Every link minted after this uses the custom domain, and `supabase.co` stops
appearing in customer email. Links minted *before* this keep their old URL
embedded — see step 6.

## Step 6 — Revive the already-sent links (production only)

`firebase.json` redirects `fifcloud.web.app/{q,i}/:token` at the Supabase
function so links already sitting in customers' inboxes keep working. Two
problems with it today:

  - **it was never deployed** — `https://fifcloud.web.app/i/<token>` returns
    404, so every already-sent link is dead;
  - its destination is the bare `supabase.co` URL, which would only land the
    customer back on the `text/plain` page.

Repoint both redirects at the **production** custom domain and deploy:

    # firebase.json destinations ->
    #   https://share.fixitfelixsoftwaresolutions.com/functions/v1/api/{q,i}/:rest*
    firebase deploy --only hosting

Development needs no equivalent — no customer ever received a staging link.

## Verify

    curl -sI https://share.fixitfelixsoftwaresolutions.com/functions/v1/api/i/short
    curl -sI https://share-dev.fixitfelixsoftwaresolutions.com/functions/v1/api/i/short
    # expect on both: content-type: text/html; charset=utf-8
    # and NO content-security-policy: default-src 'none'; sandbox

    curl -sI https://fifcloud.web.app/i/SOME_REAL_TOKEN
    # expect: HTTP/2 302 + location: https://share.fixitfelixsoftwaresolutions.com/...

Then send yourself an invoice from each build and open the link from the email.

## Auth impact: none

Supabase Auth switches to the custom domain the moment it is activated, which
normally means updating OAuth callback URLs. It does not apply here: Google and
Apple both go through `signInWithIdToken` (native ID tokens, no browser
callback) at `authentication_repository.dart:273` and `:336`. The only
`redirectTo` in the app (`:487`) is an app deep link for email confirmation,
independent of the API hostname. The `supabase.co` URLs also keep working after
activation, so `config_service.dart` needs no change and existing installs are
unaffected.

## Rollback

    supabase domains delete --project-ref <ref>
    supabase secrets unset PUBLIC_SHARE_BASE_URL --project-ref <ref>

Links minted while the custom domain was live would then 404, so only roll back
promptly if activation goes wrong.

---

# Free alternative, currently live on development

The custom-domain add-on was enabled on production and then turned back off, so
neither project has it. Instead, development now serves its share pages through
a **Vercel proxy** that re-applies the `Content-Type` the Supabase gateway
strips. Cost: $0/month.

    share-proxy/            a single function, no dependencies
    Vercel project          fixitfelixs-projects/fif-share-dev
    URL                     https://fif-share-dev.vercel.app
    UPSTREAM (env)          https://mjteytegbjvemuxoimlq.supabase.co/functions/v1/api
    PUBLIC_SHARE_BASE_URL   set on mjteytegbjvemuxoimlq to the Vercel URL

Verified:

    curl -sI https://fif-share-dev.vercel.app/i/<token>
    # content-type: text/html; charset=utf-8   ← the whole point

The proxy keeps the upstream URL shape exactly (`/q/:token`, `/i/:token`,
`/q/:token/respond`) because the quote page's Accept/Decline buttons POST to a
**root-relative** `/q/<token>/respond` (`render/quote.ts:810`). Serving the page
under a path prefix would break responding to a quote.

## Production — also live

Same proxy, second Vercel project:

    Vercel project          fixitfelixs-projects/fif-share-prod
    URL                     https://fif-share-prod.vercel.app
    UPSTREAM (env)          https://nhghuurzmwoirnjkpvaa.supabase.co/functions/v1/api
    PUBLIC_SHARE_BASE_URL   set on nhghuurzmwoirnjkpvaa to the Vercel URL

Redeploy either environment with `share-proxy/deploy.sh <dev|prod>`. It pins
VERCEL_PROJECT_ID rather than trusting whatever `vercel link` last wrote into
`.vercel/` — both environments deploy from the same directory, so the link is
shared mutable state and the wrong one would point production's invoices at the
staging database.

For a branded URL, `fixitfelixsoftwaresolutions.com` is already in the Vercel
team, so `vercel domains add share.fixitfelixsoftwaresolutions.com fif-share-prod`
plus the CNAME it prints (added in Google Cloud DNS) gets
`https://share.fixitfelixsoftwaresolutions.com/i/<token>` — still $0/month.
That makes the paid Supabase add-on unnecessary unless you want Auth and the
whole API on the branded domain too.

## Caveat

Links already sitting in inboxes still contain the `supabase.co` URL and will
keep rendering as plain text. Only links minted after `PUBLIC_SHARE_BASE_URL`
was set use the proxy — send a **new** invoice to test.
