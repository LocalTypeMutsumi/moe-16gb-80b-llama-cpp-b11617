# MoE Expert Caching on a 16 GB Card: 80B MoE at 68–81 t/s, and what it costs in quality

Measured on a single RTX 4070 Ti SUPER (16 GB) with Qwen3-Next-80B-A3B-Instruct Q4_K_M (80B total, 3B active) via llama.cpp b11617.

**TL;DR**

- **A bandwidth model fits the data — but it is a hypothesis, not a proven mechanism.** cache=0 lands at **47.0 GB/s** against a measured **48 GB/s** RAM ceiling (97.9% closure). cache=10752 is consistent with being capped by **PCIe 4.0 ×16 (~24.45 GB/s)**, which would imply an ~83% hit rate. **This is circular reasoning**: the hit rate is derived from speed and bandwidth, then used to argue PCIe is saturated. Confirming gen4 x16 only proves the link *configuration*, not that 24.45 GB/s is actually achieved. The 1.75 GB/token figure is also a proportional estimate, not a per-layer ledger. Treat the attribution as an open question.
- **If the PCIe hypothesis holds, it would explain portability**: the ceiling would sit on a hardware constant rather than on the memory subsystem. **This has not been tested on a second machine.**
- **No perplexity change was observed** at cache = 0 / 512 / 2048 / 10752 MiB (4.4617 ± 0.14700, 20 chunks of WikiText-2, 4-decimal precision). This is **not** a bit-identical claim and does not cover the decode path.
- **It is very much speed-relevant**: decode goes from 26.8 t/s (cache off) to **80.8 t/s** (cache 10752 MiB) on identical settings.
- **There is a real valley at small caches**: cache 512 MiB is *slower* than cache 0 (20.4 vs 26.8 t/s, −23.9%).
- **`ncmoe` and cache compete for the same VRAM.** On 16 GB, `ncmoe 48` is the only **tested** setting that does not collapse — `ncmoe 44` already drops to 23.6 t/s. Points 45/46/47 were not tested.
- **"Random tokens" overstate real-input throughput by ~37%** (93.6 vs 68.0 t/s). Do not quote that as real-world speed.

---

## Hardware / software

| Item | Value |
|---|---|
| GPU | RTX 4070 Ti SUPER, 16376 MiB, driver 610.88, PCIe 4.0 ×16 (verified under load) |
| CPU | Ryzen Threadripper PRO 5975WX, 32C/64T, 4×32 GB DDR4-3200 (4 of 8 slots populated) |
| OS | Windows Server 2025 Datacenter build 26100, power plan "Ultimate Performance" |
| Engine | llama.cpp **b11617**, commit 14310190c, Clang 20.1.8, CUDA 12.4 |
| Model | `Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| Model SHA-256 | `158A9E5B76A1BEF71FCEA4E1990E647088122B51B9FA823A134C6F6033D856BE` |
| `llama-server.exe` SHA-256 | `715F0EA98819F03FC596E9D352E989FC0AE093056282E0D73B2D657E7AFA7D02` |
| Corpus (perplexity) | WikiText-2 `wiki.test.raw`, SHA-256 `173C87A53759E0201F33E0CCF978E510C2042D7F2CB78229D9A50D79B9E7DD08` |

Tokenizer notes for this model: `n_vocab = 151936`, BOS = 151643, `add_bos_token = false`.

---

## 1. PPL: expert cache does not change the output

```
llama-perplexity -m <model> -f wiki.test.raw -c 512 --chunks 20 \
  -ngl 99 -ncmoe 48 -lm none --moe-cache-mib <0|512|2048|10752>
```

| cache (MiB) | PPL | ± |
|---|---|---|
| 0 | 4.4617 | 0.14700 |
| 512 | 4.4617 | 0.14700 |
| 2048 | 4.4617 | 0.14700 |
| 10752 | 4.4617 | 0.14700 |

**All four identical to 4 decimal places.**

This is *not* an inactive cache. A `-lv 4` probe confirms it engages:

```
CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
llama_moe_cache: ubatch <= 8: hits = 0, misses = 808, hit rate = 0.00%, uploaded = 1520.77 MiB
llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

Perplexity runs go through the **large-batch** path (3525 experts served from cache). Fetching relocates expert weights without changing the arithmetic, which is *consistent with* the observed result — but the output is rounded to 4 decimals, so this is "no change at display precision", not a bit-identical claim. On this workload, and within that measurement window, cache size behaved as a **speed knob, not a quality knob** — a statement about what we measured, not a general guarantee.

