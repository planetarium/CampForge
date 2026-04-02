#!/usr/bin/env bash
# v8-auth.sh — RFC 8628 Device Authorization for V8 API
# Usage:
#   eval $(bash v8-auth.sh)          # login & export V8_TOKEN
#   eval $(bash v8-auth.sh status)   # check stored token
#   bash v8-auth.sh logout           # clear stored token
set -euo pipefail

V8_API="${V8_API_BASE:-https://v8-meme-api.verse8.io}"
TOKEN_FILE="${V8_TOKEN_FILE:-${HOME}/.config/v8/token}"

# --- helpers ---

jwt_payload() {
  local payload
  payload=$(echo "$1" | cut -d. -f2)
  local pad=$(( 4 - ${#payload} % 4 ))
  [ "$pad" -lt 4 ] && payload="${payload}$(printf '%0.s=' $(seq 1 "$pad"))"
  echo "$payload" | base64 -d 2>/dev/null
}

jwt_exp() {
  jwt_payload "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exp',0))"
}

jwt_field() {
  jwt_payload "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$2','unknown'))"
}

# --- token storage (file-based, chmod 600) ---

token_get() {
  [ -f "$TOKEN_FILE" ] && cat "$TOKEN_FILE" 2>/dev/null || echo ""
}

token_set() {
  mkdir -p "$(dirname "$TOKEN_FILE")"
  printf '%s' "$1" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
}

token_delete() {
  rm -f "$TOKEN_FILE"
}

token_valid() {
  local token="$1"
  [ -z "$token" ] && return 1
  local exp
  exp=$(jwt_exp "$token")
  [ "$(date +%s)" -lt "$((exp - 60))" ]
}

# --- commands ---

cmd_status() {
  local token
  token=$(token_get)
  if token_valid "$token"; then
    local email exp_ts
    email=$(jwt_field "$token" email)
    exp_ts=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp($(jwt_exp "$token")).isoformat())")
    echo "# V8 token valid (${email}, expires ${exp_ts})" >&2
    echo "export V8_TOKEN='${token}'"
  else
    echo "# No valid V8 token found. Run: eval \$(bash $0)" >&2
    return 1
  fi
}

cmd_logout() {
  token_delete
  echo "V8 token removed." >&2
}

cmd_login() {
  local existing
  existing=$(token_get)
  if token_valid "$existing"; then
    echo "# Reusing valid token" >&2
    echo "# Logged in as $(jwt_field "$existing" email)" >&2
    echo "export V8_TOKEN='${existing}'"
    return 0
  fi

  echo "Requesting device code..." >&2
  local auth_resp
  auth_resp=$(curl -sf -X POST "${V8_API}/v1/auth/device/authorize")

  local device_code user_code verify_uri interval
  device_code=$(echo "$auth_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['device_code'])")
  user_code=$(echo "$auth_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['user_code'])")
  verify_uri=$(echo "$auth_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('verification_uri_complete') or d['verification_uri'])")
  interval=$(echo "$auth_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('interval', 5))")

  echo "" >&2
  echo "  Code:  ${user_code}" >&2
  echo "  URL:   ${verify_uri}" >&2
  echo "" >&2
  echo "Waiting for browser authorization..." >&2

  while true; do
    sleep "$interval"
    local token_resp http_code
    token_resp=$(curl -s -w "\n%{http_code}" -X POST "${V8_API}/v1/auth/device/token" \
      -H "Content-Type: application/json" \
      -d "{\"grant_type\":\"urn:ietf:params:oauth:grant-type:device_code\",\"device_code\":\"${device_code}\"}")

    http_code=$(echo "$token_resp" | tail -1)
    local body
    body=$(echo "$token_resp" | sed '$d')

    if [ "$http_code" = "200" ]; then
      local access_token
      access_token=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
      token_set "$access_token"
      echo "Logged in as $(jwt_field "$access_token" email)" >&2
      echo "export V8_TOKEN='${access_token}'"
      return 0
    fi

    local error
    error=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error',''))" 2>/dev/null || echo "")

    case "$error" in
      authorization_pending) printf "." >&2 ;;
      slow_down) interval=$((interval + 5)); printf "." >&2 ;;
      expired_token) echo -e "\nDevice code expired. Please retry." >&2; return 1 ;;
      access_denied) echo -e "\nAuthorization denied." >&2; return 1 ;;
      *) echo -e "\nUnexpected error: ${body}" >&2; return 1 ;;
    esac
  done
}

case "${1:-login}" in
  status) cmd_status ;;
  logout) cmd_logout ;;
  login|*) cmd_login ;;
esac
