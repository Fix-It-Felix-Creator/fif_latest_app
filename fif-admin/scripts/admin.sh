#!/usr/bin/env bash
#
# Grant someone staff access to the admin panel.
#
# The panel has no credential store of its own: staff sign in with an ordinary
# Fix It Felix account, and `admin_roles` is what turns that account into
# access. So there are two halves to granting it — an auth user, and a role —
# and this script does whichever halves are missing.
#
# Once one super admin exists, /admins in the panel does this by email and
# nobody needs to run this again. It is the chicken-and-egg tool: the page that
# grants roles is itself behind a role.
#
#   ./scripts/admin.sh            interactive
#   ./scripts/admin.sh --list     just show who has access
#
# Needs the Supabase CLI, logged in (`supabase login`).

set -euo pipefail

STAGING_REF="mjteytegbjvemuxoimlq"
PROD_REF="nhghuurzmwoirnjkpvaa"

# The five roles, and what each one actually sees. Kept in step with
# lib/roles.ts — that file is the real matrix; these are its one-line summaries.
ROLE_NAMES=(superAdmin admin support verifier analyst)
ROLE_BLURBS=(
  "Everything, including who else gets in and what the apps are configured with."
  "Everything except handing out roles and editing app config."
  "A person, their account, their work. Sends to named recipients only."
  "The verification queue. Nothing else."
  "Dashboards, money, the audit log. No route to one person."
)

bold()   { printf '\033[1m%s\033[0m\n' "$1"; }
dim()    { printf '\033[2m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1"; }
green()  { printf '\033[32m%s\033[0m\n' "$1"; }
die()    { red "$1"; exit 1; }

command -v supabase >/dev/null || die "The Supabase CLI is not installed."
command -v python3  >/dev/null || die "python3 is needed to read the API responses."

# ── Which project ────────────────────────────────────────────────────────────
#
# Asked first and every time, never defaulted silently. The two projects hold
# separate rosters, and "I added them" meaning staging when the ticket was
# about production is the mistake this ordering exists to prevent.
echo
bold "Which project?"
echo "  1) Staging      $STAGING_REF"
echo "  2) Production   $PROD_REF"
read -rp "> " ENV_CHOICE

case "${ENV_CHOICE:-1}" in
  1|""|staging)     REF="$STAGING_REF"; ENV_NAME="staging" ;;
  2|production|prod) REF="$PROD_REF";   ENV_NAME="production" ;;
  *) die "Pick 1 or 2." ;;
esac

if [ "$ENV_NAME" = "production" ]; then
  echo
  red "This is PRODUCTION. Whoever you grant can read every real user's data."
  read -rp "Type PRODUCTION to continue: " CONFIRM
  [ "$CONFIRM" = "PRODUCTION" ] || die "Stopped."
fi

echo
dim "Fetching the service-role key for ${ENV_NAME}…"

