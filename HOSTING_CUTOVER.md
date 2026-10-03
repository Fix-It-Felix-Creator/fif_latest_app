# Keeping already-sent share links alive

Share links that customers already have look like:

    https://fifcloud.web.app/q/{token}
    https://fifcloud.web.app/i/{token}

They are **not** app URLs — they are in people's inboxes, and there is no way
to reach back and change them. So Firebase Hosting has to stay, even though
Realtime Database, Cloud Functions, Auth and Storage do not.

`firebase.json` now keeps **only** Hosting, redirecting both paths to the
Supabase Edge Function:

    /q/:rest*  ->  https://nhghuurzmwoirnjkpvaa.supabase.co/functions/v1/api/q/:rest*
    /i/:rest*  ->  https://nhghuurzmwoirnjkpvaa.supabase.co/functions/v1/api/i/:rest*

`:rest*` appears in the source AND the destination — a bare `**` glob matches
but captures nothing, so the token would be dropped.

The redirect is **302, not 301**. A permanent redirect is cached by browsers
indefinitely; if the API URL later moves to a custom domain, anyone who opened
a link in the meantime would be stranded on the old target with no way to
clear it.

## To deploy

    firebase deploy --only hosting

Nothing else should be deployed from this repo — `functions` and `database`
have been removed from `firebase.json` precisely so a stray `firebase deploy`
cannot resurrect them.

## Verify after deploying

    curl -sI https://fifcloud.web.app/q/SOME_REAL_TOKEN | head -3
    # expect: HTTP/2 302 + location: https://nhghuurzmwoirnjkpvaa.supabase.co/...

## Better, when you're ready

Point a custom domain (e.g. `share.fixitfelixsoftwaresolutions.com`) at the
Edge Function and set `PUBLIC_SHARE_BASE_URL` so NEW links skip the hop
entirely. Old links keep redirecting; Hosting stays as a permanent shim for
them. That also removes the `supabase.co` URL from customer-facing emails.
