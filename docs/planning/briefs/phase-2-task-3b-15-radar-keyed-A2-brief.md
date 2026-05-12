# Phase 2 task 3b-15 — round brief

**Round:** 3b-15 (closes radar keyed half — sub-scope A2)
**Drafted:** 2026-05-11
**Lead:** Opus (this session)
**Teammates:** clearskies-api-dev (Sonnet), clearskies-test-author (Sonnet)
**Auditor:** clearskies-auditor (Opus, source-only review)

## Round identity

3b-15 ships the **keyed half** of the radar domain per [ADR-015](../../decisions/ADR-015-radar-map-tiles-strategy.md) + [ADR-037](../../decisions/ADR-037-inbound-traffic-architecture.md). Scope (sub-scope A2 per user choice 2026-05-11):

- **2 keyed provider modules**: `openweathermap` (Weather Maps 1.0 `precipitation_new` layer) and `aeris` (Xweather Raster Maps `radar` layer).
- **1 NEW endpoint**: `GET /radar/providers/{provider_id}/tiles/{z}/{x}/{y}?t=<iso>` — server-side binary tile proxy per ADR-037 (keys never reach the browser).
- **Frame-index endpoint extension**: `/radar/providers/{provider_id}/frames` adds dispatch rows for `aeris` and `openweathermap` (returns a single `kind=current` frame for v0.1 — time-step animation deferred, see LC-7).
- **Wiring**: `wire_radar_settings()` plumbs Aeris + OWM credentials from `settings.forecast.*` into endpoint-level module vars; provider-scoped credentials per 3b-5 Q2.

**Originally scoped A1 (3 keyed providers) cut to A2 during brief-draft research:** `mapbox_jma` dropped from ADR-015's day-1 set 2026-05-11. Mapbox JMA tilesets are `raster-array` shape — they require Mapbox GL JS for the 5-min time-band animation that justified picking them, and ADR-015 locks Leaflet. Amendment landed in meta repo at `2f49d4a`. Japan radar at v0.1 falls back to RainViewer. See the 2026-05-11 amendment header on ADR-015.

Iframe slot still deferred to 3b-16.

### Structural realities new this round (compared to 3b-14 keyless half)

1. **Binary response shape.** The tile proxy returns raw tile bytes (PNG, content-type from CAPABILITY.tile_content_type), NOT JSON. This is the first FastAPI handler in the codebase that streams binary content. Use `fastapi.Response(content=bytes, media_type=ct)`.
2. **Binary cache via base64 envelope** (LC-A below). The existing `RedisCache.set()` uses `json.dumps(value)` and cannot store raw bytes. Tile cache values wrap the bytes in `{"_tile_b64": "<base64>", "content_type": "image/png"}` — keeps the existing cache abstraction unchanged; ~33% storage overhead per tile is acceptable for v0.1.
3. **Credential pass-through.** Both keyed providers need credentials at both `/frames` (for time-step metadata — moot at v0.1) AND `/tiles/...` (for upstream composition). Credentials sourced from `settings.forecast.*` per provider-scoped 3b-5 Q2; module-level `_RADAR_AERIS_CLIENT_ID`, `_RADAR_AERIS_CLIENT_SECRET`, `_RADAR_OWM_APPID` populated by `wire_radar_settings()` at startup.
4. **Aeris URL credential leakage risk (LC-E).** Aeris embeds `{client_id}_{client_secret}` in the URL **path**. `ProviderHTTPClient.get()` logs the full URL at INFO. The existing `logging.Filter` per ADR-029 redacts header/body credentials but not path-embedded ones. Brief locks a redaction strategy — see LC-E.
5. **Two entrypoints per provider module.** Each keyed radar provider exposes `get_frames() → RadarFrameList` (same shape as 3b-14 keyless) AND `get_tile(z, x, y, *, t=None, **creds) → tuple[bytes, str]`. The tile entrypoint is novel to 3b-15.

Total impl estimate: ~1200-1600 lines api-dev work; ~2000-2500 lines test-author work. Smaller provider count than 3b-14, larger surface per provider.

## Pre-round verification (lead-completed before this brief)

