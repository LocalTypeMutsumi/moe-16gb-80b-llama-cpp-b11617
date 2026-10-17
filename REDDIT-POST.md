# Reddit r/LocalLLaMA 发帖稿

**标题候选（选一个）**

1. `80B MoE on a 16 GB card: 68–81 t/s with expert cache, and the bandwidth model that fits (PCIe hypothesis)`
2. `Measured: no perplexity change from expert cache across 4 cache sizes, and where the bandwidth ceiling seems to sit`
3. `Qwen3-Next-80B-A3B on 4070 Ti SUPER 16 GB: 68–81 t/s and a bandwidth model I cannot yet prove`

推荐 **1**（信息量最大、直接点出可移植性）。

---

**正文**

I've been running Qwen3-Next-80B-A3B-Instruct Q4_K_M (80B total / 3B active) on a single RTX 4070 Ti SUPER (16 GB) via llama.cpp b11617. The interesting part isn't the t/s number — it's **where the ceiling actually sits**, because that decides whether your machine gets the same result.

**Specs:** 4070 Ti SUPER 16GB (PCIe 4.0 x16, verified under load) · Threadripper PRO 5975WX 32C/64T · 4×32GB DDR4-3200 · Windows Server 2025 · llama.cpp b11617 (commit 14310190c) · Q4_K_M.

> ⚠️ **本稿基于 v1.0 数据与「已撤回」的归因，不可直接发布。**
> 2026-10-17 外部审核后，报告中六项断言已撤回（见 `AUDIT-RESPONSE.md`）：
> 循环推断的命中率「交叉验证」、`0.0000%`、截断坐标轴的图、定量化的「x8 腰斩」等。
> 本文件仅保留作写作素材与叙事骨架；**发布前必须按 `README.md`（v1.1）逐段重写**。
> 需要同步的关键点：数值已修正（26.806 / 80.673 / 80.144），带宽归因降级为待验证假设。

## 0. Where the ceiling might be — and why that would matter

Per token this model moves ~**1.75 GB** of expert weights.

**cache=0** (all experts on CPU, re-read from RAM every token):

```
26.84 t/s × 1.75 GB = 47.0 GB/s     vs measured RAM ceiling 48 GB/s  → 97.9% closure
```

So cache=0 isn't "misconfigured" — it's saturating memory bandwidth. (4×DDR4-3200 is 102 GB/s on paper but only ~40–48 GB/s achievable here.)

**cache=10752 MiB** (hot experts resident, misses over PCIe):

```
80.81 t/s × 1.75 GB = 141.4 GB/s needed if every token missed
PCIe 4.0 x16        =  24.45 GB/s
⇒ allowed misses = 0.303 GB/token  ⇒ implied hit rate = 82.7%
```

**A "cross-check" that does not cross-check — retracted after audit.** An earlier version used the RAM-side and PCIe-side derivations as independent confirmation. They are not: both reuse the same speeds, the same bandwidth constants and the same 1.75 GB/token guess, so their agreement is algebraic, not evidential. The 82.7% hit rate is an output of that assumption, not a measurement.

**Why it should port:** in the cache configuration the RAM only needs to supply the ~24.45 GB/s that PCIe is pulling. Dual-channel DDR4-3200 measures ~30–35 GB/s, already enough. So the ceiling becomes **PCIe lane width** — a hardware constant:

| Platform | Effective PCIe BW | Expected ceiling |
|---|---|---|
| **PCIe 4.0 x16** (4070 Ti Super / 4080 / 3090) | 24.45 GB/s | **≈ 80 t/s** |
| PCIe 4.0 x8 (**4060 Ti 16GB**) | ≈ 12.2 GB/s | ≈ 40 t/s |
| PCIe 3.0 x16 | ≈ 12.6 GB/s | ≈ 41 t/s |

**A 4060 Ti 16GB has the VRAM but not the lanes.** If you're on x8, halve the expectation. (This is inference from bandwidth constants — I only have one machine, so treat it as a prediction, not a measurement.)

## 1. Expert cache doesn't change the output at all

Teacher-forced perplexity, WikiText-2 test, 512 ctx, 20 chunks:

| cache | PPL |
|---|---|
| 0 | 4.4617 ± 0.14700 |
| 512 | 4.4617 ± 0.14700 |
| 2048 | 4.4617 ± 0.14700 |
| 10752 | 4.4617 ± 0.14700 |

