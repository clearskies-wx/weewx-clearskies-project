# reference/clearskies-dev.md — Clear Skies Development Environment

Load alongside [rules/clearskies-process.md](../rules/clearskies-process.md) when doing Clear Skies implementation work.

## Deployment architecture (ADR-034, ADR-027, ADR-038)

### Two topologies

| Topology | API runs… | Config UI + realtime + dashboard run… | Wizard detects via… |
|---|---|---|---|
| **Same-host** (default) | On the weewx host | On the weewx host | DB host is loopback |
| **Cross-host** | On the weewx host (where the DB is) | On a separate host | DB host is non-loopback |

**The API ALWAYS co-locates with weewx.** The API reads the weewx archive DB and `weewx.conf` locally. It does not belong on any other host. If the operator's dashboard is on a different machine, the API still stays with weewx.

### Wizard → API communication (ADR-038)

The wizard talks to the **API**, not the database. Flow:

1. Operator installs API on weewx host. API generates TLS cert + trust token on first start.
2. Operator opens wizard on the dashboard host. Step 1: enters API address + trust token + fingerprint.
3. Wizard connects to API over TLS. All DB operations go through the API.
4. On Apply: wizard POSTs config payload to `POST /setup/apply` → **API writes its own `api.conf` and `secrets.env`** (DB creds, provider keys). Wizard writes LOCAL files only (`realtime.conf`, `stack.conf`, local `secrets.env` with proxy secret + MQTT password).
5. Wizard triggers restarts: API via `POST /setup/restart`, realtime locally.

**The wizard does NOT write `api.conf`.** The API writes its own config after receiving the Apply payload. This is by design (ADR-038).

### What goes where

| File | Written by | Lives on | Contains |
|---|---|---|---|
| `api.conf` | API (via `/setup/apply`) | weewx host | DB connection, station metadata, providers, bind address |
| `realtime.conf` | Wizard config_writer | Dashboard host | SSE bind address, MQTT settings (password as env var ref) |
| `stack.conf` | Wizard config_writer | Dashboard host | UI settings, station display info, topology |
| `secrets.env` (API side) | API (via `/setup/apply`) | weewx host | DB password, provider API keys, proxy secret |
| `secrets.env` (local side) | Wizard config_writer | Dashboard host | Proxy secret, MQTT password |

### Topology auto-detection (routes.py lines 823–836)

```
DB host is loopback → same-host → api_bind_host = 127.0.0.1, realtime_bind_host = 127.0.0.1
DB host is remote   → cross-host → api_bind_host = 0.0.0.0, realtime_bind_host = 0.0.0.0, generate proxy_secret
```

**Bind-address note:** `::` is IPv6-only in both modern MariaDB (`my.cnf` `bind-address`) and uvicorn (sets `IPV6_V6ONLY=1`). Use `*` for MariaDB `bind-address` and `0.0.0.0` for service `bind_host` when you need all interfaces. The wizard was previously emitting `::` for cross-host topology; this was corrected in `87f8467`.

### Pipeline auto-detection (routes.py lines 951–988)

```
API address is loopback → direct mode (no MQTT needed, same machine)
API address is remote   → MQTT mode (broker bridges loop packets between hosts)
```

### Our test infrastructure = cross-host topology

| Host | IP | Role | Services |
|---|---|---|---|
| **weewx** (LXD container) | `weewx.shaneburkhardt.com` (VLAN2, dual-stack) | weewx + API | weewx, weewx-clearskies-api (port 8765 TLS), Redis (port 6379 loopback) |
| **weather-dev** (LXD container) | 192.168.2.113 | Dashboard + config host | weewx-clearskies-config (9876), dashboard static files, Caddy (ports 80/443) |

### One-door reverse proxy (ADR-037)

All public traffic goes through ONE web server. Browser uses relative URLs (`/api/v1/...`, `/sse`). Inner services bind to loopback, never publicly exposed. The proxy routes:

| Browser path | Proxied to |
|---|---|
| `/` (SPA) | Static dashboard files |
| `/api/v1/*` | clearskies-api on weewx host (port 8765 TLS) |
| `/sse` | clearskies-api on weewx host (port 8765 TLS) — SSE merged into API per ADR-058 |

