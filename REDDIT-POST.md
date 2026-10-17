# Reddit r/LocalLLaMA 发帖稿（v2.0，与报告一致）

**标题候选（选一个）**

1. `80B MoE on a 16GB card: 26.8 → 80.7 t/s with expert caching, plus the two things that will bite you`
2. `Expert caching on a 16GB card: what it bought me (3x), where it collapses, and what I could not prove`
3. `Qwen3-Next-80B-A3B on a 4070 Ti Super: a measured cache curve, a cliff at ncmoe 44, and a bandwidth story I can't verify yet`

推荐 **1**（有具体数字、有钩子、没有过度声称）。

---

**正文**

I've been running Qwen3-Next-80B-A3B-Instruct Q4_K_M (80B total / 3B active, 512 experts, 10 per token) on a single RTX 4070 Ti SUPER 16 GB via llama.cpp b11617.

Short version: expert caching took decode from **26.8 to 80.7 t/s** on my workload. There's a valley at small cache sizes, a cliff the moment you lower `ncmoe`, and a ~38% gap depending on what kind of input you feed it. Everything below is one machine, and I'll be explicit about what I did **not** verify.

**Specs:** RTX 4070 Ti SUPER 16 GB (PCIe 4.0 x16, confirmed gen4 x16 under load 3/3 samples) · Threadripper PRO 5975WX · 4×32 GB DDR4-3200 (4 of 8 slots, never downclocked) · Windows Server 2025 · llama.cpp b11617 (commit `14310190c`).

**Measurement protocol** (this matters for the numbers): one `llama-server` process per config, **3 scored requests inside that process**, and a 128-token same-prompt baseline before and after each scored request to watch for drift. Those baseline requests themselves warm the cache — so every number here is a **warm-cache protocol**, not cold-start. If your workload is one-shot requests, expect lower.

---

## 1. Expert cache did not change the output, as far as I can measure

Teacher-forced perplexity, WikiText-2, 512 ctx, 20 chunks, `ncmoe 48`:

| cache (MiB) | PPL | std err |
|---|---|---|
| 0 | 4.4617 | 0.14700 |
| 512 | 4.4617 | 0.14700 |
| 2048 | 4.4617 | 0.14700 |
| 10752 | 4.4617 | 0.14700 |

Identical to 4 decimals. Before anyone asks "did the cache even turn on" — yes:

