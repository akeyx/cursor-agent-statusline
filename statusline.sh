#!/bin/bash
# statusline.sh - Enhanced telemetry statusline for the cursor-agent CLI
# Same premium 256-color powerline theme as the Claude/Antigravity statuslines,
# adapted to the cursor-agent JSON payload schema.

set -euo pipefail
INPUT_JSON=$(cat)

# ─── ANSI Helpers ─────────────────────────────────────────────────────────
R="\033[0m"
B="\033[1m"

FG_BLACK="\033[30m"; FG_RED="\033[31m"; FG_GREEN="\033[32m"; FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"; FG_MAGENTA="\033[35m"; FG_CYAN="\033[36m"; FG_WHITE="\033[37m"
FG_GRAY="\033[90m"; FG_BRIGHT_RED="\033[91m"; FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"; FG_BRIGHT_BLUE="\033[94m"; FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"; FG_BRIGHT_WHITE="\033[97m"
NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Parse JSON from stdin (single jq pass) ───────────────────────────────
{
  read -r AUTORUN
  read -r COLS
  read -r CWD
  read -r SESSION_ID
  read -r SESSION_NAME
  read -r MODEL_ID
  read -r MODEL_NAME
  read -r PARAM_SUMMARY
  read -r MAX_MODE
  read -r VERSION
  read -r OUTPUT_STYLE
  read -r INPUT_TOKENS
  read -r OUTPUT_TOKENS
  read -r CTX_LIMIT
  read -r USED_PCT
  read -r REM_PCT
  read -r TURN_INPUT_TOKENS
  read -r TURN_OUTPUT_TOKENS
  read -r VIM_MODE
  read -r WT_NAME
  read -r _END
} <<< "$(
  echo "$INPUT_JSON" | jq -r '
    (.autorun // false),
    (.render_width_chars // 80),
    (.cwd // .workspace.current_dir // ""),
    (.session_id // ""),
    (.session_name // ""),
    (.model.id // ""),
    (.model.display_name // ""),
    (.model.param_summary // ""),
    (.model.max_mode // false),
    (.version // ""),
    (.output_style.name // "default"),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (.context_window.context_window_size // 0),
    (.context_window.used_percentage // 0),
    (.context_window.remaining_percentage // 100),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0),
    (.vim.mode // ""),
    (.worktree.name // ""),
    "END"
  ' 2>/dev/null || printf "false\n80\n\n\n\n\n\n\nfalse\n\ndefault\n0\n0\n0\n0\n100\n0\n0\n\n\nEND\n"
)"

# ─── CLI args & theme selection ────────────────────────────────────────────
USE_CLASSIC_ICONS=false
for arg in "$@"; do
  case "$arg" in
    --legend|-l|legend)
      echo -e "${FG_BRIGHT_GREEN}${B}🚀 cursor-agent Statusline Legend${R}"
      echo -e "Adapts to terminal width: wide = single powerline row, narrower = boxed multi-line."
      echo -e ""
      echo -e "${B}Field                Nerd Font   Description${R}"
      echo -e "----------------------------------------------------------------"
      echo -e "  Mode: AUTO                     Auto-run enabled."
      echo -e "  Mode: MANUAL         ✋          Auto-run disabled (approvals required)."
      echo -e "  VCS Branch                     Current git branch (red + * if dirty)."
      echo -e "  Model                          Model name + params (Max/effort)."
      echo -e "  Directory                      Current working directory (shortened)."
      echo -e "  Worktree             🌳          Active git worktree name."
      echo -e "  Session                        Session name or short session id."
      echo -e "  Context Bar          󱍏          Context window usage bar + tokens."
      echo -e "  Output Style                   Active output style (hidden if default)."
      echo -e "  Vim Mode                       NORMAL/INSERT (hidden if vim disabled)."
      echo -e "  Session Cost        💰          3 tiers, best available is shown:"
      echo -e "                                  \"\$X.XX real\"  -- exact, from cursor-real-cost.sh + Admin API"
      echo -e "                                  \"~\$X.XX cal.\" -- your own calibrated per-model rate"
      echo -e "                                  \"~\$X.XX est.\" -- static official-rate-table guess (default)"
      echo -e "                                  Add --no-token-rate if you're not on Team/Enterprise."
      echo -e "  Sys resources                  Host CPU load average & memory use."
      echo -e "  Power AC/BAT         󰚥/🔋       Host power source."
      exit 0
      ;;
    --classic|--no-nerdfont|--compatibility)
      USE_CLASSIC_ICONS=true
      ;;
  esac
done

if [ "$COLS" -ge 180 ]; then
  BAR_LEN=20
else
  BAR_LEN=10
fi

# ─── Theme colors & icons ──────────────────────────────────────────────────
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  ICON_AUTO=""; ICON_MANUAL=""; ICON_VCS="╱"; ICON_MODEL=""
  ICON_DIR="╱"; ICON_WT="wt"; ICON_SESSION="╱"; ICON_CTX="ctx"
  ICON_VIM=""; ICON_SYS="sys"; ICON_AC="AC"; ICON_BAT="BAT"; ICON_STYLE="style"; ICON_COST="\$"

  BG_AUTO="${FG_GREEN}"; FG_AUTO_TEXT="${B}"
  BG_MANUAL="${FG_YELLOW}"; FG_MANUAL_TEXT="${B}"
  BG_GIT_CLEAN="${FG_BLUE}"; FG_GIT_CLEAN_TEXT="${B}"
  BG_GIT_DIRTY="${FG_RED}"; FG_GIT_DIRTY_TEXT="${B}"
  BG_MODEL="${FG_MAGENTA}"; FG_MODEL_TEXT=""
  BG_DIR="${FG_CYAN}"; FG_DIR_TEXT=""
  BG_META="${FG_GRAY}"; FG_META_TEXT=""
else
  ICON_AUTO=""; ICON_MANUAL="✋"; ICON_VCS=""; ICON_MODEL=""
  ICON_DIR=""; ICON_WT="🌳"; ICON_SESSION="󰍪"; ICON_CTX="󱍏"
  ICON_VIM="󰌌"; ICON_SYS=""; ICON_AC="󰚥"; ICON_BAT="🔋"; ICON_STYLE="󰆍"; ICON_COST="💰"

  BG_AUTO="\033[48;5;76m"; FG_AUTO_TEXT="\033[38;5;232m\033[1m"
  BG_MANUAL="\033[48;5;214m"; FG_MANUAL_TEXT="\033[38;5;232m\033[1m"
  BG_GIT_CLEAN="\033[48;5;33m"; FG_GIT_CLEAN_TEXT="\033[38;5;255m\033[1m"
  BG_GIT_DIRTY="\033[48;5;197m"; FG_GIT_DIRTY_TEXT="\033[38;5;255m\033[1m"
  BG_MODEL="\033[48;5;63m"; FG_MODEL_TEXT="\033[38;5;255m\033[1m"
  BG_DIR="\033[48;5;38m"; FG_DIR_TEXT="\033[38;5;232m\033[1m"
  BG_META="\033[48;5;236m"; FG_META_TEXT="\033[38;5;250m"
fi

# ─── Git resilience wrapper ─────────────────────────────────────────────────
run_with_timeout() {
  if command -v timeout &>/dev/null; then
    timeout 1s "$@"
  else
    "$@"
  fi
}

GIT_DIR="${CWD:-.}"
VCS_BRANCH=$(run_with_timeout git -C "$GIT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
VCS_DIRTY="false"
if [ -n "$VCS_BRANCH" ]; then
  if run_with_timeout git -C "$GIT_DIR" status --porcelain 2>/dev/null | grep -q .; then
    VCS_DIRTY="true"
  fi
fi

# ─── CPU load & RAM (pure bash) ─────────────────────────────────────────────
MEM_PCT=""
LOAD_1M=""
if [ -f /proc/meminfo ]; then
  mem_total=0
  mem_avail=0
  while read -r name value unit; do
    if [ "$name" = "MemTotal:" ]; then
      mem_total=$value
    elif [ "$name" = "MemAvailable:" ]; then
      mem_avail=$value
      break
    fi
  done < /proc/meminfo
  if [ "$mem_total" -gt 0 ]; then
    MEM_PCT=$(( (mem_total - mem_avail) * 100 / mem_total ))
  fi
fi
if [ -f /proc/loadavg ]; then
  read -r load_1m rest < /proc/loadavg
  LOAD_1M=$load_1m
fi

# ─── Value helpers ───────────────────────────────────────────────────────
PCT_FMT=$(LC_NUMERIC=C printf "%.1f" "$USED_PCT")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}

human_format() {
  local num=$1
  if [ -z "$num" ] || [ "$num" -eq 0 ] 2>/dev/null; then
    echo "0"
    return
  fi
  if [ "$num" -ge 1000000 ] 2>/dev/null; then
    echo "$((num / 1000000)).$(((num % 1000000) / 100000))M"
  elif [ "$num" -ge 1000 ] 2>/dev/null; then
    echo "$((num / 1000)).$(((num % 1000) / 100))K"
  else
    echo "$num"
  fi
}

INPUT_TOK_FMT=$(human_format "$INPUT_TOKENS")
OUTPUT_TOK_FMT=$(human_format "$OUTPUT_TOKENS")
CTX_LIMIT_FMT=$(human_format "$CTX_LIMIT")
CTX_USED_FMT=$(human_format "$((INPUT_TOKENS + OUTPUT_TOKENS))")
TURN_INPUT_FMT=$(human_format "$TURN_INPUT_TOKENS")
TURN_OUTPUT_FMT=$(human_format "$TURN_OUTPUT_TOKENS")

shorten_path() {
  local path=$1
  if [ -z "$path" ]; then
    echo ""
    return
  fi
  path="${path/#$HOME/\~}"
  if [ "${#path}" -gt 25 ]; then
    echo "...$(basename "$path")"
  else
    echo "$path"
  fi
}
CWD_SHORT=$(shorten_path "$CWD")

visible_len() {
  local stripped wide_count
  stripped=$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')
  # `wc -m` counts *characters*, not terminal *columns*. A handful of our
  # icons (🌳 worktree, 💰 cost, 🔋 battery, ✋ manual-mode) are emoji that
  # render as 2 columns wide in virtually every terminal but only count as
  # 1 character, so budgets built on the raw char count silently under-shoot
  # the real rendered width -- eventually enough to make the terminal itself
  # hard-wrap a line we thought still had room. Add back the missing column
  # for each occurrence of a known double-width glyph.
  wide_count=$(printf '%s' "$stripped" | grep -o '🌳\|💰\|🔋\|✋' | wc -l)
  echo $(( $(printf '%s' "$stripped" | wc -m) + wide_count ))
}

# ─── Segment / badge formatters ────────────────────────────────────────────
make_segment() {
  local bg_color="$1" fg_text="$2" text="$3" next_bg="$4"
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${bg_color}${text}${R} "
    return
  fi
  local fg_sep_code
  fg_sep_code=$(echo -n "$bg_color" | sed 's/48;/38;/')
  if [ -n "$next_bg" ]; then
    echo -n "${bg_color}${fg_text} ${text} ${next_bg}${fg_sep_code}${R}"
  else
    echo -n "${bg_color}${fg_text} ${text} \033[0m${fg_sep_code}${R}"
  fi
}

make_badge() {
  local icon="$1" val="$2" icon_color="$3" bg_color="236"
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${FG_GRAY}${icon} ${NUM_COLOR}${val}${R}"
    return
  fi
  echo -n "\033[38;5;${bg_color}m\033[48;5;${bg_color}m\033[38;5;${icon_color}m${icon} \033[38;5;255m\033[1m${val}\033[0m\033[38;5;${bg_color}m\033[0m"
}

clip_line() {
  local s="$1" max="$2" vis
  vis=$(visible_len "$s")
  if [ "$vis" -le "$max" ] || [ "$max" -le 0 ]; then
    printf '%s' "$s"
    return
  fi
  # Extreme-narrow fallback: resolve escapes, strip color codes, hard-cut so
  # we never wrap (loses styling on this edge case, but stays on one row).
  echo -e "$s" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-"$max"
}

print_right_aligned() {
  local left="$1" right="$2" total_cols="$3"
  local left_vis right_vis pad
  left_vis=$(visible_len "$left")
  right_vis=$(visible_len "$right")
  pad=$(( total_cols - left_vis - right_vis ))
  [ "$pad" -lt 1 ] && pad=1
  printf "%b%*s%b\n" "$left" "$pad" "" "$right"
}

# ─── Context bar ────────────────────────────────────────────────────────────
FILLED=$((PCT_INT * BAR_LEN / 100))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  BAR=""
  for ((i = 0; i < BAR_LEN; i++)); do
    if [ "$i" -lt "$FILLED" ]; then BAR="${BAR}█"
    elif [ "$i" -eq "$FILLED" ]; then
      if [ "$REMAINDER" -ge 75 ]; then BAR="${BAR}▓"
      elif [ "$REMAINDER" -ge 50 ]; then BAR="${BAR}▒"
      elif [ "$REMAINDER" -ge 25 ]; then BAR="${BAR}░"
      else BAR="${BAR}·"
      fi
    else BAR="${BAR}·"
    fi
  done
  CTX_BAR="${FG_GRAY}${ICON_CTX} ${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"
else
  if [ "$PCT_INT" -ge 90 ]; then bar_c="197"; elif [ "$PCT_INT" -ge 60 ]; then bar_c="214"; else bar_c="76"; fi
  label_bg="236"; bar_bg="235"
  # NOTE: only change the *foreground* per character (no \033[0m reset in the
  # loop). A full reset would also wipe the pill's background color set below,
  # leaving a black gap over the unfilled portion of the bar.
  BAR="\033[48;5;${bar_bg}m"
  for ((i = 0; i < BAR_LEN; i++)); do
    if [ "$i" -lt "$FILLED" ]; then
      BAR="${BAR}\033[38;5;${bar_c}m█"
    elif [ "$i" -eq "$FILLED" ]; then
      if [ "$REMAINDER" -ge 75 ]; then BAR="${BAR}\033[38;5;${bar_c}m▓"
      elif [ "$REMAINDER" -ge 50 ]; then BAR="${BAR}\033[38;5;${bar_c}m▒"
      else BAR="${BAR}\033[38;5;${bar_c}m░"
      fi
    else
      BAR="${BAR}\033[38;5;236m░"
    fi
  done
  BAR="${BAR}\033[0m"
  CTX_BAR="\033[38;5;${label_bg}m\033[48;5;${label_bg}m\033[38;5;220m${ICON_CTX} ctx ${BAR}\033[48;5;${label_bg}m \033[38;5;220m\033[1m${PCT_FMT}%\033[0m\033[38;5;${label_bg}m\033[0m"
fi

TOK_DETAILS_WIDE=""
TOK_DETAILS_MED=""
if [ "$((INPUT_TOKENS + OUTPUT_TOKENS))" -gt 0 ] 2>/dev/null; then
  turn_str=""
  if [ "$TURN_INPUT_TOKENS" -gt 0 ] 2>/dev/null || [ "$TURN_OUTPUT_TOKENS" -gt 0 ] 2>/dev/null; then
    turn_str=" | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
  fi
  TOK_DETAILS_WIDE=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT} total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
  TOK_DETAILS_MED=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
fi

# ─── Badges ──────────────────────────────────────────────────────────────
SYS_FMT=""
if [ -n "$MEM_PCT" ] && [ -n "$LOAD_1M" ]; then
  sys_color="76"
  load_int=${LOAD_1M%.*}; load_int=${load_int:-0}
  if [ "$MEM_PCT" -ge 80 ] 2>/dev/null || [ "$load_int" -ge 8 ] 2>/dev/null; then
    sys_color="197"
  elif [ "$MEM_PCT" -ge 65 ] 2>/dev/null; then
    sys_color="214"
  fi
  SYS_FMT=$(make_badge "${ICON_SYS}" "RAM:${MEM_PCT}% | ld:${LOAD_1M}" "$sys_color")
fi

STYLE_FMT=""
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  STYLE_FMT=$(make_badge "${ICON_STYLE}" "${OUTPUT_STYLE}" "135")
fi

VIM_FMT=""
if [ -n "$VIM_MODE" ]; then
  vim_color="76"
  [ "$VIM_MODE" = "INSERT" ] && vim_color="214"
  VIM_FMT=$(make_badge "${ICON_VIM}" "${VIM_MODE}" "$vim_color")
fi

POWER_FMT=""
AC_ONLINE_PATH=$(ls /sys/class/power_supply/*/online 2>/dev/null | head -n 1)
BAT_CAP_PATH=$(ls /sys/class/power_supply/*/capacity 2>/dev/null | head -n 1)
if [ -n "$AC_ONLINE_PATH" ]; then
  AC_ON=$(cat "$AC_ONLINE_PATH" 2>/dev/null || echo "1")
  BAT_CAP=""
  [ -n "$BAT_CAP_PATH" ] && BAT_CAP=$(cat "$BAT_CAP_PATH" 2>/dev/null || echo "")
  if [ "$AC_ON" = "0" ]; then
    label="BAT"; [ -n "$BAT_CAP" ] && label="${BAT_CAP}%"
    POWER_FMT=$(make_badge "${ICON_BAT}" "$label" "214")
  else
    POWER_FMT=$(make_badge "${ICON_AC}" "AC" "76")
  fi
fi

# ─── Estimated session cost ─────────────────────────────────────────────
# cursor-agent's statusline payload has no cost/price field (unlike Claude
# Code's `cost.total_cost_usd`) -- Cursor is subscription/usage-based, not
# metered per raw token via this CLI. This is an estimate derived from
# cumulative token counts x Cursor's own published per-model list pricing
# (cursor.com/docs/models-and-pricing, USD per 1M tokens), plus the $0.25/M
# "Cursor Token Rate" surcharge Team/Enterprise plans add on third-party
# models (Cursor's own models -- Grok, Composer -- are exempt).
#
# Known limitations vs. your real bill:
#   - The payload only reports combined input/output token totals, not the
#     cache-write / cache-read split Cursor actually bills on (cache reads
#     are far cheaper than fresh input in agentic sessions with a lot of
#     repeated context) -- so this tends to OVER-estimate cost.
#   - "-fast" model variants, Auto routing, and legacy Max Mode surcharges
#     aren't reflected unless the model id/name says so explicitly.
# For a real number, check https://cursor.com/dashboard/usage after a
# session, or (Team/Enterprise admins) the Admin API's
# /teams/filtered-usage-events `chargedCents` field.
price_for_model() {
  local key
  key=$(printf '%s %s' "$MODEL_ID" "$MODEL_NAME" | tr '[:upper:]' '[:lower:]')
  case "$key" in
    # Cursor-native models -- exempt from the Cursor Token Rate surcharge
    *grok*4.6*fast*)                 echo "4 12 1" ;;
    *grok*4.5*fast*)                 echo "4 18 1" ;;
    *grok*)                          echo "2 6 1" ;;
    *composer*fast*)                 echo "3 15 1" ;;
    *composer*)                      echo "0.5 2.5 1" ;;
    # Third-party models -- list price, surcharge applied separately below
    *fable*)                         echo "10 50 0" ;;
    *opus*4.7*fast*)                 echo "30 150 0" ;;
    *opus*)                          echo "5 25 0" ;;
    *sonnet*5*)                      echo "2 10 0" ;;   # "Claude Sonnet 5" family (incl. 1M variant)
    *sonnet*)                        echo "3 15 0" ;;   # older Claude 4.x Sonnet family
    *haiku*)                         echo "1 5 0" ;;
    *muse*spark*)                    echo "1.25 4.25 0" ;;
    *gpt*5.6*sol*)                   echo "4 20 0" ;;
    *gpt*5.6*terra*)                 echo "2 12 0" ;;
    *gpt*5.6*luna*)                  echo "0.2 1.2 0" ;;
    *gpt*5.5*)                       echo "5 30 0" ;;
    *gpt*5.4*mini*)                  echo "0.75 4.5 0" ;;
    *gpt*5.4*nano*)                  echo "0.2 1.25 0" ;;
    *gpt*5.4*)                       echo "2.5 15 0" ;;
    *gpt*5.2*|*gpt*5.3*)             echo "1.75 14 0" ;;
    *gpt*5.1*mini*)                  echo "0.25 2 0" ;;
    *gpt*5.1*|*gpt*5-codex*)         echo "1.25 10 0" ;;
    *gpt*5*mini*)                    echo "0.25 2 0" ;;
    *gpt*5*fast*)                    echo "2.5 20 0" ;;
    *gpt*5*|*gpt5*)                  echo "1.25 10 0" ;;
    *gemini*3*pro*)                  echo "2 12 0" ;;
    *gemini*3.5*flash*)              echo "1.5 9 0" ;;
    *gemini*3.6*flash*)              echo "1.5 7.5 0" ;;
    *gemini*3.7*flash*|*gemini*3.8*flash*) echo "0.75 3.5 0" ;;
    *gemini*flash*)                  echo "0.5 3 0" ;;
    *gemini*)                        echo "1 6 0" ;;
    *glm*)                           echo "1.4 4.4 0" ;;
    *kimi*)                          echo "1.5 8 0" ;;
    *)                               echo "3 15 0" ;;  # unrecognized model fallback
  esac
}