For docker-compose: Caddy is the proxy (bundled, automatic, zero-config).
For native install: operator's existing web server (Apache/nginx/Caddy). Project ships example configs.

CORS is a non-issue by design — everything is same-origin through the proxy.

### Production docker-compose (ADR-034)

The production `docker-compose.yml` (Caddy + api + dashboard) is in the stack repo root. `docker compose up` yields a working stack with auto-LE TLS. The dev/test compose (MariaDB + seed data) remains at `dev/docker-compose.yml`. The realtime service was merged into the API per ADR-058.

**There should be NO clearskies-api running on weather-dev.** The API belongs on the weewx host (where the DB and weewx.conf live).

## Two-machine split

| Machine | Role | What runs here |
|---|---|---|
| **DILBERT** (Windows workstation) | Editing, git, planning, orchestration | VS Code, Claude Code, `git push`, brief-drafting |
| **weather-dev** (LXD container on ratbert) | Runtime, tests, builds | `pytest`, `uv`, `docker compose`, `npm`, `vite` |

Do NOT run pytest, uv, docker, or node toolchains on DILBERT. Do NOT edit source files on weather-dev (except test-author fixture captures, which are committed from weather-dev directly).

## Repo paths

### DILBERT (local clones)

All repos live under the meta repo:

```
c:\CODE\weather-belchertown\repos\
  weewx-clearskies-api\                # default branch: main
  weewx-clearskies-realtime\           # default branch: main
  weewx-clearskies-dashboard\          # default branch: main
  weewx-clearskies-stack\              # default branch: main
  weewx-clearskies-design-tokens\      # default branch: main
  weewx-clearskies-swan-swelltrack\    # default branch: master — standalone SWAN + SwellTrack service (librewxr)
```

