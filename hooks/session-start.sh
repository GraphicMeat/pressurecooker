#!/usr/bin/env bash
# SessionStart hook for the pressurecooker plugin.
# pressurecooker requires the `caveman` plugin. plugin.json declares it as a
# formal dependency (auto-resolved within the same marketplace); this hook is a
# fallback check for cross-marketplace installs where auto-resolution won't fire.
set -euo pipefail

plugins_root="${HOME}/.claude/plugins/cache"

# caveman is installed if any cache/<marketplace>/caveman/<version>/ manifest exists.
if compgen -G "${plugins_root}/*/caveman/*/.claude-plugin/plugin.json" >/dev/null 2>&1 \
   || compgen -G "${plugins_root}/*/caveman/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  ctx="pressurecooker plugin loaded. caveman dependency present."
else
  ctx="pressurecooker WARNING: required plugin \`caveman\` not detected. Install it: /plugin install caveman@caveman"
fi

cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ctx}"
  }
}
JSON
