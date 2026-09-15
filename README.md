# cursor-agent-statusline

An enhanced, powerline-style status line for the [`cursor-agent` CLI](https://cursor.com/cli) — matching the look of premium status line plugins like [`claude-dashboard`](https://github.com/uppinote20/claude-dashboard) for Claude Code, adapted to the `cursor-agent` status line payload.

## Features

- **Powerline segments**: approval mode (`AUTO`/`MANUAL`), git branch (dirty indicator), model name + params (`MAX` badge), current directory, git worktree name, session name/id, CLI version.
- **Context window bar**: color-coded usage bar with token counts (session total + per-turn).
- **Session cost badge**, in order of preference:
  1. **`$X.XX real`** — exact, pulled from Cursor's official Admin API by [`cursor-real-cost.sh`](#real-cost-calibration-optional-team-enterprise-admin-only) (only if it's been run and found billing data for this exact session).
  2. **`~$X.XX cal.`** — a per-model $/1M-token rate *calibrated from your own real billing history* (via the same script), applied to this session's live token counts.
  3. **`~$X.XX est.`** — a static estimate from Cursor's published [per-model rate card](https://cursor.com/docs/models-and-pricing), plus the $0.25/M "Cursor Token Rate" surcharge Team/Enterprise plans add on third-party models (pass `--no-token-rate` if you're on an individual Pro/Pro Plus/Ultra plan). Always available, no setup required — but `cursor-agent`'s statusline payload doesn't expose the cache-write/cache-read token split Cursor actually bills on, so this tier tends to *over*-estimate cost in sessions with heavy prompt caching.
- **Host badges**: RAM/load average, AC/battery status, vim mode, active output style.
- **Responsive layout**: automatically switches between a single-row powerline (wide terminals), a 2-line boxed layout (medium), and a stacked layout (narrow) — width-budgeted so segments and badges are dropped in priority order before anything wraps.
- **Nerd Font or classic**: use `--classic` for a plain-ASCII fallback on terminals without a patched Nerd Font.

## Installation

```bash
git clone https://github.com/akeyx/cursor-agent-statusline.git
cp cursor-agent-statusline/statusline.sh ~/.cursor/statusline.sh
chmod +x ~/.cursor/statusline.sh
```

Then add (or merge) this into `~/.cursor/cli-config.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.cursor/statusline.sh",
    "padding": 0
  }
}
```

Restart `cursor-agent` to see it take effect.

If your terminal doesn't have a [Nerd Font](https://www.nerdfonts.com/) installed, use the classic fallback instead:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.cursor/statusline.sh --classic",
    "padding": 0
  }
}
```

## Usage

```bash
# Show the icon/field legend
echo '{}' | ~/.cursor/statusline.sh --legend

# Test with a mock payload
echo '{"model":{"display_name":"Claude Sonnet 5"},"context_window":{"used_percentage":25}}' | ~/.cursor/statusline.sh
```

## Real cost calibration (optional, Team/Enterprise Admin only)

`cursor-agent`'s own statusline payload has no cost field at all, and there's no official Cursor MCP for billing data — only a handful of low-adoption community MCP wrappers, which didn't clear our bar for handling a billing-scoped API key. [`cursor-real-cost.sh`](./cursor-real-cost.sh) instead talks directly to Cursor's official, documented Admin API (`POST https://api.cursor.com/teams/filtered-usage-events`), which returns per-event model + token + cost breakdowns, and writes a small local cache (`~/.cache/cursor-agent-statusline/calibration.json`) that `statusline.sh` reads — no network calls happen in the statusline's own hot path.

This **requires a Team/Enterprise Admin API key** (`admin:*` scope) — a plain personal/User API key will not work here; it's a different, more restricted credential scope. We also tried the User-API-key-friendly route (Cursor's official `@cursor/sdk` and its `Agent.getUsage()`), but confirmed empirically (via direct `curl` against the underlying `GET /v1/agents/{id}/usage` REST endpoint, bypassing the SDK's own client-side checks) that it can't do this job at all: plain CLI session IDs are a structurally different ID namespace from SDK-managed "agent IDs" on Cursor's backend (`400 validation_error`), independent of any account permissions or feature flags. So an Admin API key is genuinely the only working path for this feature.

**Setup:**

```bash
# 1. Generate a key at cursor.com/dashboard -> Settings -> Advanced -> Admin API Keys
#    (requires Team/Enterprise admin access)
# 2. Store it yourself -- never paste it into a chat/agent session:
mkdir -p ~/.config/cursor-admin && chmod 700 ~/.config/cursor-admin
read -rs -p "Cursor Admin API key: " CURSOR_KEY && echo
printf '%s' "$CURSOR_KEY" > ~/.config/cursor-admin/api_key
chmod 600 ~/.config/cursor-admin/api_key
unset CURSOR_KEY

./cursor-real-cost.sh     # pulls the last 7 days by default
```

Cursor aggregates billing data hourly, so re-run this periodically (a cron job or systemd timer at most once/hour is plenty) to keep the cache fresh. Very recent/in-progress sessions won't show a `real` badge until Cursor has billed and settled them — the statusline falls back to `cal.` or `est.` until then. Without Team Admin access, just use the `est.` tier (the default, no setup needed).

## Requirements

- `bash`, `jq`
- A [Nerd Font](https://www.nerdfonts.com/) for icon glyphs (optional — use `--classic` otherwise)

## License

MIT
