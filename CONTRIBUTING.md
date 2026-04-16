# Contributing

Notes for future-you (and anyone you invite to collaborate later).

## When to update what

| You changed… | Update this |
|---|---|
| Added/removed a device | `docs/devices.md`, `docs/architecture.md` if a new zone |
| Installed/removed an integration or add-on | `docs/integrations.md` |
| Changed a YAML file on the Pi (configuration.yaml, etc.) | Run `./scripts/pull-config.sh` to snapshot |
| Made a non-obvious choice ("why X, not Y?") | Add an ADR in `docs/decisions/NNN-short-name.md` |
| Created a repeatable operational procedure | Add a runbook in `docs/runbooks/` |
| Changed how access works (SSH, URLs, tokens) | `README.md` + `docs/architecture.md` |

Rule of thumb: **if you'd have to re-derive it 6 months from now, write it down.**

## Commit message style

Conventional-ish, but not strict. One short line, imperative mood.

```
docs: add runbook for Zigbee coordinator replacement
config: enable circadian brightness on Pasillo
feat: introduce Bedroom adaptive lighting zone
fix: correct IP mapping for Kitchen Bulb 3 after DHCP change
```

Prefixes are suggestions, not required. For meaningful changes include a body explaining *why*, not just *what* — the diff already shows the what.

## Before committing

1. **Run `git diff --cached`** — eyeball every staged line.
2. **Scan for secrets**. Values to never commit:
   - JWT/long-lived access tokens (`eyJ...`)
   - Tuya `local_key` (16 random chars per device)
   - Tuya `client_secret`, `client_id`, `user_id`
   - Passwords of any kind
   - Cloudflared tunnel tokens
   
   Quick grep:
   ```bash
   git diff --cached | grep -iE "token|secret|password|local_key|eyJ"
   ```
   If anything matches a real value (vs. a mention like "the `local_key` is stored in `.storage/`"), remove it.

3. **Confirm `.gitignore` allowlist still holds.** Running `git status --ignored` will show what's being ignored; if something that should be tracked is ignored, or something sensitive is tracked, update `.gitignore`.

## Workflow cheatsheet

```bash
# After UI-driven HA changes
./scripts/pull-config.sh
git diff config/
git add -A && git commit -m "config: describe the change"
git push

# After documentation changes
# (edit docs/*.md directly)
git add docs/
git commit -m "docs: describe the change"
git push
```

## ADR template

```markdown
# ADR-NNN — Short title

- **Date**: YYYY-MM-DD
- **Status**: Accepted | Superseded by ADR-XXX

## Context
What situation forced this decision? What was broken or suboptimal?

## Decision
What you chose.

## Alternatives considered
Brief list with pros/cons. Even the rejected ones — future-you will want to know they were considered.

## Consequences
What this unlocks, and what ongoing cost it creates.

## References
Links to upstream issues, docs, or related ADRs.
```

## Runbook template

```markdown
# Runbook — Short title

## When you'd run this
One or two sentences on the trigger.

## Prerequisites
Things that must be true before starting.

## Steps
Numbered list. Copy-pasteable commands where possible.

## Verification
How to confirm it worked.

## Troubleshooting
Things that can go wrong and what to do about them.
```

## Keeping the KB honest

State dates rot. When you touch a doc that mentions a snapshot date ("State as of 2026-04-16"), update the date if the content is still accurate, or rewrite the affected section. A stale date on accurate info is fine; a current date on stale info is misleading.

Run through `docs/` top-to-bottom once a quarter — 15 minutes, catches drift.
