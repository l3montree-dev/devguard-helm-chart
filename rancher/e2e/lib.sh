# Helpers shared by the e2e scripts. Source env.sh first.

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

die() { log "ERROR: $*"; exit 1; }

# rapi <method> <path> [curl args...] — authenticated Rancher API call.
# Reads the token written by 03-bootstrap.sh.
rapi() {
  local method=$1 path=$2
  shift 2
  curl -sk -X "$method" \
    -H "Authorization: Bearer $(cat "$WORK_DIR/token")" \
    -H 'Content-Type: application/json' \
    "$RANCHER_URL$path" "$@"
}

# wait_for <timeout_seconds> <description> <command...>
# Polls every 5s until the command succeeds or the timeout is reached.
wait_for() {
  local timeout=$1 desc=$2
  shift 2
  local deadline=$((SECONDS + timeout))
  log "waiting (up to ${timeout}s) for: $desc"
  until "$@" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      log "TIMEOUT after ${timeout}s waiting for: $desc"
      return 1
    fi
    sleep 5
  done
  log "OK: $desc"
}

# expect_200 <description> <url> [host_header]
expect_200() {
  local desc=$1 url=$2 host=${3:-}
  local args=(-s -o /dev/null -w '%{http_code}' --max-time 15)
  [[ -n $host ]] && args+=(-H "Host: $host")
  local code
  code=$(curl "${args[@]}" "$url" || true)
  if [[ $code == 200 ]]; then
    log "OK: $desc -> 200"
  else
    log "FAIL: $desc -> HTTP ${code:-<no response>} (expected 200)"
    return 1
  fi
}

# rancher_container — resolve the container id of the rancher service
rancher_container() {
  docker compose -p "$COMPOSE_PROJECT" -f "$RANCHER_STATE_DIR/compose.yml" ps -q rancher
}
