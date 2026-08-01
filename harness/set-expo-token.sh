#!/usr/bin/env bash
set -uo pipefail

# Stores the Expo ROBOT access token the Expo docs MCP authenticates with.
#
#   ./set-expo-token.sh
#
# Prompts with echo off and writes harness/.env.local (gitignored, mode 600).
# Nothing is passed as an argument, so the token cannot end up in shell history,
# a process listing, or a transcript.
#
# It must be a ROBOT token, not a personal access token — mcp.expo.dev rejects
# personal tokens outright:
#   401 {"error":"invalid_token","error_description":"The MCP server accepts a
#        robot access token here; personal access tokens are not supported."}
# Create one at https://expo.dev/settings/access-tokens under Robot users.
# Robot tokens are the credential Expo intends for CI, so unlike the interactive
# OAuth session they do not expire hourly — which is what makes an unattended
# multi-hour benchmark run possible at all.

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HARNESS_DIR/.env.local"

printf 'Expo ROBOT access token (input hidden): '
IFS= read -rs TOKEN
printf '\n'

if [ -z "${TOKEN:-}" ]; then
  echo "ERROR: nothing entered — $ENV_FILE not written" >&2
  exit 1
fi

umask 077
# Rewrite only the EXPO_TOKEN line, preserving anything else already in the file.
if [ -f "$ENV_FILE" ]; then
  grep -v '^EXPO_TOKEN=' "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
  mv "$ENV_FILE.tmp" "$ENV_FILE"
fi
printf 'EXPO_TOKEN=%s\n' "$TOKEN" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"
unset TOKEN

echo "wrote $ENV_FILE (mode $(stat -f '%Lp' "$ENV_FILE"), $(wc -c < "$ENV_FILE" | tr -d ' ') bytes)"
echo "gitignored: $(cd "$HARNESS_DIR/.." && git check-ignore -q harness/.env.local && echo yes || echo 'NO — do not commit')"