- ✓ api repo origin/main HEAD: `61ea749` (matches resume prompt).
- ✓ meta repo origin/master HEAD: `2f49d4a` (ADR-015 2026-05-11 amendment landed during brief-draft).
- ✓ weather-dev synced to api `61ea749` (FF from `f2362ee` — 3 fixture sidecars from 3b-14 close).
- ✓ Lead-pytest-verify on weather-dev at `61ea749`: **2123 passed, 364 skipped, 39 warnings, 0 failed** in 521s (matches resume prompt baseline exactly).
- ✓ Cross-check rule fired: 2 keyed-radar api-docs sections added today (OWM Weather Maps + Aeris Raster Maps). Both marked "per upstream docs, not live-verified" per user path choice 2026-05-11 — test-author cross-checks at fixture capture and surfaces any divergence.
- ✓ Codebase-state verification: closest precedent for credential plumbing is `endpoints/aqi.py` `wire_aqi_settings()` + per-provider `if/elif` dispatch; closest precedent for binary-content provider work is **none** — tile proxy is novel to this codebase. Provider modules' five-responsibility shape stays as ADR-038 §2.

## Reading list (api-dev + test-author both)

In order, before any code:

1. [CLAUDE.md](../../../CLAUDE.md) — domain routing + always-applicable rules.
2. [rules/clearskies-process.md](../../../rules/clearskies-process.md) — full file.
3. [rules/coding.md](../../../rules/coding.md) — §1 (security; pay attention to credential-in-URL-log leak + Pydantic Depends pattern), §3 (organization, DRY, dead code, exception attributes not message strings).
4. `.claude/agents/clearskies-api-dev.md` / `.claude/agents/clearskies-test-author.md` — agent-specific carry-forwards.
5. [docs/decisions/ADR-015-radar-map-tiles-strategy.md](../../decisions/ADR-015-radar-map-tiles-strategy.md) — full file (note 2026-05-11 amendment header).
6. [docs/decisions/ADR-037-inbound-traffic-architecture.md](../../decisions/ADR-037-inbound-traffic-architecture.md) — §Decision (keys never reach browser; api proxies).
7. [docs/decisions/ADR-017-provider-response-caching.md](../../decisions/ADR-017-provider-response-caching.md) — full file (esp. §Per-provider TTL — radar tile bytes default 300s).
8. [docs/decisions/ADR-018-api-versioning-policy.md](../../decisions/ADR-018-api-versioning-policy.md) — §Error format (RFC 9457 problem+json on 502/503 proxy paths).
9. [docs/decisions/ADR-027-config-and-setup-wizard.md](../../decisions/ADR-027-config-and-setup-wizard.md) — §Decision (provider-scoped env var naming).
10. [docs/decisions/ADR-038-data-provider-module-organization.md](../../decisions/ADR-038-data-provider-module-organization.md) — §Decision (five-responsibility shape, capability registry).
11. [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) §4.5 (radar — confirms no canonical-entity mapping; note 2026-05-11 amendment dropping mapbox_jma).
12. [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) — `/radar/providers/{provider_id}/tiles/{z}/{x}/{y}` (lines 586-637; note 2026-05-11 amendment dropping mapbox_jma from the description). Also re-read `/frames` (lines 639-656).
13. Per-provider api-docs (Radar sections added today, with "per upstream docs, not live-verified" provenance): [openweathermap.md §Weather Maps 1.0](../../reference/api-docs/openweathermap.md), [aeris.md §Raster Maps](../../reference/api-docs/aeris.md).
14. Existing keyless radar precedents — read at least one of each shape: [rainviewer.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/rainviewer.py) (XYZ + JSON frame index), [iem_nexrad.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/iem_nexrad.py) (WMS-T). Existing endpoint: [endpoints/radar.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/radar.py).
15. Closest keyed-credential precedents: [providers/aqi/openweathermap.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/openweathermap.py) (provider-scoped appid pattern), [providers/aqi/aeris.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/aeris.py) (client_id + client_secret pattern), [endpoints/aqi.py](../../../repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/aqi.py) (`wire_aqi_settings` + if/elif dispatch).

**Closest precedent module for the tile-proxy endpoint shape:** none — binary-response endpoints are novel. **Closest precedent for keyed forecast-style provider:** `providers/forecast/aeris.py` + `endpoints/forecast.py wire_aeris_credentials` pattern. **Closest precedent for radar capability declaration:** `providers/radar/rainviewer.py` (XYZ; `tile_url_template` populated) vs. `providers/radar/iem_nexrad.py` (WMS; `wms_endpoint_url` + `wms_layer_name` populated). For the keyed-radar capability, **only `tile_url_template` is meaningful** (both OWM and Aeris are XYZ-style) — keep `wms_*` None.

