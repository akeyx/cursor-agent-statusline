# cursor-agent-statusline

An enhanced, powerline-style status line for the [`cursor-agent` CLI](https://cursor.com/cli) — matching the look of premium status line plugins like [`claude-dashboard`](https://github.com/uppinote20/claude-dashboard) for Claude Code, adapted to the `cursor-agent` status line payload.

## Features

- **Powerline segments**: approval mode (`AUTO`/`MANUAL`), git branch (dirty indicator), model name + params (`MAX` badge), current directory, git worktree name, session name/id, CLI version.
- **Context window bar**: color-coded usage bar with token counts (session total + per-turn).
- **Session cost badge**, in order of preference:
  1. **`$X.XX real`** — exact, pulled from Cursor's official Admin API by [`cursor-real-cost.sh`](#real-cost-calibration-optional) (only if it's been run and found billing data for this exact session).
  2. **`~$X.XX cal.`** — a per-model $/1M-token rate *calibrated from your own real billing history* (via the same script), applied to this session's live token counts.
  3. **`~$X.XX est.`** — a static estimate from Cursor's published [per-model rate card](https://cursor.com/docs/models-and-pricing), plus the $0.25/M "Cursor Token Rate" surcharge Team/Enterprise plans add on third-party models (pass `--no-token-rate` if you're on an individual Pro/Pro Plus/Ultra plan). Always available, no setup required — but `cursor-agent`'s statusline payload doesn't expose the cache-write/cache-read token split Cursor actually bills on, so this tier tends to *over*-estimate cost in sessions with heavy prompt caching.

### Real cost calibration (optional)

`cursor-agent`'s own statusline payload has no cost field at all, and there's no official Cursor MCP/CLI for billing data — only a handful of low-adoption community MCP wrappers, which didn't clear our bar for handling a billing-scoped API key. Instead, [`cursor-real-cost.sh`](./cursor-real-cost.sh) talks directly to Cursor's official, documented Admin API (`POST https://api.cursor.com/teams/filtered-usage-events`) and writes a small local cache the statusline reads (no network calls happen in the statusline's own hot path).

**Setup** (requires Team/Enterprise admin access to generate a key):

```bash
# 1. Generate a key at cursor.com/dashboard -> Settings -> Advanced -> Admin API Keys
# 2. Store it yourself -- never paste it into a chat/agent session:
mkdir -p ~/.config/cursor-admin && chmod 700 ~/.config/cursor-admin
read -rs -p "Cursor Admin API key: " CURSOR_KEY && echo
printf '%s' "$CURSOR_KEY" > ~/.config/cursor-admin/api_key
chmod 600 ~/.config/cursor-admin/api_key
unset CURSOR_KEY

# 3. Run it (pulls the last 7 days by default):
./cursor-real-cost.sh
```

Cursor aggregates billing data hourly, so re-run this periodically (a cron job or systemd timer at most once/hour is plenty) to keep the cache fresh. Very recent/in-progress sessions won't show a `real` badge until Cursor has billed and aggregated them — the statusline falls back to `cal.` or `est.` until then.
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

## Requirements

- `bash`, `jq`
- A [Nerd Font](https://www.nerdfonts.com/) for icon glyphs (optional — use `--classic` otherwise)

## License

MIT
