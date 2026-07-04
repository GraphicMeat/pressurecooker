#!/usr/bin/env node
// pressurecooker map server — zero-dependency MCP stdio server exposing the
// committed codebase map (docs/pressurecooker/codebase-map/) to agents and
// subagents as queryable tools, instead of every agent re-reading MAP.md.
//
// Transport: newline-delimited JSON-RPC 2.0 over stdio (MCP stdio transport).
// Data source: MAP.md + jscpd-report.json in the target project. Read-only.

import { readFileSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { createInterface } from "node:readline";

const PROJECT =
  process.env.CLAUDE_PROJECT_DIR ||
  tryGit(["rev-parse", "--show-toplevel"]) ||
  process.cwd();
const MAP_DIR = join(PROJECT, "docs", "pressurecooker", "codebase-map");
const MAP_FILE = join(MAP_DIR, "MAP.md");

function tryGit(args, cwd = process.cwd()) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

function readMap() {
  if (!existsSync(MAP_FILE)) return null;
  return readFileSync(MAP_FILE, "utf8");
}

// Split MAP.md into { sectionTitle: body } on `## ` headings.
function sections(map) {
  const out = {};
  let current = "_preamble";
  out[current] = [];
  for (const line of map.split("\n")) {
    const m = line.match(/^## (.+)$/);
    if (m) {
      current = m[1].trim();
      out[current] = [];
    } else {
      out[current].push(line);
    }
  }
  for (const k of Object.keys(out)) out[k] = out[k].join("\n").trim();
  return out;
}

function staleness(map) {
  const m = map.match(/^analyzed-at:\s*(\S+)/m);
  if (!m) return { analyzedAt: null, commitsBehind: null, note: "no analyzed-at header" };
  const hash = m[1];
  const count = tryGit(["rev-list", "--count", `${hash}..HEAD`], PROJECT);
  return {
    analyzedAt: hash,
    commitsBehind: count === null ? null : Number(count),
    stale: count !== null && Number(count) > 30,
    note: count === null ? "hash not found in this repo — map may predate a rewrite" : undefined,
  };
}

const NO_MAP =
  "No codebase map found at docs/pressurecooker/codebase-map/MAP.md. " +
  "Run the pressurecooker:analyzing-codebase skill to generate it.";

const TOOLS = [
  {
    name: "map_overview",
    description:
      "Full codebase map (MAP.md): stack, architecture, module graph, duplication report, conventions, risks, top refactoring issues. Includes staleness info.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "map_section",
    description:
      "One section of the codebase map by title, e.g. 'Module Graph', 'Duplication Report', 'Conventions', 'Risks & Observations', 'Top 5 Refactoring Issues', 'Stack', 'Architecture'. Cheaper than map_overview.",
    inputSchema: {
      type: "object",
      properties: { section: { type: "string", description: "Section title (case-insensitive substring match)" } },
      required: ["section"],
      additionalProperties: false,
    },
  },
  {
    name: "consumers_of",
    description:
      "Lines of the map's Module Graph and Duplication Report mentioning a module/file — fast first answer for 'who depends on this?'. Verify against current code; the map is a hint.",
    inputSchema: {
      type: "object",
      properties: { module: { type: "string", description: "Module or file name (substring match)" } },
      required: ["module"],
      additionalProperties: false,
    },
  },
  {
    name: "map_staleness",
    description:
      "How far the codebase map lags HEAD: analyzed-at commit, commits behind, stale flag (>30). Check before trusting map answers.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
];

function callTool(name, args) {
  const map = readMap();
  if (!map) return NO_MAP;

  switch (name) {
    case "map_overview": {
      const s = staleness(map);
      return `staleness: ${JSON.stringify(s)}\n\n${map}`;
    }
    case "map_section": {
      const secs = sections(map);
      const want = String(args?.section || "").toLowerCase();
      const key = Object.keys(secs).find((k) => k.toLowerCase().includes(want));
      if (!key) return `Section not found. Available: ${Object.keys(secs).filter((k) => k !== "_preamble").join(", ")}`;
      return `## ${key}\n${secs[key]}`;
    }
    case "consumers_of": {
      const term = String(args?.module || "").toLowerCase();
      if (!term) return "module argument required";
      const secs = sections(map);
      const pools = ["Module Graph", "Duplication Report"];
      const hits = [];
      for (const pool of pools) {
        const key = Object.keys(secs).find((k) => k.toLowerCase().includes(pool.toLowerCase()));
        if (!key) continue;
        for (const line of secs[key].split("\n")) {
          if (line.toLowerCase().includes(term)) hits.push(`[${key}] ${line.trim()}`);
        }
      }
      return hits.length
        ? `Map lines mentioning "${args.module}" (verify against current code):\n${hits.join("\n")}`
        : `No map lines mention "${args.module}". Either it has no recorded consumers or the map predates it — verify in code.`;
    }
    case "map_staleness":
      return JSON.stringify(staleness(map), null, 2);
    default:
      throw new Error(`unknown tool: ${name}`);
  }
}

// ---- JSON-RPC over stdio ----
const rl = createInterface({ input: process.stdin });
function send(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

rl.on("line", (line) => {
  line = line.trim();
  if (!line) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return; // ignore non-JSON noise
  }
  const { id, method, params } = msg;
  if (id === undefined) return; // notification — nothing to do

  try {
    if (method === "initialize") {
      send({
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: params?.protocolVersion || "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: { name: "pressurecooker-map", version: "0.1.0" },
        },
      });
    } else if (method === "tools/list") {
      send({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
    } else if (method === "tools/call") {
      const text = callTool(params?.name, params?.arguments || {});
      send({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text }] } });
    } else if (method === "ping") {
      send({ jsonrpc: "2.0", id, result: {} });
    } else {
      send({ jsonrpc: "2.0", id, error: { code: -32601, message: `method not found: ${method}` } });
    }
  } catch (e) {
    send({ jsonrpc: "2.0", id, error: { code: -32000, message: String(e?.message || e) } });
  }
});