```
CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

Two honest caveats: this is **20 chunks**, and it's the **4-decimal** view. It is not a bit-identical claim, and perplexity does not cover the decode path. What I can say is "no change I could detect with this instrument", not "provably lossless".

---

## 2. The speed curve is not monotonic — there's a valley

`ncmoe 48`, 3 requests per config:

| cache MiB | decode t/s |
|---|---|
| 0 | 26.806 |
| **512** | **20.414** |
| 1024 | 30.001 |
| 1536 | 32.424 |
| 2048 | 35.788 |
| 3072 | 42.486 |
| 4096 | 49.222 |
| 6144 | 61.675 |
| 8192 | 69.718 |
| **10752** | **80.673** |

A 512 MiB cache is **slower than no cache at all** (−23.8%). Break-even against `cache=0` sits between 512 and 1024 MiB — roughly the same order as the ~1200 MiB prefill-side break-even others have reported. Past that it keeps climbing; I saw no saturation at 10752.

So "just set some cache" is not the advice. A small cache is a pessimization: you pay the bookkeeping and the misses, and the hits don't cover it yet.

---

## 3. Lowering `ncmoe` collapses throughput — and the criteria don't all fire

`cache 10752`, 3 requests per config. This is the part people get bitten by:

| ncmoe | decode t/s | VRAM peak MiB | GPU util | power W | drop vs 48 |
|---|---|---|---|---|---|
| **48** | **80.144** | 14887–14912 | 85–86% | 77–160 | — |
| 44 | 23.639 | 15762–15830 | 95–97% | 63–92 | −70.5% |
| 40 | 19.547 | 15801–15811 | 97–100% | 63–90 | −75.6% |
| 36 | 17.443 | 15816–15831 | 100% | 64–89 | −78.2% |
| 34 | 15.818 | 15929–15935 | 100% | 65–82 | −80.3% |
| 32 | 15.108 | 15917–15924 | 100% | 62–84 | −81.2% |

There is a **cliff between the tested points 48 and 44**, and it is silent: no OOM, no error, no warning. The GPU is busy, power is *lower* than normal, and throughput is 3–4x down.

I originally wrote a tidy three-symptom criterion (util ≥99% **and** power <90 W **and** drop >25%) and labelled whole rows "collapsed". Then I went back to the raw per-run records:

| ncmoe | util run1 / run2 / run3 |
|---|---|
| 48 | 85 / 86 / 85 |
| 44 | 95 / 95 / **97** |
| 40 | 97 / 100 / 97 |
| 36, 34, 32 | 100 / 100 / 100 |

So 44 **never reaches 99%**, and 40 gets there in only **1 of 3 runs**. The criterion is partially self-defeating on this data. In the report I now record the three symptoms separately instead of collapsing them into one yes/no, and label 44 "does not meet" / 40 "partially meets" rather than "collapsed".

The budget story fits the direction but is not a ledger:
```
16376 MiB total − 917 desktop = 15459 available
cache 10752                   ≈ 10751
left for expert layers        ≈  4708  →  ~4.7 layers at 0.94 GB each
```
That ignores compute buffers, context and fragmentation, and I never built a per-layer tensor ledger. It points in the right direction; it does not locate the mechanism. Points 45/46/47 were not tested, so 48 is the best *tested* setting, not a global optimum.

---

## 4. Input type moves the number by ~38%

5 processes × 10 length-matched pairs (within ±2 tokens), 256 output tokens:

| input | standard median decode |
|---|---|
| real text (10 different prompts) | **67.54 t/s** |
| random token IDs (same lengths) | **93.61 t/s** |

A second independent run an hour earlier gave **68.12 / 93.51**. Both are 50-sample **standard medians** (mean of the 25th and 26th sorted values) — worth stating, because llama.cpp's own log lines report a median that is actually the 26th value, which is systematically ~0.2% higher. If you diff my numbers against your own, check which median convention the tooling used.

And a second trap: the **same** prompt repeated hits **80.9 t/s**, vs **68.0** when cycling 10 different prompts (+19%). Be careful with the interpretation though: those two runs differ in **prompt content as well as repetition**, so I can't attribute the 19% to repetition alone. I didn't separate the two.

Practical takeaway: `tg` numbers from random-token benchmarks overstate real-text throughput on this setup. If you quote a community number as real-world speed, you may be off by a third.

---

## 5. Why it might be PCIe-bounded — a hypothesis I could not verify

This is the part I'd most like someone else to test, and the part I'm least entitled to claim.

Per token this model moves ≈1.75 GB of expert weights. Reverse the speed:

```
cache=0    : 26.806 t/s × 1.75 GB = 46.9 GB/s   vs a back-derived ~48 GB/s RAM reference
cache=10752: 80.673 t/s × 1.75 GB = 141.2 GB/s  vs 24.45 GB/s available over PCIe 4.0 x16
```

The second line says: either the hit rate is high, or the 1.75 GB estimate doesn't apply to this config. If you assume PCIe is fully saturated, you back out an implied hit rate of **~82.7%**.

**That 82.7% is an output of the assumption, not a measurement.** I could not get a per-token hit-rate line out of `llama-server` under this test's termination method, and the 1.75 GB figure is a ratio estimate, not a tensor-level ledger. An earlier draft presented a two-sided "cross-check" of this — it wasn't one: both sides reuse the same speeds, the same bandwidth constants and the same 1.75 GB guess. I've retracted that.

So: there are two arithmetic constraints that both *fit*, and that's all I can say. If someone with a x8 slot, or a second machine, wants to test the prediction that the ceiling tracks PCIe width rather than RAM bandwidth — that would settle it. I only have one machine.

---

## 6. What I did NOT measure

- **CPU/DIMM temperature**: unavailable on this box (no ACPI thermal zone, no HWiNFO). The "abort above 95 °C" rule could not be enforced, and this host has a known RAM-cooling incident in its history.
- **PPL coverage**: 20 chunks, not the full test set. Not a benchmark score.
- **Quality on the decode path**: the 10-prompt sanity check (4 GSM8K + 4 HumanEval + 2 MMLU) scored 8/10 with cache off and 8/10 with cache on, but only 5/10 outputs were byte-identical. Qualitative only. I would not quote it as a benchmark.
- **Cross-process repeatability**: all repeats are 3 requests inside one server process. I have not shown that a fresh process per batch gives the same numbers.
- **CPU parallelism**: my mask (`0x5555`) actually selects logical CPUs 0,2,4,6,8,10,12,14 — which on this topology are **all inside CCD0**, i.e. 8 cores/8 threads on one CCD. So I have *not* tested "more CCDs doesn't help"; that claim was never run here.
- **Hyper-V interference**: two idle VMs were up during part of the collection. Stopping them changed the key config by ~0.7%, within noise — but that was one sample per side, so it only rules out a large effect.

---

## Reproduce

Raw per-run JSON, telemetry CSVs, scripts, and perplexity stderr logs:
**`https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617`**

Each config is a directory with `run1/2/3.jsonl`, `server.log`, and a telemetry CSV. The `--moe-cache-mib` and `-ncmoe` values are in `meta.json`.

Happy to run configs people care about — say the word.

---

## If you take one thing away

The silence is the dangerous part. When a 16 GB card runs out of room for the thing you asked it to cache, it does not fail — it just gets slower, with the GPU reporting busy and the power draw going *down*. If you're tuning MoE offload by eyeballing nvidia-smi, you will read that as success.