> Prior work for comparison: ChaeWoo Son (2026-10) measured **+5.7% PPL for substitution** and **+0.35% for selective fetch** on the same model. Our fetch-only result shows **no change at 4-decimal precision** on 20 chunks, which is consistent with "fetch does not alter numerics" — but it is not a bit-identical claim. Different hardware, different implementation — not a head-to-head.

## 2. Decode speed vs cache size (ncmoe 48, 3 runs each)

| cache (MiB) | decode t/s | VRAM peak (MiB) |
|---|---|---|
| 0 | 26.806 | 3502 |
| **512** | **20.414** | 4079 |
| 1024 | 30.001 | 4663 |
| 1536 | 32.424 | 5200 |
| 2048 | 35.788 | 5682 |
| 3072 | 42.486 | 6684 |
| 4096 | 49.222 | 7730 |
| 6144 | 61.675 | 9793 |
| 8192 | 69.718 | ~11800 |
| **10752** | **80.673** | 14899 |

There is a **valley at 512 MiB** (below cache=0). The break-even against cache=0 sits between **512 and 1024 MiB** — same order as the ~1200 MiB reported for prefill-side break-even elsewhere. It keeps rising to our measured maximum; we saw no saturation at 10752.

## 3. `ncmoe` collapse: below 48 the throughput collapses on 16 GB

Cache 10752 MiB, 3 runs each. Collapse criterion = GPU util ≥99% **and** power <90 W **and** drop >25% (all three together).

| ncmoe | decode t/s | VRAM peak (MiB) | util | power (W) | collapsed |
|---|---|---|---|---|---|
| **48** | **80.144** | 14887–14912 | 85–86% | 77–160 | no |
| 44 | 23.639 | 15762–15830 | 95–97% | 63–92 | suspected |
| 40 | 19.547 | 15801–15811 | 97–100% | 63–90 | **yes** |
| 36 | 17.443 | 15816–15831 | 100% | 64–89 | **yes** |
| 34 | 15.818 | 15929–15935 | 100% | 65–82 | **yes** |
| 32 | 15.108 | 15917–15924 | 100% | 62–84 | **yes** |

**The cliff is between the tested points ncmoe 48 and 44.** A rough budget is *consistent with* a VRAM-pressure story, but it is not a ledger:

```
16376 (VRAM) - 917 (desktop)        = 15459 MiB free
cache 10752                          ≈ 10751 MiB  (measured "MoE cache size")
left for expert layers               ≈  4708 MiB
0.94 GB per layer                    => ~4.7 layers
```

That estimate ignores compute buffers, context and fragmentation, and was never checked against a per-layer tensor ledger. **It points in the right direction with the collapse; it does not locate the mechanism.** ncmoe 45/46/47 were not tested, so 48 is not claimed to be a global optimum.

**Cache and `ncmoe` draw from the same VRAM pool.** Lowering `ncmoe` while keeping a large cache is associated with a silent 3–4× slowdown, with no OOM and no error — GPU sits at 100% while power stays under 90 W. Whether page migration actually happens was not measured.

## 4. Real text vs random tokens (5 processes × 10 pairs each)

Same length per pair (tokenized, matched within ±2 tokens), 256 output tokens, cache 10752, ncmoe 48.

| Input | median decode |
|---|---|
| Real text (10 different prompts) | **67.96 t/s** (P5 run) |
| Random token IDs (same lengths) | **93.62 t/s** (P5 run) |

Two independent runs ~1 hour apart, 50 pairs each: **B run 68.35 / 93.53**, **P5 run 67.96 / 93.62** (real / random). Figure 4 in the report uses the P5 run. Raw per-sample logs: `data/02-stability/B-run.log` and `P5-run.log`; the 50-sample summary is `data/02-stability/P5-summary.csv`.

**Random tokens are ~37% faster.** This is a big part of why community `tg` numbers exceed real-world throughput: llama-bench feeds random token IDs, which tend to route to a smaller, hotter set of experts. That routing explanation is an inference — we did not measure hit rate on the two input types.

### And a related trap: repeated prompts inflate numbers further

