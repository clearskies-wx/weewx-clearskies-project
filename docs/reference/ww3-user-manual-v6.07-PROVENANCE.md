# Provenance — `ww3-user-manual-v6.07.txt`

- **Source:** WaveWatch III (WW3) v6.07 User Manual, NOAA-EMC. Sourced from the
  NOAA-EMC/WW3 GitHub project's manual PDF (`manual.pdf`, hosted on the WW3 GitHub
  wiki/repository per `scratch/BRIEF-RESEARCH-WW3.md`), mirrored locally at
  `scratch/ww3-manual-6.07.pdf`.
- **Extraction method:** `scratch/ww3-manual-6.07.txt` is a PDF-to-text extraction of
  `scratch/ww3-manual-6.07.pdf`. The specific extraction tool used to produce the
  `.txt` is not recorded in any scratch artifact and is not asserted here — what is
  verifiable is the pdf→txt relationship between the two mirrored files (same
  directory, same acquisition timestamp, `.txt` is a plain-text rendering of the
  `.pdf`'s content).
- **Date pulled:** 2026-08-16 (the Q5 ruling date per
  `docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`; also the date ADR-109 D2
  records the operator's ruling to pull the 6.07 manual).
- **Committed copy:** `docs/reference/ww3-user-manual-v6.07.txt` is a byte-identical
  copy of `scratch/ww3-manual-6.07.txt` (verified by sha256 at commit time — see
  DOC-W.4 closeout report). No header was prepended to the committed `.txt`; a
  prepended header would shift every line number below it.
- **Line-cite contract:** citations of the form `6.07:NNNN` in ADR-109, in
  `docs/reference/SYNTAX-607-VERIFICATION.md`, and elsewhere refer to line numbers
  in this committed `.txt` file as it exists today. **This file must never be
  reflowed, re-wrapped, or have content inserted/removed** — doing so invalidates
  every existing `6.07:NNNN` citation across the project's decision and reference
  documents.