Identical to 4 decimals. Before anyone asks "did the cache even turn on" — yes:

```
CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

PPL runs go through the large-batch path and it serves 3525 experts from cache per pass. The reason PPL doesn't move is that fetching relocates expert weights without changing the arithmetic. So in this implementation the cache is a pure speed knob.

For context: ChaeWoo Son measured +5.7% PPL for *substitution* and +0.35% for *selective fetch* on the same model. Ours shows no change at 4-decimal precision on 20 chunks for fetch-only — not a bit-identical claim. Different hardware/implementation, so not a head-to-head — but the direction is consistent with "fetch doesn't alter numerics".

## 2. The decode curve has a real valley — and no saturation

`ncmoe 48`, 3 runs each:

| cache MiB | decode t/s |
|---|---|
| 0 | 26.84 |
| **512** | **20.42** |
| 1024 | 30.01 |
| 2048 | 35.81 |
| 4096 | 49.25 |
| 6144 | 61.76 |
| 8192 | 69.84 |
| **10752** | **80.81** |

Cache 512 is **slower than no cache at all** (−23.9%). Break-even against cache=0 is between 512 and 1024 — roughly where the prefill-side break-even (~1200 MiB) was reported. It keeps climbing to 10752; I did not see saturation.

## 3. `ncmoe` has a cliff at 44, and it's a VRAM competition problem

Cache 10752, 3 runs each. Collapse = GPU util ≥99% **and** power <90W **and** >25% drop, all three:

| ncmoe | decode t/s | VRAM | power |
|---|---|---|---|
| **48** | **80.92** | 14887–14912 | 77–160 W |
| 44 | 23.73 | 15762–15830 | 63–92 W |
| 40 | 19.58 | 15801–15811 | 63–90 W |
| 36 | 17.45 | 15816–15831 | 64–89 W |
| 34 | 15.84 | 15929–15935 | 65–82 W |
| 32 | 15.12 | 15917–15924 | 62–84 W |

The arithmetic matches the cliff exactly:

```
16376 - 917(desktop) = 15459 MiB
cache 10752          = 10751 MiB
left for layers      =  4708 MiB / 0.94 GB per layer ≈ 4.7
ncmoe 48 - 4         =  44  ← collapses here
```

The important part: **cache and ncmoe draw from the same pool**. If you lower ncmoe you must also lower cache, otherwise you get a silent 3–4× slowdown with **no OOM and no error** — GPU pegged at 100%, power flat under 90 W. Same signature as llama.cpp #26432 on AMD GTT, but on NVIDIA with the expert cache.

## 4. Random tokens overstate real speed by ~37%

5 processes × 10 pairs, length-matched within ±2 tokens:

| input | median decode |
|---|---|
| real text (10 different prompts) | **68.0 t/s** |
| random token IDs | **93.6 t/s** |

And a second trap: running the **same** prompt repeatedly hits **80.9 t/s** vs **68.0** when cycling 10 different prompts (+19%).

So "tg128 with random tokens" and "one prompt N times" both measure warm-cache cases. If you quote a community tg number as real-world speed, you may be off by up to ~37%.

(That also explains a discrepancy in my own logs: an earlier single-shot 74.18 vs a later 10-prompt 68.0 — not the same measurement.)

## What I did NOT measure

- CPU Tctl and DIMM temperature were **unavailable** on this box (no ACPI thermal zone, no HWiNFO). The "abort above 95 °C" rule could not be enforced, and this host has a known RAM-cooling issue.
- PPL uses 20 chunks of the test set, not the whole thing.
- The 10-prompt check (4 GSM8K + 4 HumanEval + 2 MMLU) scored 8/10 in both cache=0 and cache=10752 with 0 pp difference, but only 5/10 outputs were byte-identical — qualitative at best, not a benchmark result.
- Two idle Hyper-V VMs were up during part of collection. Stopped them and re-ran the key config: **80.267 vs 80.86 t/s (−0.7%)**, i.e. below noise.

## Repo

Raw per-run JSON, telemetry CSVs, scripts, and the perplexity stderr logs are here: **`https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617`**

Happy to add configs people care about — say the word and I'll run them.


