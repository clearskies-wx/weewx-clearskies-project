# Clear Skies

A modern, real-time weather dashboard for [weewx](https://weewx.com) stations.

Clear Skies replaces the legacy Belchertown skin with a ground-up rewrite: a FastAPI backend, a React SPA frontend, and a multi-step setup wizard — all deployable as a Docker stack or natively on bare metal.

## Architecture

```
weewx host                          front-end host
+-----------------------+           +------------------------------------------+
| API :8765 (TLS)       |           | Caddy :80/:443                           |
|   reads weewx archive |  network  |   serves dashboard static files          |
|   reads weewx.conf    |<--------->|   proxies /api/v1/* and /sse to API      |
|   unit conversion     |           |                                          |
|   enrichment pipeline |           | Dashboard (init container)               |
|   SSE stream          |           |   builds SPA, copies to volume           |
| Redis :6379 (cache)   |           +------------------------------------------+
+-----------------------+
```

**Single-host alternative:** All services on one machine via Docker Compose.

## Components

| Repo | What it does |
|------|-------------|
| [weewx-clearskies-api](https://github.com/clearskies-wx/weewx-clearskies-api) | FastAPI backend — REST endpoints, SSE, unit conversion, enrichment pipeline |
| [weewx-clearskies-dashboard](https://github.com/clearskies-wx/weewx-clearskies-dashboard) | React SPA — the weather UI visitors see |
| [weewx-clearskies-stack](https://github.com/clearskies-wx/weewx-clearskies-stack) | Docker Compose, Caddyfile, setup wizard, config UI |
| [weewx-clearskies-extension](https://github.com/clearskies-wx/weewx-clearskies-extension) | weewx extension — relays loop packets to the API via Unix socket |
| [weewx-clearskies-truesun](https://github.com/clearskies-wx/weewx-clearskies-truesun) | weewx XType extension — pvlib Simplified Solis solar radiation model |

This repo (`weewx-clearskies-project`) holds project-wide documentation, architecture decisions, manuals, planning, and the centralized CHANGELOG. It is also the single place to file issues and start discussions.

## Key features

- Real-time streaming updates via Server-Sent Events (no MQTT broker required)
- 9 built-in pages: Now, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal
- Operator-configurable charts (same INI format as Belchertown `graphs.conf`)
- Multi-provider support: Aeris, NWS, Open-Meteo, OpenWeatherMap, IQAir, USGS, and more
- Solar-powered sky condition classification (Kv-first Duchon-O'Malley architecture)
- NWS-style weather text generation (terse/standard/verbose)
- Light and dark themes with automatic day/night switching
- Accessible (WCAG AA target)
- Setup wizard with guided first-run configuration
- GPL v3

## Support

**Issues and discussions:** Use this repo's [Issues](https://github.com/clearskies-wx/weewx-clearskies-project/issues) and [Discussions](https://github.com/clearskies-wx/weewx-clearskies-project/discussions). Component repos do not have Issues enabled — file everything here.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — system topology, ports, endpoints, routing
- [API Manual](docs/manuals/API-MANUAL.md) — data model, units, enrichment, SSE
- [Provider Manual](docs/manuals/PROVIDER-MANUAL.md) — external API integrations, caching
- [Operations Manual](docs/manuals/OPERATIONS-MANUAL.md) — deployment, security, config
- [Dashboard Manual](docs/manuals/DASHBOARD-MANUAL.md) — technical behavior, i18n, performance
- [Design Manual](docs/manuals/DESIGN-MANUAL.md) — visual patterns, tokens, components
- [CHANGELOG](docs/CHANGELOG.md)

## License

[GNU General Public License v3.0](LICENSE)
