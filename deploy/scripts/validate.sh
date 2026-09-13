#!/bin/bash
# Fails the deployment (and therefore triggers the automatic CodeDeploy
# rollback) if the new release does not answer its health checks.
set -uo pipefail

check() {
  local url="$1" name="$2"
  for attempt in $(seq 1 30); do
    if curl -fsS --max-time 5 "$url" >/dev/null; then
      echo "$name healthy after ${attempt} attempt(s)"
      return 0
    fi
    sleep 5
  done
  echo "$name FAILED health check: $url" >&2
  return 1
}

check "http://127.0.0.1:8000/api/health" "backend"
check "http://127.0.0.1:3000/health"     "frontend"
