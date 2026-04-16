# Home Assistant — Operations & Knowledge Base

Private repository documenting the state, architecture, and operational runbooks for the Home Assistant installation at home.

## What this repository is

1. **Knowledge base** — living documentation of the setup: device inventory, zone architecture, integrations, and the *why* behind key decisions.
2. **Config snapshots** — version-controlled copies of the handful of YAML files worth tracking (most configuration lives in `.storage/*.json` and is intentionally excluded).
3. **Runbooks** — operational procedures for recurring or high-stakes tasks.

This repo is **not** a full disaster-recovery backup. Home Assistant's automatic daily backups (configured on the Pi itself, 7-copy retention) handle bit-for-bit restore. Git tracks *intent and history*; the backup archive tracks *state*.

## What this repository is NOT

- Not a complete `/config` mirror — `.storage/*.json`, the recorder DB, custom components, and TTS cache are all excluded.
- Not a place for secrets — `secrets.yaml`, long-lived tokens, Tuya local keys, and Tuya IoT Cloud client secrets must never be committed.
- Not auto-synced — snapshots are pulled manually via `scripts/pull-config.sh`; inspect the diff before every commit.

## Repository layout

```
homeassistant/
├── README.md                  — you are here
├── CONTRIBUTING.md            — commit conventions, ADR/runbook templates
├── docs/
│   ├── architecture.md        — topology, protocols, zone model
│   ├── devices.md             — full device inventory with IDs/IPs
│   ├── integrations.md        — integration list, purpose, config entries
│   ├── dashboards.md          — Home + System dashboards overview
│   ├── runbooks/              — how-to guides for operations
│   ├── decisions/             — ADR-style "why" records
│   └── automations/           — reference copies of UI-created automations
├── config/
│   ├── configuration.yaml     — main HA config
│   ├── {automations,scripts,scenes}.yaml — empty stubs (UI-managed via .storage/)
│   ├── secrets.yaml.example   — template only
│   └── dashboards/
│       ├── home.yaml          — Home dashboard YAML source
│       └── system.yaml        — System dashboard YAML source
└── scripts/
    ├── pull-config.sh         — SSH + copy tracked YAML from Pi
    └── apply-dashboard.sh     — push a dashboard YAML to the Pi via WebSocket
```

For conventions, secret-hygiene checks, and ADR/runbook templates, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Quick navigation

| I need to… | Go to |
|---|---|
| Understand what's where | [docs/architecture.md](docs/architecture.md) |
| Find a device by name, IP, or protocol | [docs/devices.md](docs/devices.md) |
| Know what's installed and why | [docs/integrations.md](docs/integrations.md) |
| Edit or understand the dashboards | [docs/dashboards.md](docs/dashboards.md) |
| Add a new Tuya bulb | [docs/runbooks/add-tuya-device.md](docs/runbooks/add-tuya-device.md) |
| Renew the Tuya IoT Cloud trial | [docs/runbooks/renew-tuya-trial.md](docs/runbooks/renew-tuya-trial.md) |
| Recover from an SD-card failure | [docs/runbooks/recover-from-sd-death.md](docs/runbooks/recover-from-sd-death.md) |
| Understand the backup strategy | [docs/runbooks/backup-strategy.md](docs/runbooks/backup-strategy.md) |
| Know why LocalTuya, not cloud | [docs/decisions/001-localtuya-xzetsubou.md](docs/decisions/001-localtuya-xzetsubou.md) |
| See what the door-alert automation does | [docs/automations/front-door-alerts-away.md](docs/automations/front-door-alerts-away.md) |

## Access

- Local URL: http://192.168.0.52:8123
- External URL: https://ha.jougarcia.uk (via Cloudflared tunnel)
- SSH: `ssh victor@192.168.0.52` (key auth only, no password)

## Keeping the repo fresh

After making meaningful changes in the HA UI:

```bash
./scripts/pull-config.sh    # snapshots YAML files from /config/
git diff                    # review what changed
git add -A && git commit -m "describe what changed"
git push
```

For KB updates, edit the relevant file in `docs/` directly — no pull script needed.
