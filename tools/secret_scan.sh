#!/usr/bin/env bash
# secret_scan.sh — Phase 0 secret gate (TDD §9.2, D6). Fails CI if a real secret pattern
# appears in any TRACKED file: OpenAI/Anthropic keys, private keys, AWS keys, or a JWT whose
# decoded payload is a service_role token. Extra-strict for client/ (anon key only ships).
# Deterministic, no external deps — the planted-secret test reliably turns CI red.
set -uo pipefail

fail=0
note() { echo "  SECRET? $1"; fail=1; }

# tracked files only (skips node_modules/.godot/art); exclude this scanner + addons.
mapfile -t FILES < <(git ls-files | grep -vE '^(client/addons/|tools/secret_scan\.sh$)')

KEY_PATTERNS=(
  'sk-[A-Za-z0-9]{32,}'              # OpenAI secret key
  'sk-proj-[A-Za-z0-9_-]{20,}'       # OpenAI project key
  'sk-ant-[A-Za-z0-9_-]{20,}'        # Anthropic key
  'AKIA[0-9A-Z]{16}'                 # AWS access key id
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
)

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  for p in "${KEY_PATTERNS[@]}"; do
    if grep -IEq -e "$p" "$f"; then note "$f matches /$p/"; fi
  done
  # JWTs whose payload decodes to a service_role token
  for tok in $(grep -ohE 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+' "$f" 2>/dev/null); do
    payload="${tok#*.}"
    pad=$(( (4 - ${#payload} % 4) % 4 )); payload="${payload}$(printf '=%.0s' $(seq 1 $pad))"
    decoded=$(printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null || true)
    if printf '%s' "$decoded" | grep -q 'service_role'; then note "$f embeds a service_role JWT"; fi
  done
done

# client/ must never contain a service-role or OpenAI key (anon key only).
if git ls-files 'client/**' | xargs -r grep -lIE 'service_role|sk-[A-Za-z0-9]{32,}|OPENAI_API_KEY=' 2>/dev/null | grep -q .; then
  note "client/ contains a forbidden secret reference"
fi

if [ "$fail" -ne 0 ]; then
  echo "SECRET SCAN: FAIL — secrets must never be committed (anon key only in client; server keys in Vercel/Supabase env)."
  exit 1
fi
echo "secret scan: clean"
