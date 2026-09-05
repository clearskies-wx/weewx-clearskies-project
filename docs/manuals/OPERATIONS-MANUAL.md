# Clear Skies — Operations Manual

Single authority for deployment, security, authentication, monitoring, configuration, and installation rules. Absorbs and replaces `contracts/security-baseline.md`.

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** — system topology, ports, containers, routing
- **[API-MANUAL.md](API-MANUAL.md)** — API implementation rules
- **[PROVIDER-MANUAL.md](PROVIDER-MANUAL.md)** — provider module rules

Last updated: 2026-06-28

---

## Table of Contents

1. [Deployment](#1-deployment)
2. [Authentication](#2-authentication)
3. [Network Architecture](#3-network-architecture)
4. [Configuration](#4-configuration)
   - [§4.1 Config Registry](#41-config-registry)
5. [Logging](#5-logging)
6. [Health and Readiness](#6-health-and-readiness)
7. [Observability](#7-observability)
8. [Updates](#8-updates)
9. [Performance Budget](#9-performance-budget)
10. [Security Model](#10-security-model)
11. [Filesystem Permissions](#11-filesystem-permissions)
12. [Anti-Patterns](#12-anti-patterns)

---

## §1 Deployment

### Topology

**Two-host default.** The API runs on the weewx host alongside the weewx engine and Redis. The dashboard, Caddy, and the config UI run on a separate front-end host. Caddy on the front-end host proxies `/api/v1/*` and `/sse` over the network to the weewx host's API on port 8765.

**Single-host alternative.** All services on one machine. Caddy proxies to local Docker network service names (`api:8765`) or `localhost:8765`. The API uses direct mode (Unix socket to the weewx loop relay) with no broker required.

Do not use a topology beyond these two defaults without understanding the cross-host auth and firewall requirements in §2 and §10. See [ARCHITECTURE.md](../ARCHITECTURE.md) for the authoritative topology diagram, port registry, and container inventory — do not duplicate that information here.

### Container images

Each repo builds its own container image independently. A dashboard CSS change does not rebuild the API image. Images are built and pushed in CI on every tagged release. See [ARCHITECTURE.md](../ARCHITECTURE.md) for the container inventory, image sources, and lifecycle (init container vs. long-running).

### Install paths

There are exactly two supported install paths:

**Container path (docker-compose + Caddy).** Pull the stack repo. Run `./scripts/setup.sh` — it asks deployment questions (topology, network stack, domain, weewx paths) and writes `.env`, `secrets.env`, and a minimal `api.conf`. Then `docker compose up -d`. Caddy handles TLS automatically via Let's Encrypt (ACME HTTP-01) or DNS-01 challenge for NAT-behind installs. The dashboard is an init container: a multi-stage Node 22 build copies `dist/` to a shared volume, then exits. Caddy serves that volume as static files.

**Native path (pip + systemd + Caddy).** Run `sudo ./scripts/setup.sh` — it creates the `clearskies` system user, groups, directories, and network configuration, then guides you through the same deployment questions. Install each component with `pip install --pre weewx-clearskies-api` into a Python 3.12+ virtual environment. Copy systemd units from `examples/systemd/` and enable. Configure Caddy as the reverse proxy using the provided example Caddyfile. TLS via the operator's existing certificate pipeline (certbot, internal CA, or existing wildcard cert).

Do not mix install paths for a single component. If the API is native, its config lives in `/etc/weewx-clearskies/api.conf`; if it is a container, the same path is bind-mounted into the container. The configuration format is identical in both cases.

### Distribution channels

| Channel | What ships there | Who should use it |
|---------|-----------------|------------------|
| PyPI | `weewx-clearskies-api`, `weewx-clearskies-config` Python packages | Native-path Linux/macOS operators |
| Container registry (GHCR) | `weewx-clearskies-api`, `weewx-clearskies-dashboard`, `weewx-clearskies-config` images | Docker-path operators |
| GitHub Releases | Tagged source archives, pre-built dashboard bundles, signed checksums | Build-from-source operators |

### Platform support matrix

| Platform | Native install | Docker install | Notes |
|----------|---------------|---------------|-------|
| Debian / Ubuntu (amd64) | Yes — primary supported path | Yes | Recommended for most operators |
| Ubuntu (ARM64 / Raspberry Pi 4+) | Yes — pip + systemd | Yes — use ARM64 image tags | Pi 4 and later recommended; Pi 3 is marginal |
| Raspberry Pi OS (32-bit ARMv7) | Yes — pip only; systemd template differs | Yes — use armv7 image tags | Confirm Python 3.12 available before installing |
| LXD container (Debian/Ubuntu guest) | Yes — same as bare metal | Yes — with nesting enabled | Recommended topology for advanced home-server operators |
| Proxmox VM (Debian/Ubuntu guest) | Yes — same as bare metal | Yes | Standard VM; no special configuration required |
| Docker Desktop (Windows 11) | No — native not supported | Yes — Docker Desktop only | Requires WSL2 backend enabled |
| macOS (Apple Silicon / Intel) | Yes — development use; no launchd template at v0.1 | Yes — Docker Desktop or Colima | Native macOS not tested for production deployments |

Windows native install is not supported. Operators on Windows use Docker Desktop with WSL2.

### Bare-metal install script (native path)

The following script creates the required users, groups, and directories for a native Linux install. Run as root or with sudo before installing the Python packages.

```bash
# Create the service user (no login shell, no home dir, no sudo)
useradd --system --no-create-home --shell /usr/sbin/nologin clearskies

# Create the read-only weewx DB group (separate from the weewx group)
groupadd --system weewx-ro

# Add clearskies to the read-only DB group and the weewx socket group
usermod -aG weewx-ro clearskies
usermod -aG weewx clearskies

# Config directory
mkdir -p /etc/weewx-clearskies
chown clearskies:clearskies /etc/weewx-clearskies
chmod 750 /etc/weewx-clearskies

# Runtime directory for the Unix domain socket (API <-> weewx loop relay
# only -- the marine service's SWAN working tree does NOT live here, see
# below; SURF-REMEDIATION-PLAN-2026-08-08 Phase R4)
mkdir -p /var/run/weewx-clearskies
chown clearskies:weewx /var/run/weewx-clearskies
chmod 770 /var/run/weewx-clearskies

# SWAN working directory (marine service only, real disk -- not tmpfs).
# Historical: before 2026-08-08 this lived under /var/run/weewx-clearskies/
# swan/ (RAM-backed tmpfs); moved to real disk in Phase R4 because cgroup
# memory accounting was charging those tmpfs pages to the service (measured
# 5.1G memory peak against a 6G container cap). Create ONLY this subdirectory
# -- /var/lib/weewx-clearskies may already exist, owned by root, with
# unrelated content; do not chown the parent.
install -d -o clearskies -g clearskies -m 0750 /var/lib/weewx-clearskies/swan

# Web root owned by Caddy (Caddy must already be installed)
mkdir -p /var/www/clearskies
chown caddy:caddy /var/www/clearskies
chmod 755 /var/www/clearskies

# SQLite: make the weewx database file readable by the weewx-ro group
# (MariaDB: use GRANT SELECT instead — see INSTALL.md)
chgrp weewx-ro /var/lib/weewx/weewx.sdb
chmod g+r /var/lib/weewx/weewx.sdb
```

After running this script, install the Python package, run the wizard to generate config, then enable and start the systemd unit. Full step-by-step procedure is in `INSTALL.md` for each component.

### Config UI distribution

The config UI is distributed as `weewx-clearskies-config` on PyPI and as a container image on GHCR (`ghcr.io/clearskies-wx/weewx-clearskies-config`). Docker-path operators get it automatically via the compose file (`config` service in `frontend-host/` and `single-host/`). Native-path operators install with `pip install --pre weewx-clearskies-config` and manage via the provided systemd unit.

### weewx extensions

Two weewx extensions are installed separately into the weewx process. Neither is containerized — they run inside weewx itself.

**ClearSkiesLoopRelay** (`weewx-clearskies-extension`): Required. Creates the Unix socket that the API reads loop packets from.

```bash
weectl extension install weewx-clearskies-extension.tar.gz
```

**ClearSkiesTruesun** (`weewx-clearskies-truesun`): Optional. Replaces weewx's built-in Ryan-Stolzenbach `maxSolarRad` with pvlib's Simplified Solis model using real atmospheric data (CAMS AOD satellite data + station humidity-derived precipitable water). Improves sky classification accuracy at sunrise/sunset edges. If not installed, weewx falls back to R-S with no regression. See ADR-072.

```bash
# Install dependencies into the weewx Python environment
pip install pvlib cdsapi h5netcdf

# Install the extension
weectl extension install weewx-clearskies-truesun.tar.gz

# Configure the CAMS API key in weewx.conf [ClearSkiesTruesun]
# Register at https://ads.atmosphere.copernicus.eu/ for a free key
# The extension reads station lat/lon/altitude from weewx.conf [Station]
sudo systemctl restart weewx
```

The `[ClearSkiesTruesun]` config stanza in `weewx.conf`:

```ini
[ClearSkiesTruesun]
    # CAMS API key (register at https://ads.atmosphere.copernicus.eu/)
    cams_api_key = <your-key>
    # Fallback AOD at 700nm when CAMS is unavailable (0.06 = typical clean coastal)
    fallback_aod700 = 0.06
    # How often to refresh CAMS AOD forecast (hours)
    aod_fetch_interval_hours = 12
```

Verification: after weewx restarts, check that `maxSolarRad` values at sunrise are > 10 W/m² at 6:00 AM (vs R-S's ~1.4 W/m²). Check the weewx log for `clearskies_truesun: CAMS AOD fetch` messages.

### eccodes native dependency (marine service)

eccodes is ECMWF's C library for GRIB/BUFR encoding and decoding. It is required for GRIB2 processing (wave data and HRRR wind) in the **marine service** — not in the API. The API has no eccodes dependency; `pip install weewx-clearskies-api` never installs or requires it.

**How eccodes is provided depends on how the marine service is deployed:**

| Deployment | How eccodes is provided | Operator action |
|---|---|---|
| Docker compose | Must be available in the marine service image | None if the image is built with eccodes baked in |
| Native install on marine service host | Operator installs the system library, then `pip install "weewx-clearskies-marine[nearshore]"` | Install system library + pip extra |

**Platform-specific system library install (native path only, on the marine service host):**

| Platform | Command |
|---|---|
| Debian / Ubuntu | `sudo apt install libeccodes-dev` |
| RHEL / Fedora | `sudo dnf install eccodes-devel` |
| macOS | `brew install eccodes` |
| Alpine | `apk add eccodes-dev` |

After the system library is installed on the marine service host: `pip install "weewx-clearskies-marine[nearshore]"`

**Detection and error handling:**

The wizard's marine step calls `GET /setup/marine/eccodes-check` on the API. That endpoint is a pass-through to the marine service's `GET /discovery/grib-availability` — the marine service probes its own process for a working GRIB2 backend (eccodes primary, pygrib fallback) and reports the result. A marine service outage or an unconfigured `marine_service_url` returns a 503 distinct from "unavailable" so the wizard never instructs the operator to install eccodes on the API host.

Operators who do not configure a marine service never encounter this dependency. `pip install weewx-clearskies-api` does not require or install eccodes.

**Precedent:** This establishes the pattern for native dependencies in companion services: pip extras for opt-in features, clear detection with actionable error messages at feature-enable time, detection performed by the service that owns the dependency.

### pmtiles CLI (API host — basemap)

The Go `pmtiles` CLI (https://github.com/protomaps/go-pmtiles/releases) must be on `PATH` on
whichever host runs the API. It is invoked by the CS-BASEMAP basemap family
(`services/basemap_extract.py`, three tiers — world/local/radar — plan
`MARINE-AND-MAPS-PLAN-2026-08-27.md` §M1, ADR-078 Amendment 2), the sole extraction feature since
ADR-078's original geographic-features overlay (`services/geographic_features.py`, one file,
operator BBOX) was removed (M5, ADR-078 Amendment 2, Accepted 2026-08-27). Basemap does not install
or download the CLI itself; `pip install weewx-clearskies-api` does not require it. A missing
binary surfaces as a `RuntimeError` at extraction time (`POST /setup/basemap/update`) naming the
install URL, not a silent no-op. Extraction also requires outbound HTTPS access to
`https://build.protomaps.com` at extraction time only — no runtime dependency once a tier's
PMTiles file has been written to `/etc/weewx-clearskies/`.

### NOAA VDatum grid data (marine service, US surf/nearshore only)

Converting SWAN bathymetry to a single vertical datum (LMSL) per cell (T8.11b, ADR-098 as amended) requires NOAA's published VDatum PROJ data directory: `proj.db` (carries the `NOAA` authority) plus its separation-grid TIFFs. This is **data, not a Python package** — it is not installed by `pip install "weewx-clearskies-marine[nearshore]"` and does not ship inside any package or container image. It must be obtained and placed on disk separately, once, on whichever host runs the marine service's nearshore (SWAN) provider.

**Only required for US surf/fishing/beach-safety spots using the SWAN nearshore model.** Operators who do not configure a surf spot, or whose spots fall outside NOAA's grid coverage, never need this (see §4 SWAN wizard step / T8.11f — a non-US or out-of-coverage spot configuration is refused at setup with a message naming the gap, not run on mismatched datums).

**Source, size, and known caveats.** Zenodo record 15184045, titled *"Vyperdatum grids (NWLD), Early release, Lacks version tag"* — one file, `proj.zip`, **14,009,147,384 bytes (13.0 GiB)**. Extracted: **14 GB, 663 files**, including `proj.db` (9.5 MB) and roughly 50 LMSL regional/national CRSs. Plan for **~28 GB transient** disk if the archive is kept alongside its extraction, plus the 14 GB steady-state footprint. Because the record is titled "early release" with no version tag, there is nothing to pin a download against; treat a future re-publication with a version tag (e.g. one built against PROJ database layout 1.4) as the trigger to revisit the `pyproj` pin below, not as a routine refresh.

**Download must verify byte count and support resume — a clean `curl` exit is not sufficient evidence of a complete file.** Zenodo throttled and truncated a transfer once at 9.94 GB while `curl` still exited 0. Use `curl -C -` (resume) and compare the final file size against the byte count above before extracting.

```bash
curl -C - -L -o proj.zip "https://zenodo.org/records/15184045/files/proj.zip"
[ "$(stat -c%s proj.zip)" = "14009147384" ] || { echo "size mismatch, re-run to resume"; exit 1; }
```

**The archive extracts one level too deep — this is not optional to check.** `proj.zip` carries a top-level `proj/` directory inside it. A naive extract straight to the target directory lands `proj.db` at `.../vdatum-grids/proj/proj.db`, one level below where `services/vertical_datum.py` looks for it (`.../vdatum-grids/proj.db` — the file must sit **directly inside** the target directory, not in a `proj/` subdirectory beneath it). Every conversion then fails with "contains no proj.db," which reads like a corrupt download rather than a one-directory-too-deep extract. `unzip` is not a dependency to assume present; extract with Python's standard-library `zipfile`, then flatten the `proj/` level:

```bash
python3 -c "import zipfile; zipfile.ZipFile('proj.zip').extractall('/var/lib/weewx-clearskies/vdatum-grids')"
mv /var/lib/weewx-clearskies/vdatum-grids/proj/* /var/lib/weewx-clearskies/vdatum-grids/
rmdir /var/lib/weewx-clearskies/vdatum-grids/proj
```

**Verify the extract before trusting it.** Expected result: **663 files**, with `proj.db` directly inside the target directory (not under a `proj/` subdirectory).

```bash
[ -f /var/lib/weewx-clearskies/vdatum-grids/proj.db ] || { echo "proj.db not at top level -- extract landed one directory too deep"; exit 1; }
find /var/lib/weewx-clearskies/vdatum-grids -type f | wc -l   # expect 663
```

**Where it lives.** Default `/var/lib/weewx-clearskies/vdatum-grids`, overridable via the `CLEARSKIES_VDATUM_GRIDS` environment variable on the marine service process (`services/vertical_datum.py`). In a Docker deployment, this directory is not baked into the marine service image (14 GB is prohibitive for an image layer) — mount it as a volume or bind mount at the same path, or point `CLEARSKIES_VDATUM_GRIDS` at wherever it is mounted.

**The ~14 GB `proj.zip` archive can be deleted once the extract is verified** (file count + `proj.db` present as above) — only the extracted directory is read at runtime. Whether to keep it around for a future re-extract (e.g. after a filesystem issue) versus reclaiming the disk is an operator decision, not a required step either way.

**Great Lakes coverage is verified.** The Great Lakes vertical-datum branch (ADR-098 as amended, C-103/C-106) needs a `NAVD88 → LWD_IGLD85` transform at every level (L1–L3, not L3 only — the Great Lakes bathymetry source is USGS Rohweder 2025 throughout, C-106), using this same `pyproj` + NOAA-grid-directory mechanism. This Zenodo grid set does carry the Great Lakes (`IGLD85` family) separation grids alongside the ~50 LMSL regional/national CRSs — confirmed empirically on librewxr with `pyproj` 3.7.0 against NOAA's own `proj.db`: `NAVD88 → LWD_IGLD85` (`NOAA:1759`) returns −176.10 m at Whiting/Calumet Harbor and −173.50 m at Lake Erie, matching NOAA's published Low Water Datum plane elevations. See ADR-098's amendment for the full measured table.

**`pyproj` version is pinned to `==3.7.0` and the upper bound is load-bearing.** NOAA's `proj.db` is database layout 1.3. `pyproj>=3.7.1` (PROJ 9.5+) requires layout 1.4 and refuses to open it — but the refusal is only a `UserWarning`, after which `pyproj` silently falls back to its own bundled database. The `NOAA` authority is then simply absent and a NAVD 88 → LMSL conversion resolves to a **ballpark no-op**: a 0.0 m offset that looks like a completed conversion. **A separation of exactly 0.0 m everywhere is the diagnostic signature of this failure, not a coincidence of datums** — no real NAVD 88 ↔ LMSL (or NAVD 88 ↔ `LWD_IGLD85`) separation is ever uniformly zero across a grid, so a converted grid reporting 0.0 m at every cell means the fallback fired, not that the two datums happen to coincide. Measured: `pyproj` 3.6.1 and 3.7.0 load the NOAA authority; 3.7.1 and later do not. **Do not bump `pyproj` in the marine `[nearshore]` extra past 3.7.0 without first confirming NOAA has republished `proj.db` at layout 1.4** (watch the Zenodo record above). The code checks for the NOAA authority and for a ballpark/all-zero result at runtime and raises rather than proceeding either way — but that is a safety net, not a substitute for respecting the pin.

**Detection.** There is no wizard pre-check for this dependency today (unlike eccodes above) — a missing or wrong-layout grid directory surfaces as a `DatumConversionError` raised from `services/vertical_datum.py` naming the missing path or the version mismatch, at the point a SWAN bathymetry grid is next resolved.

---

## §2 Authentication

### No end-user authentication

Clear Skies is a public weather site. There are no visitor accounts, no login forms for site visitors, no session tokens issued to browsers. This matches the entire weewx skin ecosystem — weather data is public information.

Operators who need access control for their site add it at the reverse-proxy layer. Examples: Apache basic-auth (5-line config, documented in `clearskies-stack/INSTALL.md`), Authelia, Cloudflare Access. Clear Skies provides no end-user auth code and has no opinion on which proxy-layer solution operators choose.

### Cross-host shared secret

When the API runs on a different host from the reverse proxy, a shared secret in `X-Clearskies-Proxy-Auth` prevents LAN hosts from bypassing Caddy and hitting the API directly.

**How it works:**

1. Proxy injects the header on every request to the API: `X-Clearskies-Proxy-Auth: <secret>`.
2. API middleware reads the header and compares against `WEEWX_CLEARSKIES_PROXY_SECRET` using constant-time compare (`hmac.compare_digest`). Timing side-channels are not possible.
3. Mismatch: HTTP 401, request rejected before any handler runs.
4. Secret not set: header is silently ignored (same-host safe mode).

**Generating the secret.** The configuration wizard generates the secret, writes it to `secrets.env` on the API host, and prints it for manual copy to the proxy host. Power users: `openssl rand -hex 32`.

**Setting the secret in `secrets.env`:**
```
WEEWX_CLEARSKIES_PROXY_SECRET=<64-char hex string>
```

**Proxy-side header injection:**

| Proxy | Directive |
|-------|-----------|
| Caddy | `header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}` in the `reverse_proxy` block |
| Apache | `RequestHeader set X-Clearskies-Proxy-Auth "${WEEWX_CLEARSKIES_PROXY_SECRET}"` |
| nginx | `proxy_set_header X-Clearskies-Proxy-Auth $clearskies_proxy_secret;` |

**Secret rotation.** Generate a new value with `openssl rand -hex 32`. Update `secrets.env` on both the API host and the proxy host. Restart both services. There is no key-expiry mechanism — rotation is manual, triggered by operator policy or a suspected exposure.

### Same-host deployments

When the API binds to `127.0.0.1` or `::1`, no shared secret is needed. The loopback interface is the trust boundary. A local process that can connect to `127.0.0.1:8765` already has shell-level access to the host, at which point the database is also directly readable. The shared secret adds no meaningful protection in this topology.

### Non-loopback without a secret — warning behaviour

When the API is bound to a non-loopback address and `WEEWX_CLEARSKIES_PROXY_SECRET` is not set, the service starts but logs the following warning at startup and every 60 seconds thereafter:

```
WARNING clearskies.middleware: API is bound to a non-loopback address
without WEEWX_CLEARSKIES_PROXY_SECRET set. Any host that can reach
this address can read this service directly, bypassing your reverse
proxy. Set the secret or restrict to loopback. See SECURITY.md.
```

Do not silence this warning. Either set the secret or move the bind address back to loopback.

### Config UI authentication

The config UI (`/wizard`, `/admin`) uses a separate admin username + password, stored as an Argon2id hash in `secrets.env`:
- `WEEWX_CLEARSKIES_ADMIN_USERNAME`
- `WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH`

**First-run bootstrap.** When no admin hash exists, the config UI prints a one-time 32-byte hex trust token to stdout. Visit the URL shown in the startup banner. Set username and password. Token is invalidated on use and cannot be re-used.

**Login rate limiting.** 5 failed login attempts per IP per minute triggers a 60-second throttle. No permanent lockout (avoids self-DoS).

**Session mechanics.** HTTP-only, `SameSite=Strict` cookie scoped to the bound origin. `Secure` flag set when TLS is active. Sessions expire on process exit when the tool is stopped.

**Recovery.** If the admin password is lost: `weewx-clearskies-config --reset-admin-password`. Clears the hash. Next launch enters bootstrap mode.

Future privileged surfaces (API-level admin endpoints, if added) define their own authentication separately. This is a deliberate constraint — mixing auth schemes across surfaces creates conflation bugs.

---

## §3 Network Architecture

### One-door reverse proxy — mandatory

All public traffic must pass through a single reverse proxy. The proxy is the only internet-facing component. It terminates TLS, sets security headers, enforces path routing, and controls what inner services are reachable.

Never expose any inner service directly to the internet. Never add `ports:` directives to Docker services other than Caddy (ports 80 and 443). See [ARCHITECTURE.md](../ARCHITECTURE.md) for the authoritative port registry and Caddy routing table.

**This is not a recommendation — it is a hard architectural constraint.** The security header layer, CSP, HSTS, path filtering, and rate-limiting choke point all live at Caddy. Bypassing Caddy removes all of them simultaneously.

### Inner service binding defaults

All inner services bind to loopback by default. Only Caddy binds to `0.0.0.0`.

| Service | Default bind | Public? |
|---------|-------------|---------|
| API main | `127.0.0.1:8765` | No — Caddy proxies to it |
| API health | `127.0.0.1:8081` | No — loopback probe only |
| Redis | `127.0.0.1:6379` | No — API-local only |
| Config UI | Docker internal network / `localhost:9876` | No — Caddy proxies `/wizard`, `/admin` |
| Caddy | `0.0.0.0:80` and `0.0.0.0:443` | Yes — the single public entry point |

Override the API bind for cross-host deploys: set `[server] bind_host` in `api.conf`. When doing so, set `WEEWX_CLEARSKIES_PROXY_SECRET` on both sides (§2).

### Docker networking note

Docker's port-publishing (`ports:` directives) uses iptables DNAT rules that can bypass `ufw` and user-defined iptables chains on many Linux distributions. Operators who rely on `ufw deny` to protect non-Caddy ports may find those ports are still reachable from the LAN. To mitigate this by default, the stack compose files bind all non-Caddy published ports to loopback: `"127.0.0.1:8765:8765"`, not `"8765:8765"`. Do not change this to `"8765:8765"` unless the API host is on an isolated network segment.

### External provider calls

All outbound calls to external provider APIs (NWS, Open-Meteo, Xweather, OWM, IQAir, USGS, GeoNet, EMSC, RainViewer, etc.) originate from the API, not from the browser. Provider API keys are held in `secrets.env` on the API host. They are never exposed in HTTP responses, never included in JavaScript bundle build-time variables, and never logged (redaction filter enforces this — see §5).

### Security headers — all responses

Caddy sets the following headers on every response via a global `header` block. Do not remove any of them.

| Header | Value |
|--------|-------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |
| `Server` | (removed — `header -Server` in Caddyfile) |

The API itself sets `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` on its own responses, and suppresses the `Server` header. HSTS, CSP, and `X-Frame-Options` are Caddy's responsibility — the API does not duplicate them.

### SSE buffering configuration

Configure the reverse proxy to disable response buffering on the `/sse` path and set an adequate idle timeout (minimum 3600 seconds). SSE requires a persistent connection; a proxy that buffers responses will hold events until the buffer fills, causing visible lag or broken reconnects.

| Proxy | Required configuration |
|-------|----------------------|
| Caddy | `flush_interval -1` in the `/sse` reverse_proxy block (Caddy default handles this) |
| Apache | `flushpackets=on timeout=3600` on the `/sse` ProxyPass directive |
| nginx | `proxy_buffering off; proxy_read_timeout 3600s;` in the `/sse` location block |

### Reference Caddyfile

A complete reference Caddyfile for the single-host compose path. The two-host path differs in the `reverse_proxy` upstream address (use the weewx host address instead of the Docker service name `api`) **and** in TLS verification: replace `tls_insecure_skip_verify` with `tls { ca_pool /etc/weewx-clearskies/api-cert.pem }` — disabling TLS verification is not acceptable when Caddy and the API are on different hosts over a non-loopback network (see §12 anti-pattern).

```caddyfile
weather.example.com {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options    "nosniff"
        X-Frame-Options           "DENY"
        Referrer-Policy           "strict-origin-when-cross-origin"
        Content-Security-Policy   "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'"
        Permissions-Policy        "geolocation=(), microphone=(), camera=()"
        -Server
    }

    handle /api/v1/* {
        reverse_proxy https://api:8765 {
            header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}
            tls_insecure_skip_verify
        }
    }

    handle /sse {
        reverse_proxy https://api:8765 {
            header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}
            tls_insecure_skip_verify
            flush_interval -1
        }
    }

    handle /branding.json {
        root * /etc/weewx-clearskies
        file_server
    }

    handle /webcam.json {
        root * /etc/weewx-clearskies
        file_server
    }

    handle /pages.json {
        header Cache-Control no-cache
        root * /etc/weewx-clearskies
        file_server
    }

    handle /now-layout.json {
        header Cache-Control no-cache
        root * /etc/weewx-clearskies
        file_server
    }

    handle /card-manifest.json {
        root * /srv/dashboard
        file_server
    }

    handle /webcam/* {
        root * /var/www/clearskies
        file_server
    }

    handle /cards/* {
        root * /var/www/clearskies
        file_server
    }

    handle /wizard*    { reverse_proxy config:9876 }
    handle /bootstrap* { reverse_proxy config:9876 }
    handle /login*     { reverse_proxy config:9876 }
    handle /logout*    { reverse_proxy config:9876 }
    handle /admin*     { reverse_proxy config:9876 }
    handle /static/*   { reverse_proxy config:9876 }

    handle {
        root * /srv/dashboard
        try_files {path} /index.html
        file_server
    }

    request_body {
        max_size 2MB
    }
}
```

For IPv6-only or dual-stack deployments, use bracket notation for IPv6 upstream addresses: `https://[2001:db8::1]:8765`. Caddy resolves hostnames to both address families automatically.

Do not configure CORS, HSTS, CSP, or `X-Frame-Options` in the API. These headers belong in Caddy's global `header` block so they apply identically to every response from every route — static files, API proxy, config UI proxy, and error pages — without per-route exceptions.

---

## §4 Configuration

### Format

ConfigObj `.conf` files with INI syntax. This matches `weewx.conf` convention. ConfigObj is already a transitive weewx dependency — no new install requirement. Sections use `[section]` and `[[subsection]]` notation. ConfigObj's comment-preservation on round-trip is required — the managed-region pattern in the wizard depends on it.

Do not use TOML, YAML, or JSON for service configuration. The canonical format is ConfigObj/INI.

### Settings model

Hand-rolled Python settings classes, parsed from ConfigObj. Do not use Pydantic for configuration parsing. One INI section maps to one settings class. Env vars carry secrets only; all non-secret configuration uses INI sections.

**Settings classes by INI section:**

| INI section | Settings class |
|------------|---------------|
| `[api]` | `ApiSettings` |
| `[health]` | `HealthSettings` |
| `[database]` | `DatabaseSettings` |
| `[station]` | `StationSettings` |
| `[alerts]` | `AlertsSettings` |
| `[aqi]` | `AQISettings` |
| `[earthquakes]` | `EarthquakesSettings` |
| `[seeing]` | `SeeingSettings` |
| `[radar]` | `RadarSettings` |
| `[forecast]` | `ForecastSettings` |
| `[forecast_correction]` | `ForecastCorrectionSettings` |
| `[tls]` | `TlsSettings` |
| `[branding]` | `BrandingSettings` |
| `[social]` | `SocialSettings` |
| `[conditions]` | `ConditionsSettings` |
| `[cache_warmer]` | `CacheWarmerSettings` |
| `[charts]` | `ChartsSettings` |
| `[input]` | `InputSettings` |
| `[units]` | `UnitsSettings` |

**Migration note — legacy `[imagery]` section (Q10-6, 2026-08-27):** the imagery provider
machinery (`naip`/`esri`/`esri_topo` modules, `ImagerySettings`, the `/imagery/tiles` proxy, the
admin section, the wizard selector) was removed. An existing `api.conf` with an `[imagery]`
section (e.g. `provider = auto`) loads without error — the config loader no longer reads that
section at all, so it is silently ignored. The section is inert and may be deleted by the
operator; leaving it in place has no effect. An in-place `git pull` deploy may leave the now-empty
`providers/imagery/` directory behind on disk — it is inert (nothing imports it) and may be
deleted.

#### ConditionsSettings keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `haze_detection` | bool | `true` | Enable or disable the haze detection engine. When `false`, sky classification runs without haze confirmation and haze-related calibration is inactive. |
| `gamma` | float | `0.45` | Hygroscopic correction gamma parameter in the f(RH) correction factor. Controls how strongly relative humidity scales apparent extinction. Valid range: 0.1–1.0. Default 0.45 is appropriate for mixed continental aerosol. |
| `haze_aqi_provider` | string | (inherits from `[aqi]`) | AQI provider used for haze PM data. Must be an observed-data provider (Xweather or IQAir). Falls back to the `[aqi]` section provider if not set. Model-based providers (Open-Meteo) are not accepted here — the haze engine will log an error and disable haze confirmation if a non-observed provider is configured. |
| `openaq_sensor_id` | int (optional) | (automatic) | OpenAQ sensor ID override for bootstrap. When set, bypasses automatic reference sensor search. Accepts any valid sensor ID, including non-reference (PurpleAir, private). Set via admin UI or directly in api.conf. |

#### ForecastCorrectionSettings keys

See ADR-079 for the decision record. When `[forecast_correction]` is absent from `api.conf`, all defaults apply — the API does not fail to start.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | bool | `false` | Apply trained model corrections to forecast temperatures. No effect if no model is available. Enable only after a model has been trained via `/setup/forecast-correction/retrain`. |
| `collection_enabled` | bool | `true` | Collect forecast-observation pairs to the correction SQLite DB. Independent of correction — pairs are collected even when correction is disabled, building data for future training. |
| `retrain_schedule` | string | `daily` | Model retraining schedule: `daily`, `weekly`, or `manual`. Daily retrains at approximately 03:00 station time. Weekly retrains on `retrain_day` at 03:00. Manual requires explicit `POST /setup/forecast-correction/retrain`. |
| `retrain_day` | int | `0` | Day of week for weekly retrain (0=Monday, 6=Sunday). Ignored when `retrain_schedule` is not `weekly`. |
| `min_samples` | int | `500` | Minimum forecast-observation pairs before first model training. Validated ≥ 100. Collection rate depends on `archive_interval` (read from weewx.conf). |
| `retention_years` | int | `3` | Rolling data retention window in years. Records older than this are purged at each training run. Validated ≥ 1. |
| `db_path` | string | `/etc/weewx-clearskies/forecast_correction.db` | Path to the correction SQLite database. Must be within the filesystem write allowlist (`/etc/weewx-clearskies/`). |
| `model_path` | string | `/etc/weewx-clearskies/forecast_correction_model.pkl` | Path to the serialized model file. Written atomically (temp file + `os.rename()`). |

### Config directory

Default location: `/etc/weewx-clearskies/`

**Search order (first match wins):**
1. `WEEWX_CLEARSKIES_CONFIG_DIR` environment variable, if set.
2. `/etc/weewx-clearskies/<component>.conf`
3. `~/.config/weewx-clearskies/<component>.conf` (XDG default)

The service refuses to start with no config file and no `--init` flag. A missing config is a startup error, not a silent fallback to defaults.

### File inventory

| File | Purpose | Secrets? | Mode |
|------|---------|---------|------|
| `api.conf` | API component configuration | No | 0640 |
| `charts.conf` | Chart group, chart, and series definitions | No | 0640 |
| `stack.conf` | Stack and config UI state | No | 0640 |
| `marine-photos.json` | Local-only marine location photo metadata (`photo_url`, `photo_attribution` per location slug). Never sent to the API; not Caddy-served — read/written directly by the wizard and admin routers to pre-populate the photo preview and attribution field on re-render. | No | 0640 |
| `secrets.env` | All secrets: DB passwords, API keys, proxy secret, admin credential hash | **Yes** | **0600** |
| `branding.json` | Operator branding: accent colour, logos, theme, social links, analytics identifiers | No | 0644 |
| `webcam.json` | Webcam config: enabled flag, image URL, video URL, refresh interval | No | 0644 |
| `pages.json` | Page visibility: `{ "hidden": [...] }`. Dashboard reads at boot. Written by admin UI. | No | 0644 |
| `now-layout.json` | Now page card layout: `{ "version": 1, "cards": [...] }`. Dashboard reads at boot. Written by admin card layout editor. | No | 0644 |
| `forecast_correction.db` | Forecast correction SQLite DB — forecast-observation pairs + model metadata. Created by the correction engine on first pair collection. (ADR-079) | No | 0640 |
| `forecast_correction_model.pkl` | Trained Random Forest model for forecast temperature correction. Written atomically by the trainer (temp file + `os.rename()`). (ADR-079) | No | 0640 |
| `basemap-world.pmtiles` | Basemap tier — global vector-tile archive, z0–6, fixed extraction box, the coarse fallback ground for panning outside the local/radar tiers on the non-radar maps. Extracted by `POST /setup/basemap/update` (CS-BASEMAP, plan §M1, ADR-078 Amendment 2). Supersedes the removed `geographic-features.pmtiles` (ADR-078's single-file overlay, deleted M5) — the operator may delete the old file at `/etc/weewx-clearskies/geographic-features.pmtiles`. | No | 0600 (mkstemp default; the API process is the only reader — same mode the old `geographic-features.pmtiles` had; Gate M1-API F2, 2026-08-27) |
| `basemap-local.pmtiles` | Basemap tier — z7–15, union(seismic box, marine locations bbox +40px@z15). Serves the marine + seismic maps' dark-theme detail. Extracted by `POST /setup/basemap/update`. | No | 0600 |
| `basemap-radar.pmtiles` | Basemap tier — z0–12, the radar provider's declared coverage box (or the seismic box if none declared). Serves the radar/satellite map's dark-theme base + labels/outlines layer. Extracted by `POST /setup/basemap/update`. | No | 0600 |
| `api-cert.pem` | API TLS certificate (Ed25519 self-signed, auto-generated) | No | 0644 |
| `api-key.pem` | API TLS private key | **Yes** | **0600** |
| `ui-cert.pem` | Config UI TLS certificate (auto-generated when `--tls` active) | No | 0644 |
| `ui-key.pem` | Config UI TLS private key | **Yes** | **0600** |

**`secrets.env` is the most restricted file in the entire installation.** Mode 0600, owner `clearskies:clearskies`. Caddy never reads it. The deploy user reads it only to write it. No other file's permissions may be as permissive as this file is restrictive — no other file carries secrets, but this one carries all of them.

Keep `branding.json`, `webcam.json`, `pages.json`, and `now-layout.json` in `/etc/weewx-clearskies/`, never in the web root. Dashboard deploys use `rsync --delete` which wipes `/var/www/clearskies/` on every run. Caddy serves all four files via dedicated routes pointing at `/etc/weewx-clearskies/`.

### Secret naming convention

All environment variable secrets follow this pattern: `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>`

Examples:
```
WEEWX_CLEARSKIES_FORECAST_AERIS_CLIENT_ID=...
WEEWX_CLEARSKIES_FORECAST_AERIS_CLIENT_SECRET=...
WEEWX_CLEARSKIES_AQI_IQAIR_KEY=...
WEEWX_CLEARSKIES_PROXY_SECRET=...
WEEWX_CLEARSKIES_ADMIN_USERNAME=...
WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH=...
WEEWX_CLEARSKIES_SODA_EMAIL=...
WEEWX_CLEARSKIES_OPENAQ_API_KEY=...
```

`WEEWX_CLEARSKIES_SODA_EMAIL` is the email registered at https://www.soda-pro.com/ — required for McClear clear-sky GHI bootstrap (ADR-072). `WEEWX_CLEARSKIES_OPENAQ_API_KEY` is the OpenAQ API key for auto-bootstrap PM data.

### Secret-leak guard

At startup, the API and config UI walk every parsed `.conf` file. Any leaf key whose name matches the regex `(?i)_(KEY|SECRET|TOKEN|PASSWORD)$` causes a fatal startup error and non-zero process exit. A developer who pastes an API key into `api.conf` gets a clear error and the service does not start — a silent credential leak into logs is prevented.

This is defence-in-depth, not a substitute for putting secrets in `secrets.env` from the start.

### Wizard-API channel (setup endpoints)

The wizard communicates with the API over TLS during setup. TLS is mandatory on this channel — do not allow the wizard to connect to the API without TLS verification.

The API uses an Ed25519 self-signed certificate by default, auto-generated at first start. On first connection, the wizard prints the certificate's SHA-256 fingerprint and requires the operator to confirm it matches what the API printed in its startup banner. This is a trust-on-first-use (TOFU) handshake. After confirmation, the wizard stores the fingerprint and verifies it on subsequent connections.

Setup endpoints use the prefix `/setup/*` (not `/api/v1/*`). These endpoints require either a trust token (first-run wizard) or a valid session cookie (admin re-run). They are never public data endpoints.

### Config UI

The config UI is a standalone FastAPI application on port 9876. It is distributed as `weewx-clearskies-config` on PyPI and as a container image on GHCR. Docker-path operators get it via the `config` service in the compose file. Native-path operators run it as a systemd service (`weewx-clearskies-config.service`).

During normal operation, access it at `https://your-site.example.com/admin` via the reverse proxy, which routes `/wizard*`, `/bootstrap*`, `/login*`, `/admin*`, and `/static/*` to `localhost:9876`. This means the config UI benefits from the site's real TLS certificate and does not require a separate browser certificate exception.

For first-run bootstrap before the reverse proxy is configured, run `weewx-clearskies-config` directly and access it at the URL shown in the startup banner (defaults to `[::]:9876`).

### Admin landing page

The config UI serves an admin landing page at `/admin`. This is the default post-login destination.

**Redirect logic:** If `api.conf` does not exist (setup has not been run), `/admin` redirects to `/wizard`.

**Domain-organized sections:** The landing page organizes all configuration areas by domain, not by config file:

| Section | Config source | What it manages |
|---------|--------------|-----------------|
| Status | API `GET /setup/marine/health` (live, read-only) + `ApiClient.health()` | API reachability; marine service status/reasons/per-input freshness/invariant activity |
| Station Identity | `stack.conf [ui]` | Station name, location, altitude |
| Database | `api.conf [database]` | DB type, connection |
| Providers | API `/setup/current-config` (authoritative); local `api.conf` fallback | Provider selection + API keys. Radar section includes LibreWxR endpoint mode, self-hosted URL, and geographic bounds when LibreWxR is configured. |
| Appearance | `branding.json` | Accent color, logos, site title, favicon, theme mode |
| Analytics & Privacy | `branding.json` | GA ID, privacy region toggles |
| Webcam | `stack.conf [webcam]` | Enabled, image/video URLs, refresh interval |
| Pages | `pages.json` | Per-page visibility checkboxes |
| Now Page Layout | `now-layout.json` | Card layout editor (drag-and-drop) |
| Column Mapping | `api.conf [column_mapping]` | Observation column mapping |
| TLS | `stack.conf [tls]` | Mode, domain, email, provider |
| Sky Classification | `api.conf [conditions]` (`sky_*` keys) | SkyPyEye threshold calibration: decay rate, clear threshold, threshold floor, min elevation |
| Haze Calibration | `api.conf [conditions]` + calibration storage | Per-month calibration status (12-month grid), drift warnings, active sensor display, sensor override (dropdown + manual ID), reset button, gamma override |

**Geographic Features section — REMOVED (M5, ADR-078 Amendment 2, Accepted 2026-08-27).** The
admin section (`/admin/geographic-features`, `POST /admin/geographic-features/update`) and the
`api.conf [geographic_features]` key it managed are deleted; superseded entirely by Basemap below.

The Haze Calibration section shows a 12-month status grid with each month's sample count, learned baseline Kcs value, and calibration status (green = fully calibrated, amber = bootstrapping, gray = no data). An overall summary shows "N of 12 months calibrated." When sensor drift or a station type change is detected, a warning banner is shown. The section also provides a "Reset Calibration" button (clears all samples and baselines, triggers re-bootstrap), a toggle to enable or disable haze detection without removing calibration data, and a gamma override input for the hygroscopic correction exponent.

**Basemap (CS-BASEMAP, plan `MARINE-AND-MAPS-PLAN-2026-08-27.md` §M1-STACK, ADR-078 Amendment 2 —
Accepted) — SHIPPED (stack `065ac62`).** One "Basemap" admin section, now the only PMTiles admin
section — the Geographic Features section above it is removed (M5, ADR-078 Amendment 2, Accepted
2026-08-27, plan journal J3)
(`GET /admin/basemap`, `weewx_clearskies_config/admin/routes.py` `basemap_get()`; landing-page
summary rows via `_fetch_basemap_status()`), showing per-tier status (world/local/radar:
available/size/updated-at/last-error) and one "update basemap" action
(`POST /admin/basemap/update` → the API's `POST /setup/basemap/update` — 202 started flash /
409 already-running flash / other API error via the existing error path); the status page polls
every 10 s while an extraction is in progress (`role="status"`); no operator-typed bounds/zoom
fields (directive 14; PRIME DIRECTIVE 11).

The Status section is read-only — it displays, it does not act. It polls every 30 seconds (HTMX) and shows whether the API is reachable (`ApiClient.health()`, a bare reachable/not-reachable signal — no API version or last-update timestamp is available to this page), and the marine service's own reported health, proxied through the API's `GET /setup/marine/health` (the admin UI never contacts the marine service directly — ARCHITECTURE.md's "add-on reached only through the API" invariant). The marine health block shows `status` (`ok`/`degraded`/`failed`, rendered with colour plus a text label so it is not colour-only), the `reasons` list shown verbatim and in full, per-input freshness (`ww3_boundary`, `wind`, `bathymetry`, `tide` — availability and age), and invariant activity (total fired, last fired time, and the names of anything that fired). An unreachable marine service renders as a status with the API's own error string, not as a stack trace. A marine service that does not yet report `reasons`/`inputs`/`invariants` (a version older than the Marine Model Restoration Plan's B3 task) shows a note that those fields are not reported by this version, rather than a blank section.

Each section shows a summary of current values with an "Edit" link that loads the edit form via HTMX fragment swap.

**"Re-run Setup Wizard" link:** At the bottom of the landing page for operators who prefer the guided sequential flow.

### Page visibility management

The Pages section of the admin landing page provides checkboxes for all 9 built-in pages. The "Now" checkbox is always checked and disabled — Now cannot be hidden. Saving writes `/etc/weewx-clearskies/pages.json`. The dashboard reads this file at boot and filters its navigation and routes.

Page visibility is NOT managed through the API. The API's `GET /pages` returns all 9 built-in pages unconditionally. Filtering is the dashboard's responsibility.

### Card layout editor

The Now Page Layout section of the admin landing page provides a drag-and-drop card layout editor:

- **Card palette:** Available cards not currently in the layout, populated from `card-manifest.json` (a build-time JSON file in the dashboard's `dist/` output). Each card shows its thumbnail, display name, and allowed footprint options.
- **Active grid:** Current layout, populated from `now-layout.json` (or the compiled-in default). Cards can be reordered by drag-and-drop (Sortable.js, vendored, MIT license).
- **Keyboard accessibility:** Move-up / move-down / add / remove buttons alongside drag-and-drop. Drag-and-drop is not the only interaction method.
- **Footprint selector:** Each card in the active grid shows a dropdown of its `allowedLayouts` — only configurations the card supports.
- **Save:** POST writes `/etc/weewx-clearskies/now-layout.json`. Card types are validated against the manifest to prevent unknown types.

### Sky classification calibration

The Sky Classification section allows operators to adjust the SkyPyEye Technology sky condition classifier thresholds. The section displays:

- Current threshold values for SCATTER_CLOUDS Km sub-splits and OVERCAST Km×Kv sub-splits.
- The Kasten-Czeplak reference table mapping Km values to okta equivalents and NWS labels.
- Sensor accuracy guidance (Davis ±3–5%, Ambient ~±15%).
- A "Reset to defaults" button.

Thresholds are saved to `api.conf [sky_classification]` and read by the API at startup. Changes require an API restart to take effect.

### Wizard pattern

The wizard is a multi-step first-run flow. Steps are defined by route handlers in `wizard/routes.py` and step templates at `templates/wizard/step_*.html` in the stack repo. Do not document a hardcoded step count — the count changes as steps are added or merged.

Each wizard step follows this contract:
- The server renders a complete HTML fragment for the step body.
- HTMX swaps the fragment into the page container using `hx-target` and `hx-swap`.
- Form submission goes to the next step's POST handler.
- A progress bar element reflects current position (driven by a data attribute, not a hardcoded width).
- Partial progress is persisted to disk when each step's form is submitted — a partial wizard run produces a valid partial config, not an empty or corrupt file.
- Re-running the wizard pre-populates all fields from the existing config.

**Surf-field re-run semantics:** `POST /setup/apply`'s `[marine]` write is replace-whole-section (deletions must stick, per operator ruling 2026-08-03 decision item 8), with a narrow preserve-list exception for surf fields the wizard/admin has no form field for. See API-MANUAL.md "Surf-field apply semantics (preserve-list)" (§19.5) for the preserve-key lists and fresh-location defaults.

#### AQI provider selection

The wizard presents the following AQI provider options. The wizard suggests observed-data providers when haze detection is enabled.

| Provider | Data type | Coverage | API key required | Haze-eligible |
|----------|-----------|----------|-----------------|---------------|
| Vaisala Xweather | Observed — blended real-time monitoring networks | Global | Yes (PWSWeather Contributor Plan provides free access) | Yes — recommended for haze detection |
| IQAir | Observed — hybrid monitoring + crowd-sourced | Global | Yes | Yes |
| Open-Meteo | Model-based — CAMS atmospheric composition model | Global | No | No |

Providers marked as "Observed" return measured PM2.5/PM10 concentrations from monitoring stations. Providers marked as "Model-based" return atmospheric model predictions. Only observed-data providers are eligible for haze confirmation — the haze detection engine checks the `is_observed_source` capability flag on the configured provider and disables haze confirmation if the provider is model-based.

OpenWeatherMap AQI was removed entirely (Phase 2 API removals) — it returned SILAM model predictions, not observed PM data, and is no longer offered as an AQI provider option. OpenWeatherMap remains available for the forecast, alerts, and radar domains.

The wizard annotates each provider's option label to show observed vs. model-based and haze eligibility. When haze detection is enabled (`[conditions] haze_detection = true`), the wizard warns if the operator selects a model-based AQI provider (only observed-data providers are eligible for haze confirmation).

### Haze calibration bootstrap

The haze detection baseline uses a monthly-normals model: 12 independent per-month Kcs baselines, each requiring >= 30 qualifying clean-sky samples before it activates. Without historical PM data, accumulating 30 samples per month from real-time observations alone takes 2–4 years depending on local weather and air quality. Bootstrapping from historical PM data populates the per-month bins immediately.

**Bootstrap is automatic.** No CLI command, admin button, or SSH step is required. At API startup, the system checks three conditions:

1. OpenAQ API key is present in `secrets.env` (`WEEWX_CLEARSKIES_OPENAQ_API_KEY=<your-key>`).
2. Calibration state has fewer than 12 months calibrated.
3. A pyranometer is present (radiation column in the weewx archive schema).

When all three are true, bootstrap runs automatically after persisted state is loaded but before packet processing begins. This takes 2–5 minutes. The API logs progress to the standard log channel.

**Prerequisites:**
- OpenAQ API key. Register for free at https://explore.openaq.org/register. Set the key in `secrets.env` as `WEEWX_CLEARSKIES_OPENAQ_API_KEY=<your-key>`.
- A PM2.5 reference monitor within 25 km of the station. Check coverage at https://explore.openaq.org/.
- A pyranometer connected to the weewx station (radiation column present in the archive).

**What bootstrap does:**
1. Reads station coordinates (latitude, longitude, altitude) from `weewx.conf`.
2. Queries the OpenAQ API for reference-grade PM2.5 monitors within 25 km (`isMonitor=true`). Filters for sensors with >= 12 months of data history. Tries candidates in distance order until one produces qualifying clean-sky samples.
3. Pulls up to 3 years of hourly PM2.5 data from that monitor.
4. Matches each PM record against the weewx archive (±30-minute window).
5. Computes Kcs (clearness index) for each matched record where radiation data is available.
6. Filters for clean-sky samples: PM2.5 < 12 µg/m³, sun above 10°, no rain.
7. Distributes samples into per-month bins (station local time determines the month).
8. Saves to `/etc/weewx-clearskies/calibration.json` in v2 (month-keyed) format.

**Clear-sky GHI source for bootstrap (ADR-072).**

The bootstrap importer uses CAMS McClear historical clear-sky GHI (via `pvlib.iotools.get_cams()`) for Kcs computation — not the archive's `maxSolarRad` column. McClear provides atmosphere-adjusted GHI at ground level with real atmospheric conditions, eliminating the sunrise/sunset Kcs poisoning that affected the Ryan-Stolzenbach model. A free SoDa account (https://www.soda-pro.com/) is required; set `WEEWX_CLEARSKIES_SODA_EMAIL` to the registered email before running bootstrap. The `maxSolarRad` archive column is no longer used by the bootstrap importer.

**Progressive activation after bootstrap.**

Each month activates its learned baseline independently as soon as it reaches 30 qualifying samples. Bootstrap may fully calibrate all 12 months immediately (if sufficient historical data is available) or bring some months to calibrated state while others remain on the flat fallback. The admin UI 12-month grid shows per-month status. Haze detection becomes active as soon as the current month's baseline (or the flat fallback) is available.

**Sensor selection and override.**

Bootstrap uses a try-until-it-works approach: candidates are tried in distance order, and the first to produce qualifying samples is selected. If all candidates fail, calibration proceeds from real-time observations alone — this is a valid outcome, not an error.

The admin UI shows the selected sensor (name, distance, coordinates) and provides two override mechanisms:
- **Dropdown:** Lists nearby reference-grade sensors. Select one and save.
- **Manual ID entry:** Type any OpenAQ sensor ID, including non-reference sensors. For operators who know their local sensor network.

To clear an override and return to automatic selection, use the "Clear override" button on the admin haze calibration page, or remove `openaq_sensor_id` from `[conditions]` in `api.conf`.

### Radar provider configuration

#### RadarSettings keys (`[radar]` in `api.conf`)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `provider` | string | `rainviewer` | Active radar provider. Valid values: `rainviewer`, `librewxr`, `openweathermap`, `msc_geomet`, `dwd_radolan`, `iem_nexrad` (deprecated), `noaa_mrms` (deprecated), `iframe`. |
| `librewxr_endpoint` | string | `https://api.librewxr.net` | LibreWxR instance URL. Public API or self-hosted operator URL. Only used when `provider = librewxr`. |
| `librewxr_bounds` | string | *(empty = global)* | Geographic bounding box `south,west,north,east` (e.g., `32.0,-120.5,35.5,-114.5`). Dashboard enforces `maxBounds` from this value. Leave empty for global coverage (public API). Set for BBOX-cropped self-hosted instances. |
| `librewxr_refresh_interval` | int | `600` | Seconds between dashboard frame metadata re-fetches. Operator matches this to their LibreWxR instance's `LIBREWXR_FETCH_INTERVAL`. The API includes this value in the capability response so the dashboard knows how often to poll. |

#### LibreWxR deployment modes

**Public API (`api.librewxr.net`):**
- Zero infrastructure. No SLA or usage guarantees.
- Set `librewxr_endpoint = https://api.librewxr.net` (the default).
- Leave `librewxr_bounds` empty (global coverage).
- Good for evaluation or low-traffic personal dashboards.

**Self-hosted:**
- Operator deploys and maintains their own LibreWxR instance.
- Set `librewxr_endpoint` to the self-hosted URL (must be reachable by Caddy on the front-end host).
- Set `librewxr_bounds` to match the instance's coverage area (especially for BBOX-cropped instances).
- Recommend `LIBREWXR_MAX_FRAMES=24` or higher for smoother animation (default is 12).
- Match `librewxr_refresh_interval` to the instance's `LIBREWXR_FETCH_INTERVAL`.
- See LibreWxR documentation at https://librewxr.net/docs/ for self-hosting setup. Clear Skies does not provide LibreWxR infrastructure config.

#### Caddy proxy route for LibreWxR

When the operator configures LibreWxR as the radar provider, the wizard writes a Caddy reverse proxy route:

```
handle /librewxr/* {
    uri strip_prefix /librewxr
    reverse_proxy {librewxr_endpoint}
}
```

This route proxies all LibreWxR traffic (tiles, alerts, satellite) through Caddy. Visitors' browsers contact Caddy only — they never connect directly to the LibreWxR instance.

Self-hosted operators must ensure their LibreWxR instance is network-reachable by Caddy. The instance does not need to be publicly accessible — only Caddy needs to reach it.

#### RainViewer (default, degraded)

RainViewer works out of the box with zero configuration. The browser fetches tiles directly from the RainViewer CDN — no Caddy proxy needed.

Since January 2026, the free tier is degraded:
- Max zoom: 7 (was 8+)
- No nowcast
- Single color scheme (Universal Blue only)
- PNG only (no WebP)

The wizard displays a degradation note when RainViewer is selected so operators understand the limitations.

### Marine alert radius (alerts configuration)

**This is a general alerts improvement — NOT part of the marine feature.** The marine alert radius lives in the alerts section of the wizard/admin, not inside marine location setup. An operator who never enables marine pages still sees marine zone alerts in the dashboard's standard alert banner if their station is near the coast.

**Config keys (in `api.conf [alerts]`):**

| Key | Type | Default | Description |
|---|---|---|---|
| `marine_alert_radius_miles` | float | 0.0 | Radius in miles for marine zone discovery. 0 = disabled = no zone queries = identical to current behavior. |
| `marine_alert_zone_ids` | list[str] | [] | NWS coastal marine zone IDs discovered at setup time. Stored after operator confirms. |

**Wizard behavior:** When the wizard's alerts step detects the station is within 50 miles of a marine zone (via NWS `/points` → CWA → `/zones/coastal` lookup), it auto-suggests a radius of 25 miles. For inland stations (no marine zones within 50 miles), the radius is left at 0.

**Zone discovery algorithm (setup time, not per-request):**

1. Station lat/lon → `GET /points/{lat},{lon}` → extract `cwa` (WFO office ID)
2. `GET /zones/coastal` filtered by CWA → typically 6–16 coastal marine zones per WFO
3. For each zone: `GET /zones/coastal/{zoneId}` → extract polygon geometry
4. Compute minimum haversine distance from station to each polygon's nearest vertex
5. Select zones within the operator's configured radius
6. Present discovered zones with names and distances to the operator for confirmation
7. Store confirmed zone IDs in `api.conf [alerts] marine_alert_zone_ids`

**Help text guidance for operators:** "NOAA Weather Radio transmitters are positioned so marine forecasts and warnings reach approximately 40 miles inland from the coast. If your station is within that range, you're in the audience NWS considers close enough to need marine alerts. The default suggestion of 25 miles captures most coastal communities; increase it if your station is further inland but still serves a coastal audience."

### Marine location configuration

Marine locations are configured in the `[marine]` section of `api.conf`. This section is additive and optional — its absence has zero impact on the rest of the API.

**Surf score weights (Round S, ADR-101 / plan S-SPEC-1, 2026-08-05 — marine service config):** the marine service reads an optional `[surf_scoring]` section with five positive floats — `weight_size`, `weight_shape`, `weight_conditions`, `weight_power`, `weight_consistency` — the exponents of the surf score's weighted geometric mean, one set for the whole system (never per spot), flowing through the existing admin → API → marine `/config` path. Defaults (0.25/0.25/0.20/0.20/0.10) live in code; an absent section means defaults. Weights normalize by their sum at computation time, so any positive values are valid; a zero, negative, or malformed value logs a warning and falls back to that key's default (scoring never crashes on config). The admin UI ("Surf Scoring Weights" section: five fields, live effective-% display, reset-to-defaults, reject ≤ 0; help keys `help.admin.surf_scoring.*`) is Round S leg 4.

**L1 offshore extent override (target — Phase G plumbing / Phase A admin UI of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D1) `(ruled 2026-08-08; lands with Phase G of L1-BOUNDARY-REBUILD-PLAN for the config key, Phase A for the admin field)`.**
New optional key `[swan] l1_offshore_extent_km` (float, marine service config). When present and > 0, the
autosized offshore extent (base + island enclosures + near-lee clamp, ADR-104) is REPLACED by the operator
value, clamped to the `L1_MAX_EXTENT_KM = 100.0` cap; lateral sizing and landward margin are unchanged; wrap
enclosure points are suppressed (the operator owns the extent when set). Absent or 0 = autosize (the default
behavior). Negative/NaN/greater-than-cap values are rejected at config-push with a refusal naming the cap.
Until Phase G lands, no such key exists and L1's offshore extent is always autosized from the shelf-anchored
horizon described above.

**Breaking-onset threshold and impact-zone width (LIVE — shipped 2026-08-11, Phase K of MARINE-PAGE-FIXIT-PLAN, marine `57ee18d`, ADR-106 R3, PA3).**
Two new optional keys, marine service config, module-level (not per-location — one value governs
every configured surf spot):

```ini
[surf]
  qb_breaking_onset = 0.05
  impact_zone_width_m = 25.0
```

`qb_breaking_onset` (float, valid `(0, 0.5)`, default **0.05**) — the Q_b (breaking-fraction)
threshold above which a candidate break region exists; today's fixed `Q_B_VISIBLE` constant,
unchanged value, now operator-tunable so the operator can adjust it against webcam observation
rather than the model re-deriving it. `impact_zone_width_m` (float, valid `(5, 200)`, default
**25.0 m** — CONFIRMED by the operator 2026-08-10 at GO, "25m proposed crash-band width is fine")
— the fixed shoreward distance from each published break marker that defines the impact/crash
band, clipped at the waterline (swash is never included). Both keys flow from `config/marine_config.py`
to the 1-D pipeline the same way existing `[surf]`-scope settings do. **Out-of-range values are a
loud config-push refusal naming the bound** — never a silent clamp. Tuning either key changes the
published break-marker set and/or the impact-zone band widths on the NEXT SWAN cycle; there is no
retroactive recompute of already-published forecast hours. Until Phase K lands, no such keys exist
and both quantities are fixed, non-adjustable constants in `services/surf_1d_analytical.py`.

**Admin marine-sources panel + override field (target — Phase A of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D5/D1) `(ruled 2026-08-08; lands with Phase A of L1-BOUNDARY-REBUILD-PLAN)`.**
A read-only "Marine Sources" admin section renders one row per required input (bathymetry, wind, WW3
boundary, currents, water level, datum path): `{input, source, coverage: ok|refused, reason?}`, sourced from
the config-push chain's own per-input source/coverage report (the chain already decides every source at
setup — this section only surfaces the decision, no new decision logic). A refusal row carries the exact
refusal string the chain already raises — no separate wording is invented for the admin display. Alongside
the sources table, one numeric field writes `l1_offshore_extent_km` (validation mirrors the config-key rule
above: blank = autosize; a value over the cap is rejected with the cap named in the error). Help content keys
`help.admin.marine_sources.*` land in the same round as the admin section (CLAUDE.md doc-sync table); Operator
Manual (`repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`) coverage is that repo's own Phase A doc-sync
task, not this document's. Until Phase A lands, no admin marine-sources panel exists and the override field
is config-file-only (Phase G).

**Config schema:**

```ini
[marine]
  [[locations]]
    [[[wrightsville_beach]]]
      name = Wrightsville Beach
      lat = 34.2085
      lon = -77.7964
      activities = surf, beach_safety, fishing
      ndbc_station_ids = 41110, 41037
      coops_station_ids = 8658163
      nws_marine_zone_id = AMZ250

      [[[[surf]]]]
        segment_start_lat = 34.2090
        segment_start_lon = -77.7970
        segment_end_lat = 34.2070
        segment_end_lon = -77.7950
        transect_spacing_m = 10.0
        bottom_type = sand
        topographic_feature = straight_beach
        directional_exposure = E:true, SE:true, S:true, SW:true

      [[[[fishing]]]]
        target_categories = saltwater_inshore, bottom_fish

      [[[[beach_safety]]]]
        [[[[[external_links]]]]]
          [[[[[[water_quality]]]]]]
            label = NC Beach Water Quality
            url = https://ncdeq.gov/beach-water-quality
```

**Location fields:**

| Field | Type | Required | Valid values | Description |
|---|---|---|---|---|
| `name` | str | Yes | — | Display name for this location |
| `lat` | float | Yes | [-90, 90] | Latitude |
| `lon` | float | Yes | [-180, 180] | Longitude |
| `activities` | list[str] | Yes | `marine`, `surf`, `fishing`, `beach_safety` (1–4) | Enabled activities |
| `ndbc_station_ids` | list[str] | No | — | NDBC buoy station IDs (auto-discovered or operator-selected) |
| `coops_station_ids` | list[str] | No | — | CO-OPS tide/water-level station IDs |
| `nws_marine_zone_id` | str | No | AMZ/GMZ/PZZ/ANZ/PKZ/PHZ prefix | NWS coastal marine zone |
| ~~`nwps_wfo`~~ | — | — | — | Removed (ADR-093). NWPS eliminated. |
| ~~`nwps_cg_grid`~~ | — | — | — | Removed (ADR-093). SWAN uses its own grid bbox. |
| `station_distance_km` | float | — | — | Computed at config time (haversine from weewx station to this location) |

**Surf configuration (`[[surf]]` sub-block):**

| Field | Type | Valid values | Description |
|---|---|---|---|
| `segment_start_lat` | float | [-90, 90] | Shoreline segment start latitude. Replaces the former single-pin `spot_lat`. |
| `segment_start_lon` | float | [-180, 180] | Shoreline segment start longitude. Replaces the former single-pin `spot_lon`. |
| `segment_end_lat` | float | [-90, 90] | Shoreline segment end latitude. |
| `segment_end_lon` | float | [-180, 180] | Shoreline segment end longitude. |
| `transect_spacing_m` | float | > 0 (default: 10.0) | Spacing between cross-shore transects along the segment. |
| `beach_facing_degrees` | float | [0, 360) | **Computed** — the **isobath-normal** (2 m/5 m depth-contour heading, seaward perpendicular) at the segment, resolved at grid-sizing time; the segment-perpendicular is a fallback until the bathymetry grid resolves it (target — Marine Geometry-Model Plan G1; ADR-093 Amendment 5 AD-1). Not operator-entered. |
| `transect_count` | int | — | **Computed** — `segment_length_m / transect_spacing_m + 1`. Read-only. |
| `primary_transect_index` | int | — | **Computed** — midpoint transect index. Used as the default display transect. |
| `bottom_type` | str | `sand`, `rock`, `coral_reef`, `mixed` | Seabed composition |
| `beach_slope` | float | — | Computed from CUDEM bathymetric profile at setup |
| `topographic_feature` | str (optional) | `point_break`, `bay_break`, `headland`, `straight_beach` | Coastal morphology classification. **No longer required** — the L3-enable break-type is **derived** from the measured shoreline/isobath curvature by default; this field is an **optional override** for a sub-grid feature bathymetry cannot see (e.g. a submerged reef). (target — Marine Geometry-Model Plan G5; ADR-093 Amendment 5 AD-5.) |
| `directional_exposure` | dict (optional) | 8 compass directions → bool | Which swell directions reach this spot. **No longer required** — exposure is **derived** from the wrap-aware fetch/openness fan (`services/geography.py`) by default; this field is an **optional override**. (target — Marine Geometry-Model Plan G3; ADR-100 AD-2.) |
| `bathymetric_profile` | list | — | Stored after CUDEM download: `[(distance_m, depth_m), ...]` |
| `structures` | list | — | Optional coastal structures (see below) |
| `l3_enabled` | str | `auto` (default), `on`, `off` | SWAN Level 3 grid control. `auto` enables L3 when structures exist near the spot (structure shadow requires fine-resolution modeling). `on` forces L3 regardless. `off` skips L3 — transects hand off from L2 at ~15m depth. |
| `breaker_formula` | str | `komar_gaughan` (default), `caldwell` | Breaker height formula used to convert post-supplement Hsig to face height (T2.6). `komar_gaughan` — Komar & Gaughan (1973), general-purpose, all periods and coastlines. `caldwell` — Caldwell & Aucan (2007) H1/10 empirical predictor calibrated to steep volcanic island coasts (Oahu north shore); auto-crossover to Komar-Gaughan below Tp=10s. |
| `surf_height_display` | str | `face` (default), `hawaiian` | Display convention for the breaking wave height in the surf card. `face` — trough-to-crest face height (Western scale). `hawaiian` — back-of-wave scale (= face height × 0.5). |

**Study-area geometry is automated (target — Marine Geometry-Model Plan; ADR-093 Amendment 5 + ADR-100).** The
operator draws the surf area (a shoreline segment, or — new — a **polygon** via the wizard draw tool) and the
rest is derived: the per-transect facing from the local isobath heading, the L1 aim and WW3 boundary sides from
the wrap-aware open-water fetch fan, the directional exposure from that same fan, and the L3 break-type from the
measured curvature. `topographic_feature` and `directional_exposure` are demoted from required inputs to
**optional overrides** (above). The wizard help-content strings for these changes land per-phase with the wizard
edits (Marine Geometry-Model Plan G3.3 / G5.3 / G6.3); the sizing formulas, the SWAN→SwellTrack handoff, and all
SWAN command syntax are unchanged (off-limits).

**Directional exposure is presented as an explicit manual override in both the wizard and admin UI (C9b,
MARINE-FORWARD-PLAN).** The stack repo's `step_marine.html` (wizard) and `marine.html` (admin) show a mode
toggle per surf location — **Auto (measured)** (default; the checkbox directions are disabled and excluded from
the submitted form so the config key stays absent) or **Manual override** (the operator picks directions, which
are sent as the `directional_exposure` dict above). The admin location list additionally shows a per-location
**Exposure** column with the mode currently in effect and, for overrides, the chosen directions — computed
display-only from whether the on-disk config carries the key at all (`directional_exposure_is_override`, kept
outside the `surf` payload sub-dict so neither apply-payload builder ever forwards it to the API). Switching a
location back to Auto and saving removes the key, restoring the fan-derived measurement. The wire shape and the
absent-key-means-Auto / present-key-means-override contract above are unchanged by this UI work.

**Structure configuration (within `[[surf]]`):**

| Field | Type | Valid values | Description |
|---|---|---|---|
| `type` | str | `jetty`, `pier`, `breakwater`, `seawall`, `groin` | Structure type |
| `material` | str | `impermeable`, `semi_permeable`, `permeable` | Material permeability |
| `length_m` | float | > 0 | Approximate structure length |
| `bearing_degrees` | float | [0, 360) | Structure orientation |
| `distance_m` | float | > 0 | Distance from the surf spot |

**Structure auto-discovery (T5.2):** The wizard calls `GET /setup/marine/discover-structures` (`lat`, `lon`, `radius_m`, default 2000) to pre-populate the structures list from OpenStreetMap data (via the Overpass API) instead of requiring the operator to enter every jetty/pier/breakwater/seawall/groin by hand. The endpoint returns each candidate structure's OSM id, mapped `type`, computed `length_m`/`bearing_degrees`/`distance_m` (Haversine geometry over the way's node coordinates), and a best-effort `material` guess mapped from the OSM `material` tag (`concrete`→`impermeable`; `rock`/`stone`/`metal`→`semi_permeable`; `wood`→`permeable`) with `material_source: "osm"`. When OSM has no usable `material` tag, `material` is `null` and `material_source: "operator"` — the operator must choose in the wizard UI before the structure can be saved (`_VALID_STRUCTURE_MATERIALS` in `config/marine_config.py` has no "unknown" option). Floating docks (`floating=yes` in OSM) and ways shorter than 5 m are filtered out before the response is returned. Results are cached 24h server-side (structures rarely change); an Overpass outage degrades to an empty list plus an `error` string, never a wizard-blocking failure — the operator can still add structures manually.

**Fishing configuration (`[[fishing]]` sub-block):**

| Field | Type | Valid values | Description |
|---|---|---|---|
| `target_categories` | list[str] | `saltwater_inshore`, `bottom_fish`, `freshwater_sport`, `salmonids` | Target fishing categories (multi-select). Backward compat: a bare string `target_category` is normalized to a single-element list on load. |
| `species` | list[str] | — | Auto-populated from biogeographic region + selected categories. Species data loaded from `data/species.yaml` (see "Species database customization" below). |
| `biogeographic_region` | str | — | Auto-classified from coordinates (11 US regions) |

**Beach safety configuration (`[[beach_safety]]` sub-block):**

| Field | Type | Description |
|---|---|---|
| `external_links` | list | Operator-provided links to local water quality reports, lifeguard schedules, wildlife alert services. Displayed as informational resources on the beach safety page. Each link: `label` (str) + `url` (str). |

**Validation:** Missing `[marine]` section → `load_marine_config()` returns `None` (no error, no marine features). Empty `[marine]` section → empty `MarineConfig`. Invalid values (out-of-range coordinates, unknown bottom type, unknown activity) → clear error naming the offending field and location.

### Species database customization

Species data (lists, scoring profiles, seasonal behavior) is loaded from `data/species.yaml` inside the API package at process start. Operators can edit this file to add local species, adjust temperature ranges, or add seasonal closures. Changes take effect after an API restart (`sudo systemctl restart weewx-clearskies-api`).

The YAML file contains four sections:

| Section | Purpose |
|---|---|
| `regions` | Biogeographic region bounding boxes (11 US regions). Used by `classify_region()` to auto-determine which species list applies to a given coordinate. |
| `species_by_region` | Species lists per region per target category. Controls which species appear as checkboxes in the wizard. |
| `species_profiles` | Per-species scoring parameters: pressure sensitivity, temperature ranges (optimal/good/marginal in °F), tide and time-of-day preferences with multipliers. |
| `seasonal_behavior` | Per-species per-month entries for spawning runs (score multiplier), pre-spawn activity boosts, and regulatory closures. |

**Adding a new species** (worked example — adding "spotted bay bass" to `pacific_sw`):

1. Add the species name to the appropriate category in `species_by_region`:
   ```yaml
   pacific_sw:
     saltwater_inshore:
       - spotted bay bass    # ← add here
       - california halibut
       # ... existing species
   ```

2. Add a scoring profile in `species_profiles`:
   ```yaml
   spotted bay bass:
     pressure_sensitivity: 0.7
     temp_optimal: [65.0, 78.0]
     temp_good: [58.0, 82.0]
     temp_marginal: [50.0, 88.0]
     tide_preference: incoming
     tide_multiplier: 1.15
     time_preference: dawn
     time_multiplier: 1.2
   ```

3. Optionally add seasonal behavior in `seasonal_behavior`:
   ```yaml
   spotted bay bass:
     4: {pre_spawn_multiplier: 1.5}
     5: {spawning_multiplier: 2.0}
   ```

4. Restart the API: `sudo systemctl restart weewx-clearskies-api`

Species listed in `species_by_region` but missing from `species_profiles` receive a neutral default profile (no temperature penalty, no tide/time preference) — the scorer degrades gracefully rather than failing.

### Marine location setup procedure

Step-by-step wizard flow for adding a marine location:

1. **Enter location identity:** Operator provides a name and coordinates (manual entry or map pin).
2. **Select activities:** Choose one or more of: marine/boating, surf, fishing, beach safety.
3. **NDBC station discovery:** Wizard calls `GET /setup/marine/discover-stations` (`lat`, `lon`, `radius_miles`), which queries `activestations.xml`, finds nearest buoys with distances and sensor capabilities (full, wave-only, atmospheric-only), and returns a `quality` tier per station (excellent ≤25mi, good ≤50mi, fair beyond). Operator confirms or overrides.
4. **CO-OPS station discovery:** Same `GET /setup/marine/discover-stations` call also queries the CO-OPS metadata API and returns nearest tide/water-level stations with distances, available products, and a `quality` tier (excellent ≤20mi, good ≤40mi, fair beyond). Operator confirms or overrides.
5. **NWS zone discovery:** System queries NWS `/points` → CWA. Discovers marine zones within the configured alert radius (shared with the marine alert radius feature). Operator confirms.
6. **Surf spot configuration** (if surf activity selected): Operator draws a **shoreline segment** on the Leaflet map (2-point polyline along the shore) to define the surfable measurement zone — replaces the previous pin-drop method. The system generates transects perpendicular to local isobath orientation at 10m spacing (configurable via `transect_spacing_m`). Transects are displayed on the map as thin perpendicular lines fanning out from the segment. Discovered OBSTACLE structures are shown as colored lines. Transects crossing an OBSTACLE render in orange (structure-affected); open transects render in blue. Operator can drag segment endpoints to adjust. The operator also selects bottom type, topographic feature, directional exposure. L3 grid is automatically enabled when structures are present near the spot, disabled for structure-free open beaches (operator can override in admin). CUDEM bathymetric profiles are downloaded on-demand at runtime during SWAN runs (cached at `/etc/weewx-clearskies/spot_profiles/`); no wizard-time download occurs. Wizard calls `GET /setup/marine/discover-structures` (`lat`, `lon`, `radius_m`) to pre-populate nearby coastal structures from OpenStreetMap (see "Structure auto-discovery" above); operator confirms, edits, removes, or adds structures manually — any structure with no OSM `material` tag match requires the operator to pick a material before saving.
7. **Fishing spot configuration** (if fishing activity selected): System auto-classifies biogeographic region from coordinates. Operator selects one or more target categories (multi-select checkboxes). Species checkboxes populate with the union of all selected categories' species for that region (no duplicates). Operator unchecks any species they don't target.
8. **Beach safety configuration** (if beach safety selected): Operator optionally adds external links (water quality, lifeguard reports, wildlife alerts).
9. **Review and save:** System presents a summary of the configured location with all discovered stations, zones, and settings. Operator confirms. Wizard sends the accumulated `marine` block on the next `POST /setup/apply` call. The API validates all locations (coordinates, activity/bottom-type/topographic-feature/target-category enums, NDBC/CO-OPS station-id and NWS marine-zone-id formats), and writes the result to `api.conf [marine]` using the nested-subsection shape shown above (`[[[[surf]]]]`/`[[[[fishing]]]]`/`[[[[beach_safety]]]]` inside each location's own section — not top-level `[[surf_spots]]`/`[[fishing_spots]]` sections). When the marine service reports SWAN is available (`GET /setup/marine/swan-check` returns `available: true`), the wizard also collects SWAN nested grid configuration (outer grid resolution, inner nest resolution, inner nest bounding box, deployment mode) — see §4 SWAN wizard step.

### SWAN configuration

The `[swan]` section in `api.conf` controls nearshore wave-model behavior. It is only relevant when the marine service is configured and reports SWAN as available. These keys are collected by the wizard's SWAN nested grid step (referenced in "Marine location setup procedure" above) and are not normally edited by hand.

#### SWAN configuration keys (`[swan]` in `api.conf`)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `convergence_retry` | bool | `false` | Controls behavior on SWAN numerical divergence — see "SWAN convergence monitoring" below. **Note:** Only `false` mode is currently implemented. Setting to `true` has no additional effect until the degradation ladder is implemented (SWAN-L3-STABILITY-PLAN Phase 4 future). |

#### SWAN convergence monitoring

After every SWAN run, a convergence health check runs. If it fails, the run's hotstart is NOT saved and the API continues serving the last-good forecast, preventing a single bad run from infecting all subsequent runs.

**Config key:** `convergence_retry` in `[swan]` section of `api.conf`

**Mode: `convergence_retry = false` (default, recommended during testing)**

When a SWAN run fails the convergence health check:
- ERROR log emitted with level, check type, and numeric metrics (greppable pattern: `SWAN convergence FAILED`)
- No retry attempted
- Failed working directory (`/var/lib/weewx-clearskies/swan/level{N}/`; historical: `/var/run/weewx-clearskies/swan/level{N}/`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4) preserved untouched for debugging — contains INPUT, PRINT, TABLE, and hotstart files from the failed run
- Hotstart NOT saved — prevents NaN propagation to next cycle
- Forecast cache NOT updated — API serves the previous good run with its true timestamp (staleness visible on the card)
- The failed workdir is overwritten only by the next scheduled SWAN cycle

**Mode: `convergence_retry = true` (production, enable after verified stable)**

When a SWAN run fails:
- Evidence quarantined to `/var/lib/weewx-clearskies/swan/failed/{cycle}_{level}/` (historical: `/var/run/weewx-clearskies/swan/failed/{cycle}_{level}/`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4; retains last 5 quarantines, older pruned)
- Degradation ladder fires, one rung per retry:
  - Rung 1: Rerun with DIFFRACTION smoothing doubled (smnum ×2)
  - Rung 2: Rerun with DIFFRACTION removed for this cycle only
  - Rung 3: Abandon cycle — no hotstart save, no cache update, API serves last-good
- Each rung logged at ERROR with the specific rung and metrics
- A successful degraded run (rung > 0) IS cached and served — degraded data beats stale data — but a WARNING log notes the degradation

**Health checks performed (all three must pass):**

1. **PRINT scan:** Any `******` in accuracy lines (overflow/divergence marker) → FAIL
2. **NaN scan:** Any NaN values in the run's hotstart or TABLE output → FAIL
3. **Valid-point fraction:** Percentage of timesteps where ≥50% of wet transect points have non-exception values must be ≥80% → otherwise FAIL

**Metrics exposed:**
- `swan_convergence_failures_total{level, check}` — Prometheus counter, incremented per failure
- `swan_last_run_valid_fraction{level}` — Prometheus gauge, most recent valid-point fraction

**Purging a contaminated hotstart:**

If a diverged run's hotstart was saved (before this gate was implemented), manually delete it:

```bash
rm -f /var/lib/weewx-clearskies/swan/level3_0_hotstart.dat
```

(Historical: before 2026-08-08 this file lived under `/var/run/weewx-clearskies/swan/`, a RAM-backed tmpfs — corrected 2026-08-08 Phase R4.)

The next full run will cold-start (first 3-6 hours show reduced accuracy, then the hotstart chain recovers).

**Hotstart isolation:**

Stationary quick updates (hourly) never save hotstart files. Only full nonstationary runs (every 6 hours) write `level{N}_hotstart.dat`. This prevents a diverged quick-update snapshot from contaminating the nonstationary warm-start chain.

#### Forecast cache lifecycle (M-0/D-1b, 2026-08-06)

`forecast_cache.json` (`/var/lib/weewx-clearskies/swan/forecast_cache.json`; historical: `/var/run/weewx-clearskies/swan/forecast_cache.json`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4) persists each spot's forecast payload — `forecast`, `spectral`, `spectral_dwr`, `transect`, `swelltrack`, and related keys — across marine-service restarts, so `fetch()` can serve immediately without waiting for the next full SWAN run. A full run replaces the file wholesale; the hourly quick update merges only the spots it touched, leaving others untouched.

**M-0 remediation (OOM kill-loop, production outage 2026-08-05/06):** the per-transect handoff carrier form introduced late July grew the cached `spectral` key to 5,508 per-transect 2-D spectra per spot per full run — 95.5% of a measured 223 MB file, none of it read by any live consumer (M0-D1B fact-pin: every reader of a cached `spectral` entry touches only `components`, `handoff_depth_m`, `handoff_source_level`, and `clamped` — never the `freqs_hz`/`dirs_deg`/`energy` 2-D arrays). `providers/nearshore/swan.py`'s `_trim_spectral_for_cache()` now drops those three fields from every `spectral` entry — at the entry's own top level and inside every `handoff_by_transect` value — before it reaches the cache or the disk file. This bounds both the 7-day in-memory last-good cache and the persisted file; nothing downstream changes, since nothing downstream read the dropped fields.

**Size-guard WARNING.** Both `_persist_forecast_cache_to_disk()` and `_update_forecast_cache_on_disk()` log a WARNING (`SWAN: forecast cache size ... exceeds ... MB warn threshold`) if the serialized payload exceeds `_FORECAST_CACHE_WARN_MB` (64 MB, a monitoring threshold, not admin config). This is a fire-only regression tripwire, not a hard cap — the persist still completes. A firing WARNING after this change means an unbounded field has likely rejoined the payload (the same class of defect this task fixed); investigate what new key was added to the per-spot payload and whether it needs the same trim-at-write treatment.

**D-1a preserved-aside artifact.** The immediate-relief step ahead of this fix moved the 223 MB pre-trim file aside on librewxr rather than deleting it: `/home/ubuntu/forecast_cache.json.oom-m0-aside-20260806`. This is a historical artifact of the OOM incident — do not delete it without operator say-so.

#### Surf-spot data-completeness conditions worth alerting on

These are model-completeness signals, not crashes: the service keeps running and keeps serving, but a spot in one of these states publishes less than a full surf card. All are greppable in the marine service log.

| Level | Condition | Operator-visible effect | What to do |
|---|---|---|---|
| **ERROR** | A spot's ~15 m contour cannot be located — the cached profile never reaches 15 m **and** carries no `contour_15m_distance_m` (or that distance falls shoreward of the point being projected from). Message names the spot. | No deep-water reference is emitted for that spot: **the swell card is empty** (`multiSwell: null`) for every timestep, and the 1D pipeline runs with no canonical partition list. The surf height, score, and beach profile are unaffected. | Re-push marine config so the grid-sizing chain regenerates the spot's profile against MEDIUM (L2) bathymetry. If the contour still cannot be found, the spot's bathymetry does not reach 15 m within the L2 domain — this is a spot/bathymetry problem, not a service fault. There is deliberately no fallback position. |
| **WARNING** | No deep-water-reference spectral entries cached for a spot (whole forecast), or none for one timestep. Message names the spot, and the timestep where applicable. | Same as above for the affected timesteps. | Usually downstream of the ERROR above, or of a cache written before the deep-water reference channel existed. A single successful SWAN cycle repopulates it. |
| **WARNING** | QB (breaking-fraction) coverage gap on a transect — logged once per transect per run with the reason and the count of stations and hours affected. | The handoff selection steps seaward over stations whose QB is unknown. A persistently dry outermost station is normal and benign; an unexpected per-hour gap is not. | Benign when it names one consistently dry station. Investigate if it names many stations or varies hour to hour. |
| **WARNING** | A transect's bathymetric profile cannot be truncated at the handoff depth (handoff shallower than every sample, fewer than two samples left, or a non-physical depth). | That transect is skipped for that hour, exactly as one with no bathymetry is. The spot still reports from its remaining transects. | Check the spot's cached profile extent against its configured `max_hs_m`. Repeated occurrences across most transects mean the profile does not overlap the handoff range. |

None of these conditions is retried or substituted. A visible gap is the intended outcome — the alternative is a confident number computed without all of the model's inputs.

#### Bathymetry vertical datum requirement

SWAN requires bathymetry (BOTTOM input) and water level (WLEVEL input) to use the same vertical datum. Mixing datums produces silently wrong depth calculations — SWAN does not detect or report datum mismatches.

**Automated sources (NCEI regional DEMs, USGS Great Lakes DEMs):** The system handles datum matching automatically. The DEM's native datum is read from the index, and CO-OPS tide predictions are fetched in that datum for SWAN input. No operator action is required.

**CRM/DEM_all fallback:** The NCEI CRM mosaic has mixed or unknown vertical datums — its source DEMs were not normalized to a common datum. Areas served by the CRM fallback have reduced accuracy for wave modeling due to both coarse resolution (~90 m) and datum uncertainty. The coverage endpoint flags CRM-sourced levels as `"degraded"` and includes a `datum_warning` when the datum cannot be confirmed.

**Operator-uploaded bathymetry:** When uploading your own bathymetry file, you must specify its vertical datum. The system fetches CO-OPS tide predictions in the datum you specify to ensure consistency with your bathymetry.

Accepted datums for operator uploads: **NAVD88, MLLW, MHW, MHHW, MSL**. These are the datums directly supported by CO-OPS as prediction request parameters. If your bathymetry file is in a different datum, convert it before uploading using VDatum (vdatum.noaa.gov) or QGIS. The system does not perform local datum conversion for uploaded files.

### SwellTrack configuration (SurfBeat removed 2026-08-23)

#### Per-spot configuration keys (in marine location `[[[[surf]]]]` sub-block)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `friction_coefficient` | float | `0.038` | Bottom friction coefficient (cfjon) for SwellTrack. Swell default 0.038, windsea 0.067. Always enabled — frictionless is not production-valid. Advanced setting, hidden from wizard by default. |
| *(removed 2026-08-23)* | — | — | `surfbeat_enabled` and `surfbeat_cadence_hours` no longer exist: SurfBeat was removed from the system (operator ruling "surfbeat is gone", SURFBEAT-REMOVAL round). An old config carrying them is ignored. |

#### Compute offloading — removed (T6.8, 2026-07-25)

The standalone compute-offload service described in earlier revisions of this manual (`surf_compute_host`/`surf_compute_verify_tls` in `api.conf [providers]`, `SURF_COMPUTE_SECRET` in `secrets.env`, a service on port 8770 running `python -m weewx_clearskies_api.services.compute_service`) **no longer exists.** `ApplyRequest` and `CurrentConfigResponse` stopped accepting `surf_compute_host`/`surf_compute_secret`/`surf_compute_verify_tls` in Phase 6 (T6.8); the API has no code path left that reads or writes them, and `services/compute_service.py`/`services/compute_client.py` were deleted from the API repo in the same phase.

All marine computation — including what this service used to offload — now runs
in the standalone `weewx-clearskies-marine` service, configured via
`marine_service_url` in `api.conf [providers]` and `MARINE_SERVICE_SECRET` in
`secrets.env`. See "Marine service deployment" below for the current
connection, secret, and deployment topology.

Accepted formats for upload: GeoTIFF, NetCDF, ASCII XYZ.

### Marine service deployment (current as-built)

This section documents the deployed standalone marine service
(`weewx-clearskies-marine`). ADR-099 was accepted on 2026-07-26.

**Current state:** All marine computation — WW3, SWAN, SwellTrack, and
marine-provider fetches — runs in `weewx-clearskies-marine` on port 8780. The
API communicates with it over authenticated HTTPS. The old compute-offload
service and its port are not part of the deployed architecture.

#### Deployment topologies

Two topologies are supported. Choose same-host unless CPU and memory constraints require otherwise.

**Same-host (recommended):** Marine service runs on the weewx host alongside the API.

```
weewx host
├── weewx-clearskies-api  (port 8765)
└── weewx-clearskies-marine  (port 8780, localhost-only TLS)
```

**Separate-host:** Marine service runs on a dedicated host (for example, a host with more CPU for SWAN computation).

```
weewx host
└── weewx-clearskies-api  (port 8765)

compute host
└── weewx-clearskies-marine  (port 8780, public TLS or VLAN TLS)
```

#### Port assignment

| Service | Port | Notes |
|---------|------|-------|
| `weewx-clearskies-api` | 8765 | Unchanged |
| `weewx-clearskies-marine` | 8780 | Current marine service port |

Port 8780 is registered in ARCHITECTURE.md.

#### Installation

Deploy the marine service with the project workflow:

```bash
scripts/deploy-marine.sh
```

Run it from the local repository after the intended source is available to the
deployment workflow. The script provisions the package and service, applies
the guarded restart policy, and verifies the result. Its package and service
commands are deployment internals, not manual operator procedure.

SWAN 41.51AB must be compiled and on PATH (`/usr/local/bin/swan`) on
whichever host runs the marine service. Use `scripts/install_swan.sh` or the
Docker image. The marine service verifies its own SWAN binary.

#### First install — WW3 warm start

The WW3 leg (ADR-109 D10) starts every cycle from the restart file the *previous* cycle
saved, and refuses any restart file it did not itself write — it will not trust a restart
file with no recorded generating cycle in its own state. On a brand-new install there is no
previous cycle, so a hand-installed restart file (from a warm-up march, run the same way the
buoy-validated one was) is otherwise refused forever with `ww3_restart_missing`: "restart
file found but no recorded generating cycle -- untrusted, refusing."

The first real install of this chain (2026-08-19) hit exactly this and was unblocked by a
one-time, by-hand state edit rather than this procedure (EVO-Q9 ruling, operator: "THAT IS
NOT ARCHITECTURAL, THAT IS JUST PROCEDURAL") — quoted here for the record: *"Seed record:
`state_snapshot.json` `ww3_leg.lastSuccessCycleTime` = `2026-08-19T00:00:00Z` (the minted
restart's real generating march; backup `.bak-preseed-20260819T085347Z`), service
stop/edit/start, state verified reloaded."* That was ruled procedural because its content was
true (the warm-up run really happened) — but it is a by-hand edit of the service's saved
state, and it was ruled "parked as a pre-ship row" pending a durable mechanism. **Every
install from here forward uses the procedure below instead** — no service stop/edit/start,
no hand-editing `state_snapshot.json`.

**Procedure.** After copying the warm-up run's ending restart file into
`level0/restart_<token>.ww3` (`<token>` is the `%Y%m%d.%H%M%S` UTC timestamp of the cycle the
chain's *first* production cycle will start from — the same stamp WW3 itself uses for every
restart file it writes), drop a provenance note beside it, same directory, same `<token>`:

```bash
cat > /path/to/level0/restart_<token>.provenance.json <<'EOF'
{
  "generating_cycle": "<ISO-8601 UTC, e.g. 2026-09-01T00:00:00Z, matching <token>>",
  "source": "bootstrap",
  "created_at": "<ISO-8601 UTC, when this note was written>",
  "note": "First-install warm start: <describe the warm-up run this restart file came from>"
}
EOF
```

`generating_cycle` must parse as ISO-8601 UTC and equal the cycle the `<token>` in the
restart file's own name encodes — anything else is a mismatch, refused with today's
`ww3_restart_missing` reason (the note's contents are quoted in the service's ERROR log so
the mismatch is diagnosable). The service accepts a matching note exactly ONCE: it logs a
WARNING naming the note, runs that first cycle using the note's `generating_cycle` as the
restart's provenance (so the D11 staleness-age gate — `WW3_RESTART_MAX_AGE_H = 9` — still
applies to it), and deletes the note file the moment that cycle succeeds. Every cycle after
that chains normally from its own restart output. A second fresh install (or a rebuild of
`level0/`) needs a new note — the mechanism is consumed, not reusable. No note present is
byte-identical to the refusal behaviour above.

#### Configuration

**In `api.conf [providers]` on the weewx host:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `marine_service_url` | str or null | `null` | Base URL of the marine service. Same-host: `https://localhost:8780`. Separate-host (IPv4): `https://192.0.2.10:8780`. Separate-host (IPv6): `https://[2001:db8::1]:8780`. When null, no marine service is connected. |
| `marine_verify_tls` | bool | `true` | Verify TLS certificate on marine service requests. Set `false` for a self-signed cert on the same VLAN (see "Marine service TLS" below). |

**In `secrets.env` on the weewx host:**

```
MARINE_SERVICE_SECRET=<generated token>
```

**In `secrets.env` on the marine service host (same value):**

```
MARINE_SERVICE_SECRET=<same generated token>
```

Generate the shared secret once:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

The secret must be identical on both hosts. The API sends it as `Authorization: Bearer {token}` on all protected marine service endpoints. The `/health` and `/manifest` endpoints do not require auth.

**Setting these from the wizard/admin UI (T7.2, 2026-07-25).** All three values above (on the weewx host's side) can be set via `POST /setup/apply`'s top-level `marine_service_url`/`marine_verify_tls`/`marine_service_secret` fields, instead of hand-editing `api.conf`/`secrets.env` — the API writes them to the locations above. The marine service host's own `secrets.env` copy is still a manual step (no automated distribution across hosts). `POST /setup/providers/test-marine` verifies connectivity and, when a secret is supplied, that the secret is accepted, before the operator saves — see API-MANUAL §19 setup-endpoint inventory.

**The admin UI will not let you save a blank marine service URL while marine locations exist, and will not let you add a marine location while the URL is unset (C-64, 2026-07-26).** Either combination produces marine locations that nothing serves, and until this guard the save reported success while doing it. To take a marine service out of service, delete its locations first, or edit `api.conf [providers]` by hand — clearing the URL box on its own leaves the saved value untouched (API-MANUAL §19.2).

**Marine service environment and paths (Phase 4).** All marine-service settings
live on the marine service host, separate from the API's own:

| Knob | Kind | Default | Notes |
|---|---|---|---|
| `MARINE_SERVICE_SECRET` | env var, from `secrets.env` via the systemd unit's `EnvironmentFile=` | none — **required** | Bearer token for every endpoint except `/health` and `/manifest`. The process refuses to start if unset; a request arriving while unset returns **500** (a deployment fault), deliberately distinct from the **401** a bad client token gets. |
| `CLEARSKIES_MARINE_CACHE_URL` | env var | unset → in-process memory cache | Redis URL for provider response caching. **Deliberately distinct from the API's `CLEARSKIES_CACHE_URL`** — same-host deployment is a supported topology, and sharing one Redis database would collide the two services' key namespaces. |
| `CLEARSKIES_MARINE_BIND_HOST` | env var | `0.0.0.0` | Bind address. Mirrors the API's `CLEARSKIES_BIND_HOST`. Accepts an IPv4 or IPv6 literal, a hostname, or `*` for true dual-stack. |
| `CLEARSKIES_MARINE_API_URL` | env var | unset → no recovery fetch attempted | Base URL of the Clear Skies API (e.g. `https://weewx.example.com:8765`), used only for T6.4b startup config recovery (below). Unset is a normal, silent state — not an error — for operators who don't need it. |
| `CLEARSKIES_MARINE_API_VERIFY_TLS` | env var | unset → TLS certificate verification ON (secure default) | **Added 2026-08-02 (C7a).** Whether the marine service verifies the Clear Skies API's TLS certificate on its own outbound calls to `CLEARSKIES_MARINE_API_URL` (startup config recovery and `services/api_client.py`'s two calls — one shared helper, both honor it identically). Secure by default: verification stays on unless the value is exactly `false`, `0`, or `no` (case-insensitive, whitespace-stripped) — any other value, including unset/empty/garbage, leaves it on. Set `false` when the API host serves a self-signed certificate with no SAN entry covering the hostname/IP the marine service connects on (a CN-only cert fails hostname verification regardless of hostname) — TLS encryption stays active either way, only certificate verification is skipped. Mirrors the API's own `marine_verify_tls` (`api.conf [providers]`, same secure-default shape and same three-value disable set) for the reverse direction — that variable governs the API verifying the marine service's self-signed cert; this one governs the marine service verifying the API's. |
| `/etc/weewx-clearskies/marine/secrets.env` | file | — | Holds `MARINE_SERVICE_SECRET` (and optionally `CLEARSKIES_MARINE_CACHE_URL`) on the marine service host. |
| `/etc/weewx-clearskies/marine/marine.conf` | file | — | Config persisted by `POST /config`, written atomically (temp + rename), mode `0640`. Reloaded at startup. |
| `/etc/weewx-clearskies/marine/marine-cert.pem` / `marine-key.pem` | files | auto-generated on first start | Ed25519 self-signed TLS cert and key; key mode `0600`. |
| CLI: `--host`, `--port`, `--cert-dir`, `--hostname`, `--config` | CLI args | port `8780`, cert dir `/etc/weewx-clearskies/marine` | `--hostname` sets the TLS cert's SAN entry, needed for separate-host deployments. |

> **Two `secrets.env` files, one value.** `MARINE_SERVICE_SECRET` must appear in
> **both** the API's `secrets.env` (so the API can authenticate *to* the marine
> service) and the marine service's own (so it can verify). They are separate
> files by design — a dedicated compute host has no API `secrets.env` to read.
> Nothing enforces that they match, and a mismatch surfaces as a blanket 401
> with no indication of which side is wrong. This cannot be solved by pushing
> the secret through `POST /config`: that push itself requires the secret.

> **Request body limit.** The marine service caps request bodies at 1 MiB
> (413 `application/problem+json` above that), matching the API. `POST /config`
> persists into the same directory as the TLS private key, so an unbounded body
> is a disk-fill vector that also breaks the atomic-write guarantee.

**Marine service TLS:** A self-signed Ed25519 certificate and key are auto-generated at `/etc/weewx-clearskies/marine/` on first start, as `marine-cert.pem` and `marine-key.pem` (key mode `0600`). Path corrected 2026-07-24 — this section previously said `/etc/weewx-clearskies/marine/tls/`, which never matched the code (Phase 4 audit finding F1). For same-host deployments the API accepts this certificate without verification (localhost trust). For separate-host deployments with a self-signed cert, set `marine_verify_tls = false` in `api.conf [providers]` (TLS encryption remains active; only certificate verification is skipped for the internal VLAN connection).

#### Config push model

The marine service never reads `api.conf` directly. All configuration is pushed from the API:

1. Operator saves marine location settings in the wizard or admin UI.
2. Wizard/admin sends `POST /setup/apply` to the API.
3. The API writes the validated config to `api.conf [marine]` and then POSTs the marine-relevant config subset to `POST {marine_service_url}/config` with `Authorization: Bearer {MARINE_SERVICE_SECRET}`.
4. The marine service validates, persists, and applies the config.
5. `/setup/apply` returns success to the wizard/admin whether or not the push reached the marine service (T6.4) — a marine service outage never blocks the rest of setup. A failed push is logged at **ERROR** on the API side; nothing is retried automatically before the next apply.

On marine service restart, the service reloads its config **from its own local
disk** — `POST /config` persists atomically (temp file + rename) to
`/etc/weewx-clearskies/marine/marine.conf`, and startup reads that file. This is
the implemented and tested behaviour (verified against a `kill -9` mid-life, not
just a graceful shutdown). Local disk always wins: if `marine.conf` exists,
startup uses it and nothing is fetched.

**Config recovery on an empty config directory (T6.4b).** A marine service
with no local config — a fresh install, or one whose config directory was
wiped — recovers automatically at startup, *if* `CLEARSKIES_MARINE_API_URL`
is set: it calls `GET {CLEARSKIES_MARINE_API_URL}/setup/marine/config`
(authenticated with `MARINE_SERVICE_SECRET`), which returns exactly what the
push above sends (API-MANUAL.md §19.5 — one serializer, both paths), and
persists the result the same way a `POST /config` would. If
`CLEARSKIES_MARINE_API_URL` is unset, no fetch is attempted — that is a
normal, silently-accepted state (an operator relying solely on
`POST /config` doesn't need it set), logged at INFO, not ERROR. If the fetch
is attempted and fails (unreachable API, non-200, bad auth, malformed body),
it is logged at **ERROR** and the service starts anyway, serving `/health`
and `/manifest` only — it does not crash-loop and does not retry until the
next process restart.

#### Health check

The API polls the marine service health check every 60 seconds:

```
GET {marine_service_url}/health
```

No auth required. Response fields: `status`, `version`, `last_run`, `spots`, `run_in_progress`, `reasons`, `inputs`, `invariants`, `fullRun`. Three consecutive failures → API removes marine capabilities from `/api/v1/capabilities` and continues serving last-good cached marine data. Non-marine API functionality is unaffected. (The API's failure-detection loop keys off HTTP-level failures / `last_run`, not off `status` — see B3, MARINE-MODEL-RESTORATION-PLAN.md, 2026-07-27.)

**`status`** (B3, 2026-07-27 — previously hardcoded to `"ok"` on every call regardless of what the model was doing): one of `ok` / `degraded` / `failed`.

- `failed` — the last cycle did not complete (`last_run` is `null`), or a required input (`ww3_boundary`, `wind`, `bathymetry`, `tide` — all four are required; a missing one aborts the SWAN run rather than substituting a default, per rules/coding.md §1) was GENUINELY recorded unavailable, so nothing was published. (Z3.9b, V8: an input never recorded THIS process at all — e.g. immediately after a restart, before the on-disk snapshot restores — no longer counts as an unavailability failure; see the `inputs` note below.)
- `degraded` — the last cycle completed and every required input was available, but an input was stale past its own monitoring threshold, a B2 runtime invariant fired at or after `last_run`, OR (Z3.9b, V6/V7) the full-run cycle is overdue AND has failed 3+ consecutive attempts (`fullRun` note below). A current no-publish reason also floors status at `degraded` while the last-good cycle remains the health baseline.
- `ok` — last cycle completed, every input fresh, no invariant fired, full-run cycle not overdue.

**`reasons`** — list of short machine-readable strings explaining a non-`ok` status. Empty when `ok`.

### R8a `modelHealth` ledger (schema version 1)

Marine `/health` now carries additive `modelHealth`; existing top-level health keys remain unchanged. The R8a skeleton is model truth, independent of legacy liveness and transport state:

```text
modelHealth = {
  schemaVersion,
  overall: {state, reasonCodes},
  serving: {state, reasonCodes, attemptId, selectedFullCycleId,
            firstValidTime, lastValidTime, modelTime, ageSeconds, lastGoodFallback},
  attempts: {active, latestByKind: {full, fast, horizon, recovery}},
  stages: {providerInputs, ww3Leg, ww3Horizon, boundaryMerge, swan,
           swellTrack, cache, publication, recovery}
}
```

`providerInputs.children` are `noaaBoundary`, `wind`, `stofsWaterLevel`, and `wcofsCurrents`; `swan.children` are `l2`, `l3`, and `l4`. Every stage and child uses the same evidence shape: `state`, `reasonCodes`, `observedAt`, `attemptId`, `coverage` (`requiredStart`, `requiredEnd`, `actualStart`, `actualEnd`, `complete`), `provenance`, and `output` (`artifact`, `bytes`, `hash`, `published`). R8b persists compact terminal attempt summaries and records producer-owned evidence at WW3-leg, horizon, merge, current, SWAN, SwellTrack, cache, and publication boundaries; any unobserved required stage remains `unknown` rather than being inferred healthy.

`currentForcing` is the compact current-input record: availability, selected WCOFS issue cycles, required/actual coverage, first/last field, native/hourly field counts, held-tail hours, refusal, and update time. It never contains current grids or arrays. `inputs.currents` becomes available only after every active SWAN grid has passed current-file preflight; a fetch, resampling, writer, or preflight failure keeps it unavailable and refuses publication.

**R4 source behavior (2026-09-03).** The current resolver chooses one OFS
regular-grid model (WCOFS for this recovery path) only when it contains the
complete active SWAN box. It
composes same-model issue cycles by valid time (newer issue wins duplicates),
resamples U/V onto each active grid, and holds only the terminal field beyond
the WCOFS reach. Interior gaps, undersized grids, non-finite fields, and
containment failure remain refusals; no alternate current provider is selected.
The full and 12-hour fast paths share this preflight and refusal behavior
(`providers/ocean/ofs.py`, `services/swan_formats.py`,
`services/swan_runner.py`, `providers/nearshore/swan.py`).

**R4d SWAN hotstart quarantine.** Before the first repaired publish, tokened L2, L3, and L4 hotstarts are copied into one unique quarantine directory, each copy is SHA-256 verified and synchronized to disk, and a completion manifest is atomically written before the original files become ineligible. A partial quarantine authorizes neither deletion nor publication; rollback restores only matching original names. This procedure does not alter WW3 restarts, forecast cache, bathymetry, or grid-sizing data.

State vocabulary is `failed`, `blocked`, `unknown`, `degraded`, `stale`, `running`, `ok`, plus `skipped` only for a topology-not-required stage. The reducer uses that order as worst-required-state precedence: a required failed stage wins; then blocked, unknown, degraded, stale, running, and ok. `skipped` is ignored only where the configured topology makes the stage unnecessary and supplies the exact `topology_not_required` reason. Required matrices are fixed: full requires every stage except recovery; fast requires provider inputs, boundary merge, SWAN, SwellTrack, cache, and publication; horizon requires provider inputs and the raw horizon; recovery requires all stages. Full, fast, and recovery require all provider children; horizon requires only NOAA boundary and wind. For `ok`, evidence needs an empty `reasonCodes` list, nonempty observation and attempt IDs, complete coverage (with all four bounds except recovery), nonempty provenance, and valid output evidence; model stages also require an artifact and publication requires `published: true`. Missing required evidence, incomplete coverage, missing/corrupt required artifacts, or invalid evidence cannot reduce to `ok`.

`overall` describes the current surf-production/recovery generation and its required dependencies; a later raw-horizon success cannot mask a failed merge or publication. `serving` separately says what callers can receive: `valid`, `stale`, or `unavailable`, including the selected full-cycle ID, model and valid-time range, age, and whether a last-good fallback serves. It is derived from the published forecast-cache artifact plus its cache/publication stage evidence; a missing, malformed, or unrelated selected artifact is `unavailable`, never a fabricated fresh result. A retained cache beyond its existing seven-day last-good policy is `stale` with its original model time and age, not restamped. Fast fills retain the selected full-cycle identity while recording their own changed-hour and per-hour provenance in the cache/publication stages. A blocked attempt may therefore coexist with valid last-good serving.

**Current R8b state:** observations and latest terminal attempt summaries are persisted in the existing atomic state snapshot and restored without inventing missing evidence. Every active and terminal attempt carries only compact runtime identities: the installed marine package version, the executable SWAN SHA-256 when readable, the hash of the existing WW3 pin set, and hashes of the model configuration and current grid derivation. A missing identity may never end an attempt as `ok`; it is a named fail-closed stage result. A nested horizon march records its own terminal summary but never replaces the enclosing full attempt in `attempts.active`. The legacy top-level health response and API pass-through remain additive and unchanged. Stages not yet observed remain `unknown` with `reasonCodes: ["not_instrumented"]`; `overall` remains conservative until every required stage has valid evidence. If report computation fails, `/health` emits the same complete schema and topology with `overall.reasonCodes: ["computation_failed"]`, never a partial block. R8c operator UI and CheckMK integration remain later work.

For a failed fast attempt, only the stage owner that reached and recorded the
failure contributes stage evidence (for example, `wcofsCurrents`, `swan`, or
the wind stage); a generic runner exception may contribute only the terminal
fast-attempt summary. The health builder selects observations for the current
attempt ID, so unobserved required stages remain `unknown` with
`not_instrumented` rather than inheriting a previous attempt's success
(`state.py`, `service.py`, `providers/nearshore/swan.py`).

**Source-backed operating boundary (2026-09-03).** The current implementation
does not add a public health field or endpoint for the recovery wave. The
marine service emits `modelHealth` and `currentForcing` through its existing
`/health` response; the API passes that JSON through opaquely at
`GET /setup/marine/health`, and the Stack Status panel renders it read-only.
The Stack source provides operator guidance through state, reason, coverage,
and source columns; it does not start, retry, or restart a model. CheckMK is
not integrated (`endpoints/health.py`, API companion-health route, and Stack
`admin/status` route/template).

**H-1 reasons (SURF-PHYSICS-REMODEL-PLAN-2026-08-05, 2026-08-06) — floor status at `degraded`:**

- `bulk_fallback: {spot_id}@{time_iso} {count}/{n_transects} transects` (≤3 flagged hours, one reason each) or `bulk_fallback: {N} hour(s) flagged, worst {spot_id}@{time_iso} {count}/{n_transects} transects` (>3 flagged hours, one summary reason) — a SWAN-cycle hour where the 1-D surf pipeline bulk-fell-back (synthesized a single bulk partition instead of a transect's own measured spectral data) for a number of transects at or above the H-1 threshold (`max(8, 25% of n_transects)`). What to check: journal-grep `H-1 handoff-collapse` around the same `time_iso` for the per-transect silent-exit causes (`no_hs_proxy`, `breaking_zone_exhausted`, `no_station_selected`, `no_curve_match`) that produced the collapse. This is a diagnostic flag on the underlying handoff-collapse mechanism (task H-1 item 4, a separate later fix) — it does not itself indicate a data-input problem.
- `no-publish: ww3_boundary_refused D-3 refusal — {detail}` — the WW3 boundary-station selection explicitly refused this cycle (D-3: fewer than 2 qualifying stations, or one side with zero) rather than substituting a degraded boundary. Distinct from `no-publish: ww3_boundary_failed` (a network/parse failure reaching WW3 at all). What to check: PROVIDER-MANUAL.md §14.3b's live station-count findings for this spot's L1 extent — a persistent refusal usually means the configured spot(s) don't admit a spatially varying boundary at the current L1 size (see "Refusal, never degradation" there).
- `no-publish: l2_boundary_exhausted SWAN L2 PRINT reported 'data on boundary file exhausted'` (R3, 2026-08-29) — the BOUNDNEST3 transfer did not cover the requested L2 run. Exhaustion takes precedence over a simultaneous L2 convergence failure. The full path re-raises for the normal same-cycle retry; the hourly fast path returns no update. In both cases, last-good output remains in place and no L2 hotstart promotion, downstream parse, L3/L4, cache, or marker write occurs. R3 does not change a prior hotstart; the pre-existing crash-cleanup path still removes a hotstart set that crashes SWAN and retries cold without restoring poisoned state. One current no-publish reason is recorded; health suppresses the old flag-only frozen-ocean reason when this reason exists. A persisted successful fast update resets `l2BoundaryExhausted` and clears only this matching no-publish reason. Legacy/restored flag-only health reports `attemptCycle=unknown`, plus separate `pendingFullCycle` and `lastGoodCycle`, rather than inventing a fast-cycle identity. This condition does not prove the horizon merge is fixed.
- `full run overdue: {N} consecutive failures, last: {reason}` (Z3.9b, V6/V7, MARINE-PAGE-FIXIT-PLAN-2026-08-10 audit) — the full SWAN cycle has failed/refused `N` consecutive attempts (`N >= 3`) AND no full-run success has landed within the last 8h (two extended-HRRR-cycle intervals plus margin). What to check: `fullRun.lastFailureReason`/`fullRun.pendingCycle` for which cycle is stuck, and the journal around `fullRun.lastFailureAt` for the underlying cause (input outage, SWAN crash, convergence gate). Below the 3-failure threshold, or once a success lands, this reason clears — see `fullRun` below.

**Post-deploy sweep addition (R3, 2026-08-29).** In addition to the standard post-deploy journal sweep (checking for new ERROR/WARNING classes since restart), check: (1) `fullRun.l2BoundaryExhausted` on `/health` is **FALSE** for every observed cycle; (2) if it is TRUE, health contains exactly one `no-publish: l2_boundary_exhausted` reason and no new forecast was published; (3) a persisted successful fast update resets the flag and clears only that matching reason; (4) journal-grep `l2_boundary_exhausted` for the detector warning and refusal. A true flag is a fail-closed refusal, not evidence that the horizon merge is fixed. See PROVIDER-MANUAL.md §14.18 and the `ww3Horizon`/`fullRun.l2BoundaryExhausted` key descriptions below.

**`inputs`** — per-input freshness, one entry per required input: `{"available": bool, "age_s": int | null}`. An input never recorded (no fetch attempt observed yet this process) reports `{"available": false, "age_s": null}` — this is the honest "no evidence this was ever fetched" state, and (Z3.9b, V8) does NOT by itself contribute a `failed` reason; only an input GENUINELY recorded as unavailable (a real fetch attempt that failed) does.

**`invariants`** — `{"fired_total": int, "last_fired_at": str | null, "last_fired_names": [str]}` from `services/invariants.py` (B2), scoped to `since=last_run`.

**`handoffRestart`** (S12 HANDOFF-RESTART, M8, 2026-08-27; plan `MARINE-AND-MAPS-PLAN-2026-08-27.md` §S12) — count-only, never affects `status`/`reasons`. `{"runs": int, "restartedRuns": int, "exhausted": int, "attemptsHistogram": {"<attempts>": int}, "lastExhaustedAt": iso | null}`, in-memory since service start (NOT persisted to disk or restored on restart, unlike `inputs`/`fullRun` above — a restart-time gap in this counter is expected). `runs` increments once per transect-hour's handoff-restart-loop resolution; `restartedRuns` counts resolutions that needed more than the formula's first-pick station; `exhausted` counts transect-hours where every band station failed the acceptance test (`handoff_restart_exhausted` — that transect-hour is refused, nothing served from the last attempt); `attemptsHistogram` keys are `str(min(attempts, 151))`. What the loop is: SWAN hands the wave to the 1-D beach model (SwellTrack) at a station picked by `1.3 × Hs / 0.73`; the 1-D model now checks its own result (break at the profile's own first node, or the outermost break marker closer than `HANDOFF_BREAK_CLEARANCE_M` = 10 m / one L4 cell to the handoff) and, on failure, walks the handoff one SWAN band station (10 m spacing) seaward and re-runs every surfable partition, in the same cycle, until it passes or the band's deep end is reached. See PROVIDER-MANUAL.md §14.15 for the full station-selection mechanics and API-MANUAL.md's `handoffDepthM` field for what a settled restart publishes.

**`fullRun`** (Z3.9b, V6/V7/V8, MARINE-PAGE-FIXIT-PLAN-2026-08-10 audit) — the full SWAN cycle's retry/success surface: `{"lastSuccessCycle": str | null, "lastSuccessAt": iso | null, "pendingCycle": str | null, "consecutiveFailures": int, "lastFailureReason": str | null, "lastFailureAt": iso | null, "overdue": bool, "l2BoundaryExhausted": bool}`. `pendingCycle` names the cycle currently retrying-on-failure (distinct from `lastSuccessCycle`, the most recently completed one). `overdue` is `true` when no success has landed within 8h. `l2BoundaryExhausted` is true when the last recorded full or fast L2 attempt refused for boundary exhaustion; a persisted successful fast update writes false. R3 treats true as no-publish, not a successful forecast. A run that fails 3+ consecutive attempts backs off from retrying every `check_interval_s` tick to a 30-minute retry cadence (server-side only — this field is how an operator observes that it's happening); see the `degraded` reason above for when this surfaces in `status`.

`lastSuccessCycle`/`lastSuccessAt`/`consecutiveFailures`/`lastFailureReason`/`lastFailureAt` (Z3.9b, V8) persist to disk (`SWAN_WORK_ROOT/state_snapshot.json`, atomic write) and are restored at service startup — along with the `inputs` freshness registry, same file, same restore step. A restart no longer wipes this history: restored input entries keep their ORIGINAL fetch timestamps (age stays honest, never refreshed by a restore), and a restart with a healthy prior history no longer shows the false `failed` a bare in-memory wipe used to produce (see the `status`/`inputs` notes above). `last_run`/`spots`/`run_in_progress` are NOT part of this snapshot — `last_run`'s own restart survival is the pre-existing forecast-cache mechanism (the per-spot cache's `run_time`, T5.9), unrelated to this file.

Immediately after a service restart with NO prior on-disk history (a fresh install, or a `state_snapshot.json`/forecast-cache-free restart), `/health` still reports `failed` until the first cycle completes — this remains correct, not a regression; the operator is being told the truth rather than a stale `ok`. What changed (Z3.9b, V8): a restart that DOES have prior history (the common case — a routine deploy/restart of an already-running service) now restores that history instead of reporting a spurious `failed` with "required input unavailable" for all four inputs alongside the genuine "no cycle has ever completed" reason.

> **Legacy `l1NestAge` compatibility key and current hourly age gate.** `/health`
> retains `l1NestAge` as `null` since SWAN L1 was removed. The hourly fast cycle
> instead resolves the persisted WW3 L2 boundary and applies the existing
> `L1_NEST_MAX_AGE_H = 9` value (a legacy constant name). A missing or stale WW3
> boundary produces a warning and skips the fill; no SWAN-L1 nest is rebuilt.

Operators can check marine service health directly:

```bash
# Same-host
curl https://localhost:8780/health

# Separate-host
curl https://librewxr.shaneburkhardt.com:8780/health

```

#### Supported environments

| Environment | Marine service install path | Notes |
|-------------|---------------------------|-------|
| Debian/Ubuntu native | `pip install` + systemd unit | SWAN compiled from source |
| LXD container | `pip install` + systemd unit inside container | Container needs network access to API on port 8765 |
| Docker | `docker compose up weewx-clearskies-marine` | Image includes pre-compiled SWAN |
| Proxmox VM | Same as Debian/Ubuntu native | VM needs network access to API |
| Raspberry Pi | `pip install` + systemd unit | Pi 4/5 recommended; SWAN compile takes ~30 min |

#### Alerts

Marine alerts (coastal flood, high surf, rip current, marine zone alerts) are NOT hosted by the marine service. They remain in the API's unified alert system and are served from `/api/v1/alerts` regardless of marine service deployment status. See API-MANUAL §19.6 for the rationale.

#### WW3 deep-water leg + chain-serves (as-built; ADR-109, CHAIN-SERVES round, operator order 2026-08-19)

This subsection documents the WW3 deep-water leg's build, installation,
scheduling, monitoring, and production chain for every location. The WW3 leg
runs on the marine-service host and is the only deep-water model leg; no live
SWAN-L1 or non-chain fallback remains.

**Build/install.** WW3 **6.07.1**, commit `b582f8cbc82aec6f13a66a58c661fba4ae24e4ee` — the only buildable release tag off NOAA-EMC/WW3 (public source, LGPL v3); WW3 5.16 predates NOAA's move to GitHub and cannot be checked out (ADR-109 D2, `scratch/F1-BUILD-REPORT.md` §1). Two switch-file configurations (a "switch file" is WW3's build-time selection of physics packages, compiled in rather than configured at runtime) are DESIGNED artifacts fixed by ADR-109's embedded D13 catalog — **never operator defaults, never hand-edited at install time**: P1 (ST6/FLX4 — ST6 is the wave-growth/decay physics package, FLX4 its paired wind-stress formulation; the production selection, ADR-109 D4) and P2 (ST4/FLX0, an alternative physics pairing that was built but not selected for production). Build tokens honor `OMP_NUM_THREADS ≤ 4` (pure-OpenMP combination `F90 NOGRB LRB4 NOPA SHRD OMPG OMPX`, ADR-109 D13 Group 1). See `scratch/F1-BUILD-REPORT.md` (cited via ADR-109) for the full build log and both switch-file token sets.

**Binary checksum pins — generated by the deploy script, never by hand (J24, operator order 2026-08-27: "THIS ENTIRE SETUP HAS TO BE AUTOMATIC!").** The WW3-leg runner refuses to run any `ww3_*` program whose SHA-256 does not match an expected value (`services/ww3_runner.py` `_verify_binaries()`, refuse slug `ww3_binaries_invalid`). Those expected values live in a **host-local file the config push never touches**: `/etc/weewx-clearskies/marine/ww3-binaries.json` (`{"generated_by", "generated_at", "binary_dir": "/var/lib/weewx-clearskies/ww3/bin", "binary_sha256": {"ww3_bound", "ww3_grid", "ww3_outp", "ww3_prep", "ww3_shel"}}`, owner ubuntu, mode 0640). `scripts/deploy-marine.sh` step 4b writes it on EVERY deploy by hashing the five installed programs (a missing program fails the deploy, same standing as the SWAN-binary prerequisite). The marine config loader (`config/__init__.py` `load_ww3_binaries()`, laid over the pushed `ww3` block by `config/marine_config.py` `load_ww3_config()`) takes `binary_dir`/`binary_sha256` from this file whenever it exists — a pushed value is at best a stale copy and never wins; every other `ww3` key (timeouts, `vchain_buoys`, retention) still comes from the pushed config. Startup logs one line: `WW3 binary pins: 5 program(s) from /etc/weewx-clearskies/marine/ww3-binaries.json (binary_dir=…)`, or a WARNING that the file is absent (then the leg refuses `ww3_binaries_invalid` unless the pushed config happens to carry pins). *Why:* until 2026-08-27 the pins lived only in a hand-placed `ww3` block inside `marine.conf`, and every API config push (`POST /config` → `persist_config()`, which rewrites the whole file from a payload that has no `ww3` block) silently deleted them — the 18Z leg that day refused `ww3_binaries_invalid` after a routine push. Replacing the binaries (a rebuild) is therefore just a redeploy: the hashes are recomputed and the service restarted in the same run.

**Scheduling.** The WW3 leg runs on the 6-hourly full-cycle cadence; it does
not run on the hourly fast-cycle cadence, matching the restart-chaining design.
It runs serially with the SWAN cycle (never concurrently) to avoid resource
contention, at `OMP_NUM_THREADS ≤ 4`, `nice -n 15`. Per-cycle wall-clock is in
the tens-of-minutes class at production shape (measured: 4706.82 s ≈ 78.4 min
for G1×P1 at F4b's 24 h production-shaped march; corroborated by real-data
marches at 4183.58–4509.74 s, ADR-109 D12).

**00Z daily long march (Q16 Round A, 2026-08-25; ADR-109 amendment note).** In addition to the four 6-hourly legs above, the **00Z** cycle ALSO runs a continuation march once daily, strictly AFTER that cycle's own 6 h leg and production publish complete: `cycle+6h → cycle+96h` on the same G1 grid/binary/physics, starting from a COPY of the leg's own +6 h restart (the leg's restart chain above is untouched). Wall-clock ≈4 h at the same contention budget as the leg (never concurrent with a production full run); ceiling 6 h. It stages a merged boundary transfer for SWAN L2 — hours 0–6 from that cycle's own leg, hours 7–72 from the newest 00Z march — rather than the 7-record leg file alone. This staging does not establish that the horizon merge is fixed: R3 refuses a new cycle if L2 PRINT proves the boundary exhausted. See PROVIDER-MANUAL.md §14.18 for the merge/cycle-pin mechanics and ADR-109's amendment note for the full design.

**Retry (J28, 2026-08-28, operator order — "the 72 hours never fired").** The march is no longer once-a-day-and-forgotten: it is attempted after ANY cycle's publish, and from the runner loop's own tick as a catch-up, whenever the newest horizon transfer on disk cannot cover the last published cycle's 72 h window (no file, no recorded coverage, or coverage ending before `cycle + 72 h`) — at most 3 attempts per cycle, 30 min apart, counter in-memory (a restart resets it: a restart is what killed the previous attempt). The 00Z-only refusal is gone. On the production host the march had never succeeded before this (08-27 refused on short wind; 08-28's was killed by a deploy's `systemctl restart` — the march is a child of the service). **R3 supersedes the prior publish behavior:** L2 boundary exhaustion now refuses the new cycle and preserves last-good output; it does not establish that the horizon merge is fixed. **Deploy guard:** `scripts/deploy-marine.sh` runs a fail-closed guard before every named mutation phase (source, environment/config, WW3 pins, unit, bootstrap/migration) and immediately before restart. It first requires the local SSH alias `librewxr` to resolve to `librewxr.shaneburkhardt.com`; a missing or different FQDN fails before SSH. The guard accepts health only when the remote loopback response is HTTP 200 with valid duplicate-free JSON and actual Boolean `ww3Horizon.inFlight` and `run_in_progress` fields; non-200, statusless, empty, malformed, or duplicate-key responses are malformed and therefore `unknown-busy`. A true busy field is `busy`. False fields are idle only with an active service and no descendant. The recursive cgroup walk makes a confirmed descendant with reachable idle health and an active service `busy`; a descendant in every other inconsistent state remains `unknown-busy`, unless health itself is busy. Health unreachable is idle only when the service is inactive or failed and has no descendant; in particular, an active unreachable service is `unknown-busy`. Any transition state, query failure, or unlisted combination makes the result `unknown-busy`.

Run `scripts/deploy-marine.sh --check-guard` for this read-only classification. It makes no mutation, names the health/service/descendant evidence, exits **0** for idle, and exits **2** for busy or `unknown-busy`. A normal deploy rechecks every 60 seconds for at most 23,400 seconds (6.5 h), then refuses the next mutation. `--force-restart` is the sole guard bypass and is operator-only. **Visibility:** `fullRun.l2BoundaryExhausted = true` records exactly one `no-publish: l2_boundary_exhausted` reason (admin status page pass-through) and no new forecast. Mechanics in PROVIDER-MANUAL.md §14.18 "Retry".

**Recovery-order correction (2026-09-01).** The preceding 00Z and retry
paragraphs record a rejected order and are not an operating procedure for cold or
wiped recovery. After the six-hour WW3 leg completes, the service must build the
same cycle's +6 through +96 hour continuation from the leg's +6-hour restart and
verify the complete +0 through +72 hour boundary before it starts SWAN. A missing,
short, corrupt, or wrong-cycle continuation refuses the new cycle before SWAN and
preserves any verified last-good output. Do not use the six-hour transfer alone,
and do not wait for a SWAN publish before building the continuation. This correction
restores recovery-plan §§5.3–5.4; it does not close A0, A0-I, R1, R2, R11, or their
required evidence gates.

**Monitoring keys + refuse reasons.** A WW3-leg restart-age health key — the `l1NestAge`/`L1_NEST_MAX_AGE_H` analog documented above — with refuse gate **`WW3_RESTART_MAX_AGE_H = 9`** (ADR-109 D11, proposed by analogy to the live path's precedent, not itself a WW3-specific measurement): when the WW3 leg's most recent restart exceeds this age, the WW3-leg cycle refuses to publish its artifacts (never falls back to a fabricated or stale-but-unflagged state) and health reports the named reason, following the same refuse-loudly semantics as `l1NestAge` above. Named refuse reasons at this leg follow the existing no-publish-slug convention (this manual's H1 no-publish reasons list, above) — a WW3-leg build/run failure or a stale restart is a refuse condition, never a silent degrade.

**Monitoring keys — Q16 Round A additions (2026-08-25; ADR-109 amendment note).** New top-level `/health` block **`ww3Horizon`**: `{"lastSuccessCycleTime": str | null, "coverageEndTime": str | null, "wallClockS": float | null, "refuseReason": str | null, "inFlight": bool, "inFlightCycleTime": str | null, "lastAttemptCycleTime": str | null, "lastAttemptAt": str | null}` — the continuation march's own status, independent of the leg's own health fields above (a horizon-march refusal never affects `status`/`reasons` or blocks a publish; the four `inFlight`/attempt keys are J28 additions — `inFlight` is forced false on restart, and is what `deploy-marine.sh`'s restart guard reads). Existing field **`fullRun.l2BoundaryExhausted`** (boolean): a detector scans SWAN L2's PRINT output every run for the "data on boundary file exhausted" warning and surfaces it here — **FALSE is the healthy/expected state every cycle; TRUE triggers R3 fail-closed refusal**. Full and fast refusal paths set the existing `no-publish: l2_boundary_exhausted` reason; a persisted successful fast update resets the flag and clears only that matching reason. For a restored legacy flag with no matching no-publish reason, health says `attemptCycle=unknown` and separately names `pendingFullCycle` and `lastGoodCycle`; it does not invent a fast-cycle identity. No R11 recovery intent, exit, restart, or refetch follows. Named refuse reason at the horizon march: `ww3_horizon_cycle_unpinned` (the march's NOAA-cycle pin, `level0/boundary_cycle_<token>.txt`, was unavailable — the march makes exactly one pinned fetch attempt, no fallback ladder). See PROVIDER-MANUAL.md §14.18 for the merge/cycle-pin mechanics.

**Disk/retention.** New top-level `level0/` directory (alongside the existing `level1/`–`level4/` directories, ADR-109 D12): `mod_def.ww3` (versioned build artifact, rebuilt only on geometry/config change — **876 KB** for P1/G1, per `scratch/F3-MARCH-REPORT.md` §2.2), per-cycle `nest_out_<cycle>.ww3` (the boundary product handed to L2, retention **≥24 h**, mirroring the live path's `nest_out_<cycle>.dat` retention pattern), per-cycle `restart_<cycle>.ww3` (chained per cycle — **~212.8 MB** for G1, exact measured `restart*.ww3` size 212,839,200 B per `scratch/F3-MARCH-REPORT.md` §2.2), per-cycle field/point output for the ledger instruments and validation.

**WW3 grid rebuild (G10 hook, S8.1-B, 2026-08-27; ADR-109 Gap G10).** `mod_def.ww3` is D12's versioned build artifact — the WW3-leg cycle only ever CONSUMES it; nothing rebuilds it on a per-cycle basis. This hook is the production trigger that rebuilds it when it goes stale, running once at the very start of every `_run_ww3_leg()` call, before the restart-chaining decision (its outcome decides whether that cycle cold-starts).

*What triggers it.* The hook reconstructs the current cycle's WW3 setup derivation from the `ww3_leg` block of the grid-sizing cache (`swan_grid_sizing.json`), renders the `ww3_grid.inp` deck and the three NAME files (`G1_bottom.txt`, `G1_status.txt`, `G1_obstr.txt`) to a per-cycle staging directory, and hashes all four (deck text + the three files, in that fixed order) with SHA-256 — deliberately never the sizing JSON's own `provenance` block, whose timestamps would force a rebuild every cycle. It compares that hash to `level0/mod_def.provenance.json`'s `derivation_sha256`. A rebuild fires when the note is missing, unreadable, lacks `derivation_sha256`, or the value differs — never when they match (no rebuild, no file writes, `ww3_grid` is not invoked). If the sizing cache lacks the required D15 occupancy/depth/status/transparency evidence, the hook cannot rebuild: it trusts an existing readable provenance note and otherwise refuses the cycle (`ww3_grid_rebuild_inputs_missing`). Operators resolve this by rerunning the configuration-time chain so it fetches complete OSM occupancy geometry and regular datum-converted bathymetry; the hook never substitutes a depth or geometry source on its own.

*The files it writes.* On a triggered rebuild: `WW3Runner.run_grid()` produces a new `mod_def.ww3` in the staging directory; the hook renames the CURRENT `level0/mod_def.ww3` to `level0/mod_def.ww3.prev-<token>` (kept — every `.prev-*` file is retained indefinitely, ~876 KB each, rebuilds are rare; `_prune_ww3_level0` does NOT prune these), promotes the staged file into `level0/mod_def.ww3`, then writes `level0/mod_def.provenance.json` atomically (`.tmp` + rename): `{"derivation_sha256": str, "rebuilt_at": ISO-8601 UTC, "cycle_time": str, "reason": "provenance_missing"|"derivation_changed", "previous_file": str|null, "fine_dem_source": str|null, "deck_sha256": str, "name_file_sha256": {filename: hex}}`. The per-cycle staging directory itself (`level0/grid_<token>/`) is always removed afterward, success or failure.

*The cold start that follows.* A cycle that rebuilt `mod_def.ww3` skips the restart-chaining block entirely and cold-starts (the existing restart file was generated against the OLD grid geometry — it is not deleted, but it is not consumed either; the next cycle's restart comes from this cold-started march). Health reports `ww3.restartRefusedReason == "ww3_grid_rebuilt_cold_start"` for that cycle (cleared by the next leg outcome recorded for a later cycle) and logs a WARNING naming the slug. This is NOT a `record_ww3_leg_refusal()` outcome — the cycle still runs and can still publish. **Retries of that cycle cold-start too (fix 2026-08-27 22:xxZ).** The "not consumed" promise holds on every later attempt, not only the attempt that rebuilt: the restart-chaining block refuses any restart file whose modification time is earlier than the provenance note's `rebuilt_at` (`service.py::_ww3_restart_predates_grid()`), logging `restart … predates the current mod_def.ww3 … refused: ww3_grid_rebuilt_cold_start` and cold-starting. *Why:* the first production rebuild's SWAN run refused to publish, the runner retried the same 18Z cycle, the hook found the provenance hash matching (no rebuild), and the leg consumed the pre-rebuild `restart_20260827.180000.ww3` — `ww3_shel` exited 13 in under a second reading a restart from a grid with a different sea-point count. The stale file is still never deleted.

*Baseline/diff commands (operator procedure).* Before and after a config push that could change the WW3 G1 geometry (extent, resolution, or the S8.1-A transparency field's fine-DEM cut):
```
sha256sum level0/mod_def.ww3
cat level0/mod_def.provenance.json
ls -l level0/mod_def.ww3.prev-*
cmp level0/mod_def.ww3 level0/mod_def.ww3.prev-<token>   # (expect: differ, after a real rebuild)
```
`sha256sum` on the live artifact should change exactly once, at the first cycle after the push; the provenance note's `derivation_sha256`/`rebuilt_at`/`reason` should match that cycle. If a rebuild is expected but did not happen, compare `cat level0/mod_def.provenance.json`'s `derivation_sha256` against a fresh run of the same hash computation over the new derivation — a mismatch there is a hook defect, not an operator error.

*Forcing a rebuild.* The ONLY sanctioned way is deleting `level0/mod_def.provenance.json` — the next cycle's hook then finds no note, rebuilds unconditionally (`provenance_missing`), and cold-starts. Never hand-edit `mod_def.ww3` or the note; never delete `mod_def.ww3` itself to force a rebuild (that trips the separate, byte-identical `ww3_mod_def_missing` refusal instead, which does NOT rebuild anything).

*Health slugs.* `ww3_grid_rebuild_inputs_missing` (arrays absent from the sizing cache and no readable provenance note — the sizing chain must re-run with the CRM fine DEM), `ww3_grid_rebuild_failed` (`ww3_grid` itself refused, or the promote/provenance-note write failed after a successful `ww3_grid` run — the existing `mod_def.ww3` and note are left untouched either way), `ww3_grid_rebuilt_cold_start` (not a refusal — recorded in `/health`'s `ww3` block only, per above). New additive `/health` `ww3` block fields: `gridRebuiltAt`, `gridRebuildReason`, `gridDerivationSha256`, `gridRebuildCycleTime`, `restartRefusedReason`.

**Migration note — `swan_grid_sizing.json` `level1`→`deep_water` key rename (S3(b), marine `c57bb8e`, 2026-08-27). No operator action.** The sizing cache's deep-water-domain geometry block was persisted under the key `level1`; the code/config label renamed to `deep_water` (cosmetic — same geometry, same domain, no formula or grid change; the on-disk `swan/level1/` run directory and `swan_bathymetry_L1.json` cache filename are untouched). Reads accept either key (`deep_water` first, falling back to the legacy `level1` with one INFO log line: `legacy \`level1\` key read`); writes always emit `deep_water` only. The next sizing-chain run (an apply-time config push, or a forced full run) rewrites `swan_grid_sizing.json` with the new key automatically — nothing to delete, nothing to force, nothing to verify.

**Disk/retention — R2 boundary selection.** `level0/horizon_<token>/` holds raw continuation output and remains independently retained from the consumer merge. `level0/hstage_<token>/ww3_l2_transfer.ww3` is the selected 73-record consumer boundary for that cycle. A full run first writes a private candidate in the same hstage directory; only a successfully published full run promotes it atomically to that exact canonical filename and records its path and SHA-256 with full-run success in `state_snapshot.json`. A failed candidate is removed and must not replace a previous selected canonical boundary. Operators must not copy, rename, or prune a selected canonical artifact by hand; use the normal recovery/rollback procedure so the state reference and file remain matched. `level0/boundary_cycle_<token>.txt` is the NOAA cycle pin the horizon march re-fetches against. Disk: horizon transfer output runs to hundreds of MB/day, retention-bounded (394 GB free measured at implementation time). See PROVIDER-MANUAL.md §14.18.

**R9 retry/deploy guard.** A repeated full-run attempt can reuse its completed WW3 leg for the same cycle when the recovery checkpoint proves the retained transfer, diagnostic transfer, +6 restart, nest output, and boundary pin are present, non-empty, and the transfer records are exactly ordered from +0 through +6 hours. Only a missing or corrupt WW3 output proof causes that leg to rerun; a downstream SWAN refusal does not discard the completed leg or selected merged boundary. Reuse does not record a new WW3 success time. `run_in_progress` covers the complete production attempt from WW3 through boundary staging, SWAN, parse, SwellTrack, and publication; its outer cleanup clears it on every refusal or exception. The guarded deployment script treats that active state as busy and does not restart the service.

**Build/install-time verification citation:** the build/install steps above are the proven Phase F steps — see `scratch/F1-BUILD-REPORT.md` (cited in full via ADR-109 D2/D13). Supported-environment matrix for the WW3 build follows the marine service's own matrix above (native Debian/Ubuntu, LXD container, Docker, Proxmox VM, Raspberry Pi) — no additional environment constraints beyond gfortran/OpenMPI/NetCDF, which the marine service's `[nearshore]` extra already requires for SWAN.

**Chain-enabled gate (config, not scheduling) — CORRECTED 2026-08-27 (D1 as-built re-sync, plan §S3, C19).** The single per-location `ww3_chain_enabled` boolean (CHAIN-SERVES D1 — REPLACES the two transition-era keys `ww3_shadow_mode_enabled`/`vchain_enabled`, which no longer bind anything; see API-MANUAL.md §19.7a for the config-push mechanics) is a **legacy no-op for the WW3-leg/chain path itself**: the leg runs unconditionally for every location and the production SWAN call always threads `chain=ChainSpec` (`weewx_clearskies_marine/service.py`, `_run_ww3_leg()` comment "The per-location ww3_chain_enabled flag is a legacy no-op"; the full-run trigger's own gate is hardcoded `if True: # was: if chain_location_ids:` — there is no remaining code path where the flag being false produces a different (legacy L1-fed) run). What the flag actually still gates today: the two buoy-ledger writers, `services/vchain.py`'s `record_leg_refused_ledger_row()` and `record_chain_cycle_ledger_row()`, both of which no-op via `chain_enabled_location_ids()` when no location has the flag set — turning it off silently stops the per-cycle buoy ledger, not the chain. It does not change the WW3 leg's own cadence, thread budget, or refuse-gate values documented above, which are universal (the leg itself is always-on per Q1, independent of this flag). Live config has it `true`. (`vchain.py`'s `chain_enabled_location_ids()` docstring was corrected to match this, marine `5c0cb21`, same day — a D1 docs finding fixed lead-direct.) **Where it is set (as-built 2026-08-28):** in `api.conf` on the API host, `[marine][[locations]][[[<location-id>]]] ww3_chain_enabled = true` — a config-file-owned key the wizard preserves on every apply and the config push carries to the marine service (API-MANUAL §19.7a). Before 2026-08-28 it existed only as a hand-typed entry in the marine service's `marine.conf` and every push erased it, silencing the ledger; never set it there again.

**Chain-serves (as-built, CHAIN-SERVES round, operator order 2026-08-19: "NO NOT IN SHADOW, JUST MAKE IT SO IT IS THE CHAIN! ... GET IT WIRED CORRECTLY WITH THE CORRECT MODELS IN THE CORRECT PLACES HANDING OFF TO THE CORRECT MODELS TO GET THE CORRECT ANSWER.").** For every location, a full-run trigger runs the WW3 leg FIRST (`service.py`'s `_run_ww3_leg()`, renamed from `_run_ww3_shadow_leg()` — ADR-109's frozen mechanics unchanged). A leg refusal (any `ww3_*` slug) means NO SWAN run and NO publish this cycle (`_record_full_run_attempt_failure(cycle, "ww3_leg_<slug>")`, existing retry-same-cycle/backoff semantics unchanged) — the standing all-inputs-required posture applied to the chain's deep-water input. Leg success builds a `ChainSpec` (`services/vchain.py`'s `build_chain_spec()`: stages the cycle's own `ww3_outp` transfer file into SWAN L2's PRODUCTION working directory) and threads it into `providers/nearshore/swan.py`'s `run_full_swan_cycle_from_store(..., chain=ChainSpec(...))` — the PRODUCTION full-run call itself: production workdir, production run marker, dedup, caches, hotstarts, publish, state recording — none of it diverted, no isolated shadow tree (`SWAN_WORK_ROOT/vchain/work/` no longer holds a second SWAN run; the ledger's SurfBeat-companion probe that used it as scratch was removed 2026-08-23 with SurfBeat), no compute-priority override. SWAN L1 never runs. The direct `BOUNDNEST3` path does not require retired L1 `BOUNDSPEC` files after a configuration rebuild.

**Hourly quick-update substitution (CHAIN-SERVES D8, operator ruling verbatim: "what feeds the hourly runs should not change ... the only thing we are doing is substituting the WW3 model for L1").** The hourly (fast) L2+ stationary fill (`services/swan_runner.py`'s `run_stationary_full_nest()`) keeps its established cadence, trigger, age-gate value (`L1_NEST_MAX_AGE_H = 9`, a legacy constant name), and refusal shape (WARNING + skip). The caller resolves the state-selected canonical WW3 L2 boundary (`level0/hstage_<token>/ww3_l2_transfer.ww3`), hash-verifies it against `state_snapshot.json`, age-gates it, and passes `l2_boundary_source="boundnest3_ww3"` to `run_stationary_full_nest()`. A missing, mismatched, or stale selected transfer refuses that hourly fill. Retired L1 `BOUNDSPEC` scaffolding is not a prerequisite. There is no `boundnest1` or archived-SWAN-L1 fallback path.

**Buoy-scorecard ledger (CHAIN-SERVES D5, the operator's stated point: "scored against buoys").** `services/vchain.py` keeps its instruments and ledger exactly where they were (`vchain/ledger/row_<cycle>.json`, schema 2 since 2026-08-23 — the `surfbeat` companion key was dropped with SurfBeat's removal; schema 1 before that, retention key `vchain_ledger_retention_days`, atomic write, `obs=null` + named reason on fetch failure), rewired to read PRODUCTION outputs rather than a second run: WW3 buoy-point Hs/Tp/dir from the cycle's transfer spectra at the nearest points to the `[ww3] vchain_buoys` stations (default NDBC 46253/46222, with honest point-to-buoy distances), chain per-spot served-first-hours + DWR-dominant summaries from the production last-good-cache payloads (the SurfBeat companion result was dropped 2026-08-23) the SAME cycle just published, wall-clocks from the production run, and matched-time NDBC realtime2 observations. Every chain-enabled cycle ATTEMPT writes exactly one row — including a WW3-leg refusal (row status `refused`, slug `ww3_leg_<slug>`, written by `record_leg_refused_ledger_row()` BEFORE any SWAN attempt) and a SWAN-side refusal after a successful leg (`record_chain_cycle_ledger_row()`, reading the SAME no-publish reason the production call itself recorded) — closing the gap where WW3-leg refusals previously produced no row at all. Health surfaces via the read-only `/health` `vchain` block (`lastCycleTime`/`status`/`refuseReason`/`chainWallClockS`/`ledgerPath`; never feeds `status`/`reasons`). Named refuse slugs: `ww3_leg_<cause>` (a leg refusal), `vchain_bad_cycle_time`, `chain_transfer_missing` (the WW3 leg succeeded but did not produce a transfer file), `chain_scaffold_missing` (no reusable L2 BOUNDSPEC scaffold, or a referenced spectrum file is missing; there is no supported automatic recovery), `chain_l2_boundary_staging_failed` (a disk/OS failure while staging -- the catch-all for any other build_chain_spec() failure), `chain_swan_refused` (a SWAN refusal with no recorded no-publish reason) or the production no-publish slug verbatim (e.g. `wind_series_gap`), `vchain_ledger_write_failed`, and the escape catch-all `vchain_unexpected_error` (service.py wrapper). The old `vchain_skipped_budget`/`vchain_chain_failed`/`vchain_chain_refused`/`vchain_no_payloads` slugs are RETIRED — there is no separate chain run any more to budget-gate or fail independently of the production publish. Ledger retention (Gate VCHAIN F3, unchanged): rows are age-pruned at the start of each ledger write by their filename cycle token, retention `[ww3] vchain_ledger_retention_days` (default **45 days**); pruning logs a named INFO line and is never fatal to the cycle.

**Direct-boundary correction (2026-08-31).** The preceding historical `chain_scaffold_missing`
description is superseded for the direct WW3 path. A configuration rebuild may remove old L1
`BOUNDSPEC` files; their absence is not a refusal condition because `BOUNDNEST3` replaces the
temporary input section before SWAN runs. `chain_l2_boundary_staging_failed` remains the staging
failure reason for a real disk or operating-system error.

**Seam-fidelity row (S1, PA5, EVO-Q16 C6, schema 3 — additive, 2026-08-27).** Every chain-enabled cycle's ledger row (success path) additionally carries `row["seam"]`: a per-cycle comparison of the WW3 spectrum HANDED to SWAN at the most-seaward WW3 L2-boundary transfer point (`L2P####`) against the spectrum SWAN itself reports ABSORBING at a new dedicated output point, `SEAM` — one L2 cell inward from that same boundary point, toward the L2 centre (ADR-095 Amendment 2: never AT a boundary cell). Labelled explicitly `"model-vs-model (WW3 handed vs SWAN absorbed), NOT a truth check"` — this is a boundary-transfer-fidelity instrument, not a validation-against-observation instrument (that remains the buoy-scorecard rows above). Compared per frequency band (`SEAM_BAND_EDGES_HZ = (0.09, 0.20)` Hz, i.e. `< 0.09` / `0.09–0.20` / `> 0.20` Hz) as Hs ratio (`SEAM_HS_TOLERANCE = ±10%`, the interpolation-error class of BOUNDNEST3) and direction agreement (`SEAM_DIR_DIFF_FLAG_DEG = 30°` — an Hs-only check is blind to a mirrored-direction defect class since Hs is direction-independent; `dir_diff_deg` exists specifically to catch that). `within_tolerance` is `True` only when every band is within BOTH thresholds. **`hs_ratio` carries a real ≈0.3% noise floor** even for a perfectly-transmitted spectrum: the WW3 transfer-file writer stores its frequency axis at 4 significant figures (`%0.3E`) while the SWAN SPECOUT writer stores the SAME axis at 6 (`%.5E`); re-parsed back, the two sides' bin-width (`df`) calculations differ by a fraction of a percent, propagating into Hs via `4*sqrt(m0)`. `SEAM_HS_TOLERANCE = ±10%` is sized well above this floor — it is the meaningful threshold, not the floor itself. A parse/alignment failure at any step (no transfer spectra this cycle, no grid-sizing cache, no `L2P`-named boundary point, `SPEC_SEAM.txt` missing/unparseable, no timestep common to both sides, or any other unexpected error) writes a named `error` (`seam_transfer_unavailable`, `seam_grid_sizing_unavailable`, `seam_no_boundary_point`, `seam_specout_missing`, `seam_specout_parse_failed`, `seam_no_common_timestep`, `seam_unexpected_error`) with `bands`/`within_tolerance` `null` — the row is written EITHER way, same never-fails-the-cycle contract as the rest of this ledger; the failure is also logged at WARNING. See PROVIDER-MANUAL.md §14.15 Amendment "C6 seam-fidelity ledger row" for the SEAM output point's deck mechanics.

**A1 paired output (deployed; recovery evidence remains open, 2026-08-31).** The WW3
producer validates and atomically promotes a boundary transfer and its matching diagnostic transfer
after the WW3 march. The direct L2 handoff was live-tested with the regenerated boundary: L2 accepted
it and retained an approximately 1.0 m component. The attempt did not publish because the required
+7 through +72 hour continuation transfer was absent. Do not copy, remove, or manually prune either
artifact. A future approved procedure must retain the active complete pair and its complete rollback
predecessor, and may delete an older pair only after a newer pair is validated and no process or
reader still references the older one. The recovery plan §8A A0-I gate must name and test the durable
generation and reference mechanism before this becomes an operator action. This result does not
complete A0, A0-I, A1, R1, R2, or full recovery.

#### Restart/resume and cleanup (as-built recovery behavior)

After a service restart, a stage resumes only when its owner-validated
checkpoint still names the current cycle and carries SHA-256 hashes of its
retained outputs. The existing atomic state snapshot
stores checkpoints for the WW3 leg, horizon, SWAN L2/L3/L4, SwellTrack, cache,
and publication. In the full production recovery path, verified WW3 and
horizon output remains reusable after a restart or downstream refusal. For a
same-cycle retry, only a stage's own missing or corrupt output proof causes a
rebuild; a new cycle starts a new stage attempt. Fresh provider timestamps or
runtime identity alone do not invalidate verified output. SWAN
reuses verified L2/L3/L4 work directories, and the final
SwellTrack/cache/publication tail reuses the restored forecast-cache artifact
when its three output checkpoints still match. Only a stage's own missing or
corrupt output causes that stage to rebuild; a downstream refusal leaves
completed upstream output available (`state.py`, `service.py`,
`providers/nearshore/swan.py`, and `services/swan_runner.py`). The selected
merged `ww3_l2_transfer.ww3` boundary is retained and reused while its
recorded hash matches.

**Selected WW3 recovery wind artifact.** `recovery_wind_timeline.json` lives
under the existing durable SWAN work root and belongs to one selected UTC
recovery cycle only. It is written atomically after exact-cycle HRRR f00–f48
and GFS f048–f072 retrieval and strict validation, then reread before the
SWAN tail starts. It is not a routine cache and never replaces or is replaced
by `wind_timeline.json`. If it is absent, corrupt, mixes cycles/sources,
contains a gap, duplicate, unexpected valid time, invalid geometry, or
non-finite wind component, the recovery tail refuses as
`recovery_wind_invalid`; valid retained WW3 artifacts remain available for a
later retry.

WW3's per-cycle staging tree is private and is removed on either successful
promotion or refusal; its destination remains untouched until the complete
H/D transaction succeeds. SWAN cleanup removes only unproved private input,
forcing, intermediate, and temporary hotstart files before rewriting a level.
Diagnostics from a failed SWAN level remain available for diagnosis, but the
failure record invalidates its recovery checkpoint, so those diagnostics are
never reused as model state. Durable forecast cache, grid sizing, bathymetry,
and WW3 restart artifacts are outside this cleanup boundary.

The ordered recovery path is WW3 six-hour leg → +6…+96 horizon → verified
+0…+72 merge → forcing acquisition/preflight → SWAN L2–L4 → SwellTrack →
cache persistence → publication. WW3 restart-file grammar follows the local
v6.07 manual's Type 4 restart section (`docs/reference/ww3-user-manual-v6.07.txt`,
around line 19098). SWAN's `BOUNDNEST3` gate requires sequential formatted WW3
output locations and the 0.1 corridor (`docs/reference/swan-user-manual.txt`,
pp. 54–55); `INITIAL HOTSTART` is used only when its input is verified.

---

### §4.1 Config Registry

The config wizard and admin UI share a unified config registry: a set of Python frozen dataclasses registered at import time that drive field rendering, validation, and persistence in both UIs. An implementing agent reads this section — not ADR-077 (archived) — to build the registry.

#### ConfigField schema

Every configurable field is a `ConfigField` frozen dataclass:

```python
@dataclass(frozen=True)
class ConfigField:
    field_id: str           # Globally unique. e.g. "earthquakes.radius_km"
    field_type: str         # One of: text, url, number, boolean, select, radio,
                            #   password, file_or_url, radio_swatch, textarea,
                            #   checkbox_group  (11 types — no others)
    label: str
    help_text: str = ""
    wizard_help: str = ""   # Extra guidance shown only in wizard mode
    placeholder: str = ""
    default: Any = None
    options: tuple[FieldOption, ...] = ()      # Required for select/radio types
    validation: tuple[ValidationRule, ...] = ()
    config_target: str = ""  # e.g. "stack.conf:earthquakes", "branding.json",
                             #   "secrets.env"
    config_key: str = ""
    is_secret: bool = False
    secret_env_key: str = ""  # env var name when is_secret=True
    conditions: tuple[Condition, ...] = ()
    wizard_visible: bool = True
    admin_visible: bool = True
    admin_landing_display: bool = False  # Show current value on admin landing card
    grid_column: str = "full"            # "full" or "half" — no other values
```

`FieldOption`, `ValidationRule`, and `Condition` are also frozen dataclasses:

```python
@dataclass(frozen=True)
class FieldOption:
    value: str
    label: str
    description: str = ""

@dataclass(frozen=True)
class ValidationRule:
    rule_type: str   # One of: required, min, max, step, pattern, one_of,
                     #   max_length, max_file_size
    value: Any       # The rule's parameter (e.g. min=1, pattern="G-[A-Za-z0-9]+")

@dataclass(frozen=True)
class Condition:
    field_id: str    # The controlling field
    operator: str    # Comparison operator — e.g. "eq", "ne", "in"
    value: Any       # Value to compare against
```

All four dataclasses must be frozen. No mutable state is permitted in these objects.

#### SectionDef schema

A `SectionDef` groups fields for admin display:

```python
@dataclass(frozen=True)
class SectionDef:
    section_id: str
    display_name: str
    domain_group: str      # One of: station, providers, appearance, dashboard,
                           #   advanced, cards
    config_source: str     # Which file or API this section reads from
    custom_template: str = ""   # Path to escape-hatch template (see §4.1 below)
    custom_handler: str = ""    # Dotted Python path to custom handler function
```

#### WizardStepDef schema

A `WizardStepDef` groups sections for the wizard's sequential flow:

```python
@dataclass(frozen=True)
class WizardStepDef:
    step_number: int
    title: str
    description: str
    section_ids: tuple[str, ...] = ()
    custom_template: str = ""   # Path to escape-hatch template
```

#### ConfigRegistry API

`ConfigRegistry` is built at import time. All registration must happen before any request is handled.

| Method | Signature | Description |
|--------|-----------|-------------|
| `register_section` | `(section: SectionDef, fields: tuple[ConfigField, ...]) -> None` | Register a section with its fields. Must be called once per section. Raises `DuplicateSectionError` if `section_id` is already registered. |
| `register_wizard_step` | `(step: WizardStepDef) -> None` | Register a wizard step. Raises `DuplicateStepError` if `step_number` is already registered. |
| `register_card_config` | `(card_type: str, fields: tuple[ConfigField, ...]) -> None` | Register fields from a card manifest. Creates a section with `section_id = f"card_{card_type}"` in the `cards` domain group. |
| `get_sections_for_group` | `(domain_group: str) -> tuple[SectionDef, ...]` | Return all sections in the given domain group, in registration order. |
| `get_fields_for_section` | `(section_id: str) -> tuple[ConfigField, ...]` | Return all fields for the section, in registration order. |
| `get_wizard_steps` | `() -> tuple[WizardStepDef, ...]` | Return all wizard steps sorted by `step_number`. |
| `get_all_domain_groups` | `() -> tuple[str, ...]` | Return all domain group names that have at least one registered section. |

`ConfigRegistry` uses `dict`-based internal storage. All query methods return immutable tuples. O(1) lookups by `section_id` and `step_number`.

#### render_field macro contract

The `render_field` Jinja2 macro handles all 11 field types. It lives in `templates/macros/form_fields.html`.

```jinja2
{% macro render_field(field, value, mode) %}
{# field: ConfigField object
   value: current value (str, bool, or None)
   mode: "wizard" or "admin" #}
```

Rules for every field type:

- Every `<input>`, `<select>`, and `<textarea>` element must have `aria-describedby` linking to the field's help text element. The help text element id must be `help_{{ field.field_id | replace('.', '_') }}`.
- Every field wrapper `<div>` must carry `data-condition-field`, `data-condition-op`, and `data-condition-value` attributes when `field.conditions` is non-empty. When multiple conditions exist, encode them as JSON arrays in those attributes.
- `grid_column` must produce `class="field-full"` for `"full"` and `class="field-half"` for `"half"` on the wrapper div.
- Password fields must include a show/hide toggle button.
- `radio_swatch` fields render each option as a colored radio button using Pico CSS custom properties. Each swatch must have a visible focus indicator.
- `checkbox_group` renders each option as a labelled checkbox. All checkboxes in the group share the same `name` attribute (the `config_key`).
- `boolean` renders as a Pico CSS switch (`<input type="checkbox" role="switch">`).
- `file_or_url` renders a URL text input. File upload handling is done by the route handler alongside the registry-rendered field — the macro renders only the URL input.
- In wizard mode (`mode="wizard"`), the macro uses `field.wizard_help` when non-empty, falling back to `field.help_text`.
- In admin mode (`mode="admin"`), the macro always uses `field.help_text`.

The companion `render_section_fields` macro loops over a section's fields and calls `render_field` for each one, applying grid layout:

```jinja2
{% macro render_section_fields(fields, values, mode) %}
{# fields: tuple[ConfigField, ...]
   values: dict of {config_key: current_value}
   mode: "wizard" or "admin" #}
```

#### Conditional visibility JS contract

A single shared JS file (`static/js/conditional-visibility.js`) handles conditional show/hide for all field types. No per-section inline scripts.

The handler must:

1. On `DOMContentLoaded`, scan the document for all elements with `data-condition-field` attribute.
2. For each such element, register a `change` listener on the controlling field (identified by `data-condition-field`).
3. On each change event, evaluate the condition (`data-condition-op` and `data-condition-value`) against the controlling field's current value.
4. Set `aria-hidden="true"` and `inert` on the wrapper when the condition is false. Remove both attributes when the condition is true. Do not use `display: none` alone — `inert` is required so that hidden fields are excluded from form submission and keyboard navigation.

The JS handler is approximately 30 lines. It must not depend on any framework or library beyond the browser DOM API.

#### Validation and save helper signatures

Three functions in `registry/validation.py`:

```python
def validate_form_against_fields(
    form_data: dict[str, str],
    fields: tuple[ConfigField, ...],
) -> list[str]:
    """
    Validate form_data against field ValidationRule tuples.
    Returns a list of human-readable error strings.
    Empty list means validation passed.

    Checks per rule_type:
    - required:       field absent or empty string
    - min:            float(value) < float(rule.value)
    - max:            float(value) > float(rule.value)
    - step:           (float(value) - min) % float(rule.value) != 0 (if min rule present)
    - pattern:        not re.fullmatch(rule.value, value)
    - one_of:         value not in rule.value (rule.value is a tuple of allowed strings)
    - max_length:     len(value) > int(rule.value)
    - max_file_size:  (for file_or_url fields) content-length check deferred to handler
    """

def extract_field_values(
    form_data: dict[str, str],
    fields: tuple[ConfigField, ...],
) -> dict[str, Any]:
    """
    Extract validated field values from form_data, keyed by config_key.
    Only fields present in the registry for this section are extracted.
    Unknown keys in form_data are silently dropped — equivalent to
    _SECTION_ALLOWED_KEYS allowlist behavior.
    Secret fields are excluded — secrets are handled by save_field_values.
    """

def save_field_values(
    values: dict[str, Any],
    section_def: SectionDef,
    config_dir: str,
) -> None:
    """
    Persist values to the correct backend, dispatching on config_target:
    - "stack.conf:<section>"     → update_managed_region(config_dir, "stack.conf", section, values)
    - "api.conf:<section>"       → update_managed_region(config_dir, "api.conf", section, values)
    - "branding.json"            → update_branding(config_dir, values)
    - "branding.json:<key>"      → update_branding(config_dir, {key: values})
    - "pages.json"               → update_pages(config_dir, values)
    - "secrets.env"              → update_secrets(config_dir, values, section_def)
    Raises ValueError for any config_target not matching these patterns.
    """
```

#### Escape hatch pattern for custom sections

Four sections keep custom templates because they have interactive behavior beyond form-field rendering: Haze Calibration, Card Layout, Column Mapping, and API Connection. Set `custom_template` in their `SectionDef` to the path of the custom template.

Rules for escape-hatch sections:

- The registry still owns all `ConfigField` metadata for the section. Do not declare field metadata inside the custom template.
- The custom template calls `render_field(field, value, mode)` for individual fields within its custom layout. It must not re-implement field HTML.
- The generic admin section handler checks `section_def.custom_template` and renders the custom template when it is set, passing the same context variables as the generic template.
- Custom sections appear in the admin landing page alongside generic sections — they get the same landing card treatment. The landing page does not distinguish custom from generic.

#### Canonical values for resolved mismatches

These values are locked. Code and templates must use exactly these values — no variations:

| Field | Canonical value | Banned alternatives |
|-------|----------------|---------------------|
| Theme mode — auto sunrise/sunset | `auto-sunrise-sunset` | `auto-sunrise` is banned. It was a truncation bug in the admin UI. |
| Earthquake radius default | `250` (km) | `100` (old wizard), `500` (old admin) |
| Earthquake min magnitude default | `2.0` | `2.5` (old admin) |
| Earthquake default days | `30` | `7` (old wizard) |
| TLS mode — full set | `self-signed`, `acme_http01`, `acme_dns01`, `manual`, `behind_proxy` | Any subset presented as the complete set. The wizard may show a subset via `wizard_visible=False` on individual options, but the registry must declare all 5. |

Phase 2 QC gate verifies: grep confirms no `auto-sunrise` (without `-sunset`) in any Python or template file; no `_EARTHQUAKE_DEFAULTS` in `admin/routes.py`; all 5 TLS modes present in registry declarations.

#### Plugin card config integration

Cards declare config fields in `card-manifest.json` under a `configFields` key. Each entry matches the `ConfigField` schema (subset: `fieldId`, `fieldType`, `label`, `helpText`, `default`, `options`, `validation`).

The `load_card_config_fields(manifest_path: str) -> None` method on `ConfigRegistry`:

1. Reads `card-manifest.json` from `manifest_path`.
2. Iterates cards with non-empty `configFields`.
3. Converts each entry to a `ConfigField` object with `config_target = f"stack.conf:card_{card_type}"`.
4. Registers them under `section_id = f"card_{card_type}"` in the `cards` domain group via `register_card_config()`.

Call `load_card_config_fields()` at admin startup, passing the path to `card-manifest.json` from the dashboard web root. Card config sections appear in the admin UI automatically via the registry-driven landing page under the `cards` domain group.

---

## §5 Logging

### Format

JSON, one record per line, written to stdout. The API writes no log files. Capture via:
- **Native (systemd):** `journalctl -u weewx-clearskies-api`
- **Container:** `docker logs clearskies-api` or the host's configured Docker logging driver

Log shipping to Loki, ELK, CloudWatch, or any other aggregation system is the operator's concern. Clear Skies does not ship log-shipping configuration.

### Required fields

Every log record must include these fields as top-level JSON keys:

| Field | Format | Required when |
|-------|--------|--------------|
| `timestamp` | ISO 8601 UTC with `Z` suffix — e.g., `2026-06-18T14:23:01.452Z` | Always |
| `level` | One of `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` | Always |
| `logger` | Module-path logger name — e.g., `weewx_clearskies_api.providers.aqi.iqair` | Always |
| `message` | Human-readable string | Always |
| `request_id` | UUID string | All HTTP-request-context records |

Additional structured fields (`provider_id`, `endpoint`, `duration_ms`, `status_code`, etc.) attach as additional top-level JSON keys on the same line. They are never embedded inside the `message` string. Machine-parseable fields must be top-level keys, not freeform text.

### Implementation

Use Python stdlib `logging` with a project-internal JSON formatter. Do not use structlog or loguru — additional logging dependencies are not warranted at v0.1. Configure uvicorn's access log to use the same JSON formatter at startup so all stdout output has a consistent format.

Register the redaction filter at root logger level (not per-handler) so it applies regardless of which handler is active.

### Redaction filter

The filter is a `logging.Filter` subclass installed on the root logger. It rewrites the `LogRecord` before any handler emits it.

Fields it must redact:
- `Authorization` header — any value
- `X-Clearskies-Proxy-Auth` header — any value
- Values of any env var matching `WEEWX_CLEARSKIES_*` (catches provider keys, proxy secret, admin hash)
- Known API key parameter names: `appid`, `client_id`, `client_secret`, `key`, `api_key`
- SQL bind-variable values — log the parameterized query template only, never the bound values
- Full request bodies on authentication endpoints (`/bootstrap`, `/login`, `/admin/*`, `/setup/*`)

The filter is defence-in-depth. Do not log sensitive values and then rely on the filter to catch them — write code that does not produce them in the first place.

### Error responses

Error responses follow RFC 9457 `application/problem+json`. The `detail` field contains only information safe for the operator to see — no stack traces, no internal file paths, no database schema details. Full error context (stack trace, query, request ID) lives in the structured log record. Operators cross-reference the `request_id` in the error response with the log stream.

### Log level

Production default: `INFO`. Override with the `CLEARSKIES_LOG_LEVEL` environment variable. Acceptable values: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.

Set `DEBUG` only during active incident investigation. At DEBUG level, the service logs at high volume and may include request details that pass through the redaction filter before the filter's regex patterns match.

---

## §6 Health and Readiness

### Health port — separate, loopback-only

The API exposes health, readiness, and metrics endpoints on a dedicated port bound to `127.0.0.1` only. This port is never routed through Caddy to the public internet. Configure with `[health] bind = 127.0.0.1:8081` in `api.conf`.

Default port: 8081. This port is unauthenticated — the loopback binding is the access control. Do not bind it to a public interface without adding proxy authentication in front.

The health port socket follows `rules/coding.md` §1 IPv4/IPv6 dual-stack rules. When configured with `::1` (IPv6 loopback), the socket is IPv6-only. When configured with `127.0.0.1`, it is IPv4-only. For dual-stack loopback, use the hostname `localhost` and let the system resolve both `127.0.0.1` and `::1`.

| Endpoint | Method | Port | Purpose |
|----------|--------|------|---------|
| `/health/live` | GET | 8081 | Liveness probe |
| `/health/ready` | GET | 8081 | Readiness probe |
| `/metrics` | GET | 8081 | Prometheus metrics (opt-in) |
| `/health` | GET | 8765 | Simple main-port canary |

### Liveness

`GET /health/live` returns HTTP 200 whenever the process is alive and responding to HTTP. It performs no external dependency checks. Orchestrators (Docker health checks, systemd `WatchdogSec`) use this to decide whether to restart the container. A liveness failure that persists results in a container restart.

Always returns 200 while the process is up. The process will not return 503 from liveness — if it is alive enough to respond, it returns 200.

### Readiness

`GET /health/ready` checks whether the service is ready to serve real requests. It checks:
- Database connectivity (can establish a connection and run a trivial query)
- Loop subscription state (direct adapter connected to Unix socket, or MQTT adapter connected to broker)
- Capability registry (at least one provider module registered for each enabled domain)

**Response codes and body:**

| `status` value | HTTP code | Meaning |
|---------------|----------|---------|
| `ok` | 200 | All checks pass |
| `degraded` | 200 | One or more non-critical checks failing; core data endpoints functional |
| `unhealthy` | 503 | A critical check failed; service cannot serve requests |

**Response body example (degraded):**
```json
{
  "status": "degraded",
  "checks": {
    "database": {"status": "ok"},
    "loop_subscription": {"status": "ok"},
    "providers": {
      "status": "warning",
      "messages": ["forecast.aeris: quota exhausted"]
    }
  }
}
```

**Degraded returns HTTP 200, not 503.** A single provider failure — quota exhausted, upstream down, key invalid — puts the service in degraded state, not unhealthy. Returning 503 on degraded would cause orchestrators to kill and restart the container, terminating all active SSE connections for all subscribers, for a problem that resolves itself on the next cache refresh. Degraded services still serve weewx archive data and all other providers that are healthy.

### Health probe response body

The `/health/ready` response body provides per-check detail. Orchestrators key on the HTTP status code; the body is for human diagnostics and operator monitoring scripts.

```json
{
  "status": "degraded",
  "checks": {
    "database": {
      "status": "ok",
      "latency_ms": 2
    },
    "loop_subscription": {
      "status": "ok",
      "mode": "direct",
      "socket": "/var/run/weewx-clearskies/loop.sock"
    },
    "providers": {
      "status": "warning",
      "messages": [
        "forecast.aeris: quota exhausted — retry after 2026-06-18T15:00:00Z",
        "aqi.iqair: key invalid — check WEEWX_CLEARSKIES_AQI_IQAIR_KEY"
      ]
    }
  }
}
```

The `checks` object enumerates each dependency by name. Provider failures appear as `warning` within the `providers` check, not as a top-level unhealthy status, because individual provider failures do not prevent the service from serving archive data or other healthy providers.

### Main port canary

`GET /health` on port 8765 returns `{"status": "ok"}` when the service is running and can respond. This is for operators who want a simple reachability check through Caddy without exposing the full readiness state.

---

## §7 Observability

### Logs — always on, zero config

Structured JSON logs (§5) are always available. They require no configuration and no additional infrastructure. Begin all operational investigation here.

### Feature status endpoints — Basemap

`GET /api/v1/basemap/status` carries `last_error` — a `"; "`-joined string naming every tier
(`world`/`local`/`radar`) whose most recent extraction attempt failed, or `null` when the last run
had no failures. A failing tier's previous PMTiles file is left in place (`available` still
reflects what's on disk), so `last_error` is the signal that an extraction needs attention even
when tile serving looks unaffected. Check it after every `POST /setup/basemap/update` and as part
of routine health review once the admin "Basemap" section ships (§4 "Admin landing page").
(CS-BASEMAP, plan `MARINE-AND-MAPS-PLAN-2026-08-27.md` §M1, ADR-078 Amendment 2)

### Prometheus metrics — opt-in

Enable with `CLEARSKIES_METRICS_ENABLED=true` in `secrets.env` or the systemd unit's `Environment=` directive. When enabled, `/metrics` is served on the health port (8081, loopback). Format: Prometheus plain-text exposition format.

An example Prometheus scrape configuration for the API:
```yaml
scrape_configs:
  - job_name: clearskies_api
    static_configs:
      - targets: ['127.0.0.1:8081']
    metrics_path: /metrics
```

This scrapes from loopback. For remote Prometheus instances, use a Prometheus push gateway or SSH tunnel — do not expose port 8081 to the network.

### Required metrics

All of the following must be present when metrics are enabled:

| Metric name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `http_requests_total` | Counter | `method`, `endpoint`, `status` | Total HTTP requests by method, route template, status code |
| `http_request_duration_seconds` | Histogram | `method`, `endpoint` | Request duration; buckets at standard latency points |
| `provider_calls_total` | Counter | `provider_id`, `domain`, `outcome` | Provider calls with outcome: `cache_hit`, `cache_miss_success`, `cache_miss_failure` |
| `provider_call_duration_seconds` | Histogram | `provider_id`, `domain` | Duration of cache-miss provider calls only (excludes cache hits) |
| `cache_hits_total` | Counter | `backend` | Cache hits by backend type (`redis`, `memory`) |
| `cache_misses_total` | Counter | `backend` | Cache misses by backend type |
| `db_query_duration_seconds` | Histogram | `endpoint` | Database query duration per API endpoint |

### Cardinality constraints

Metric labels must never include:
- Request or response bodies
- Operator configuration values
- Client IP addresses or any PII
- Full URLs with query parameters — use route templates only (e.g., `/api/v1/archive`, not `/api/v1/archive?start=2026-01-01&end=2026-06-18`)
- User-agent strings

The `endpoint` label uses the FastAPI route template, not the concrete request path. High-cardinality labels make Prometheus memory usage unbounded and degrade query performance.

### OTel and distributed tracing

OpenTelemetry is deferred to a future phase. v0.1 is a single-process service; distributed tracing provides no value without multiple trace producers.

### CI gating per repo

CI fails the PR (blocks merge) on every check below. No exceptions.

| Gate | api | dashboard | stack |
|------|-----|-----------|-------|
| DCO `Signed-off-by:` on every commit | Yes | Yes | Yes |
| Lockfile present and used (`uv sync --locked` / `npm ci`) | Yes | Yes | N/A |
| `pip-audit` (Python) / `npm audit --audit-level=high` (JS) | Yes | Yes | N/A |
| `gitleaks` secret scan on diff and full tree | Yes | Yes | Yes |
| Ruff linter including `S` (Bandit) security rules | Yes | N/A | N/A |
| ESLint with `no-eval`, `react/no-danger` rules | N/A | Yes | N/A |
| mypy strict / pyright type check | Yes | N/A | N/A |
| TypeScript type check (`tsc --noEmit`) | N/A | Yes | N/A |
| pytest (both MariaDB and SQLite backends) | Yes | N/A | N/A |
| vitest unit tests | N/A | Yes | N/A |
| Playwright end-to-end tests | N/A | Yes | N/A |
| axe-core accessibility scan on built dashboard | N/A | Yes | N/A |
| Third-party GHA actions pinned by SHA | Yes | Yes | Yes |

Manual pre-release verification is in `rules/coding.md` §4 and §5.8.

### Middleware stack

Middleware wraps every API request in this order, outermost to innermost:

| Order | Middleware | Purpose |
|-------|-----------|---------|
| 1 (outermost) | `MetricsMiddleware` | Record request counts and durations before any other processing |
| 2 | `RequestIdMiddleware` | Generate `X-Request-ID` UUID and attach it to request state for structured log records |
| 3 | `BodySizeLimitMiddleware` | Enforce 1 MiB body limit before the body is read into memory |
| 4 | `ProxyAuthMiddleware` | Validate `X-Clearskies-Proxy-Auth` when `WEEWX_CLEARSKIES_PROXY_SECRET` is set |
| 5 | `RateLimitMiddleware` | Enforce 60 req/min per IP; bypassed for proxy-authenticated requests |
| 6 | `CORSMiddleware` | Enforce same-origin or operator-configured-origin CORS policy |
| 7 (innermost) | `SecurityHeadersMiddleware` | Set `X-Content-Type-Options`, `Referrer-Policy`, suppress `Server` header |

The order is not negotiable. `MetricsMiddleware` must be outermost so that metrics capture the full request lifecycle including auth failures. `RequestIdMiddleware` must precede any handler that logs, so all log records carry the request ID.

---

## §8 Updates

### Update command by install path

| Install path | Update command | Post-update step |
|-------------|---------------|-----------------|
| Native pip (API) | `pip install -U weewx-clearskies-api` | `systemctl restart weewx-clearskies-api` |
| Native pip (config UI) | `pip install -U weewx-clearskies-config` | Restart config UI if it is running |
| Docker compose (any component) | `docker compose pull && docker compose up -d` | None — compose handles container replacement |
| Source tarball | Download new archive, unpack, reinstall per `INSTALL.md` | `systemctl restart weewx-clearskies-api` |

Update the same way you installed. If you installed with pip, update with pip. If you installed with compose, update with compose.

No in-app self-update mechanism exists at v0.1. The dashboard does not check for new versions. The API does not poll for updates. There is no auto-update daemon. Operators who want automatic updates configure them at the OS/container level (e.g., Watchtower) — this is documented as the operator's choice, not a recommended default.

### Reading the CHANGELOG before upgrading

Read each component's `CHANGELOG.md` before upgrading. CHANGELOG is the single authoritative source of upgrade-relevant information per release:
- Breaking configuration changes
- New required config fields
- Manual migration steps (if any)
- Schema changes to the weewx archive queries
- Security fixes (noted as information, not a support commitment)

Pre-1.0 minor version bumps (`0.5.x → 0.6.x`) may include breaking changes. CHANGELOG will flag them. Post-1.0, breaking changes are major-version bumps only.

### Cross-repo compatibility

Before mixing component versions — for example, upgrading the API but not the dashboard — check the cross-repo compatibility matrix in `clearskies-stack/README.md`. Not all version combinations are tested. The matrix states which (api version, dashboard version) pairs are known-compatible.

### No support windows

Clear Skies is distributed AS-IS under GPL v3. There are no LTS branches, no security-backport commitments for prior releases, no end-of-life schedules, and no support-window promises of any kind. A CHANGELOG entry that says "this release contains a security fix" is information, not a commitment that the prior release will also be patched.

Stay current or accept the risk of running an older release. This posture is non-negotiable — it is built into the license and architectural design.

### Config preservation across upgrades

**Native (pip) path.** Config lives at `/etc/weewx-clearskies/`, outside the Python package directory tree. `pip install -U` writes only to `site-packages/`. Config is untouched automatically.

**Docker compose path.** The stack compose file bind-mounts the host's `/etc/weewx-clearskies/` directory into each container. `docker compose pull` swaps the image layer; the bind-mounted config directory is unchanged. Operators who build custom compose files without the bind-mount will lose config when the container is recreated — this is documented as a loud warning in `clearskies-stack/INSTALL.md`.

**Schema drift.** When a new release requires a new config field, the code defaults the missing field gracefully where feasible, allowing older configs to load. When graceful defaulting is not possible, CHANGELOG states the manual edit required before upgrading. Config-file schema changes are always CHANGELOG-flagged — never silent.

---

## §9 Performance Budget

### API latency targets (p95)

These targets apply to the local development environment with realistic data volumes. Production performance depends on operator hardware, database size, and network conditions — we do not promise these numbers in production deployments.

| Endpoint class | p95 target | Measurement method |
|---------------|-----------|-------------------|
| Archive read (current / today / recent observations) | < 100 ms | pytest-benchmark against SQLite fixture |
| Archive aggregation (chart queries, windowed aggregates) | < 500 ms | pytest-benchmark against representative archive |
| Provider response — cache hit | < 50 ms | pytest-benchmark with mocked cache backend |
| Provider response — cache miss | Bounded by upstream provider response time + retry policy | Not benchmarked locally; monitor in production via metrics |

### Dashboard performance targets

| Metric | Target |
|--------|--------|
| Lighthouse Performance score (Now / Forecast / Charts / Records pages) | ≥ 90 |
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |
| Initial JS bundle — Now-page route (gzipped) | ≤ 200 KB |

### Targets, not gates

Missed targets are bugs to investigate and backlog items to file — they do not block a release.

When a release misses a target:
1. Record the actual measured values in `docs/audits/<release>.md`.
2. Note the cause (e.g., "new chart type added to Now page pushed bundle to 230 KB gzipped").
3. File a backlog issue if the cause is addressable.
4. Ship the release.

Accessibility failures are different — they are release-blocking per their own ADR because they determine whether a class of visitors can use the dashboard at all. Performance misses are quality signals, not usability gates.

---

## §10 Security Model

### Threat model

The API is a gateway to data, not a door into the host. A vulnerability exploited through the API must not grant an attacker filesystem access, the ability to modify weewx configuration, or lateral movement to other services on the host.

Trust boundaries:
```
Internet
  → Caddy on front-end host
      TLS termination, security headers, rate limiting, path filtering
    → [LAN or Docker internal network]
      → API on weewx host
          loopback or LAN bind, ProxyAuth, input validation, query limits, read-only DB
        → weewx (read-only: weewx.units import only — never engine, never drivers)
        → weewx DB (SELECT grants only — startup write probe enforced)
        → External providers (outbound HTTPS — keys held server-side)
```

Caddy is the only internet-facing component. The API is never directly internet-accessible. Each layer enforces its own constraints — defence in depth.

### Rate limiting

Default: 60 requests per minute per client IP on all API paths. Requests exceeding this limit receive HTTP 429 with a `Retry-After` header. Rate-limit state is stored in Redis when `CLEARSKIES_CACHE_URL` is set; in-process otherwise.

**Multi-worker warning.** In-process rate-limit state is per-worker. A multi-worker deployment without Redis delivers N times the documented rate limit across N workers. Multi-worker deployments must configure Redis.

Rate limiting is bypassed for requests that carry a valid `X-Clearskies-Proxy-Auth` header. This allows Caddy to make high-frequency internal health and SSE requests without hitting the limit.

Rate limiting applies to `GET /sse` connections like any other path. An IP that opens 60+ SSE connections in a minute is rate-limited.

### CORS policy

Default: same-origin. The operator may add one additional dashboard origin via `[api] cors_origins` in `api.conf` (comma-separated list). Never use wildcard `*` — it defeats the same-origin policy enforced by Caddy's security headers and exposes the API to cross-site request abuse. CORSMiddleware is in the middleware stack (see §7) and processes every request.

### Input validation

Every HTTP endpoint uses Pydantic models with `extra="forbid"` wired via FastAPI `Depends()`. Undeclared query parameters are rejected with HTTP 422. Undeclared body fields are rejected with HTTP 422. There are no unvalidated inputs to the API. Provider wire responses are also validated by per-provider Pydantic models — malformed provider responses raise `ProviderProtocolError`, not silent data corruption.

### Body size limit

Maximum request body: 1 MiB. Requests exceeding this are rejected with HTTP 413 before the body is read into memory. Configurable via `[api] max_request_bytes` for paths with legitimately larger payloads.

### Database access

The API connects with a read-only database user:
- SQLite: connection URI includes `?mode=ro`
- MariaDB: `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'` — no INSERT, UPDATE, DELETE, or DDL

At startup, the API attempts a sentinel `INSERT` against the database. If the insert succeeds (meaning the connection has write access), the service logs CRITICAL and exits non-zero. A writable database connection is a fatal startup error — the service refuses to run.

All queries use SQLAlchemy 2.x parameterized statements: typed `select()` expressions and Core constructs only. F-string SQL and string concatenation in query construction are banned by `rules/coding.md` §1 and enforced by ruff linting in CI.

### Archive query cap

Raw archive queries are capped at 366 days. A time range exceeding this returns HTTP 400 with a clear error message. This prevents expensive full-archive scans from being triggered by a single request.

Database query timeout: 30 seconds on all backends.
- SQLite: `connect_args={"timeout": 30}`
- MariaDB: `read_timeout=30, write_timeout=30` on engine creation

### TLS

TLS is mandatory on the API main port (8765). Default: Ed25519 self-signed certificate, auto-generated at first start. Stored at `/etc/weewx-clearskies/api-cert.pem` and `api-key.pem` (mode 0600).

Caddy uses this certificate for the Caddy→API internal TLS connection. Browsers never see this certificate — the Caddy→browser TLS uses Caddy's auto-issued Let's Encrypt certificate.

In Caddyfile, use `tls_verify = false` or `tls { ca_pool <path-to-api-cert.pem> }` for the API upstream. Do not disable TLS on the API port. Do not configure the API for HTTP-only in production.

### SSE security controls

| Control | Value | Enforcement |
|---------|-------|------------|
| Max concurrent SSE subscribers | 500 | `SSEEmitter._MAX_SUBSCRIBERS` — returns 503 when exceeded |
| Per-subscriber queue maxsize | 64 messages | Slow consumers are ejected when their queue overflows |
| SSE keepalive | Every 15 seconds, SSE comment line | Prevents proxy/firewall idle timeout killing long-lived connections |
| Rate limit on SSE connection establishment | 60/min/IP (same as all paths) | `RateLimitMiddleware` applies to `GET /sse` |

### X-Forwarded-For trusted proxy restriction

`X-Forwarded-For` is honoured only when the direct TCP peer is listed in `_TRUSTED_PROXIES`. Default trusted proxies: `127.0.0.1`, `::1`. XFF headers from non-trusted peers are ignored — the direct peer IP is used as the client address for rate limiting and logging. This prevents rate-limit bypass by spoofing XFF from an untrusted IP.

### systemd hardening (mandatory for production native installs)

All of the following flags must be present in the `weewx-clearskies-api.service` unit file. The command `systemd-analyze security weewx-clearskies-api` must return an exposure score ≤ 3.0.

| Flag | Value | Rationale |
|------|-------|-----------|
| `User` | `clearskies` | Dedicated service user, no sudo |
| `NoNewPrivileges` | `yes` | Prevents privilege escalation via setuid |
| `ProtectSystem` | `strict` | OS and package dirs read-only |
| `ProtectHome` | `yes` | Home directories inaccessible |
| `PrivateTmp` | `yes` | Private `/tmp` namespace |
| `ProtectKernelTunables` | `yes` | `/proc/sys` and sysfs kernel parameters inaccessible |
| `ProtectKernelModules` | `yes` | Module loading blocked |
| `ProtectControlGroups` | `yes` | cgroups hierarchy read-only |
| `RestrictAddressFamilies` | `AF_INET AF_INET6 AF_UNIX` | Only TCP/IP and Unix sockets |
| `RestrictNamespaces` | `yes` | Namespace operations blocked |
| `LockPersonality` | `yes` | Execution domain locked |
| `CapabilityBoundingSet` | (empty string) | All capabilities dropped |
| `AmbientCapabilities` | (empty string) | No ambient capabilities |
| `SystemCallFilter` | `@system-service` | Restricts to normal service syscalls |
| `SystemCallErrorNumber` | `EPERM` | Filtered syscalls return EPERM, not SIGKILL |
| `ReadWritePaths` | Config dir and data dirs only | No log dir — logs go to stdout |

Note: `MemoryDenyWriteExecute` is excluded. Python requires writable + executable memory pages for its JIT and code compilation.

### Docker hardening

| Control | Compose directive | Required value |
|---------|-----------------|---------------|
| Runtime user | `user:` | `clearskies` (explicit UID, non-root) |
| Capability drop | `cap_drop:` | `[ALL]` |
| Capability add | `cap_add:` | (empty — no capabilities added back) |
| Root filesystem | `read_only:` | `true` |
| `/tmp` | `tmpfs:` | Mount as tmpfs |
| no-new-privileges | `security_opt:` | `[no-new-privileges:true]` |
| Privileged mode | `privileged:` | `false` (never set true) |
| Host network | `network_mode:` | Never `host` |

All containers run these controls. The dashboard init container is exempt from `read_only` (it writes `dist/` to a volume) but still runs non-root with no capabilities.

### Dedicated service user

All runtime services run under the `clearskies` system user. This user has:
- No login shell (`/usr/sbin/nologin`)
- No home directory
- No sudo access
- No membership in any privileged group except `weewx-ro` (DB read) and `weewx` (socket access)
- No access to `/etc/shadow` or other privileged system files — verify access denied on direct read attempt after install

Create with: `useradd --system --no-create-home --shell /usr/sbin/nologin clearskies`

### Dependency scanning

| Repo | Command | Frequency |
|------|---------|----------|
| Python repos (api, stack) | `pip-audit` against `uv export --format requirements-txt` output | Every PR + nightly schedule |
| JavaScript (dashboard) | `npm audit --audit-level=high` | Every PR + nightly schedule |
| All repos | `gitleaks` on diff + full tree | Every PR + pre-commit hook |
| All repos | Third-party GHA actions pinned by SHA (not tag) | Reviewed on every dependency update PR |

CI fails the PR on any new high-severity advisory or detected secret leak.

### Dashboard security controls

| Control | Enforcement |
|---------|------------|
| No `eval` / `Function` / `innerHTML` with untrusted data | ESLint `no-eval`, `no-implied-eval`, `no-new-func`, `react/no-danger` — CI fails on violation |
| Zero external scripts in built bundle | `index.html` post-build inspection in CI |
| SRI required if external script ever added | Reviewer enforces `integrity=` + `crossorigin=` on any future external `<script>` |
| Markdown content sanitization | `react-markdown` with default sanitizers; raw HTML pass-through disabled; unit test proves `<script>` tags are rendered as text |
| Output escaping in JSX | React default escaping; `dangerouslySetInnerHTML` banned except in the one allowlisted sanitized-markdown component |
| CSP | Set by Caddy (§3), not the dashboard |
| `npm audit --audit-level=high` clean | CI gate, every PR |
| `package-lock.json` in CI | `npm ci` (not `npm install`); lockfile committed to repo |

---

## §11 Filesystem Permissions

### Runtime process model

Every runtime process runs under a dedicated system user with no login shell, no sudo access, and exactly the filesystem access it needs.

| Process | User | Group | Supplementary groups | Purpose |
|---------|------|-------|---------------------|---------|
| API | `clearskies` | `clearskies` | `weewx-ro` (DB read), `weewx` (socket access) | REST endpoints, SSE, provider calls, unit conversion |
| Config UI | `clearskies` | `clearskies` | — | Setup wizard and admin config management |
| Caddy | `caddy` | `caddy` | — | Reverse proxy, TLS, static file server |
| Redis | `redis` | `redis` | — | Provider response cache |
| Dashboard build | deploy user | — | — | Build-time only — not a runtime process |
| weewx + loop relay | `weewx` | `weewx` | — | Unchanged — Clear Skies does not modify weewx's process model |

**`ubuntu` at runtime: NO.** The `ubuntu` user (or any general deploy user) handles deploy-time operations only: `git pull`, `npm run build`, `rsync`, `systemctl restart` via sudo. No runtime service runs as `ubuntu`. In Docker, deploy operations are handled by image build — no deploy user is present at runtime.

### Config directory permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/etc/weewx-clearskies/` (dir) | `clearskies:clearskies` | 0750 | API, Config UI | Config UI | Directory root. Caddy reads specific files via 0644 world-read on those files. |
| `api.conf` | `clearskies:clearskies` | 0640 | API, Config UI | Config UI (wizard apply) | No secrets — secret-leak guard enforced at startup. |
| `charts.conf` | `clearskies:clearskies` | 0640 | API | Config UI, migration tool | Chart definitions. |
| `stack.conf` | `clearskies:clearskies` | 0640 | Config UI | Config UI | Wizard/UI state. |
| `marine-photos.json` | `clearskies:clearskies` | 0640 | Config UI | Config UI | Local-only marine photo metadata (`photo_url`, `photo_attribution`). Never sent to the API; not Caddy-served. |
| `secrets.env` | `clearskies:clearskies` | **0600** | API (`EnvironmentFile=`), Config UI | Config UI (wizard apply) | **Most restricted file.** DB passwords, API keys, proxy secret. Caddy never reads this. |
| `branding.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser), API | Config UI (wizard apply) | World-readable — Caddy serves it directly. No secrets. |
| `webcam.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser) | Config UI (wizard apply) | World-readable. No secrets. |
| `api-cert.pem` | `clearskies:clearskies` | 0644 | Caddy (upstream TLS verification) | API (auto-generated at first start) | API self-signed TLS cert. Caddy trusts this cert for the internal Caddy→API connection. |
| `api-key.pem` | `clearskies:clearskies` | **0600** | API only | API (auto-generated) | API TLS private key. Owner-read only. |
| `ui-cert.pem` | `clearskies:clearskies` | 0644 | Config UI | Config UI (auto-generated when `--tls` active) | Config UI self-signed cert. |
| `ui-key.pem` | `clearskies:clearskies` | **0600** | Config UI only | Config UI (auto-generated) | Config UI TLS private key. |

### Web root permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/var/www/clearskies/` (dir) | `caddy:caddy` | 0755 | Caddy | Deploy script (rsync, then chown) | SPA root. Wiped by `rsync --delete` on every dashboard deploy. |
| `/var/www/clearskies/*` (files) | `caddy:caddy` | 0644 | Caddy, browsers | Deploy script | Static HTML/CSS/JS. World-readable (served directly to browsers). |
| `/var/www/clearskies/webcam/` | read-only mount | — | Caddy | External capture process on weewx host | LXD disk device or bind mount. Read-only inside the serving container. Never written by Clear Skies itself. |

### Runtime directory permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/var/run/weewx-clearskies/` | `clearskies:weewx` | **0770** | API | weewx extension (loop relay) | Group `weewx` with group-write so the weewx extension can create the socket file inside. |
| `/var/run/weewx-clearskies/loop.sock` | `weewx:weewx` | **0660** | API (connects as client) | weewx extension (runs socket server) | Created by the loop relay at weewx startup. API connects as client via `weewx` group membership. |
| `/tmp` (in container) | — | tmpfs | API | API | Mounted as tmpfs in Docker. `PrivateTmp=yes` on bare-metal native installs. |

**Socket directory is 0770, not 0777.** Only `clearskies` and `weewx` group members may enter the directory. This prevents other local processes from enumerating or connecting to the socket.

### Caddy-specific permissions

| Path | Owner | Mode | Notes |
|------|-------|------|-------|
| Caddyfile | `caddy:caddy` | 0644 | Generated by the wizard TLS configuration step. |
| ACME cert storage (`/data/caddy/` or `.caddy/`) | `caddy:caddy` | 0700 | Caddy's internal certificate storage for Let's Encrypt certs. No other process reads this directory. |

### Loop relay (weewx extension) connection limit

The loop relay (`ClearSkiesLoopRelay`, part of `weewx-clearskies-extension`) runs inside the weewx process as the `weewx` user. It enforces a maximum of **8 concurrent client connections** in its accept loop. A 9th connection is rejected immediately with a log warning. This limit prevents the relay from becoming a denial-of-service amplifier against the weewx engine process.

No application-level authentication on the socket. Filesystem permissions (0660, `weewx:weewx`) are the access control. Non-group processes receive `EACCES`. The `clearskies` user accesses the socket by virtue of its `weewx` group membership.

### weewx files — read access only

| Path | Access by `clearskies` | How |
|------|----------------------|-----|
| weewx DB (SQLite `.sdb`) | Read-only | `clearskies` in `weewx-ro` group; file is group-readable |
| weewx DB (MariaDB) | Read-only | `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'` |
| `weewx.conf` | Read-only | World-readable (0644); parsed for station metadata |
| weewx Python packages | Read-only | `sys.path` addition via `.pth` file; only `weewx.units` imported |

Clear Skies never writes to any weewx file. Clear Skies never modifies `weewx.conf`. The weewx engine runs exactly as it did before Clear Skies was installed.

---

## §12 Anti-Patterns

**Never expose the API directly to the internet.** The API must sit behind the reverse proxy. Port 8765 bound to `0.0.0.0` and published to the internet removes the security headers layer, the path-filtering layer, the HSTS and CSP layer, and the single TLS termination point that Caddy provides. This is a deployment error, not a supported configuration.

**Never run any service as `ubuntu` or any sudo-capable user.** Runtime services run as `clearskies`, `caddy`, `redis`, and `weewx`. Using a general-purpose user with sudo at runtime means a single exploited service can write to arbitrary files, execute arbitrary commands, and read `secrets.env` — destroying the entire trust model.

**Never store secrets in `.conf` files.** API keys, database passwords, the proxy shared secret, and admin credential hashes all belong in `secrets.env` (mode 0600). The secret-leak guard at startup catches the common case (`_KEY`, `_SECRET`, `_TOKEN`, `_PASSWORD` key suffixes), but do not rely on the guard as a substitute for correct placement from the start. The guard is defence-in-depth against accidents, not a policy tool.

**Never skip the startup write probe on the database.** The write probe is the enforcement mechanism that guarantees the API cannot modify weewx data. If the probe succeeds (write access exists), the service exits non-zero. Bypassing or disabling the probe removes this guarantee with no compensating control — a bug in the API could silently corrupt the weewx archive.

**Never bind the API to a non-loopback address without setting the proxy shared secret.** Cross-host deployments must set `WEEWX_CLEARSKIES_PROXY_SECRET` on both hosts. Binding to a LAN address without the secret means any host that can reach port 8765 can call provider-enriched endpoints, enumerate station capabilities, and trigger outbound provider API calls — bypassing all Caddy-layer controls.

**Never use `--no-verify` or bypass TLS verification for the Caddy→API connection in production.** In the Caddyfile, use `tls { ca_pool /etc/weewx-clearskies/api-cert.pem }` to trust the API's self-signed certificate specifically. Setting `tls_verify = false` is acceptable for the same-host case where Caddy and the API are on the same Docker network or loopback, but is not acceptable for cross-host deployments where the network between Caddy and the API is not fully trusted.

**Never place `branding.json` or `webcam.json` in the web root (`/var/www/clearskies/`).** Dashboard deploys use `rsync --delete`, which removes every file in the web root that is not present in the `dist/` build output. Both files belong in `/etc/weewx-clearskies/` and are served by a dedicated Caddy `handle` block. Any operator who moves them to the web root will lose them on the next dashboard deploy.

**Never use `eval`, `exec`, `pickle.loads` on untrusted input, `subprocess(shell=True)` with user-controlled data, or `yaml.load` without the `SafeLoader`.** These are banned in `rules/coding.md` §1 and enforced by ruff's `S` (Bandit) ruleset in CI. A PR that introduces any of these fails CI regardless of test coverage.

**Never commit secrets to source or git history.** Use `.env` files (gitignored) or environment variable injection. `gitleaks` runs as a pre-commit hook and in CI on every PR. A detected secret in the diff or full tree fails CI immediately. If a secret is committed accidentally, treat the secret as compromised — rotate it, do not merely rewrite history.

**Never run the config UI as a long-lived daemon.** The config UI is an on-demand tool. Start it to make configuration changes. Stop it when done. Leaving it running permanently on port 9876 expands the attack surface of the configuration management interface unnecessarily. Normal ongoing access is via the reverse proxy at `/admin` — the standalone port 9876 listener is for first-run bootstrap and emergency access only.

---

## Appendix: Source ADR Index

The controls in this manual trace to the following ADRs. When this manual and an ADR conflict on the same point, investigate — one of them is stale, and this manual is updated first.

| Section | Source ADRs |
|---------|------------|
| §1 Deployment | ADR-001, ADR-034, ADR-039, ADR-058 |
| §2 Authentication | ADR-008, ADR-027 |
| §3 Network Architecture | ADR-037, ADR-060 |
| §4 Configuration | ADR-027, ADR-038a, ADR-066, ADR-068 |
| §4.1 Config Registry | ADR-077 |
| §5 Logging | ADR-029 |
| §6 Health and Readiness | ADR-030 |
| §7 Observability | ADR-031 |
| §8 Updates | ADR-003, ADR-018, ADR-028, ADR-032 |
| §9 Performance Budget | ADR-033 |
| §10 Security Model | ADR-008, ADR-012, ADR-027, ADR-029, ADR-030, ADR-037, ADR-060; `rules/coding.md` §1 |
| §11 Filesystem Permissions | ADR-061 |
| §12 Anti-Patterns | ADR-008, ADR-012, ADR-027, ADR-037, ADR-061; `rules/coding.md` §1 |

ADR index: [docs/decisions/INDEX.md](../decisions/INDEX.md)
