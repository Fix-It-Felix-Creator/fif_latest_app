#!/usr/bin/env bash
# Deploy the share proxy to one environment.
#
#   ./deploy.sh dev
#   ./deploy.sh prod
#
# The project is pinned by ID rather than by whatever `vercel link` last wrote
# into .vercel/, because both environments deploy from THIS directory — linking
# is shared mutable state and picking the wrong one would point production's
# invoices at the staging database.

set -euo pipefail

export VERCEL_ORG_ID=team_nyUJ99h5XGVUFAZP8mXTYS9T

case ${1:-} in
  dev)  export VERCEL_PROJECT_ID=prj_EHkvILeXaAZ6QYOy2xpq8L8vPHOz ;;
  prod) export VERCEL_PROJECT_ID=prj_3jY7v8TByUtxYvzs2rj3ukwDkBAD ;;
  *) echo "usage: $0 <dev|prod>" >&2; exit 2 ;;
esac

exec vercel deploy --prod --yes
