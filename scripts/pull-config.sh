#!/usr/bin/env bash
# Pull tracked YAML files from the Home Assistant Pi into config/ on this repo.
#
# This is an ALLOWLIST, not a mirror. We only pull files that are safe to
# commit and meaningful to diff. Anything not listed here is deliberately
# excluded (see .gitignore for the full blocklist).
#
# Usage: ./scripts/pull-config.sh
# Then:  git diff config/  (review)  →  git add -A && git commit
#
# Assumes SSH key auth is set up for `victor@192.168.0.52`.

set -euo pipefail

HA_HOST="${HA_HOST:-victor@192.168.0.52}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/config"

mkdir -p "$DEST"

# Explicit allowlist — append new paths here when the setup grows.
FILES=(
  "configuration.yaml"
  "automations.yaml"
  "scripts.yaml"
  "scenes.yaml"
)

for f in "${FILES[@]}"; do
  echo "→ $f"
  scp -q -O "$HA_HOST:/config/$f" "$DEST/$f" || {
    echo "  WARNING: $f missing on the Pi (file may not exist yet)"
  }
done

# Capture HA version for context (useful in commit messages)
ssh "$HA_HOST" 'cat /config/.HA_VERSION 2>/dev/null' > "$DEST/.HA_VERSION.snapshot" || true

# Stub secrets.yaml — NEVER pull the real one
SECRETS_EXAMPLE="$DEST/secrets.yaml.example"
if [ ! -f "$SECRETS_EXAMPLE" ]; then
  cat > "$SECRETS_EXAMPLE" <<'EOF'
# This is a template only. The real secrets.yaml lives on the Pi at
# /config/secrets.yaml and is deliberately NOT tracked in git.
#
# Document the KEYS you reference in HA config here, with stubbed values,
# so a fresh install knows what to fill in.

# some_password: "REDACTED"
EOF
fi

echo ""
echo "Done. Review changes:"
echo "  git diff config/"
