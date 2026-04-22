# Runbook — Alexa Smart Home setup

How the Alexa ↔ HA voice control was set up. Use this if you ever need to migrate, reset, or extend the integration.

## Final architecture

```
"Alexa, enciende el salón"
        │
        ▼
  Echo Dot (Alexa device on home WiFi)
        │
        │ Alexa cloud (Amazon)
        ▼
  ┌─────────────────────────────────────────┐
  │ Alexa Smart Home Skill                  │
  │ (developer.amazon.com)                  │
  │  - Skill ID: amzn1.ask.skill.xxxxx      │
  │  - Locale: es-ES                        │
  │  - Account-linked to HA via OAuth       │
  └────────────────┬────────────────────────┘
                   │ HTTPS
                   ▼
  ┌─────────────────────────────────────────┐
  │ AWS Lambda function                     │
  │ HomeAssistant-Alexa (eu-west-1)         │
  │  - Forwards Alexa directives to HA      │
  │  - Returns HA's response to Alexa       │
  └────────────────┬────────────────────────┘
                   │ HTTPS via Cloudflared
                   ▼
  ┌─────────────────────────────────────────┐
  │ Home Assistant                          │
  │ https://ha.jougarcia.uk/api/alexa/...   │
  │  - alexa.smart_home in configuration.yaml│
  │  - Curated entity allowlist             │
  │  - Spanish friendly names               │
  └─────────────────────────────────────────┘
```

## Components

| Component | Where | Purpose |
|---|---|---|
| Alexa Smart Home Skill | developer.amazon.com (private skill, dev mode) | Receives voice intent, calls Lambda |
| AWS Lambda function | aws.amazon.com → Lambda → eu-west-1 | Bridges Alexa ↔ HA |
| HA `alexa.smart_home` integration | `/config/configuration.yaml` | Exposes selected entities via REST endpoint `/api/alexa/smart_home` |
| HA OAuth (built-in) | HA core | Account-linking endpoint for Alexa skill |
| Cloudflared tunnel | already in place | Provides HTTPS endpoint at `ha.jougarcia.uk` |

## Cost

**€0/month** for the volume of voice commands a household generates. AWS Lambda free tier covers ~1M invocations/month — household usage is well under 1000/month.

The skill itself is a private "developer mode" skill — never published to the Alexa Skills marketplace. Only your own Amazon accounts (those signed in to your Alexa devices) can see/use it.

## Configuration on each layer

### HA (`config/configuration.yaml`)

```yaml
alexa:
  smart_home:
    locale: es-ES
    filter:
      include_entities:
        - light.living_room
        - light.kitchen_light
        - light.pasillo
        - light.office_light_local
        - light.lightstrip
        - switch.adaptive_lighting_kitchen
        - switch.adaptive_lighting_pasillo
        - switch.adaptive_lighting_office
    entity_config:
      light.living_room:        { name: Salón }
      light.kitchen_light:      { name: Cocina }
      light.pasillo:            { name: Pasillo }
      light.office_light_local: { name: Oficina }
      light.lightstrip:         { name: Tira de cocina }
      switch.adaptive_lighting_kitchen: { name: Adaptativo cocina }
      switch.adaptive_lighting_pasillo: { name: Adaptativo pasillo }
      switch.adaptive_lighting_office:  { name: Adaptativo oficina }
```

Adding a new entity to Alexa: append it to `include_entities` and (optionally) give it a friendly Spanish name in `entity_config`. Restart HA. Then in the Alexa app: **Devices → + → Add Device → Other → Discover**.

### AWS Lambda

