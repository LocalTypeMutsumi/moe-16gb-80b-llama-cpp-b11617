# MoE Expert Caching on a 16 GB Card: Measured on Qwen3-Next-80B-A3B

**Single-machine exploratory performance report · v2.0 · 2026-10-17**

> Full document and raw data live in this repo under `docs/` and `data/`. This is the Markdown edition.

---

## Summary

Running an 80B-class MoE model on a single 16 GB consumer GPU, expert caching (`--moe-cache-mib`) is what makes decode usable at all. This report covers three measurement tracks on one machine: whether the cache changes output quality, how speed varies with cache size and `ncmoe`, and how much the input type matters.

**The speed result is solid; the mechanism is not established.** On this machine and this workload, expert caching took decode from **26.806 t/s to 80.673 t/s**. Why it's fast, and whether another machine would see the same, is something this report offers only an unverified hypothesis for — not a conclusion.

### Five findings

1. **Output quality: no change at display precision.** Perplexity across cache 0 / 512 / 2048 / 10752 MiB was `4.4617 ± 0.14700` in all four cases, with `-lv 4` confirming the cache was actually serving experts. Limits: 20 chunks only, large-batch path only, four decimal places only. This is not a bit-identical claim, and it says nothing about the decode path.
2. **Speed: about 3.01×.** Decode goes from 26.806 t/s (cache=0) to 80.673 t/s (cache=10752). The curve is **V-shaped** — 512 MiB is *slower* than no cache (20.414 t/s, −23.8%).
3. **An `ncmoe` cliff.** With cache fixed at 10752 MiB, only 48 of the six tested values avoids a large regression (80.144 t/s); 44 already drops to 23.639 t/s. Points 45/46/47 were not tested, so 48 is the best *tested* setting, not a global optimum.
4. **Input type matters.** Real text 67.54–68.12 t/s vs length-matched random tokens 93.51–93.61 t/s — roughly **38%**. Repeating a single prompt is about 19% faster than cycling diverse prompts, but those two runs also changed the prompt *content*, so the 19% cannot be attributed to repetition alone.
5. **Mechanism: not established.** A model in which cache=0 is bound by memory bandwidth and cache>0 by PCIe effective bandwidth is consistent with the data, but it is derived by back-solving speed against bandwidth constants — circular reasoning. Cross-platform reproducibility is likewise unverified.

### What this report does NOT claim

- **Not** that PCIe is the sole bottleneck. Section 4 is a self-consistent arithmetic frame, not a proven mechanism.
- **Not** that a hit rate was measured. The 82.7% figure is back-solved under a "PCIe is saturated" assumption; it is not a logged value.
- **Not** that perplexity is provably lossless. The evidence supports "no change observed at four decimals, on 20 chunks, on the large-batch path."
- **Not** that consumer platforms will reproduce this. One machine only; cross-platform statements are inference.
- **Not** that 48 is optimal. 45/46/47 untested, and neither was "reduce cache + keep static experts."

---

## Platform and method

| Item | Value |
|---|---|
| GPU | NVIDIA RTX 4070 Ti SUPER, 16376 MiB, driver 610.88 |
| PCIe | 4.0 x16 (gen4 x16 in 3/3 samples under load) |
| CPU | AMD Ryzen Threadripper PRO 5975WX, 32C/64T, L3 131072 KB |
| Memory | 4 × 32 GB DDR4-3200, 4 channels (4 of 8 slots), 3200 MT/s throughout |
| OS | Windows Server 2025 Datacenter build 26100 |
| Engine | llama.cpp **b11617** (commit `14310190c`, Clang 20.1.8, CUDA 12.4) |
| Model | Qwen3-Next-80B-A3B-Instruct Q4_K_M (80B total / 3B active, 512 experts, 10 per token) |

**CPU topology (easy to misread).** All speed runs used mask `0x0000000000005555`, i.e. logical CPUs 0, 2, 4, 6, 8, 10, 12, 14 — which on this topology are **all inside CCD0**. If adjacent logical IDs are SMT siblings, that is 8 physical cores on one CCD, one thread each. **The measurement therefore covers a single CCD.** Cross-CCD behaviour comes from historical data, not from this report.

**Measurement protocol (affects how you read the numbers).** One `llama-server` process per config, with 3 scored requests inside it. Each scored request is bracketed by a 128-token same-prompt baseline used for drift monitoring. **Those baselines themselves warm the cache, so every number here is a warm-cache protocol, not cold start.**

---

## Result 1: Quality — no change at display precision

llama-perplexity, WikiText-2, 512 ctx, 20 chunks, `ncmoe 48`:

| cache (MiB) | PPL | std err | samples |
|---|---|---|---|
| 0 | 4.4617 | 0.14700 | 20 chunks |
| 512 | 4.4617 | 0.14700 | 20 chunks |
| 2048 | 4.4617 | 0.14700 | 20 chunks |
| 10752 | 4.4617 | 0.14700 | 20 chunks |

The cache was demonstrably active (`-lv 4`):

