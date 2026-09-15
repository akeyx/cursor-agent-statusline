#!/usr/bin/env bash
# cursor-real-cost.sh - Pull REAL billed cost from Cursor's official Admin API
# and cache a calibration file that statusline.sh can use instead of guessing
# from a static per-model rate table.
#
# API docs: https://cursor.com/docs/account/teams/admin-api
#   POST https://api.cursor.com/teams/filtered-usage-events
#
# This is a standalone script, NOT invoked by the statusline itself. Run it
# manually, or on a timer (cron/systemd, at most once/hour per Cursor's own
# polling guidance -- the endpoint aggregates hourly anyway).
#
# ── Requirements ─────────────────────────────────────────────────────────
# A Cursor Admin API key (Team/Enterprise admins only):
#   cursor.com/dashboard -> Settings -> Advanced -> Admin API Keys
#
# SECURITY: never paste your API key into a chat/agent session. Generate and
# store it yourself, directly in your own terminal:
#
#   mkdir -p ~/.config/cursor-admin && chmod 700 ~/.config/cursor-admin
#   read -rs -p "Cursor Admin API key: " CURSOR_KEY && echo
#   printf '%s' "$CURSOR_KEY" > ~/.config/cursor-admin/api_key
#   chmod 600 ~/.config/cursor-admin/api_key
#   unset CURSOR_KEY
#
# ── Usage ────────────────────────────────────────────────────────────────
#   ./cursor-real-cost.sh [--days N] [--email you@company.com]
#
# Writes ~/.cache/cursor-agent-statusline/calibration.json with:
#   - a per-model blended $/1M-token rate, calibrated from your own recent
#     billed events (input+output tokens only, matching what the statusline
#     payload exposes -- this automatically bakes in your real cache-hit
#     ratio, which a static rate card can't)
#   - a per-session (conversationId) real $ total, for exact lookups when
#     the statusline's session_id happens to match a conversationId

set -euo pipefail

KEY_FILE="${CURSOR_ADMIN_KEY_FILE:-$HOME/.config/cursor-admin/api_key}"
CACHE_DIR="${CURSOR_COST_CACHE_DIR:-$HOME/.cache/cursor-agent-statusline}"
CACHE_FILE="$CACHE_DIR/calibration.json"
DAYS=7
EMAIL="${CURSOR_USER_EMAIL:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--days N] [--email you@company.com]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }

if [ -n "${CURSOR_ADMIN_API_KEY:-}" ]; then
  API_KEY="$CURSOR_ADMIN_API_KEY"
elif [ -f "$KEY_FILE" ]; then
  API_KEY=$(cat "$KEY_FILE")
else
  echo "No Cursor Admin API key found." >&2
  echo "Set \$CURSOR_ADMIN_API_KEY, or store one at: $KEY_FILE" >&2
  echo "(Generate a key at cursor.com/dashboard -> Settings -> Advanced -> Admin API Keys." >&2
  echo " Requires Team/Enterprise admin access. Never paste the key into a chat session.)" >&2
  exit 1
fi

if [ -z "$EMAIL" ] && command -v cursor-agent >/dev/null 2>&1; then
  EMAIL=$(cursor-agent about --format json 2>/dev/null | jq -r '.userEmail // empty')
fi

mkdir -p "$CACHE_DIR"

END_MS=$(($(date +%s) * 1000))
START_MS=$(( END_MS - DAYS * 86400 * 1000 ))

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

PAGE=1
PAGE_SIZE=1000
while :; do
  BODY=$(jq -n --argjson start "$START_MS" --argjson end "$END_MS" \
    --arg email "$EMAIL" --argjson page "$PAGE" --argjson pageSize "$PAGE_SIZE" \
    '{startDate:$start,endDate:$end,page:$page,pageSize:$pageSize}
     + (if $email != "" then {email:$email} else {} end)')

  HTTP_CODE=$(curl -s -o "$TMP_DIR/page_$PAGE.json" -w '%{http_code}' \
    -X POST "https://api.cursor.com/teams/filtered-usage-events" \
    -u "${API_KEY}:" -H "Content-Type: application/json" -d "$BODY")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "Admin API request failed (HTTP $HTTP_CODE). Response:" >&2
    cat "$TMP_DIR/page_$PAGE.json" >&2
    exit 1
  fi

  NUM_PAGES=$(jq -r '.pagination.numPages // 1' "$TMP_DIR/page_$PAGE.json")
  HAS_NEXT=$(jq -r '.pagination.hasNextPage // false' "$TMP_DIR/page_$PAGE.json")
  [ "$HAS_NEXT" != "true" ] && break
  PAGE=$((PAGE + 1))
  [ "$PAGE" -gt "$NUM_PAGES" ] && break
  [ "$PAGE" -gt 200 ] && { echo "Aborting after 200 pages (safety cap)." >&2; break; }
done

# Flatten all pages into one events array, then aggregate with jq:
#   - per model: blended $/1M tokens using ONLY input+output tokens (what
#     the statusline payload actually has -- this bakes in the real cache
#     mix instead of assuming everything is uncached)
#   - per conversationId: real total charged $, for exact-session lookups
jq -s '
  [.[].usageEvents[]?] as $events
  | {
      updated_at: (now | todate),
      window_days: '"$DAYS"',
      window_start_ms: '"$START_MS"',
      window_end_ms: '"$END_MS"',
      email: '"$(jq -n --arg e "$EMAIL" '$e')"',
      total_events: ($events | length),
      total_charged_usd: (($events | map(.chargedCents // 0) | add // 0) / 100),
      models: (
        $events
        | map(select(.isTokenBasedCall == true and .tokenUsage != null))
        | group_by(.model)
        | map({
            key: (.[0].model),
            value: {
              sample_events: length,
              sample_io_tokens: (map((.tokenUsage.inputTokens // 0) + (.tokenUsage.outputTokens // 0)) | add // 0),
              charged_usd: ((map(.chargedCents // 0) | add // 0) / 100)
            }
          })
        | map(select(.value.sample_io_tokens > 0))
        | map(.value += {blended_usd_per_m_io_tokens: ((.value.charged_usd / .value.sample_io_tokens) * 1000000)})
        | from_entries
      ),
      by_conversation: (
        $events
        | map(select(.conversationId != null))
        | group_by(.conversationId)
        | map({
            key: (.[0].conversationId),
            value: {
              charged_usd: ((map(.chargedCents // 0) | add // 0) / 100),
              events: length
            }
          })
        | from_entries
      )
    }
' "$TMP_DIR"/page_*.json > "$CACHE_FILE"

echo "Wrote $CACHE_FILE"
echo
jq -r '
  "Window: last \(.window_days)d (\(.total_events) events, $\(.total_charged_usd | tostring) total)",
  "",
  "Per-model blended rate (calibrated from your real cache-hit ratio):",
  (.models | to_entries[] | "  \(.key): $\(.value.blended_usd_per_m_io_tokens | (.*100|round)/100)/1M input+output tokens  (\(.value.sample_events) events, \(.value.sample_io_tokens) tokens, $\(.value.charged_usd) charged)")
' "$CACHE_FILE"
