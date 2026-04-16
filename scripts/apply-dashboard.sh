#!/usr/bin/env bash
# Apply a dashboard YAML from this repo to the Home Assistant Pi.
#
# Usage: ./scripts/apply-dashboard.sh <dashboard-name>
#   e.g. ./scripts/apply-dashboard.sh home  →  config/dashboards/home.yaml
#
# Mechanism: converts the YAML to HA's storage-JSON shape and calls the
# `lovelace/config/save` WebSocket command on the Pi. HA re-renders live;
# no restart needed. Browser may need a hard refresh to pick up new cards.
#
# Requires: ssh key auth to the Pi, HA_TOKEN in
#   /Users/victor/.claude/projects/-Users-victor-Playground-hass/memory/ha_token.txt

set -euo pipefail

DASHBOARD="${1:?Usage: $0 <dashboard-name>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YAML="$REPO_ROOT/config/dashboards/${DASHBOARD}.yaml"
TOKEN_FILE="/Users/victor/.claude/projects/-Users-victor-Playground-hass/memory/ha_token.txt"
HA_URL="${HA_URL:-192.168.0.52:8123}"
URL_PATH="${DASHBOARD_URL_PATH:-dashboard-${DASHBOARD}}"

[ -f "$YAML" ] || { echo "Missing: $YAML"; exit 1; }
[ -f "$TOKEN_FILE" ] || { echo "Missing HA token at $TOKEN_FILE"; exit 1; }

HA_TOKEN=$(cat "$TOKEN_FILE") YAML_PATH="$YAML" URL_PATH="$URL_PATH" HA_URL="$HA_URL" \
python3 <<'PY'
import asyncio, json, os, yaml, websockets, sys

cfg = yaml.safe_load(open(os.environ["YAML_PATH"]))
token = os.environ["HA_TOKEN"].strip()
url_path = os.environ["URL_PATH"]
ws_url = f"ws://{os.environ['HA_URL']}/api/websocket"

async def main():
    async with websockets.connect(ws_url, max_size=50_000_000) as ws:
        await ws.recv()
        await ws.send(json.dumps({"type":"auth","access_token":token}))
        auth = json.loads(await ws.recv())
        assert auth.get("type") == "auth_ok", auth
        await ws.send(json.dumps({
            "id": 1,
            "type": "lovelace/config/save",
            "url_path": url_path,
            "config": cfg,
        }))
        resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
        if resp.get("success"):
            print(f"OK: {url_path} updated")
        else:
            print("FAIL:", resp, file=sys.stderr)
            sys.exit(1)

asyncio.run(main())
PY