```
CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

Strict limits: the evidence supports "no change observed on 20 chunks, on this batch path, at four decimals." It does not support a bit-identical claim, cannot exclude small numerical differences, and does not substitute for quality validation on the decode path.

---

## Result 2: The speed curve is V-shaped, valley at 512 MiB

`ncmoe 48`, 3 scored requests per config:

| cache MiB | decode t/s | VRAM MiB |
|---|---|---|
| 0 | 26.806 | 3502–3503 |
| **512** | **20.414** | 4079 |
| 1024 | 30.001 | 4654–4672 |
| 1536 | 32.424 | 5151–5250 |
| 2048 | 35.788 | 5677–5687 |
| 3072 | 42.486 | 6681–6688 |
| 4096 | 49.222 | 7727–7732 |
| 6144 | 61.675 | 9785–9801 |
| 8192 | 69.718 | 12128–12485 |
| **10752** | **80.673** | 14749–14814 |

A 512 MiB cache is **23.8% slower than no cache**. Break-even against cache=0 sits between 512 and 1024 MiB — same order as the ~1200 MiB prefill-side break-even reported elsewhere. It was still climbing at 10752; no saturation observed in the tested range.

---

## Result 3: The `ncmoe` cliff

Cache fixed at 10752, 3 scored requests per config:

| ncmoe | decode t/s | VRAM MiB | GPU util | power W | drop vs 48 | criterion |
|---|---|---|---|---|---|---|
| **48** | **80.144** | 14887–14912 | 85–86% | 77–160 | — | no |
| 44 | 23.639 | 15762–15830 | 95–97% | 63–92 | −70.5% | no |
| 40 | 19.547 | 15801–15811 | 97–100% | 63–90 | −75.6% | partial |
| 36 | 17.443 | 15816–15831 | 100% | 64–89 | −78.2% | yes |
| 34 | 15.818 | 15929–15935 | 100% | 65–82 | −80.3% | yes |
| 32 | 15.108 | 15917–15924 | 100% | 62–84 | −81.2% | yes |

**The cliff sits between the tested points 48 and 44, and it is silent**: no OOM, no error, no warning. The GPU reports busy, and power draw is *lower* than at full load.

I originally wrote a tidy three-symptom criterion (util ≥99% **and** power <90 W **and** drop >25%) and labelled whole rows "collapsed." Then I went back to the raw per-run records:

| ncmoe | util run1 / run2 / run3 |
|---|---|
| 48 | 85 / 86 / 85 |
| 44 | 95 / 95 / **97** |
| 40 | 97 / 100 / 97 |
| 36, 34, 32 | 100 / 100 / 100 |

44 **never reaches 99%**, and 40 does so in only **1 of 3 runs**. The criterion is partly self-defeating on this data. The report now records the three symptoms separately instead of collapsing them into a single boolean.

A rough budget is consistent with the direction, but it is not a ledger:

```
16376 MiB total − 917 desktop = 15459 available
cache 10752                   ≈ 10751
left for expert layers        ≈  4708  →  ~4.7 layers at 0.94 GB each
```

That ignores compute buffers, context and fragmentation, and no per-layer tensor ledger was built.

---

## Result 4: Input type moves the number by ~38%

5 independent processes × 10 length-matched pairs (±2 tokens), 256 output tokens:

| input | standard median decode |
|---|---|
| Real text (10 different prompts) | **67.54 t/s** |
| Random token IDs (same lengths) | **93.61 t/s** |

A second independent run an hour earlier gave **68.12 / 93.51**. Both are **standard medians** over 50 samples — the mean of the 25th and 26th sorted values.

> Worth stating explicitly: llama.cpp's own log lines report a median that is actually the 26th value, which is systematically ~0.2% higher. If you diff my numbers against your own tooling, check which convention it uses.

A second trap: the **same** prompt repeated hits 80.9 t/s, vs 68.0 when cycling 10 different prompts (+19%). But those two runs differ in **prompt content as well as repetition**, so the 19% cannot be attributed to repetition alone. I did not separate the two.

---

## Result 5: Environment controls

- **PCIe link**: gen4 x16 in 3/3 samples under load. This proves the negotiated configuration only, not that a particular throughput was achieved.
- **Hyper-V interference**: two VMs were running during part of the collection. Stopped them and re-ran once — no clear difference (~−0.7%). But that is one sample per side, not enough to exclude a small effect.
- **Baseline drift**: of 45 baseline checks, 34 VALID, 8 VALID_WITH_NOTE, 3 UNSTABLE (max 21.03%, all at the highest-load config).

---

## An unverified explanatory hypothesis

**This chapter is not a conclusion.** It places the speed numbers into an arithmetic frame to see whether they are self-consistent. The frame is derived by back-solving speed against bandwidth constants; this report has no independent evidence for it.

Per token this model moves ≈1.75 GB of expert weights (ratio estimate from total/active parameters):

| cache | measured decode | required bandwidth | reference ceiling | closure |
|---|---|---|---|---|
| 0 | 26.806 t/s | 46.9 GB/s | memory ~48 GB/s (back-derived) | 97.7% |
| 10752 | 80.673 t/s | 141.2 GB/s (if every token missed) | PCIe 24.45 GB/s | — |

Under the assumption that PCIe is fully saturated, an implied hit rate of **82.7%** falls out. **That number is an output of the assumption, not a measurement.**

An earlier draft presented the memory-side and PCIe-side derivations as a "cross-check." That was wrong: both sides reuse the same speeds, the same bandwidth constants and the same 1.75 GB estimate, so their agreement is algebraic, not evidential. **This report explicitly retracts that framing.**

Establishing the model would require at least one of: PCIe throughput measured with a DMA benchmark, per-token hit-rate logs, or a per-layer expert transfer ledger. This report has none of the three.

---

## Relationship to prior work

| Work | Established | What this report adds |
|---|---|---|
| ChaeWoo Son (2026-10-05), same model | substitution +5.7% PPL, selective fetch +0.35% | fetch-only as shipped in llama.cpp: no change at four decimals, across 4 cache sizes |
| adrianhoehne, "MoE Hot Cache PP Journey" | prefill-side break-even at 31–32% hit rate | a complete decode-side 10-point curve, including the cache=0 baseline |
| llama.cpp Wiki, "Short Prompt MoE Comparison" | cache changes the numerical path; tokens may differ | no change at four decimals in this implementation; sample size limited, the warning is not excluded |
| llama.cpp issue #26432 | AMD GTT overflow, 60% speed loss, no error | **similar degradation pattern** on NVIDIA 16 GB (71% loss); same migration mechanism not verified |
| jundot/omlx PR #2343 | repeated fill 1.9× faster than real code (MTP) | random tokens 38% faster than real text; repeated prompt 19% faster than diverse |
| Olson et al., ACL/EMNLP 2025 Findings | MoE semantic routing statistically significant | routing not directly tested here; background only |

All comparisons are directional. Hardware, implementation and test protocol differ in every case; **none is a head-to-head experiment.**

---

## Practical advice

Applies to "16 GB-class VRAM + large cache + single card."

1. **On this tested config, don't lower `ncmoe` to put more layers on the GPU.** With the cache already occupying most of VRAM, every measurement in this round showed a large regression, and the failure is silent. Cache and static offload were not adjusted jointly.
2. **Benchmark with your target workload.** In this batch, random tokens ran ~38% faster than real text; both numbers are specific to this input set, but the direction suggests synthetic inputs overstate real throughput.
3. **Confirm PCIe width before forming expectations.** If the model in Section 4 holds, x8 would lower the ceiling substantially; the magnitude is unmeasured and no quantitative claim is made.

---

## Limitations

| # | Limitation | Impact |
|---|---|---|
| L1 | CPU Tctl and DIMM temperature unreadable (no ACPI thermal zone, no HWiNFO) | "abort above 95 °C" rule could not be enforced |
| L2 | One machine only | cross-platform inference unverified |
| L3 | 82.7% hit rate is back-solved | not a logged value |
| L4 | Why random tokens are faster was not measured separately | routing explanation is inference |
| L5 | PPL covers 20 chunks | not full-test-set perplexity |
| L6 | 10-prompt check is qualitative only | 8/10 both ways, but only 5/10 byte-identical |
| L7 | PCIe effective bandwidth uses the common 24.45 GB/s estimate | no DMA benchmark |
| L8 | Single model, single quantization (Q4_K_M) | does not generalise to other MoE architectures |
| L9 | Hit rate not obtained on the speed path | not emitted under this termination method; not proven impossible |
| L10 | Single CCD only | cross-CCD behaviour untested |

---

## Reproduce

- **Full report**: [docs/](https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617/tree/master/docs) — the v2.0 DOCX is written in Chinese; this Markdown file is the English edition
- **Raw data**: `data/` — per config `run1/2/3.jsonl`, `server.log`, telemetry CSV
- **Serve config**: `tools/serve/` — best parameters and measured notes
- **Figure data**: `data/05-environment/FIGURE-DATA.csv`

Every number in the report maps to a source file. If a value disagrees with the repo, the repo wins.

---

## Errata

This report is v2.0, revised from v1.0/v1.1 after two rounds of external review. Main corrections:

1. **The "median" was actually the maximum.** The script used `[int](3/2)`, which rounds to 2, selecting the largest of three samples. Fixed to take the middle value; all summaries regenerated.
2. **"Three independent processes" was three requests in one process.** The script starts one server per config and loops inside it. Reworded; cross-process repeatability listed as unverified.
3. **Figure 4's median convention and provenance.** The original 68.12 / 93.51 are in fact the standard medians of the B run's 50 samples — the data were sound; the figure simply did not state its source. The review also surfaced that the older log lines' "median" was the 26th value; everything now uses standard medians.
4. **The circular "cross-check"** is explicitly retracted (Section 4).
5. **The collapse criterion** is now recorded as three separate symptoms rather than one boolean (Result 3).
6. **CPU mask description.** `0x5555` is entirely inside CCD0; the earlier "2 physical cores per CCD" was wrong.

---

*This is a single-machine exploratory measurement. It supports "on this 16 GB card and workstation, the specified workload gets a large speedup." Mechanism confirmation, full quality assurance, and consumer-platform reproduction remain future work.*
