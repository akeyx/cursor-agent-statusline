#!/usr/bin/env node
// refresh-real-cost.mjs - Fetch REAL billed cost per cursor-agent session
// via Cursor's official @cursor/sdk (npm), using a personal User API key.
//
// Unlike the Admin API (cursor-real-cost.sh), this does NOT require Team
// Admin access -- a plain User API key works, because the SDK explicitly
// supports user API keys (Team Admin API keys are not yet supported by the
// SDK, per Cursor's own docs). Agent.getUsage() returns the same billed
// `chargedCents` figure regardless of whether the session was started from
// the IDE, the CLI, or the SDK itself -- it's one underlying agent/run
// concept across all of Cursor's clients.
//
// ── Setup ────────────────────────────────────────────────────────────────
//   1. Generate a User API key: cursor.com/dashboard -> API Keys -> New API Key
//   2. Never paste it into a chat/agent session. Store it yourself:
//        export CURSOR_API_KEY="crsr_..."
//      or persist it in your shell profile / a local .env you control.
//   3. npm install   (installs the pinned @cursor/sdk from package.json)
//
// ── Usage ────────────────────────────────────────────────────────────────
//   node refresh-real-cost.mjs                 # scan recent local CLI sessions
//   node refresh-real-cost.mjs <sessionId> ... # refresh specific session IDs
//   node refresh-real-cost.mjs --days 3        # change the recency window (default 7)
//
// Writes/merges into the SAME cache file statusline.sh already reads:
//   ~/.cache/cursor-agent-statusline/calibration.json  (by_conversation map)

import { Agent } from "@cursor/sdk";
import { readdir, stat, readFile, writeFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

const apiKey = process.env.CURSOR_API_KEY;
if (!apiKey) {
  console.error("Set CURSOR_API_KEY to a User API key (cursor.com/dashboard -> API Keys).");
  console.error("Never paste the key into a chat/agent session -- export it yourself.");
  process.exit(1);
}

const args = process.argv.slice(2);
let days = 7;
const explicitIds = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--days") {
    days = Number(args[++i]) || 7;
  } else {
    explicitIds.push(args[i]);
  }
}

const CACHE_DIR = process.env.CURSOR_COST_CACHE_DIR || path.join(homedir(), ".cache", "cursor-agent-statusline");
const CACHE_FILE = path.join(CACHE_DIR, "calibration.json");

async function discoverRecentSessionIds(maxAgeDays) {
  const chatsRoot = path.join(homedir(), ".cursor", "chats");
  const ids = [];
  let workspaceDirs;
  try {
    workspaceDirs = await readdir(chatsRoot, { withFileTypes: true });
  } catch {
    return ids;
  }
  const cutoff = Date.now() - maxAgeDays * 86400 * 1000;
  for (const wsDir of workspaceDirs) {
    if (!wsDir.isDirectory()) continue;
    const wsPath = path.join(chatsRoot, wsDir.name);
    let sessionDirs;
    try {
      sessionDirs = await readdir(wsPath, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const sDir of sessionDirs) {
      if (!sDir.isDirectory()) continue;
      const sPath = path.join(wsPath, sDir.name);
      try {
        const st = await stat(sPath);
        if (st.mtimeMs >= cutoff) ids.push(sDir.name);
      } catch {
        // ignore
      }
    }
  }
  return ids;
}

async function loadCache() {
  try {
    const raw = await readFile(CACHE_FILE, "utf8");
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

async function saveCache(cache) {
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(CACHE_FILE, JSON.stringify(cache, null, 2));
}

const sessionIds = explicitIds.length > 0 ? explicitIds : await discoverRecentSessionIds(days);
if (sessionIds.length === 0) {
  console.error("No session IDs to check (nothing found under ~/.cursor/chats in the lookback window).");
  process.exit(0);
}

console.error(`Checking ${sessionIds.length} session(s) via @cursor/sdk Agent.getUsage()...`);

const cache = await loadCache();
cache.by_conversation = cache.by_conversation || {};

let updated = 0;
let skipped = 0;
for (const id of sessionIds) {
  try {
    const usage = await Agent.getUsage(id, { apiKey });
    if (usage && usage.cost) {
      cache.by_conversation[id] = {
        charged_usd: usage.cost.chargedCents / 100,
        events: usage.runs ? usage.runs.length : 1,
        source: "sdk",
        updated_at: new Date().toISOString(),
      };
      updated++;
    } else {
      // Cost not settled yet, or this ID has no billing record (e.g. free/
      // plan-included run with nothing charged). Leave any existing entry.
      skipped++;
    }
  } catch (err) {
    skipped++;
    if (process.env.DEBUG) console.error(`  ${id}: ${err?.message || err}`);
  }
  // Be gentle -- these are individual lookups, not a bulk endpoint.
  await new Promise((r) => setTimeout(r, 150));
}

cache.updated_at = new Date().toISOString();
await saveCache(cache);

console.error(`Updated ${updated} session(s), skipped ${skipped} (not found / not settled / $0).`);
console.error(`Cache: ${CACHE_FILE}`);
