#!/usr/bin/env bash
# View a quote/invoice share page while Supabase is still rewriting text/html
# to text/plain on the *.supabase.co functions domain.
#
# The HTML the Edge Function returns is correct — only the Content-Type header
# is stripped by the gateway (see CUSTOM_DOMAIN.md). Saving the body to a .html
# file and opening it from disk sidesteps the header entirely, so what you see
# is exactly what a customer will see once a custom domain is in place.
#
# Usage:
#   tools/view-share.sh https://<ref>.supabase.co/functions/v1/api/i/<token>
#   tools/view-share.sh <token>            # defaults to dev + invoice
#   tools/view-share.sh <token> prod
#   tools/view-share.sh <token> dev q      # a quote instead of an invoice
#
# Just paste the link straight out of the email you received.

set -euo pipefail

DEV_REF=mjteytegbjvemuxoimlq
PROD_REF=nhghuurzmwoirnjkpvaa

arg=${1:?usage: view-share.sh <share-url|token> [prod|dev] [i|q]}
env=${2:-dev}
kind=${3:-i}

if [[ $arg == http* ]]; then
  url=$arg
else
  case $env in
    prod|production) ref=$PROD_REF ;;
    dev|development|staging) ref=$DEV_REF ;;
    *) echo "unknown env '$env' (expected prod or dev)" >&2; exit 2 ;;
  esac
  url="https://$ref.supabase.co/functions/v1/api/$kind/$arg"
fi

out=$(mktemp -t share).html

code=$(curl -sS -w '%{http_code}' -o "$out" "$url")
if [[ $code != 200 ]]; then
  echo "HTTP $code from $url" >&2
  head -c 400 "$out" >&2; echo >&2
  exit 1
fi

# The gateway drops the charset along with the content type, which is what turns
# an em dash into "â€"" in the browser. Writing the bytes to a .html file and
# letting the document's own <meta charset="utf-8"> apply fixes that too.
echo "$url"
echo "→ $out ($(wc -c < "$out" | tr -d ' ') bytes)"
open "$out"