# Whether to add Cursor's $0.25/M "Cursor Token Rate" surcharge for
# third-party models (applies on Team/Enterprise plans). Override with
# --no-token-rate if you're on an individual Pro/Pro Plus/Ultra plan.
APPLY_TOKEN_RATE=true
for arg in "$@"; do
  [ "$arg" = "--no-token-rate" ] && APPLY_TOKEN_RATE=false
done

# ─── Session token tracking & accumulation ────────────────────────────────
# cursor-agent payloads report current context window snapshot size
# (context_window.total_input_tokens), NOT cumulative tokens across all turns.
# In multi-turn sessions, each turn sends the context window to the API.
# We persist session token state in ~/.cache/cursor-agent-statusline/sessions/
# to accumulate cumulative input/output tokens for accurate session cost math.
CUM_INPUT_TOKENS="$INPUT_TOKENS"
CUM_OUTPUT_TOKENS="$OUTPUT_TOKENS"

if [ -n "$SESSION_ID" ] && command -v jq &>/dev/null; then
  SESS_CACHE_DIR="${CURSOR_COST_CACHE_DIR:-$HOME/.cache/cursor-agent-statusline}/sessions"
  mkdir -p "$SESS_CACHE_DIR" 2>/dev/null || true
  SESS_FILE="$SESS_CACHE_DIR/${SESSION_ID}.json"

  if [ -f "$SESS_FILE" ]; then
    eval "$(jq -r '
      "PREV_CUM_IN=" + (.cum_input // 0 | tostring) +
      "\nPREV_CUM_OUT=" + (.cum_output // 0 | tostring) +
      "\nLAST_CTX_IN=" + (.last_ctx_in // 0 | tostring) +
      "\nLAST_CTX_OUT=" + (.last_ctx_out // 0 | tostring) +
      "\nLAST_TURN_IN=" + (.last_turn_in // 0 | tostring) +
      "\nLAST_TURN_OUT=" + (.last_turn_out // 0 | tostring)
    ' "$SESS_FILE" 2>/dev/null || true)"

    PREV_CUM_IN="${PREV_CUM_IN:-0}"
    PREV_CUM_OUT="${PREV_CUM_OUT:-0}"
    LAST_CTX_IN="${LAST_CTX_IN:-0}"
    LAST_CTX_OUT="${LAST_CTX_OUT:-0}"
    LAST_TURN_IN="${LAST_TURN_IN:-0}"
    LAST_TURN_OUT="${LAST_TURN_OUT:-0}"

    DELTA_IN=0
    DELTA_OUT=0

    if [ "$TURN_INPUT_TOKENS" -gt 0 ] 2>/dev/null && [ "$TURN_INPUT_TOKENS" -ne "$LAST_TURN_IN" ]; then
      DELTA_IN="$INPUT_TOKENS"
      DELTA_OUT="$TURN_OUTPUT_TOKENS"
    elif [ "$INPUT_TOKENS" -gt "$LAST_CTX_IN" ] 2>/dev/null; then
      DELTA_IN="$INPUT_TOKENS"
      [ "$OUTPUT_TOKENS" -gt "$LAST_CTX_OUT" ] 2>/dev/null && DELTA_OUT=$((OUTPUT_TOKENS - LAST_CTX_OUT))
    elif [ "$OUTPUT_TOKENS" -gt "$LAST_CTX_OUT" ] 2>/dev/null; then
      DELTA_OUT=$((OUTPUT_TOKENS - LAST_CTX_OUT))
    fi

    CUM_INPUT_TOKENS=$((PREV_CUM_IN + DELTA_IN))
    CUM_OUTPUT_TOKENS=$((PREV_CUM_OUT + DELTA_OUT))

    [ "$CUM_INPUT_TOKENS" -lt "$INPUT_TOKENS" ] 2>/dev/null && CUM_INPUT_TOKENS="$INPUT_TOKENS"
    [ "$CUM_OUTPUT_TOKENS" -lt "$OUTPUT_TOKENS" ] 2>/dev/null && CUM_OUTPUT_TOKENS="$OUTPUT_TOKENS"
  fi

  jq -n \
    --argjson cum_in "$CUM_INPUT_TOKENS" \
    --argjson cum_out "$CUM_OUTPUT_TOKENS" \
    --argjson last_ctx_in "$INPUT_TOKENS" \
    --argjson last_ctx_out "$OUTPUT_TOKENS" \
    --argjson last_turn_in "$TURN_INPUT_TOKENS" \
    --argjson last_turn_out "$TURN_OUTPUT_TOKENS" \
    '{cum_input:$cum_in, cum_output:$cum_out, last_ctx_in:$last_ctx_in, last_ctx_out:$last_ctx_out, last_turn_in:$last_turn_in, last_turn_out:$last_turn_out}' \
    > "$SESS_FILE" 2>/dev/null || true
fi

# ─── Optional calibration cache (see cursor-real-cost.sh) ────────────────
# A separate, manually/cron-run script can fetch REAL billed cost from
# Cursor's Admin API and write a small JSON cache here. When present, we
# prefer it over the static rate-table guess, in priority order:
#   1. Exact real $ for this session (by_conversation[session_id]) -- no
#      pricing math involved at all, just the actual chargedCents Cursor
#      billed for this conversation.
#   2. A per-model blended $/1M-token rate calibrated from your own recent
#      billing history (bakes in your real cache-hit ratio).
#   3. The static official-rate-table estimate (always available, no setup
#      required).
CALIBRATION_FILE="${CURSOR_COST_CACHE_DIR:-$HOME/.cache/cursor-agent-statusline}/calibration.json"
CAL_REAL_USD=""
CAL_BLENDED_RATE=""
if [ -f "$CALIBRATION_FILE" ] && command -v jq &>/dev/null; then
  if [ -n "$SESSION_ID" ]; then
    CAL_REAL_USD=$(jq -r --arg sid "$SESSION_ID" '.by_conversation[$sid].charged_usd // empty' "$CALIBRATION_FILE" 2>/dev/null || true)
  fi
  if [ -z "$CAL_REAL_USD" ]; then
    MODEL_KEY_LC=$(printf '%s' "${MODEL_ID:-$MODEL_NAME}" | tr '[:upper:]' '[:lower:]')
    CAL_BLENDED_RATE=$(jq -r --arg m "$MODEL_KEY_LC" \
      '.models | to_entries[] | select(.key | ascii_downcase == $m) | .value.blended_usd_per_m_io_tokens' \
      "$CALIBRATION_FILE" 2>/dev/null | head -1 || true)
  fi
fi

COST_FMT=""
if [ -n "$CAL_REAL_USD" ] && command -v awk &>/dev/null; then
  COST_VAL=$(awk -v v="$CAL_REAL_USD" 'BEGIN{printf "%.2f", v}')
  COST_FMT=$(make_badge "${ICON_COST}" "\$${COST_VAL} real" "76")
elif [ -n "$CAL_BLENDED_RATE" ] && [ "$((CUM_INPUT_TOKENS + CUM_OUTPUT_TOKENS))" -gt 0 ] 2>/dev/null && command -v awk &>/dev/null; then
  COST_VAL=$(awk -v it="$CUM_INPUT_TOKENS" -v ot="$CUM_OUTPUT_TOKENS" -v r="$CAL_BLENDED_RATE" \
    'BEGIN{printf "%.2f", ((it+ot)/1000000)*r}')
  COST_FMT=$(make_badge "${ICON_COST}" "~\$${COST_VAL} cal." "214")
elif [ "$((CUM_INPUT_TOKENS + CUM_OUTPUT_TOKENS))" -gt 0 ] 2>/dev/null && command -v awk &>/dev/null; then
  read -r PRICE_IN PRICE_OUT IS_NATIVE <<< "$(price_for_model)"
  TOKEN_RATE="0"
  if [ "$APPLY_TOKEN_RATE" = "true" ] && [ "$IS_NATIVE" != "1" ]; then
    TOKEN_RATE="0.25"
  fi
  COST_VAL=$(awk -v it="$CUM_INPUT_TOKENS" -v ot="$CUM_OUTPUT_TOKENS" -v pi="$PRICE_IN" -v po="$PRICE_OUT" -v tr="$TOKEN_RATE" \
    'BEGIN{printf "%.2f", (it/1000000*pi)+(ot/1000000*po)+((it+ot)/1000000*tr)}')
  COST_FMT=$(make_badge "${ICON_COST}" "~\$${COST_VAL} est." "220")
fi

truncate_str() {
  local s="$1" max="$2"
  local len
  len=$(printf '%s' "$s" | wc -m)
  if [ "$len" -gt "$max" ]; then
    printf '%s…' "$(printf '%s' "$s" | cut -c1-$((max - 1)))"
  else
    printf '%s' "$s"
  fi
}

MODEL_DISP="${MODEL_NAME:-$MODEL_ID}"
if [ -n "$PARAM_SUMMARY" ]; then
  MODEL_DISP="${MODEL_DISP} ${PARAM_SUMMARY}"
fi
if [ "$MAX_MODE" = "true" ]; then
  MODEL_DISP="${MODEL_DISP} MAX"
fi
MODEL_DISP=$(truncate_str "$MODEL_DISP" 32)

SESSION_DISP=""
if [ -n "$SESSION_NAME" ]; then
  SESSION_DISP="$SESSION_NAME"
elif [ -n "$SESSION_ID" ]; then
  SESSION_DISP="${SESSION_ID:0:8}"
fi
SESSION_DISP=$(truncate_str "$SESSION_DISP" 18)

# ─── LINE1 assembly (powerline, width-budgeted to avoid wraparound) ────────
ACTIVE_SEGS=(); ACTIVE_BGS=(); ACTIVE_FGS=()

# Reserve a safety margin (box prefix + rounding slack for wide glyphs/emoji)
LINE1_BUDGET=$((COLS - 8))
[ "$LINE1_BUDGET" -lt 12 ] && LINE1_BUDGET=12
LINE1_RUNNING=0

add_seg() {
  local text="$1" bg="$2" fg="$3" force="${4:-false}"
  local w
  w=$(( $(visible_len "$text") + 2 ))
  if [ "$force" != "true" ] && [ "$((LINE1_RUNNING + w))" -gt "$LINE1_BUDGET" ]; then
    return 1
  fi
  ACTIVE_SEGS+=("$text"); ACTIVE_BGS+=("$bg"); ACTIVE_FGS+=("$fg")
  LINE1_RUNNING=$((LINE1_RUNNING + w))
  return 0
}

# 1. Approval mode (always shown)
if [ "$AUTORUN" = "true" ]; then
  add_seg "${ICON_AUTO} AUTO" "$BG_AUTO" "$FG_AUTO_TEXT" true
else
  add_seg "${ICON_MANUAL} MANUAL" "$BG_MANUAL" "$FG_MANUAL_TEXT" true
fi

# 2. Model (core identity, always shown)
if [ -n "$MODEL_DISP" ]; then
  add_seg "${ICON_MODEL} ${MODEL_DISP}" "$BG_MODEL" "$FG_MODEL_TEXT" true
fi

# 3. Directory (core identity, always shown)
if [ -n "$CWD_SHORT" ]; then
  add_seg "${ICON_DIR} ${CWD_SHORT}" "$BG_DIR" "$FG_DIR_TEXT" true
fi

# 4. VCS branch (optional, dropped first on narrow terminals)
if [ -n "$VCS_BRANCH" ]; then
  if [ "$VCS_DIRTY" = "true" ]; then
    add_seg "${ICON_VCS} ${VCS_BRANCH}*" "$BG_GIT_DIRTY" "$FG_GIT_DIRTY_TEXT" || true
  else
    add_seg "${ICON_VCS} ${VCS_BRANCH}" "$BG_GIT_CLEAN" "$FG_GIT_CLEAN_TEXT" || true
  fi
fi

# 5. Worktree (optional)
if [ -n "$WT_NAME" ]; then
  add_seg "${ICON_WT} ${WT_NAME}" "$BG_META" "$FG_META_TEXT" || true
fi

# 6. Session (optional)
if [ -n "$SESSION_DISP" ]; then
  add_seg "${ICON_SESSION} ${SESSION_DISP}" "$BG_META" "$FG_META_TEXT" || true
fi

# 7. Version (optional, lowest priority)
if [ -n "$VERSION" ]; then
  add_seg "v${VERSION}" "$BG_META" "$FG_META_TEXT" || true
fi

LINE1=""
num_segs=${#ACTIVE_SEGS[@]}
for ((i = 0; i < num_segs; i++)); do
  next_bg=""
  if [ "$((i + 1))" -lt "$num_segs" ]; then
    next_bg="${ACTIVE_BGS[i+1]}"
  fi
  LINE1="${LINE1}$(make_segment "${ACTIVE_BGS[i]}" "${ACTIVE_FGS[i]}" "${ACTIVE_SEGS[i]}" "$next_bg")"
done

# ─── Output assembly based on terminal size ─────────────────────────────────
sep="  "
line_pref1=""; line_pref2=""; line_pref3=""
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  sep=" | "
else
  line_pref1="${FG_GRAY}╭─${R}"
  line_pref2="${FG_GRAY}├─${R}"
  line_pref3="${FG_GRAY}╰─${R}"
fi

# Build the badge row, dropping least-important badges first if it would
# overflow the available width (mirrors the LINE1 budgeting above).
build_badge_line() {
  local budget="$1"
  local running line
  line="${CTX_BAR}${TOK_DETAILS_MED}"
  running=$(visible_len "$line")
  for badge in "$COST_FMT" "$STYLE_FMT" "$VIM_FMT" "$SYS_FMT" "$POWER_FMT"; do
    [ -z "$badge" ] && continue
    local w
    w=$(( $(visible_len "$badge") + 2 ))
    if [ "$((running + w))" -le "$budget" ]; then
      line="${line}${sep}${badge}"
      running=$((running + w))
    fi
  done
  printf '%s' "$line"
}

LINE1_VIS=$(visible_len "$LINE1")

if [ "$COLS" -ge 180 ] && [ "$((LINE1_VIS + 40))" -lt "$COLS" ]; then
  # Wide layout: single row, powerline left + badges right (only when there
  # is comfortably enough room; otherwise fall through to boxed layout below)
  LINE2=$(build_badge_line $((COLS - LINE1_VIS - 4)))
  LINE2_VIS=$(visible_len "$LINE2")
  if [ "$((LINE1_VIS + LINE2_VIS + 1))" -le "$COLS" ]; then
    print_right_aligned "$LINE1" "$LINE2" "$COLS"
  else
    echo -e "${line_pref1}$(clip_line "$LINE1" $((COLS - 2)))"
    echo -e "${line_pref3}$(clip_line "$LINE2" $((COLS - 2)))"
  fi

elif [ "$COLS" -ge 100 ]; then
  # Medium layout: 2-line boxed display
  LINE2=$(build_badge_line $((COLS - 3)))
  echo -e "${line_pref1}$(clip_line "$LINE1" $((COLS - 2)))"
  echo -e "${line_pref3}$(clip_line "$LINE2" $((COLS - 2)))"

else
  # Compact layout: stacked display, badges wrapped onto their own line(s)
  LINE2="${CTX_BAR}${TOK_DETAILS_MED}"
  LINE3=""
  for badge in "$COST_FMT" "$SYS_FMT" "$STYLE_FMT" "$VIM_FMT" "$POWER_FMT"; do
    if [ -n "$badge" ]; then
      if [ -n "$LINE3" ]; then LINE3="${LINE3}${sep}${badge}"; else LINE3="${badge}"; fi
    fi
  done
  echo -e "${line_pref1}$(clip_line "$LINE1" $((COLS - 2)))"
  echo -e "${line_pref2}$(clip_line "$LINE2" $((COLS - 2)))"
  if [ -n "$LINE3" ]; then
    echo -e "${line_pref3}$(clip_line "$LINE3" $((COLS - 2)))"
  fi
fi
