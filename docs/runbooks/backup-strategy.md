# Runbook — Backup strategy

## Current state (2026-04-16)

| Aspect | Setting |
|---|---|
| Schedule | Daily at 03:30 CEST |
| Retention | Last 7 backups |
| Agent | `hassio.local` (on the Pi itself) |
| Database included | Yes |
| Add-ons included | All |
| Password-protected | No |

One manual backup (`audit-2026-04-16`, 23.18 MB) exists from initial setup.

## ⚠️ Known gap: backups are on the same SD card

The current agent writes to `/backup/` on the Pi's SD card. **This protects against software corruption but not hardware failure.** If the SD card dies, both the running install and the backups are lost.

This is the single biggest remaining risk in the setup. Addressing it is the next priority when time allows.

## Options for off-Pi backup storage

Ordered by lift vs. value:

### Home Assistant Cloud (~€7.50/month)

Native one-click integration. Stores backups in Nabu Casa's cloud. Also gets you remote access (bypassing Cloudflared) and Alexa/Google voice. Easiest option if you don't mind the subscription.

### Google Drive Backup (free)

HACS add-on: `sabeechen/hassio-google-drive-backup`. Authenticates once with a Google account, then uploads each new backup automatically. Set-and-forget. Storage is your Drive quota.

### Samba Backup (free, needs a NAS or always-on Mac)

Pushes backups to an SMB share. Requires a reliable target host. Good option if you already have a Synology / QNAP / always-on Mac on the LAN.

### rsync via SSH (free, no add-on)

Cron job on another machine that pulls `/backup/` via SSH. Most flexible, least polish.

## Verifying backups work

### Is automatic backup scheduled?

```bash
curl -sS -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.0.52:8123/api/states/sensor.backup_next_scheduled_automatic_backup \
  | python3 -m json.tool
```

Should show the next `03:30` as `state`.

### Did the last scheduled backup succeed?

```bash
curl -sS -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.0.52:8123/api/states/sensor.backup_last_successful_automatic_backup
```

### List stored backups

```bash
ssh victor@192.168.0.52 'ls -lh /backup/'
```

### Trigger a backup on demand

Via the `hassio.backup_full` service:

```bash
curl -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"manual-YYYY-MM-DD"}' \
  http://192.168.0.52:8123/api/services/hassio/backup_full
```

Or via the UI: Settings → System → Backups → Create backup.

## If Settings → System → Backups UI shows "set up automatic backups"

This is a cosmetic flag (`automatic_backups_configured`) that only flips to `true` when the user clicks through the UI setup wizard once. The schedule runs regardless, but the flag drives UI nag prompts. Running through the wizard once will silence it.
