# Runbook — Recover from SD-card failure

## When you'd run this

- SD card is dead, corrupted, or the RPi won't boot.
- You're migrating to new hardware (new Pi, different SBC, VM, etc.).
- You're doing a fresh install and want to restore prior state.

## What you need

- A recent Home Assistant backup (see [backup-strategy.md](backup-strategy.md) for location).
- A fresh SD card (32 GB+, A2-rated preferred) or new host hardware.
- The [Home Assistant OS installer](https://www.home-assistant.io/installation/raspberrypi) image.
- About an hour of time.

## Steps

### 1. Install a fresh Home Assistant OS

Flash Home Assistant OS to the new SD card using Raspberry Pi Imager (select *Other specific-purpose OS → Home assistant and home automation → Home Assistant OS*). Boot the Pi, wait for the onboarding page to appear at `http://homeassistant.local:8123` (may take 15–30 minutes on first boot).

**Don't create the onboarding user yet.** Look for the "Restore from a backup" link on the welcome screen instead.

### 2. Upload the backup

The onboarding "Restore from backup" flow accepts a `.tar` backup file. Upload the most recent one from your off-Pi location.

If no off-Pi backup exists but the old SD card is partially readable, pull backups from `/backup/` on the old card via an SD reader.

### 3. Wait for restore

HA restores all config entries, `.storage/`, and the recorder DB. On a Pi 3 this takes 10–20 minutes for a typical backup. Don't interrupt.

### 4. Post-restore verification

- Log in with your old credentials.
- Check **Settings → Devices & Services** — all integrations should be `loaded`.
- Check the LocalTuya integration — all 6 bulbs should appear, though they may briefly be `unavailable` until they rediscover the Pi's new IP.
- Check the Cloudflared add-on — if the tunnel token is in the restored config, external access should come back. If not, re-enter the token from the Cloudflare Zero Trust dashboard.
- Verify SSH add-on — key auth should work since `authorized_keys` was restored.
- Check `update.*` entities — apply any pending updates.
- Trigger a manual backup to confirm the chain is healthy.

### 5. If some integrations fail to restore

- **Tuya-related**: re-run the LocalTuya cloud setup flow if cloud creds were wiped. See [renew-tuya-trial.md](renew-tuya-trial.md).
- **Cloudflared**: re-enter the tunnel token; the routes in the Cloudflare dashboard are independent and still exist.
- **iPhone mobile_app**: delete and re-register from the iOS app (the stored shared secret binds to the old install).

## What this runbook does NOT recover

- **Your SD card's entropy** — entropy files are regenerated.
- **Cached sensor readings older than the backup** — whatever was in the recorder DB at backup time is preserved; anything after is lost.
- **Zigbee coordinator pairing state** — CC2531 doesn't support coordinator backup; if you swap coordinator hardware, devices need to be re-paired. (Staying on the same CC2531 is fine — its state is in `/config/zigbee.db` which is included in backups.)

## Prevention (you should already have this)

Automatic backups run daily at 03:30, retain 7 copies, stored locally on the Pi. See [backup-strategy.md](backup-strategy.md) for the current setup and open items.
