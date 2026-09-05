# Codex project configuration

This directory is the active Codex configuration for the Weather Belchertown and Clear Skies meta repository. The repository root [AGENTS.md](../AGENTS.md) is the instruction entry point. Detailed workflows remain in `rules/`, stable system facts remain in `reference/` and `docs/reference/`, and project status remains in planning documents and `docs/CHANGELOG.md`.

## Coordinator

`.codex/config.toml` selects `gpt-5.6-terra` with high reasoning and its 1,050,000-token context window for new project tasks. The Coordinator is the normal user-facing task owner: it manages approved plans, assigns work, preserves project context, and synthesizes results.

Existing tasks retain the model configuration with which they were opened. Restart the Codex desktop app and open a new task after changing model defaults.

## Supporting agents

Codex may run at most three supporting agents concurrently, excluding the coordinator.

| Agent class | Model | Reasoning | Access |
| --- | --- | --- | --- |
| Workhorse coding roles | `gpt-5.3-codex-spark` | high | bounded implementation only; never given broad project context |
| Expert coding lead | `gpt-5.6-terra` | high | context-heavy or cross-cutting work; may oversee bounded Spark work |
| QC and review | `gpt-5.6-terra` | high | adversarial phase gates; may coordinate Luna testing evidence |
| Research lead | `gpt-5.6-terra` | high | source judgment and synthesis; may coordinate Luna retrieval |
| Testing | `gpt-5.6-luna` | high | focused test evidence, normally for QC |
| Mechanical and retrieval work | `gpt-5.6-luna` | medium | deterministic, low-judgment work only |
| SOL adviser | `gpt-5.6-sol` | high | 1,050,000-token context; only after the user explicitly authorizes a named task |

Automatic routing never restricts the user: an explicit user request for a different model or reasoning level wins. General agents and the converted Clear Skies roles live in `.codex/agents/`. Every role remains subordinate to `AGENTS.md`, `rules/agents.md`, and the architectural approval gate.

## Production-first execution — operator rule, 2026-09-04

Every implementation role must read and follow the **"Production-first implementation"** section
of [`rules/coding.md`](../rules/coding.md) before editing code. The approved plan, documented
contract, and real deployed outcome define the work. A test, fixture, or assertion is a regression
guard and never a substitute for the design or the real operating goal.

Implementation agents must not hardcode a known answer, static string, magic number, fixture
shape, or special branch to satisfy a visible test. They implement generic behavior driven by real
inputs and handle missing, malformed, wrong-type, empty, and extreme-but-valid inputs under the
stated contract. Before reporting implementation ready for quality control, the agent must ask
whether a small input or test-case change would break or mislead the result and correct that
weakness. Review and quality-control roles must reject code that violates this standard even when
all checks pass.

For a WW3 → SWAN → SwellTrack phase, no role may characterize the model as working based on unit
checks, generated decks, or an individual solver exit. The required evidence is a real end-to-end
chain run on the correct live host with real inputs and planned, inspectable output.

Use the project roles by judgment level, not simply by file type:

| Role | Use it for | Do not use it for |
| --- | --- | --- |
| `expert_coder` (Terra, high) | Cross-service phases, dependent slices, design interpretation, and integration | Exact edits, inventories, ordinary documentation, or routine checks |
| `worker` (Spark, high) | A single explicit coding slice with a strict file allowlist | Design choices, multi-service integration, or manual reconciliation |
| `documentation_author` (Luna, high) | Documentation based on verified source and a stated scope | Deciding what the design should be |
| `test_engineer` (Luna, high) | Post-phase live-environment quality checks using real input and output | Designing code or testing during implementation |
| `mechanical_worker` (Luna, medium) | Exact replacements, inventories, and bounded formatting | Any judgment call |
| `reviewer` (Terra, high) | Independent quality control after a completed phase | Implementation |
| `troubleshooter` (Terra, high) | Difficult evidence-based diagnosis | Routine retrieval or implementation |

## Trust, MCP, and credentials

Codex loads project-local configuration only for trusted projects. The exact path `c:\code\weather-belchertown` must have `trust_level = "trusted"` in the user's Codex config.

The previous project configuration defines no Model Context Protocol (MCP) servers, so this project config intentionally defines none. Do not copy servers from another project or infer a server from a legacy tool-permission name.

If a future project MCP server needs a credential, keep the canonical value in `reference/CREDENTIALS.md`, expose it as a Windows user environment variable, and list only its name in the server's `env_vars` array. Never place a credential value under `.codex/`.