- **Function name**: `HomeAssistant-Alexa`
- **Runtime**: Python 3.12+
- **Region**: `eu-west-1` (Ireland)
- **Timeout**: 10 seconds
- **Trigger**: Alexa Smart Home, gated by Skill ID (security)
- **Code**: see [the canonical Lambda function](https://www.home-assistant.io/integrations/alexa.smart_home/#configuration) — also pasted below for reference
- **Environment variables**:
  - `BASE_URL` = `https://ha.jougarcia.uk`
  - `DEBUG` = `true` (during setup; remove or set to empty when stable)
  - `LONG_LIVED_ACCESS_TOKEN` = empty (only used in DEBUG mode if Alexa fails to send a token)

```python
import json
import logging
import os
import urllib3

_debug = bool(os.environ.get('DEBUG'))

_logger = logging.getLogger('HomeAssistant-SmartHome')
_logger.setLevel(logging.DEBUG if _debug else logging.INFO)


def lambda_handler(event, context):
    _logger.debug('Event: %s', event)

    base_url = os.environ.get('BASE_URL')
    assert base_url is not None, 'Please set BASE_URL environment variable'
    base_url = base_url.strip("/")

    directive = event.get('directive')
    assert directive is not None, 'Malformatted request - missing directive'
    assert directive.get('header', {}).get('payloadVersion') == '3', \
        'Only support payloadVersion == 3'

    scope = directive.get('endpoint', {}).get('scope')
    if scope is None:
        scope = directive.get('payload', {}).get('grantee')
    if scope is None:
        scope = directive.get('payload', {}).get('scope')

    assert scope is not None, 'Malformatted request - missing endpoint.scope'
    assert scope.get('type') == 'BearerToken', 'Only support BearerToken'

    token = scope.get('token')
    if token is None and _debug:
        token = os.environ.get('LONG_LIVED_ACCESS_TOKEN')

    verify_ssl = not bool(os.environ.get('NOT_VERIFY_SSL'))

    http = urllib3.PoolManager(
        cert_reqs='CERT_REQUIRED' if verify_ssl else 'CERT_NONE',
        timeout=urllib3.Timeout(connect=2.0, read=10.0)
    )

    response = http.request(
        'POST',
        '{}/api/alexa/smart_home'.format(base_url),
        headers={
            'Authorization': 'Bearer {}'.format(token),
            'Content-Type': 'application/json',
        },
        body=json.dumps(event).encode('utf-8'),
    )
    if response.status >= 400:
        return {
            'event': {
                'payload': {
                    'type': 'INVALID_AUTHORIZATION_CREDENTIAL'
                    if response.status in (401, 403) else 'INTERNAL_ERROR',
                    'message': response.data.decode("utf-8"),
                }
            }
        }
    _logger.debug('Response: %s', response.data.decode("utf-8"))
    return json.loads(response.data.decode('utf-8'))
```

### Alexa Smart Home Skill

In the [Alexa Developer Console](https://developer.amazon.com/alexa/console/ask):

- **Type**: Smart Home (provision your own)
- **Locale**: Spanish (ES)
- **Default endpoint**: the AWS Lambda ARN (`arn:aws:lambda:eu-west-1:...:function:HomeAssistant-Alexa`)
- **Account Linking**:
  - Authorization URI: `https://ha.jougarcia.uk/auth/authorize`
  - Access Token URI: `https://ha.jougarcia.uk/auth/token`
  - Client ID: `https://layla.amazon.com/` (EU; would be `pitangui.amazon.com/` for US)
  - Client Secret: `required` (placeholder — HA doesn't validate it)
  - Client Authentication Scheme: **Credentials in request body**
  - Scope: empty (or `smart_home`)

## Voice commands

Tested working:

- "Alexa, enciende el salón"
- "Alexa, apaga la cocina"
- "Alexa, pon la cocina al 30 por ciento"
- "Alexa, apaga adaptativo cocina" (pauses Adaptive Lighting for that zone)

Spanish Alexa supports natural-language brightness ("al 30 por ciento", "más brillante", etc.), color temperature ("más cálido", "más frío"), and color (where the bulb supports it).

## Adding new entities

1. Append to `filter.include_entities` in `/config/configuration.yaml` (via SSH + sudo, or pull script + push back)
2. Add a Spanish friendly name under `entity_config`
3. Restart HA
4. In Alexa app → Devices → + → Add Device → Other → Discover

If the new entity doesn't appear after discovery, restart the Alexa app and try again. Sometimes Alexa's cache needs a kick.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Couldn't find a new Other to connect" | Lambda errored or wasn't invoked | Check CloudWatch logs (Lambda → Monitor → View CloudWatch logs) |
| `Runtime.UserCodeSyntaxError` in CloudWatch | Code pasted with bad indentation | Re-paste the Lambda code, ensuring no leading whitespace on line 1 |
| `Login attempt or request with invalid authentication` in HA log | Lambda is forwarding a stale or absent token | Re-run account linking: Alexa app → Skill → Disable → Enable again |
| Voice commands don't work but devices appeared | Locale mismatch or entity_config name issue | Check `locale: es-ES` is set in HA config; check entity name doesn't collide with another |
| `INTERNAL_ERROR` returned to Alexa | HA returned 500 — check HA log for the underlying error | `curl ha.jougarcia.uk/api/alexa/smart_home` test (see below) |

## Diagnostic: send a discovery directly to HA (bypassing Alexa + Lambda)

If you suspect HA-side trouble, fire a discovery directive directly:

```bash
HA_TOKEN=$(cat ~/.claude/projects/-Users-victor-Playground-hass/memory/ha_token.txt)
curl -sS \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"directive\":{\"header\":{\"namespace\":\"Alexa.Discovery\",\"name\":\"Discover\",\"payloadVersion\":\"3\",\"messageId\":\"test\"},\"payload\":{\"scope\":{\"type\":\"BearerToken\",\"token\":\"$HA_TOKEN\"}}}}" \
  https://ha.jougarcia.uk/api/alexa/smart_home | python3 -m json.tool
```

A successful response includes `event.payload.endpoints` with all your exposed devices. If this works but Alexa discovery doesn't, the failure is on the AWS side.

## Why we didn't use Nabu Casa

Nabu Casa (Home Assistant Cloud, €7.50/month) provides Alexa integration as a one-click feature. We chose self-hosting via AWS Lambda for:

- Zero ongoing cost
- Same external-access infrastructure (Cloudflared) we use for everything else
- Full control over what's exposed
- No dependency on a third-party subscription

Trade-off: 2-hour setup vs 5 minutes. One-time pain for ongoing freedom.

## References

- HA docs: https://www.home-assistant.io/integrations/alexa.smart_home/
- Alexa Developer Console: https://developer.amazon.com/alexa/console/ask
- AWS Lambda Console: https://console.aws.amazon.com/lambda/