Running the **same** prompt repeatedly reaches **80.9 t/s**, while cycling through 10 **different** prompts gives **68.0 t/s** (+19%). Two things change at once here — the prompt content *and* the cache history — so the 19% cannot be attributed to repetition alone. If you measure one prompt N times, you are measuring the warm-cache case, not a realistic workload; but the same caution applies to the claim that repetition *causes* the gap.

This also explains a discrepancy in our own logs: an older single-shot 74.18 t/s and a later 10-prompt 68.0 t/s are not the same measurement.

## 5. Where the ceiling may be: PCIe or RAM (unverified hypothesis)

This is the part that makes the numbers portable. See `BANDWIDTH-ANALYSIS.md` for the full derivation.

Per token this model moves ≈ **1.75 GB** of expert weights (80B total / 3B active, 10 of 512 experts per token).

**Path A — cache=0** (all experts on CPU, every token re-read from RAM):

```
26.806 t/s × 1.75 GB = 46.9 GB/s   vs   measured RAM ceiling 48 GB/s   → 97.7% closure
```

So cache=0 is not "untuned" — the numbers are **consistent with** saturating memory bandwidth. (Note: 4×DDR4-3200 is 102 GB/s theoretical but only ~40–48 GB/s achievable here; theory does not explain the measurement.)

**Path B — cache=10752** (hot experts resident, misses fetched over PCIe):

```
80.673 t/s × 1.75 GB = 141.2 GB/s needed if every token missed
PCIe 4.0 ×16        =  24.45 GB/s available
⇒ allowed miss traffic = 0.303 GB/token  ⇒ implied hit rate = 82.7%
```

**The two-sided arithmetic below is NOT an independent cross-check** (retracted after audit): both sides reuse the same speeds, the same bandwidth constants and the same 1.75 GB/token estimate, so the agreement is algebraic, not evidential.

```
cache=0    : 48 GB/s ÷ 26.806 = 1.791 GB/token  (full traffic, RAM side)
cache=10752: 24.45 GB/s ÷ 80.673 = 0.303 GB/token (miss traffic, PCIe side)
hit rate = 1 − 0.303 / 1.791 = 83.1%   ← agrees with 82.7% within 0.4 pp
```

This agreement is **self-consistent by construction**, not by evidence — see the retraction above.

### What this implies for other platforms

| Platform | PCIe | Effective BW | Expected ceiling (if the model holds) |
|---|---|---|---|
| **PCIe 4.0 ×16** (4070 Ti Super, 4080, 3090) | 24.45 GB/s | **≈ 80 t/s (as measured here)** |
| PCIe 4.0 ×8 (**4060 Ti 16GB**) | ≈ 12.2 GB/s | ≈ 40 t/s (predicted, not measured) |
| PCIe 3.0 ×16 | ≈ 12.6 GB/s | ≈ 41 t/s (predicted, not measured) |

In the cache configuration, memory channels and DDR generation are expected to matter much less than PCIe width — the RAM only has to supply the ~24.45 GB/s that PCIe takes. That is a consequence of the model, not an independent observation.

**⇒ If the model holds, PCIe width sets the ceiling and ×8 or Gen3 roughly halves it.** A 4060 Ti 16GB has the VRAM but not the lane width. Neither the halving nor the DDR insensitivity has been measured on a second machine.

⚠️ This is an inference from bandwidth constants, **not a second-machine measurement** (see Limitations).

## 6. Environment caveats (what we could not measure)

| Item | Status |
|---|---|
| CPU Tctl | **UNAVAILABLE** — no ACPI thermal zone on this box, no HWiNFO installed. The "abort if ≥95 °C" rule could not be enforced. |
| DIMM temperature | **UNAVAILABLE** — same reason. Our host had a confirmed RAM-cooling incident (fan obstruction), so this is a real blind spot. |
| PCIe idle reading | Unstable (reported gen 2 once, gen 4 other times). Under load it was **gen 4 ×16** in 3/3 samples. |
| Hyper-V VMs | Two VMs were running during part of data collection. Stopped them and re-ran the key config once each: **80.27 vs 80.86 t/s (−0.7%)**. One sample per side — enough to say no large effect was seen, not enough to exclude a small one. The claim that the vCPUs could not touch the pinned cores is *not* supported by CPU affinity alone; it would need per-core sampling. |

---

## What is new here (relative to prior work)