## Per-endpoint spec — `GET /radar/providers/{provider_id}/tiles/{z}/{x}/{y}?t=<iso>` (NEW)

OpenAPI source: `docs/contracts/openapi-v1.yaml` lines 586-637.

### Behavior decision tree

1. `provider_id` not in `_KEYED_RADAR_PROVIDERS` frozenset (`{"aeris", "openweathermap"}` this round) → `404 Problem`. Distinct from /frames because /frames accepts the 5 keyless providers too; /tiles is keyed-only.
2. `provider_id` IS in `_KEYED_RADAR_PROVIDERS` but is NOT in the capability registry (operator configured a different radar provider) → `404 Problem` with distinguishing detail text.
3. Credentials for the configured keyed provider are missing (env vars unset; `_RADAR_OWM_APPID` is None or `_RADAR_AERIS_CLIENT_ID`/`_RADAR_AERIS_CLIENT_SECRET` are None) → `502 Problem` with detail "Aeris credentials missing" / "OpenWeatherMap appid missing". Same pattern as `endpoints/aqi.py` lines 273-292.
4. `z`/`x`/`y` validation failure (z out of 0-22, x/y < 0) → FastAPI auto-422 from path-parameter Pydantic constraints. No special handling needed.
5. Cache hit → return cached bytes with cached `content_type` (200, no upstream call).
6. Cache miss → call provider module's `get_tile(z, x, y, t=None, **creds)` → cache bytes + content_type wrapped in `{"_tile_b64": ..., "content_type": ...}` JSON envelope (LC-A) → return 200 with `Response(content=bytes, media_type=content_type)`.
7. Upstream 404 from provider (tile out of provider's domain — e.g. NEXRAD outside CONUS) → propagate as `404 Problem` with provider-context detail. **Lead call**: the canonical taxonomy doesn't have a "tile-out-of-domain" class; `ProviderHTTPClient.get()` raises `ProviderProtocolError` for non-429/non-401-403 4xx. For tile 404 specifically, the provider's `get_tile()` catches `ProviderProtocolError` with `status_code == 404` and re-raises a new `RadarTileNotFound` — OR — simpler, the endpoint catches the generic `ProviderProtocolError` and inspects `.status_code`. See LC-3.
8. Upstream network failure / 5xx after retries → `502 Problem` (TransientNetworkError).
9. Upstream 429 → `503 Problem` + `Retry-After` (QuotaExhausted).
10. Upstream 401/403 → `502 Problem` (KeyInvalid — operator's credentials are wrong/revoked).

### Path parameters

- `provider_id`: required, lowercase string. Validated against `_KEYED_RADAR_PROVIDERS` frozenset at request time.
- `z`: integer, FastAPI `Path(..., ge=0, le=22)` per OpenAPI.
- `x`: integer, FastAPI `Path(..., ge=0)`.
- `y`: integer, FastAPI `Path(..., ge=0)`.

### Query parameters

- `t`: optional, ISO-8601 UTC datetime. **Accepted by FastAPI but IGNORED at v0.1 per LC-7.** Both OWM (current-only) and Aeris (always-current at v0.1) serve the source's current frame regardless. Logged at DEBUG so future-round upgrade has visibility into how operators are using it.

### Response (200)

`fastapi.Response(content=bytes, media_type=ct)` where `ct` is the provider's `CAPABILITY.tile_content_type` (`image/png` for both providers this round).

**No JSON body, no Pydantic response model.** This handler is one of two non-JSON endpoints in the codebase (the other is the deferred `/aqi/history` 501 stub). Document this in the docstring; future readers should not look for a `*Response` Pydantic class.

### Cache layer (ADR-017 / LC-A / LC-B)

- **Cache key**: SHA-256 of `json.dumps({"provider_id": <id>, "endpoint": "tile", "z": z, "x": x, "y": y, "t": t_normalized}, sort_keys=True).encode()` where `t_normalized` is `None` (Python null → JSON null) for v0.1 since `t` is always ignored. Credentials NOT in key (privacy/leakage; same as AQI keyed modules).
- **Cache value**: `{"_tile_b64": base64.b64encode(bytes).decode("ascii"), "content_type": "image/png"}` (LC-A — base64 envelope keeps the existing cache abstraction unchanged).
- **TTL**: 300s (5 min) per ADR-017 default for tile bytes (LC-B). Distinct from frame-index TTL of 60s in 3b-14.
- **On hit**: decode `_tile_b64` → bytes; return with cached `content_type`.

## Per-endpoint spec — `/radar/providers/{provider_id}/frames` (EXTENSION)

Existing handler in `endpoints/radar.py`. Extend `_KNOWN_RADAR_PROVIDERS` frozenset to include `"aeris"` and `"openweathermap"`. Provider modules' `get_frames()` implementations:

- **OWM**: returns `RadarFrameList(providerId="openweathermap", frames=[RadarFrame(time=<now-iso>, kind="current")], attribution="OpenWeatherMap (https://openweathermap.org/)")`. Weather Maps 1.0 has no documented frame index → synthesize a single `current` frame at the request time. **Cache TTL: 60s** for frame index (parity with 3b-14 keyless precedent). No upstream call needed for OWM frames (synthetic), but still cache to keep the pattern uniform.
- **Aeris**: same shape — `frames=[RadarFrame(time=<now-iso>, kind="current")]`. Future round can wire Aeris's `/info` or `/maps/img` endpoints for past-frame timestamps. **Cache TTL: 60s.**

Frame-index work is small for both providers (no upstream call); the tile-proxy endpoint is the structural lift.

## Per-provider module specs

### `providers/radar/openweathermap.py` (NEW)

Five responsibilities per ADR-038 §2:

1. **Outbound API call** — Weather Maps 1.0 XYZ tile fetch: `GET https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={appid}`. Layer hardcoded to `precipitation_new` per ADR-015 (model precipitation). Frame index synthesized — no upstream call.
2. **Response parsing** — tile response is binary PNG; no Pydantic wire model needed. Frame response is synthesized in Python.
3. **Translation** — radar has no canonical-entity mapping (canonical §4.5). `get_frames()` builds `RadarFrame(time=<now-iso>, kind="current")`. `get_tile()` returns `(response.content, response.headers.get("Content-Type", "image/png"))`.
4. **Capability declaration**:
   ```python
   CAPABILITY = ProviderCapability(
       provider_id="openweathermap",
       domain="radar",
       supplied_canonical_fields=(),  # §4.5
       geographic_coverage="global",
       auth_required=("appid",),
       default_poll_interval_seconds=_FRAMES_TTL,  # 60
       operator_notes=(
           "OpenWeatherMap Weather Maps 1.0 — precipitation_new layer (NWP model "
           "precipitation, NOT radar reflectivity). UI label: 'Model precipitation' "
           "per ADR-015. Keyed (query-param appid); reuses provider-scoped credential "
           "from forecast/alerts/AQI OWM (WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID env var). "
           "Current-only at v0.1; ?t query param ignored. Tile bytes cached 300s; "
           "frame index synthesized + cached 60s."
       ),
       tile_url_template="https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png",
       wms_endpoint_url=None,
       wms_layer_name=None,
       tile_content_type="image/png",
   )
   ```
   Note `tile_url_template` does NOT include the appid (per LC-D — template is public-shape; credentials inject at api-proxy time).
5. **Error handling** — canonical taxonomy via `ProviderHTTPClient.get()` (KeyInvalid, QuotaExhausted, TransientNetworkError, ProviderProtocolError). No re-construction. The only narrow wrap is `(httpx error → re-raise as canonical)` which lives in `ProviderHTTPClient`, not in the module.

Module-level singletons: `_http_client: ProviderHTTPClient | None`, `_rate_limiter: RateLimiter(max_calls=5, window_seconds=1)` (be-polite guard). `_reset_http_client_for_tests()` per precedent.

Empty-appid guard at top of `get_tile()` AND `get_frames()`: `if not appid: raise KeyInvalid(...)` — explicit fail-fast.

### `providers/radar/aeris.py` (NEW)

Same five-responsibility shape with these specifics:

1. **Outbound API call** — `GET https://maps.api.xweather.com/{client_id}_{client_secret}/radar/{z}/{x}/{y}/current.png`. Layer hardcoded to `radar` (global radar mosaic) per ADR-015. **The `current` offset is hardcoded at v0.1** (time-step animation deferred per LC-7).
2. **Response parsing** — tile bytes.
3. **Translation** — `get_frames()` synthesizes single `current` frame (same as OWM); `get_tile()` returns `(response.content, response.headers.get("Content-Type", "image/png"))`.
4. **Capability declaration**:
   ```python
   CAPABILITY = ProviderCapability(
       provider_id="aeris",
       domain="radar",
       supplied_canonical_fields=(),
       geographic_coverage="global",
       auth_required=("client_id", "client_secret"),
       default_poll_interval_seconds=_FRAMES_TTL,
       operator_notes=(
           "AerisWeather/Xweather Raster Maps — radar layer (global radar mosaic). "
           "Keyed (path-embedded client_id_client_secret); reuses provider-scoped "
           "credentials from forecast/alerts/AQI Aeris (WEEWX_CLEARSKIES_AERIS_CLIENT_ID + "
           "_AERIS_CLIENT_SECRET env vars). Free path via PWSWeather Contributor Plan "
           "(per ADR-015) — confirm at fixture capture; flag if access has tightened. "
           "Current-only at v0.1; ?t query param ignored. Time-step animation deferred. "
           "Tile bytes cached 300s; frame index synthesized + cached 60s. "
           "URL-credential redaction: log_url helper sanitizes path before any logging "
           "(security baseline — Aeris is the only path-credential provider in the codebase)."
       ),
       tile_url_template="https://maps.api.xweather.com/{auth}/radar/{z}/{x}/{y}/current.png",
       wms_endpoint_url=None,
       wms_layer_name=None,
       tile_content_type="image/png",
   )
   ```
   `tile_url_template` uses `{auth}` placeholder for the credential segment so the template stays public-shape.
5. **Error handling** — canonical taxonomy. Empty-credential guard at top of every public entrypoint: `if not client_id or not client_secret: raise KeyInvalid(...)`.

**URL-credential redaction helper** (LC-E): module-private `_redact_url(url: str) -> str` that returns the URL with the `{client_id}_{client_secret}` path segment replaced by `<redacted>`. Used BEFORE any logger call in `get_tile()` / `get_frames()` AND passed to `ProviderHTTPClient.get(url, log_url=<redacted>)` IF the http client is extended. See LC-E for the locked redaction strategy.

## Settings + dispatch wiring

### `config/settings.py` — `RadarSettings.validate()` extension

Current `valid_providers` set lists 5 keyless providers. Extend to 7:

```python
valid_providers = {
    "rainviewer", "iem_nexrad", "noaa_mrms", "msc_geomet", "dwd_radolan",
    "aeris", "openweathermap",
}
```

Drop the "3b-14 only" framing in the docstring; update comment to mention 3b-15 added the 2 keyed providers and that `mapbox_jma` is deferred per ADR-015 2026-05-11 amendment.

### `endpoints/radar.py` — `wire_radar_settings(settings: object)` (NEW)

Pattern mirrors `endpoints/aqi.py wire_aqi_settings`:

```python
_RADAR_AERIS_CLIENT_ID: str | None = None
_RADAR_AERIS_CLIENT_SECRET: str | None = None
_RADAR_OWM_APPID: str | None = None

def wire_radar_settings(settings: object) -> None:
    global _RADAR_AERIS_CLIENT_ID, _RADAR_AERIS_CLIENT_SECRET, _RADAR_OWM_APPID
    radar_section = getattr(settings, "radar", None)
    if radar_section is None:
        return
    provider = getattr(radar_section, "provider", None)
    if provider == "aeris":
        forecast_section = getattr(settings, "forecast", None)
        if forecast_section is None:
            logger.error("[radar] provider=aeris but [forecast] missing; cannot wire")
            return
        _RADAR_AERIS_CLIENT_ID = getattr(forecast_section, "aeris_client_id", None)
        _RADAR_AERIS_CLIENT_SECRET = getattr(forecast_section, "aeris_client_secret", None)
        if not _RADAR_AERIS_CLIENT_ID or not _RADAR_AERIS_CLIENT_SECRET:
            logger.error("[radar] aeris credentials missing; /radar/.../tiles will 502")
    elif provider == "openweathermap":
        forecast_section = getattr(settings, "forecast", None)
        if forecast_section is None:
            logger.error("[radar] provider=openweathermap but [forecast] missing")
            return
        _RADAR_OWM_APPID = getattr(forecast_section, "openweathermap_appid", None)
        if not _RADAR_OWM_APPID:
            logger.error("[radar] openweathermap appid missing; /radar/.../tiles will 502")
    # Keyless providers: nothing to wire.
```

Call `wire_radar_settings(settings)` from `__main__.py` after settings load, alongside the existing `wire_aqi_settings(settings)` call.

### `providers/_common/dispatch.py` — extension

Add two rows to `PROVIDER_MODULES`:

```python
from weewx_clearskies_api.providers.radar import aeris as radar_aeris
from weewx_clearskies_api.providers.radar import openweathermap as radar_openweathermap

PROVIDER_MODULES = {
    # ... existing rows ...
    ("radar", "aeris"): radar_aeris,
    ("radar", "openweathermap"): radar_openweathermap,
}
```

Update the module docstring: drop the `mapbox_jma` reference; mention 3b-15 added 2 keyed radar providers; reference the ADR-015 2026-05-11 amendment.

## Lead-resolved calls

These are decisions the lead has made for this round. **If api-dev or test-author disagrees with any of these, STOP and ping the lead — do NOT silently re-interpret.**

### LC-A — Binary cache via base64 envelope

Cache values for tile bytes wrap into `{"_tile_b64": "<base64>", "content_type": "image/png"}`. This keeps the existing JSON-based `RedisCache` unchanged and avoids a production-module expansion outside brief scope (3b-13 lesson). Profiling in a future round can promote to native bytes if the encode/decode overhead matters. **Why**: existing `RedisCache.set()` is `json.dumps(value)`; tile bytes are not JSON-encodable; base64 is the lowest-friction wrap.

### LC-B — TTL for tile bytes vs frame index

- **Tile bytes**: 300s (ADR-017 default for the "tile bytes (proxied keyed providers)" row). For v0.1 the tile proxy does NOT inspect upstream `Cache-Control` — flat 300s. Future round can honor upstream max-age.
- **Frame index** (`/frames`): 60s (parity with 3b-14 keyless precedent, including the conscious deviation noted as a parking-lot ADR-017 amendment from 3b-14).

### LC-C — Credential plumbing (no new env vars needed)

- **OpenWeatherMap radar** reuses existing `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` env var → `settings.forecast.openweathermap_appid`. No new setting added.
- **Aeris radar** reuses existing `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` / `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET` env vars → `settings.forecast.aeris_*`. No new setting added.

The brief's earlier "settings.aeris.client_id" wording (carried over from prior AQI briefs) is **wrong** — Settings has no aeris attribute; credentials live on `settings.forecast`. See `endpoints/aqi.py` line 144-146 commit-body provenance note for the precedent that established this.

### LC-D — Tile URL template public-shape

`CAPABILITY.tile_url_template` shows the URL **without** credentials (OWM omits `?appid=`; Aeris uses `{auth}` placeholder). Keeps the capability declaration safe to publish via `/capabilities` (even though the OpenAPI `CapabilityDeclaration` schema extension for radar fields is deferred to a dashboard-integration round per 3b-14 parking-lot).

### LC-E — Aeris URL credential leakage in logs (security baseline)

Aeris embeds `{client_id}_{client_secret}` in the URL path; `ProviderHTTPClient.get()` logs the full URL at INFO (line 200 of http.py). The existing `logging.Filter` per ADR-029 does NOT redact path-embedded credentials.

**Locked strategy**: provider module computes a `_redact_url(url)` helper that replaces the credential segment with `<redacted>` and uses it in any local logging. For the underlying `ProviderHTTPClient.get()` call, extend the http client with an optional `log_url: str | None = None` parameter — when provided, the INFO log line uses `log_url` instead of `url`. Default behavior (None) preserves existing logging for all non-Aeris callers. **Scope**: a ~10-line extension to `providers/_common/http.py` (a production module outside the immediate radar package — disclose in commit body per the "production-module changes outside brief scope" rule; this brief authorizes it explicitly, so no separate lead-approval gate fires).

### LC-F — `?t` query parameter accepted but ignored at v0.1

OpenAPI exposes `?t=<iso>` on the tile proxy. Both keyed providers serve current-only at v0.1 (OWM has no time-step support in Weather Maps 1.0; Aeris time-step is deferred). The endpoint accepts `?t` for forward-compatibility but logs at DEBUG and discards. **Future round** can wire Aeris's `{offset}` URL segment.

### LC-G — Single `current` frame from `/frames` for both providers

`get_frames()` returns `RadarFrameList(providerId=<id>, frames=[RadarFrame(time=<now-iso>, kind="current")], attribution=...)`. Synthesized at request time; cached 60s for shape parity with keyless providers (avoids per-request datetime drift inside the cache window).

### LC-H — Tile-404 mapping (provider's tile out-of-domain)

When upstream returns 404 (OWM/Aeris doesn't have a tile at the requested z/x/y — rare for "global" providers but possible at high zoom), `ProviderHTTPClient.get()` raises `ProviderProtocolError(status_code=404)`. The provider's `get_tile()` catches and re-raises a new exception class... wait — that violates the "don't re-construct canonical exceptions" rule from coding.md §3. **Correct strategy**: the endpoint catches `ProviderProtocolError`, inspects `.status_code`, and maps `404 → HTTPException(404)` directly. No new canonical class.

### LC-I — Empty-credential guard at provider entrypoint

Per the OWM AQI precedent (line 491-499), both keyed radar provider modules guard at the top of `get_tile()` and `get_frames()`: if any credential is empty/None, raise `KeyInvalid` immediately BEFORE the network call. Avoids cryptic upstream 401s with no provenance.

### LC-J — Rate limiter per provider

Both modules instantiate a `RateLimiter(max_calls=5, window_seconds=1)` (be-polite guard, same as 3b-14 keyless). Tile cache TTL of 300s means typical traffic is well under this anyway; the limiter is defense-in-depth.

## Process gates (lead enforces; STOP triggers)

- **Pull-then-pytest gate**: api-dev and test-author both `git fetch origin main && git merge --ff-only origin/main` BEFORE their pre-submit pytest. Per agent-def carry-forward; 3b-12 incident confirmed.
- **Lead-pytest-verify**: before audit spawn, lead re-runs pytest on weather-dev independently. Pre-round baseline = **2123 passed / 364 skipped / 0 failed**. Any divergence > pre-existing-baseline gets investigated before audit.
- **Live capture cross-check** (test-author): at fixture capture, compare the live tile response shape (Content-Type header, response size, header set) against the api-docs claims. **STOP and message lead** if anything differs.
- **No silent canonical-exception reconstruction** (api-dev): if you find yourself writing `except <CanonicalException>: raise <CanonicalException>(...)`, STOP. See coding.md §3 "Dispatch on exception state via attributes."
- **No silent brief-vs-impl divergence** (api-dev): if your impl diverges from the brief because the canonical contracts say something different, STOP and ping lead. See agent-def carry-forward from 3b-2 F2 + 3b-4 brief-vs-canonical incidents.
- **Workflow visibility** (3b-14 lesson): if you choose to work directly on weather-dev (not DILBERT-edit + sync), say so in your first SendMessage so the lead polls weather-dev's local state.
- **Mid-flight SendMessage cadence ≤ 4 min** per agent-def. Commit + push + SendMessage as one atomic milestone.
- **Brief-gate honesty** (test-author): if a gate cannot be met (e.g. PWSWeather Contributor account unavailable for live Aeris capture; OWM appid unavailable; weather-dev Redis missing) — SURFACE VIA SENDMESSAGE BEFORE closeout. Do not silently skip.

## Test-author scope

Real-backends rule applies (ADR-038 §Testing pattern). Tests assert against:

- **Provider modules** (`tests/providers/radar/test_openweathermap_unit.py`, `test_aeris_unit.py`):
  - Empty-credential guard raises `KeyInvalid` BEFORE any HTTP call.
  - `get_tile()` cache hit path bypasses HTTP and returns cached bytes.
  - `get_tile()` cache miss → upstream call → cache populated with base64 envelope → returns `(bytes, content_type)`.
  - Cache key includes `(provider_id, "tile", z, x, y, t)`; does NOT include credentials.
  - Upstream 429 → `QuotaExhausted` with `retry_after_seconds`.
  - Upstream 401/403 → `KeyInvalid`.
  - Upstream 404 → `ProviderProtocolError` with `status_code=404` (NOT a custom canonical class — LC-H).
  - Upstream 5xx (after retries exhausted) → `TransientNetworkError`.
  - `get_frames()` returns single `current` frame synthesized at the request time.
  - Aeris-only: `_redact_url()` helper redacts the path credential segment.

- **Tile proxy endpoint** (`tests/test_endpoints_radar_tiles_integration.py`):
  - Unknown provider_id → 404 (e.g. `iem_nexrad` requested at /tiles — keyed-only endpoint).
  - Unconfigured provider_id (e.g. `aeris` requested but operator has `openweathermap` in registry) → 404 with distinguishing detail.
  - Missing credentials → 502.
  - Cache hit → 200 with `Content-Type: image/png` and the cached bytes.
  - Cache miss + upstream success → 200 + cache populated.
  - Upstream errors → 502/503 + RFC 9457 problem+json per ADR-018.

- **Frames extension** (`tests/test_endpoints_radar_frames_integration.py`):
  - Existing tests for 5 keyless providers still pass.
  - New cases for `aeris` + `openweathermap` returning single `current` frame.

- **Settings + wire** (`tests/test_config_settings_radar_validation.py`, `tests/test_wire_radar_settings.py`):
  - `valid_providers` accepts the 2 new keyed entries; rejects unknown.
  - `wire_radar_settings()` populates module vars for each configured keyed provider.
  - Missing credentials logs CRITICAL/ERROR but does NOT prevent startup (degraded — `/tiles` returns 502 at request time).

### Live captures

- **OWM tile**: capture one tile from `https://tile.openweathermap.org/map/precipitation_new/4/4/6.png?appid=<key>` (Pacific Northwest at z=4 is a useful overlay region). Sidecar must record live URL, captured timestamp, response Content-Type, response size, and any divergence from api-docs claims.
- **Aeris tile**: capture one tile from `https://maps.api.xweather.com/{id}_{secret}/radar/4/4/6/current.png`. Sidecar same fields. **Confirm Contributor Plan via PWSWeather still bundles Maps API access** — if access is gated, surface via SendMessage as a STOP per LC-E ramification.

If a paid Aeris account or OWM appid isn't available, hand-craft a synthetic-PNG fixture per the test-author's synthetic-from-real fixture pattern (precedent: 3b-4 Aeris paid-tier discussion). Sidecar marks the fixture origin clearly.

## Closeout report shape (api-dev + test-author both)

Both teammates' final SendMessage to the lead includes:

1. **Files touched** with line counts (impl modules, endpoint extensions, dispatch updates, settings updates).
2. **Commits landed** (hashes + one-line summary each).
3. **Test counts** (pre-submit pytest run on weather-dev). Surface failures classified as introduced-this-round vs pre-existing-baseline (with verification against the baseline commit per agent-def).
4. **ADRs / rules followed** with citations.
5. **Anything surprising** — divergences from brief, live-capture findings that don't match api-docs, anything that triggered a lead ping mid-flight.
6. **Precedent claims cite file:line** per 3b-13 lesson.
7. **api-dev specifically**: did you make any production-module changes outside the brief scope? List them.
8. **test-author specifically**: did you capture live fixtures? What were the divergences from api-docs (zero is fine; the cross-check still ran)?

## Post-round triage

Lead does at round close:

- Lessons triage per CLAUDE.md "Capture lessons in the right place" — decision-log only by default; project-level or agent-level lessons get routed to the right file.
- Plan-status commit on meta repo: mark 3b-15 closed, queue 3b-16 (iframe slot).
- 3b-16 resume prompt at `c:/tmp/3b-16-resume-prompt.md`.

## References

- [ADR-015](../../decisions/ADR-015-radar-map-tiles-strategy.md) (2026-05-11 amendment).
- [ADR-017](../../decisions/ADR-017-provider-response-caching.md).
- [ADR-018](../../decisions/ADR-018-api-versioning-policy.md) (RFC 9457 errors).
- [ADR-027](../../decisions/ADR-027-config-and-setup-wizard.md) (env-var secret pattern).
- [ADR-037](../../decisions/ADR-037-inbound-traffic-architecture.md) (proxy pattern).
- [ADR-038](../../decisions/ADR-038-data-provider-module-organization.md) (provider module shape).
- [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) §4.5.
- [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) lines 586-656.
- [docs/reference/api-docs/openweathermap.md §Weather Maps 1.0](../../reference/api-docs/openweathermap.md) (Radar section added 2026-05-11).
- [docs/reference/api-docs/aeris.md §Raster Maps](../../reference/api-docs/aeris.md) (Radar section added 2026-05-11).
- 3b-14 keyless precedent: [phase-2-task-3b-14-radar-keyless-brief.md](phase-2-task-3b-14-radar-keyless-brief.md).
