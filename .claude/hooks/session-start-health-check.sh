#!/usr/bin/env bash
# Claude Analytics - SessionStart health check hook
# VERSION: 1.0.0

DOCKER_CONTAINERS=("claude-analytics-clickhouse" "claude-analytics-otel" "claude-analytics-grafana" "claude-analytics-hooks")
HOOKS_SERVER_URL="http://localhost:14319/health"

docker_healthy=true
hooks_healthy=true
down_containers=()

for container in "${DOCKER_CONTAINERS[@]}"; do
  running=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)
  if [ "$running" != "true" ]; then
    docker_healthy=false
    down_containers+=("$container")
  fi
done

hooks_status=$(curl -sf -o /dev/null -w "%{http_code}" "$HOOKS_SERVER_URL" 2>/dev/null)
if [ "$hooks_status" != "200" ]; then
  hooks_healthy=false
fi

escape_for_json() {
  local s=""
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

if [ "$docker_healthy" = true ] && [ "$hooks_healthy" = true ]; then
  context="[claude-analytics] All services healthy. Docker stack and hooks server running. Dashboards: http://localhost:3000"
  sysmsg="[claude-analytics] Services healthy. Dashboards: http://localhost:3000"
else
  context="[claude-analytics] WARNING: Monitoring services are NOT fully operational."
  sysmsg="[claude-analytics] WARNING: Monitoring services are NOT fully operational."
  if [ "$docker_healthy" = false ]; then
    detail=" Containers down: ${down_containers[*]}. Run: docker compose up -d from Analytic_Claude/docker-stack."
    context="$context$detail"
    sysmsg="$sysmsg$detail"
  fi
  if [ "$hooks_healthy" = false ]; then
    detail=" Hooks server not responding on port 14319. Run: docker compose up -d from Analytic_Claude/docker-stack."
    context="$context$detail"
    sysmsg="$sysmsg$detail"
  fi
fi

escaped_context=$(escape_for_json "$context")
escaped_sysmsg=$(escape_for_json "$sysmsg")

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  },\n  "systemMessage": "%s"\n}\n' "$escaped_context" "$escaped_sysmsg"

exit 0
