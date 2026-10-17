# Complete test data

Two rounds, plus the historical baseline.

| Directory | Round | Content |
|---|---|---|
| `00-historical-baseline/` | 2026-10-15/16 | 60 groups x 2 models (historical diagnostic track) |
| `01-perplexity/` .. `06-10prompts/` | 2026-10-17 round 1 (v3.0) | PPL, stability, collapse points, cache curve (3 pts), 10-prompt check |
| `07-prepost-v30/` | v3.0 raw | full per-task raw output: TASK-A/A0/B/C/D, telemetry, server logs |
| `08-prepost-v32/` | v3.2 raw | P1 PCIe, P2 ncmoe 48-32, **P3 cache 10-point curve**, P4 PPL x4, P5 stability rerun, P6 VM A/B |

## Why the table above (`01`..`06`) is not the whole story

Those are the *curated* extracts used by the report tables. `07-prepost-v30/` and
`08-prepost-v32/` hold the **raw per-run output** they were built from: every `run<N>.jsonl`,
every `telemetry/*.csv`, server logs, baseline drift records.

## What is deliberately NOT here

- `wiki.train.raw` / `wiki.valid.raw` (10.7 MB + 1.1 MB). Only `wiki.test.raw` is needed to
  reproduce the perplexity numbers; the rest is re-downloadable from the ggml-org CI dataset mirror.
  `wiki.test.raw` SHA-256 is in `05-environment/environment.json`.
- Model weights (46.6 GB). SHA-256 is in the report §2.2.
- The separate P1-P7 re-test programme (`T-REDO-02/`), which is an independent track.

## Provenance

Every file in `07`/`08` was produced by the scripts in `../../tools/` and is byte-identical
to the copies under the working directory; `checksums.sha256` in each round directory predates
the copy and still validates.
