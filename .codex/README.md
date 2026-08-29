# Codex project configuration

This directory is the active Codex configuration for the Weather Belchertown and Clear Skies meta repository. The repository root [AGENTS.md](../AGENTS.md) is the instruction entry point. Detailed workflows remain in `rules/`, stable system facts remain in `reference/` and `docs/reference/`, and project status remains in planning documents and `docs/CHANGELOG.md`.

## Coordinator

`.codex/config.toml` selects `gpt-5.6-sol` with high reasoning. The installed model catalog reports an 872,000-token maximum context window and a 95 percent effective ceiling of 828,400 tokens. Automatic compaction starts at 800,000 total tokens, below that ceiling.

The Codex desktop app must be restarted and a new task opened before this extended context window appears. Existing tasks retain the configuration with which they were opened.

## Supporting agents

Codex may run at most three supporting agents concurrently, excluding the coordinator.

| Agent class | Model | Reasoning | Access |
| --- | --- | --- | --- |
| Standard worker and repository implementation roles | `gpt-5.6-terra` | medium | workspace write, bounded by the task allowlist |
| Routine reviewer and Clear Skies auditor | `gpt-5.6-terra` | high | read-only |
| Difficult troubleshooter | `gpt-5.6-sol` | max | read-only, diagnostic only |
| Mechanical worker | `gpt-5.6-luna` | medium | workspace write, no ambiguous decisions |

General agents and the converted Clear Skies roles live in `.codex/agents/`. Repository-specific roles preserve their existing scope and closeout contracts. Every role remains subordinate to `AGENTS.md`, `rules/agents.md`, and the architectural approval gate.

## Trust, MCP, and credentials

Codex loads project-local configuration only for trusted projects. The exact path `c:\code\weather-belchertown` must have `trust_level = "trusted"` in the user's Codex config.

The previous project configuration defines no Model Context Protocol (MCP) servers, so this project config intentionally defines none. Do not copy servers from another project or infer a server from a legacy tool-permission name.

If a future project MCP server needs a credential, keep the canonical value in `reference/CREDENTIALS.md`, expose it as a Windows user environment variable, and list only its name in the server's `env_vars` array. Never place a credential value under `.codex/`.

## Claude compatibility

`CLAUDE.md` and `.claude/` remain for compatibility. They are not authoritative for Codex and are not maintained as part of the active Codex configuration. `CLAUDE.md` directs compatible clients to `AGENTS.md`.