| Prior work | What it covered | What we add |
|---|---|---|
| Son (2026-10): substitution +5.7% PPL, selective fetch +0.35% | PPL of two cache *algorithms* | **PPL of the fetch-only cache actually shipped in llama.cpp**: no change at 4-decimal precision across 4 cache sizes |
| MoE Hot Cache write-up: prefill break-even at 31–32% hit rate | prefill side | **decode-side cache curve, 10 points from 0 to 10752 MiB, including the cache=0 baseline** |
| omlx PR #2343: repeated fills 1.9× faster (MTP) | MTP scenario | **MoE + random-token overstatement: +37%; repeated-prompt overstatement: +19%** |
| llama.cpp #26432: AMD GTT overflow, 60% drop, no error | AMD GTT | **expert-cache collapse on a 16 GB NVIDIA card: same silent signature (100% util, <90 W, −71%)** |
| Son used 3090 + 16 GB system RAM | — | **full 16 GB single-card config on 80B with 128 GB RAM, incl. the ncmoe/cache VRAM competition** |

**Repo:** https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617

## Reproduce

Everything is deterministic except speed. Scripts and raw per-run JSON are in `data/` and `tools/`. Each measurement records `prompt_n`, `predicted_n`, `prefill_ms`, `decode_ms`, VRAM peak, GPU util, power, and a before/after baseline drift check.

The exact commands are in [`data/05-environment/commands.md`](data/05-environment/commands.md).

## Limitations

- Single machine, single model, single quant (Q4_K_M). Not a general claim about MoE caching.
- PPL uses `--chunks 20` of WikiText-2 test, **not the full test set**.
- The 10-prompt check (secondary evidence, in `data/06-10prompts/`) scored 8/10 in both arms with 0 pp difference, but only 5/10 outputs were byte-identical — treat as qualitative.
- **Hit rate was not obtained on the speed path.** Under this test's termination method (taskkill without `/F`, and `-lv 4`), llama-server never emitted a per-token MoE cache hit-rate line. That is *not* proof it is impossible: the source calls `log_stats()` in the cache destructor, so a graceful Ctrl+C exit may be required — untested here. Only llama-perplexity produced hit data, and its large-batch path saturates at ~2048 MiB (34668 experts copied at 2048, 4096, 8192 and 10752 — identical), while server decode keeps scaling (35.8 -> 80.7 t/s over the same range). So the decode-side 82.7% in this report is **derived from PCIe bandwidth, not logged**. See `data/08-prepost-v32/P7-hitrate/FINDINGS.md`.
- Client-side desktop was in use during collection (browser, WeChat). A per-run baseline drift check was added specifically for this; 34/45 runs were VALID (<2% drift), 8 VALID_WITH_NOTE, 3 UNSTABLE (all in the highest-load config).

---

## License / attribution

Data and scripts here are our own measurements. Prior work is cited, not reproduced. If you use these numbers, cite this repo and note the engine build (b11617) — expert-cache behaviour is version-specific.



## Audit corrections (2026-10-17)

An external audit found real defects. All are confirmed and fixed; details in
[`AUDIT-RESPONSE.md`](AUDIT-RESPONSE.md) and `data/05-environment/MEDIAN-CORRECTION.csv`.

| # | Defect | Status |
|---|---|---|
| 1 | The reported "median" was actually the **maximum** of 3 runs (`ds[[int](3/2)]`) | Fixed; every summary regenerated. cache0 26.842→**26.806**, cache10752 80.809→**80.673**, ncmoe48 80.917→**80.144** |
| 2 | "Three independent processes" was **three requests in one server process** | Reworded; cross-process repeatability now listed as untested |
| 3 | PCIe attribution was **circular** | Demoted to hypothesis throughout |
| 4 | "Server cannot log hit rate" may be caused by `Stop-Process -Force` skipping `log_stats()` | Retested with graceful `taskkill`; still no stats, but impossibility is no longer claimed |
| 5 | "bit-identical PPL" overstated | Reworded to "no change at 4 decimals over 20 chunks" |
| 6 | Repo copy was missing 22 runtime files; `usage_log.csv` hash mismatched | Fixed; both rounds now verify 0 missing / 0 mismatched |

**What survives the audit:**
> On this 16 GB card and workstation, expert caching substantially improves speed for the tested workload: ~**80.7 t/s** on a repeated fixed prompt, ~**68.0 t/s** on varied real inputs. Small caches can regress. No perplexity change was observed in the limited test. Bottleneck attribution and consumer-platform portability still require independent verification.