Meta repo (`c:\CODE\weather-belchertown\`) default branch: **master**.

### weather-dev (runtime clones)

```
/home/ubuntu/repos/
  weewx-clearskies-api/
  weewx-clearskies-realtime/
  weewx-clearskies-dashboard/
  weewx-clearskies-stack/
  weewx-clearskies-design-tokens/
```

Owner: `ubuntu`. Container IP: `192.168.2.113` (DHCP/SLAAC on `br-vlan2`).

### librewxr (compute host) — **this is where SWAN runs**

```
/home/ubuntu/repos/
  weewx-clearskies-api/                # API repo — provides the venv BOTH services run from,
                                       # and the compute service's own code
  weewx-clearskies-swan-swelltrack/    # SWAN standalone service package
```

Owner: `ubuntu`. Host IP: `192.168.7.22`. SSH: `ssh -F .local/ssh/config librewxr`.

**SWAN is split out of the API. It does not run on the weewx host and it does not run on
weather-dev.** Verified running on librewxr 2026-07-25:

| systemd unit | Port | ExecStart module | What it computes |
|---|---|---|---|
| `weewx-clearskies-swan.service` | 8767 | `weewx_clearskies_swan` | SWAN 3-level nested grid |
| `weewx-clearskies-compute.service` | 8770 | `weewx_clearskies_api.services.compute_service` | SwellTrack + SurfBeat strip |

Both run from the **same interpreter**:
`/home/ubuntu/repos/weewx-clearskies-api/.venv/bin/python`. The SWAN binary is at
`/usr/local/bin/swan`. Both load `/etc/weewx-clearskies/secrets.env`, and the SWAN unit reads
`/etc/weewx-clearskies/api.conf`.

Two consequences that catch people out:

- The **compute service is API-repo code running on librewxr.** A change to
  `weewx_clearskies_api/services/` that the compute service imports takes effect on librewxr,
  not on the weewx host. Test it there.
- Because both services run from the API repo's venv, **the API repo checkout on librewxr is
  the one that matters for any SWAN, SwellTrack, SurfBeat, or surf-endpoint change.**

### librewxr resource budget — `omp_num_threads = 6` is an operator decision

`/etc/weewx-clearskies/api.conf` → `[swan] omp_num_threads = 6`. **Six. Not 16, not 0.**
This is an operator ruling, not a tuning knob. Do not change it without asking.

Why it matters: the SWAN binary is OpenMP (`ldd /usr/local/bin/swan` → `libgomp.so.1`) and
allocates private work arrays *per thread*, so the thread count multiplies its resident set,
not just its core usage. Measured on the same 81×71 L2 grid:

| `omp_num_threads` | SWAN RSS | L2 wall-clock, quiet box |
|---|---|---|
| 16 | 627 MB peak, **179 MB into swap** | 6m51s – 7m57s |
| 6 | **87 MB**, no swap | 9m40s |

Six threads is *slower* in isolation. That is the accepted trade: the box has 5.7 GB total
with the radar container (`librewxr.main`) holding ~3.2 GB resident, leaving ~1.7 GB. At 16
threads SWAN only just fit, and on 2026-07-25 08:37 UTC — when the compute service was
simultaneously working through a batch at 519 MB RSS — it stopped fitting and **L2 took
50m32s instead of 7m**. Both conditions were necessary; 16 threads alone ran fine for days.

`api.conf` is **not in git** — it is deployed state only, so nothing detects drift in it.
It drifted once already: `docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md:382` records
`omp_num_threads=6→16 now visible`, when renaming the dead `[trushore]` section to `[swan]`
made the key live and it was written as 16. Check the live value before trusting any
runtime measurement from this host:

```bash
ssh -F .local/ssh/config librewxr "grep -A1 '^\[swan\]' /etc/weewx-clearskies/api.conf"
```

## SSH access

Direct SSH from DILBERT using the project SSH config at `.local/ssh/config`. Always use `-F .local/ssh/config`.

```bash
# Direct SSH to weather-dev
ssh -F .local/ssh/config weather-dev "<command>"

# Direct SSH to weewx
ssh -F .local/ssh/config weewx "<command>"

# Ratbert host (LXD management only — NOT for accessing weewx or weather-dev)
ssh -F .local/ssh/config ratbert "<command>"
```

**Do NOT go through ratbert with `lxc exec` to reach weewx or weather-dev.** Direct SSH is configured and works. The only container that still requires `lxc exec` through ratbert is `cloud` (legacy Belchertown, no direct SSH).

Keys and config live in `.local/ssh/` (project directory, replicates via Nextcloud). NOT in `~/.ssh/`.

## Deploy scripts

All three scripts live in `scripts/`. Always use them — never run manual `git pull`, `npm build`, `rsync`, `systemctl restart`, or `chown`/`chmod` on containers. See CLAUDE.md "Filesystem permissions on containers" for why.

### Dashboard + config UI → weather-dev

```bash
# Full redeploy: pull + restart config UI + build dashboard + publish dist/
scripts/redeploy-weather-dev.sh

# Source-only refresh (no build, no restart):
scripts/sync-to-weather-dev.sh

# Pull one repo only:
scripts/sync-to-weather-dev.sh weewx-clearskies-dashboard
```

### API → weewx

```bash
# Full deploy: pull + restart API + wait for cache warmer + health verify
scripts/deploy-api.sh

# Pull only (no restart — e.g., docstring-only change):
scripts/deploy-api.sh --no-restart

# Restart only (already pulled):
scripts/deploy-api.sh --skip-pull
```

The API cache warmer takes ~2 minutes. `deploy-api.sh` waits 130 seconds after restart before checking the health endpoint. Do not hit API endpoints during the warm-up — you will get connection refused.

## Toolchain on weather-dev

- **Python:** 3.12
- **Package manager:** uv
- **Test runner:** pytest (via uv)
- **Node:** 22 LTS
- **Docker:** Engine 29.4 + Compose v5

## Common commands

### Which host runs which tests — check this before running anything

There is **no maintained API-repo checkout on weather-dev.** `sync-to-weather-dev.sh`
deliberately refuses the API repo (`Unknown repo 'weewx-clearskies-api'`) because the API
belongs with weewx. A stale, unmanaged clone exists there — **do not use it, and do not
report a result from it.** It was last seen at `ba3af8f`, unrelated to any current branch.

| Change touches… | Run its **tests** on | Runs in **production** on |
|---|---|---|
| SWAN, SwellTrack, SurfBeat, surf endpoint, beach profile, marine providers | **librewxr** — where the code actually runs | **librewxr** — SWAN service 8767, compute service 8770 |
| Condition modules (haze, calibration, sky, fog), archive/DB, general API | **weewx** | weewx — API installed natively, reads the weewx archive |
| Dashboard, config UI | **weather-dev** | weather-dev — dashboard build + Caddy |

**Test SWAN/surf code on the host it runs on — librewxr.** Testing it on weewx measures a
host that does not execute that code in production.

**Corrected 2026-07-25.** This table previously read "run its tests on **weewx** (librewxr has
no test deps)" for the SWAN/surf row, and the section below asserted librewxr "cannot run
tests." That was true only before SWAN was split out onto librewxr, and the doc was never
updated. It cost a session: an agent followed it, deployed SWAN changes to weewx — a host
that does not run SWAN at all — and ran the test suite there. `pytest`, `pytest-asyncio` and
`pytest-timeout` were installed into librewxr's venv on 2026-07-25, so the stated blocker no
longer exists either.

### Deploy before you test — a container test proves nothing about an unpushed edit

Every deploy path pulls **from GitHub**. Local commits are invisible to every container until
pushed. A pytest run on a container whose checkout predates your commit is measuring old code,
and reporting it as verification is a false-clean result.

```bash
# Get the code onto weewx WITHOUT restarting the service (safe mid-phase):
scripts/deploy-api.sh --no-restart
```

### Run pytest on the host that runs the code

- **SWAN, SwellTrack, SurfBeat, surf endpoint, beach profile, marine providers → `librewxr`.**
  `pytest`, `pytest-asyncio` and `pytest-timeout` are installed in
  `/home/ubuntu/repos/weewx-clearskies-api/.venv` (added 2026-07-25).
- **Everything else (conditions, archive/DB, general API) → `weewx`.**

```bash
# SWAN / surf tests — on librewxr, using the venv python directly:
ssh -F .local/ssh/config librewxr "sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-api/.venv/bin/python -m pytest /home/ubuntu/repos/weewx-clearskies-api/tests/services/test_swan_runner.py -q"
```

**Never run pytest on librewxr while a SWAN cycle is in progress.** A full cycle is 15–30
minutes and the box has ~1.7 GB free after the radar container's 3.2 GB. Test load during a
run competes for memory with SWAN and both distorts the run's wall-clock and risks pushing it
into swap. Check first:
`ssh -F .local/ssh/config librewxr "systemctl is-active weewx-clearskies-swan; pgrep -x swan"`

Three things all container test runs need, or they fail in confusing ways:

1. **`sudo -u ubuntu bash -c '...'`** — wrapping the whole command, not just prefixing `uv`.
   The `claude` SSH user cannot even `cd` into `/home/ubuntu/repos/`
   (`Permission denied`), so the `cd` has to be inside the `ubuntu` shell.
2. **`--frozen`** — without it `uv` tries to rewrite `uv.lock` and dies with
   `Permission denied (os error 13)`.
3. **The full path to `uv`** — it is not on `PATH` over non-interactive SSH.

```bash
# Specific files (preferred — never run the full suite, see clearskies-process.md):
ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && /home/ubuntu/.local/bin/uv run --frozen pytest tests/test_wave_transform.py -q'"

# A whole directory, when you want to catch test files nobody has been running:
ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && /home/ubuntu/.local/bin/uv run --frozen pytest tests/services/ -q --tb=no'"
```

**Run the directory, not only the files an agent named.** On 2026-07-25 the targeted files all
passed while `tests/services/test_swan_runner.py` had 15 collection errors that had been there
for many commits, because nobody ran that file. A per-file run cannot find a test file that is
not in the list.

**Windows-vs-Linux divergence is real — the local run is not the verification.** Same date: a
new test file passed on Windows and failed on Linux, because the code under test had an inline
`Path("/etc/weewx-clearskies/...")` literal. On Windows that POSIX path resolves harmlessly; on
Linux it hits the real directory and raises `PermissionError`. Any test touching a config path
must be isolated to `tmp_path`, and a green Windows run proves nothing about Linux.

### Restart the librewxr compute services

```bash
ssh -F .local/ssh/config librewxr "sudo systemctl restart weewx-clearskies-swan weewx-clearskies-compute && systemctl is-active weewx-clearskies-swan weewx-clearskies-compute"
```

### Read SWAN run history on librewxr

```bash
ssh -F .local/ssh/config librewxr "sudo journalctl -u weewx-clearskies-swan --since '5 days ago' --no-pager | grep -E 'cached|nan_detected|low_valid_fraction'"
```

Get the **whole timeline** before concluding anything systemic from a single log line — a
`nan_detected` line next to ten successful runs is an intermittent, not a root cause. That
mistake has been made twice on this project.

### Run condition module tests (on weewx, NOT weather-dev)

The API is installed natively on the weewx container. Condition module tests (haze, calibration, sky, fog) run there — weather-dev is for dashboard and config UI only.

```bash
# Haze + calibration tests only
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"

# All four condition modules
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py tests/test_sky_condition.py tests/test_fog_condition.py --tb=short -q"

# Full API suite (only when needed)
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"
```

### Browser testing

The public-facing dev dashboard is at:

```
https://weather-test.shaneburkhardt.com
```

This is the URL to use for visual verification, screenshots, and all browser-based testing. Do NOT use raw container IPs — use FQDNs for dual-stack compatibility.

For direct service ports via SSH (curl from weather-dev), use `ssh weather-dev "curl http://localhost:<port>/..."`.

## Pytest baselines

Track the pass/skip/fail count at each round close to detect regressions.

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| 3b-13 close | ecd7e75 | 1954 | 364 | 0 |
| 3b-14 close | f2362ee | 2123 | 364 | 0 |
| 3b-15 close | ad1fe37 | 2283 | 364 | 0 |
| 3b-16 close | ae4a86d | 2302 | 364 | 0 |
| post-3b cleanup | 8e691f4 | 2305 | 364 | 0 |
| P4-R1 close | 66cb2e9 | 2311 | 365 | 0 |
| P4-R3 close | 2dcb6f6 | 2311 | 365 | 0 |

## Realtime pytest baselines

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| P4-T1 initial | cf7b6ab | 72 | 0 | 0 |
| P4-R3 close | 640d2dc | 78 | 0 | 0 |

## Dashboard bundle baselines

Track gzipped JS bundle size at each round close against ADR-033's 200 KB target.

| Round | Commit | Gzipped JS | % of budget |
|---|---|---|---|
| P3-T1 scaffold | 52d2d9a | 60.14 KB | 30% |
| P3-T2 mock-data | 29692cd | 194.77 KB | 97% |
| P3-T3 priority-pages | 716873a | 96.78 KB | 48% |
| P3-T4 remaining-pages | 49c44a0 | 93.01 KB | 47% |
| P3-T5 API wiring | 2e385e7 | 100.0 KB | 50% |
| P3-T6 mobile-first | a3a70f9 | 95.11 KB | 48% |
| P3-T7 light-dark-mode | 14eeb95 | 95.68 KB | 48% |
| P3-T8 theming-branding | af1ff8e | 96.16 KB | 48% |
| P4-T2 SSE wiring | f2a30e4 | 96.16 KB | 48% |
| P4-R3 close | 6ee7b24 | 96.21 KB | 48% |

## Dashboard vitest baselines

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| P4-T2 initial | f2a30e4 | 40 | 0 | 0 |
| P4-R3 close | 6ee7b24 | 40 | 0 | 0 |

## GitHub remotes

All repos under `github.com/clearskies-wx/`:

- `weewx-clearskies-project` (this repo — docs, manuals, rules, planning)
- `weewx-clearskies-api`
- `weewx-clearskies-dashboard`
- `weewx-clearskies-stack`
- `weewx-clearskies-extension`
- `weewx-clearskies-truesun`

Branching policy (pre-1.0): no feature branches. Commit straight to `main`.
