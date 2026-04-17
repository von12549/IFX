#!/usr/bin/env bash
# Claude Analytics - Generic forward hook
# VERSION: 1.0.0
# Forwards hook payload to hooks server via fire-and-forget POST.
# Used for SessionStart and all command-only hook events.
#
# Usage: "$CLAUDE_PROJECT_DIR"/.claude/hooks/forward-hook.sh <PROJECT_NAME>

PROJECT_NAME="${1:-unknown}"
HOOKS_URL="http://localhost:14319/hook?projectName=${PROJECT_NAME}"

payload=$(cat)

(
  curl -sS --max-time 2 -X POST \
    -H "Content-Type: application/json" \
    --data-raw "$payload" \
    "$HOOKS_URL" >/dev/null 2>&1 &
) >/dev/null 2>&1

printf '{"continue": true}\n'
exit 0