# The legacy `service_role` JWT specifically: these projects reject the newer
# sb_secret_ form with "Invalid API key".
KEY=$(supabase projects api-keys --project-ref "$REF" --output json | python3 -c '
import sys, json
for k in json.load(sys.stdin):
    if k.get("name") == "service_role":
        print(k["api_key"]); break
')
[ -n "$KEY" ] || die "Could not get a service_role key. Is the CLI logged in? Try: supabase login"

URL="https://${REF}.supabase.co"
api() { curl -sS -H "apikey: $KEY" -H "Authorization: Bearer $KEY" "$@"; }

# ── Who already has access ───────────────────────────────────────────────────
show_roster() {
  echo
  bold "Who has access to $ENV_NAME right now"
  api "$URL/rest/v1/admin_roles?select=user_id,role,is_active,display_name,last_seen_at&order=is_active.desc" \
  | python3 -c '
import sys, json
rows = json.load(sys.stdin)
if not rows:
    print("  Nobody. The panel cannot be opened by anyone yet.")
else:
    for r in rows:
        state = "active " if r.get("is_active") else "REVOKED"
        seen  = (r.get("last_seen_at") or "never")[:10]
        name  = r.get("display_name") or r["user_id"][:8]
        role  = r["role"]
        print(f"  {state}  {role:<11} {name:<28} last seen {seen}")
'
}

show_roster
[ "${1:-}" = "--list" ] && exit 0

# ── Which role ───────────────────────────────────────────────────────────────
echo
bold "Which role?"
for i in "${!ROLE_NAMES[@]}"; do
  printf '  %d) %-11s %s\n' "$((i+1))" "${ROLE_NAMES[$i]}" "${ROLE_BLURBS[$i]}"
done
read -rp "> " ROLE_CHOICE
IDX=$(( ${ROLE_CHOICE:-0} - 1 ))
[ "$IDX" -ge 0 ] 2>/dev/null && [ "$IDX" -lt "${#ROLE_NAMES[@]}" ] || die "Pick 1-${#ROLE_NAMES[@]}."
ROLE="${ROLE_NAMES[$IDX]}"

# ── Who ──────────────────────────────────────────────────────────────────────
echo
read -rp "Their email: " EMAIL
[ -n "$EMAIL" ] || die "An email is needed."
read -rp "Name for the audit log (optional): " DISPLAY_NAME

# Does an auth account already exist? If so the password is left completely
# alone — someone who already signs in to the app must not have their login
# changed as a side effect of being handed a staff role.
dim "Looking for an existing account…"
USER_ID=$(api --get "$URL/auth/v1/admin/users" --data-urlencode "page=1" --data-urlencode "per_page=1000" \
  | EMAIL="$EMAIL" python3 -c '
import sys, json, os
want = os.environ["EMAIL"].strip().lower()
for u in json.load(sys.stdin).get("users", []):
    if (u.get("email") or "").lower() == want:
        print(u["id"]); break
')

if [ -n "$USER_ID" ]; then
  green "Found it — $EMAIL already has an account. Its password is untouched."
else
  echo
  dim "No account with that email. Creating one."
  dim "The password is typed here and sent straight to Supabase; it is not stored"
  dim "in this repo, echoed, or kept in your shell history."
  echo
  read -rsp "Password (min 6 characters): " PASSWORD; echo
  read -rsp "Again: " PASSWORD2; echo
  [ "$PASSWORD" = "$PASSWORD2" ] || die "They do not match."
  [ "${#PASSWORD}" -ge 6 ] || die "Supabase needs at least 6 characters."

  CREATED=$(EMAIL="$EMAIL" PASSWORD="$PASSWORD" python3 -c '
import json, os
print(json.dumps({
    "email": os.environ["EMAIL"],
    "password": os.environ["PASSWORD"],
    # Confirmed on creation: this is a staff account made by an operator who
    # already knows who it belongs to, and a confirmation email that never
    # arrives would leave it unable to sign in with no sign of why.
    "email_confirm": True,
}))' | api -X POST "$URL/auth/v1/admin/users" -H "Content-Type: application/json" -d @-)

  USER_ID=$(echo "$CREATED" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if d.get("id"): print(d["id"])
else: sys.exit("Supabase refused: " + (d.get("msg") or d.get("error_description") or json.dumps(d)))
') || die "Could not create the account."
  unset PASSWORD PASSWORD2
  green "Account created."
fi

# ── Grant ────────────────────────────────────────────────────────────────────
#
# Upsert, so re-running to change somebody's role works and re-activates a
# revoked row rather than failing on the primary key.
dim "Granting ${ROLE}…"
RESULT=$(USER_ID="$USER_ID" ROLE="$ROLE" DISPLAY_NAME="$DISPLAY_NAME" python3 -c '
import json, os
print(json.dumps({
    "user_id": os.environ["USER_ID"],
    "role": os.environ["ROLE"],
    "is_active": True,
    "display_name": os.environ.get("DISPLAY_NAME") or None,
}))' | api -X POST "$URL/rest/v1/admin_roles?on_conflict=user_id" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates,return=representation" -d @-)

echo "$RESULT" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if isinstance(d, list) and d:
    sys.exit(0)
msg = d.get("message") if isinstance(d, dict) else str(d)
hint = ""
if msg and "admin_roles_role_check" in msg:
    hint = ("\n  That role is not in the CHECK constraint yet — apply "
            "20260914090000_phase9_admin_panel.sql with `supabase db push`.")
sys.exit("Supabase refused: " + str(msg) + hint)
' || die "The grant failed."

echo
green "Done. $EMAIL is $ROLE on $ENV_NAME."
show_roster
echo
dim "They sign in at the panel with that email and their own password."
dim "From here on, /admins in the panel can grant and revoke without this script."
