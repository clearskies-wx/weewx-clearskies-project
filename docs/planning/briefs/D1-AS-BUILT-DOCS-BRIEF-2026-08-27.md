# D1 brief — as-built doc re-sync + firewalled zero-drift audit (Phase D)

**Round identity:** MARINE-AND-MAPS-PLAN Phase D, task D1. Date 2026-08-27. Lead: coordinator.
Teammates: `clearskies-docs-author` (re-sync) then `clearskies-auditor` (zero-drift, firewalled from the
docs-author's report). **Dispatch condition:** Gate M sweep and Gate S sweep both closed (every M/S row
accepted). **Pre-round verification (lead, fill at dispatch):** meta HEAD `<hash>`; marine `<hash>`; API `<hash>`;
dashboard `<hash>`; stack `<hash>`; the plan's checklist shows every M/S row ✅.

## What D1 is (plan §PHASE D, verbatim)
*ARCHITECTURE.md, the four manuals, ADR-078 (per the operator-accepted amendment from M1), ADR-101
(row-5), ADR-109 (gaps closed, D10 bootstrap), CHANGELOG — re-synced to the as-built state; zero-drift
audit by a firewalled auditor; this plan's own artefacts archived. The C9–C11 plans are NOT touched by
D1 (Q2 — they are the separate conversation's).*

## Hard constraints
- **No ADR status flips.** ADR-078 Amendment 2, ADR-093 Amendment 9, ADR-101 Amendment 1 and the
  ADR-109 S8.1 amendment are all **Proposed** and stay Proposed until the operator accepts them in chat
  (journal J3/J6/J7). D1 aligns their TEXT with the as-built code (line cites, hashes) and nothing else.
  The ADR-078 removal commit (if any) only happens after acceptance — not in D1.
- **Docs describe what the code does at the pinned hashes** — never what a brief planned. Every "as-built"
  sentence the docs-author changes cites the commit and file:line it was read from.
- **Doc-only round.** No code, no tests, no plan edits (the lead archives the plan after the audit).

## Scope — docs-author (meta repo)
Allowlist: `docs/ARCHITECTURE.md`, `docs/manuals/{API,PROVIDER,OPERATIONS,DASHBOARD,DESIGN}-MANUAL.md`,
`docs/decisions/ADR-078-*.md`, `ADR-093-*.md`, `ADR-101-*.md`, `ADR-109-*.md`, `docs/CHANGELOG.md`,
`docs/contracts/openapi-v1.yaml` (only if a landed endpoint/field is missing from it), `docs/INDEX.md`.
Method: for each landed round (M0, M1-API/DASH/STACK/DOCS, M3, M4-API/DASH, M4-B, S12, S1, S2, S3(a)(b)(c),
S4/S4b, S5, S8.1-A/B) read the plan row's commit hashes, `git show --stat` each, and diff the doc's claims
against the code. Known items to close (Gate M sweep F2/F3, 2026-08-27 — MUST be fixed): `docs/ARCHITECTURE.md:12` and `:384` still say dashboard basemap consumption is "not yet shipped"/"pending" — it shipped (dashboard `b307797`); `docs/manuals/OPERATIONS-MANUAL.md:658–661` says the stack admin Basemap page "has not shipped" — it shipped (stack `065ac62`). Also (from this session's journal): J12 — the dashboard's local
`src/api/openapi-v1.yaml` drifted ~1,200 lines from the meta contract before this plan: REPORT the drift
(do not resync the dashboard copy — that is code, a separate round); J15 — the API repo's dead
`SpectralWaveComponent` Pydantic model: REPORT, do not delete; the `level1` label now reads `deep_water`
(S3(b)) — every manual/ARCHITECTURE mention updated, the on-disk names unchanged and said so; the
`[imagery]` key/section/wizard field removal (M4-B) reflected in every manual that named them; the
basemap tiers/endpoints/admin page (M1) and the surf-map rasterization (M4) in DASHBOARD/API/OPERATIONS;
`ww3.gridRebuiltAt`/`handoffRestart` health blocks in OPERATIONS + API-MANUAL; ledger schema 3 `seam`
block in PROVIDER §14.15; Consistency in DESIGN + API-MANUAL §17. CHANGELOG: one consolidated
"MARINE-AND-MAPS-PLAN 2026-08-27" section listing every repo's commit range.
Closeout: a table — doc, section, what changed, code cite — plus a list of doc claims you could NOT
verify against code (those become audit rows).

## Scope — auditor (after the docs-author's closeout is accepted; firewalled — not shown that report)
Gate file `scratch/GATE-D1-DEFINITION.md` (lead writes it results-free at dispatch). Rows: every
ARCHITECTURE ⚓ block vs code; every manual section touched this plan vs code; every ADR amendment's
"as-built" cites resolve to real lines; the openapi contract vs the API's mounted routes (`app.py`) and
response models; no doc claims a Proposed ADR is Accepted; no doc still names CARTO/Esri/NAIP/`[imagery]`
as live; `level1` mentions only where the on-disk name is meant; CHANGELOG entries exist per repo; plus
two adversarial rows of the auditor's own.

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote branches.
You may only `git add <explicit paths>`, `git commit`, `git status`, `git log`, `git diff`, `git show`.
Never move, rename or delete a file outside your allowlist by any means. Before `git add` of any file,
`git diff -- <file>` and confirm every hunk is yours. Edit and commit ONLY on the local machine; SSH to
containers is read-only.

**Architectural changes — STOP, do not proceed.** A doc round makes no code changes; if aligning a
document would require the CODE to change, or two governing documents contradict each other on an
architectural point (triggers 1–7 of CLAUDE.md), STOP and report via SendMessage — a wrong or stale
document is a finding, not permission. The coordinator's ruling on your report is FINAL.

**Stale tests:** not applicable (no tests touched). Any test you notice contradicting a doc is a finding.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition.
