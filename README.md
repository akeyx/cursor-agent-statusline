# cursor-agent-statusline

An enhanced, powerline-style status line for the [`cursor-agent` CLI](https://cursor.com/cli) — matching the look of premium status line plugins like [`claude-dashboard`](https://github.com/uppinote20/claude-dashboard) for Claude Code, adapted to the `cursor-agent` status line payload.

## Features

- **Powerline segments**: approval mode (`AUTO`/`MANUAL`), git branch (dirty indicator), model name + params (`MAX` badge), current directory, git worktree name, session name/id, CLI version.
- **Context window bar**: color-coded usage bar with token counts (session total + per-turn).
- **Estimated session cost**: a `~$X.XX est.` badge derived from token counts x Cursor's own published [per-model rate card](https://cursor.com/docs/models-and-pricing), plus the $0.25/M "Cursor Token Rate" surcharge Team/Enterprise plans add on third-party models (pass `--no-token-rate` if you're on an individual Pro/Pro Plus/Ultra plan). `cursor-agent`'s payload has no real billing/cost field, and doesn't expose the cache-write/cache-read token split Cursor actually bills on — so this tends to *over*-estimate cost in sessions with heavy prompt caching. For a real number, check [cursor.com/dashboard/usage](https://cursor.com/dashboard/usage), or (Team/Enterprise admins) the Admin API's `/teams/filtered-usage-events` `chargedCents` field.
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
