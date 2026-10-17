# Historical baseline: 60 groups (30 x 2 models)

Source: `baseline-30x2-20261016.zip` (SHA-256 `8C89269862C9B1F633B9983F4E53C68B583D8832042EBD5B1ADF0C6F489AB2BF`)
Collected: 2026-10-15/16, before the expert-cache experiments in this repo.

## What is here

60 groups x 2 models, G01..G30 each:

| Model | Groups | Directory |
|---|---|---|
| gpt-oss-120b MXFP4 | G01..G30 | `gpt-oss-120b/` |
| Qwen3-Next-80B-A3B Q4_K_M | G01..G30 | `qwen3-next-80b-a3b/` |

Each group has `RESULT.md` plus `raw/`:

| File | Content |
|---|---|
| `meta.json` | **the only source of the historical configuration** (server_args, ncmoe, cache, threads, ccd, affinity) |
| `runs.jsonl` | 3 runs, 192 output tokens each |
| `samples.jsonl` | per-second telemetry |
| `sample-stats.json` | telemetry summary |
| `sched.txt` | scheduling / placement |
| `weights.json` | weight ledger |
| `tensors.txt` | tensor placement |
| `server.log` / `stdout.log` | engine logs |

## Two caveats you MUST carry forward

1. **MANIFEST summary fields were empty.** Configuration is taken from `raw/meta.json` only.
2. **The historical CPU masks are wrong for this topology.** They were written as if the CCD mapping
   were known, but it was not. Measured topology (see `../../README.md`) is 4 CCD x 8 physical cores
   x 2 threads. For example the G01 mask `0x000000FF000000FF` selects logical CPUs 0-7 **and** 32-39,
   i.e. 4 cores from CCD0 plus 4 cores from CCD2 — it straddles two L3 domains and does not match any
   single CCD. Any performance number derived from these masks is therefore **not a clean CCD
   comparison**, and the correct masks are the `0x5555` family (one thread per physical core).

These 60 groups are kept as a **historical diagnostic track**, not as a clean baseline.
