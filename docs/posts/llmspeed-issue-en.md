# MoE expert cache: a config the model classifies as "won't run" actually hits 80.7 t/s

*Correction up front: I initially assumed MoE wasn't modelled. After reading `calc.ts` I see it is (`active_params_b` is used, and the library includes DeepSeek V4 / GPT-OSS 120B / Gemma 4 26B A4B). The real issue is elsewhere — see below.*

This is the first issue on this repo; if it's off-topic or not useful, feel free to close it.

---

## What actually breaks: the `fit` cutoff and the offload model

From `src/calc.ts`:

```js
const usable = hw.vram_gb * 0.93;                       // 16 GB card ≈ 15.2 GB
const total  = w + kv + 0.6;                            // weights + KV + overhead
const fit = total <= usable ? 'fits'
  : (hw.vendor !== 'apple' && total <= usable * 2.4 ? 'partial' : 'no');
```

The model below is a **46.64 GB** file. On a 16 GB card:

- `usable ≈ 15.2 GB`
- `partial` extends to `usable × 2.4 ≈ 36.5 GB`
- 46.64 GB is **past that** → `fit = 'no'` → shown as "won't run"

**But it runs, and it isn't slow.**

The `partial` branch (L84–L93) can't reach this case either:

```js
gpuShare = usable / total;
t = (gpuShare * aw) / (gpu_bw * eff) + ((1 - gpuShare) * aw) / OFFLOAD.ram_bw_gbs;
```

It assumes the spilled share streams from **system RAM at ~55 GB/s**. Expert offload is a different regime: experts do live in system memory, but each token only fetches the ones its router picked, and most of those hit a resident **VRAM expert cache**. So far less than "spilled share × full active weights" actually crosses PCIe.

---

## Data

**Setup**

| | |
|---|---|
| GPU | RTX 4070 Ti SUPER, **16376 MiB** |
| CPU | Threadripper PRO 5975WX (32C/64T) |
| RAM | 4 × 32 GB DDR4-3200 (4 channels) |
| Engine | llama.cpp **b11617** (commit `14310190c`, CUDA 12.4) |
| Model | Qwen3-Next-80B-A3B-Instruct **Q4_K_M** (80B total / 3B active, 512 experts, 10 per token, **46.64 GB**) |
| PCIe | 4.0 ×16 (gen4 ×16 in 3/3 samples under load) |

**Protocol** (matters for reading these numbers): one `llama-server` process per config, 3 scored requests inside it, a 128-token same-prompt baseline before and after each scored request. ⇒ **warm-cache numbers, not cold start.**

### Curve 1 — expert cache size vs decode (`-ncmoe 48` fixed)

| `--moe-cache-mib` | decode t/s | VRAM peak MiB |
|---|---|---|
| 0 | 26.806 | 3502–3503 |
| 512 | **20.414** | 4079 |
| 1024 | 30.001 | 4654–4672 |
| 1536 | 32.424 | 5151–5250 |
| 2048 | 35.788 | 5677–5687 |
| 3072 | 42.486 | 6681–6688 |
| 4096 | 49.222 | 7727–7732 |
| 6144 | 61.675 | 9785–9801 |
| 8192 | 69.718 | 12128–12485 |
| **10752** | **80.673** | 14749–14814 |

Two things worth noting:

1. **The curve is V-shaped** — 512 MiB is **23.8% slower** than no cache at all
2. It was still rising at 10752 MiB; **no saturation observed**

### Curve 2 — `-ncmoe` vs decode (`cache 10752` fixed)

| `-ncmoe` | decode t/s | vs 48 |
|---|---|---|
| **48** | **80.144** | — |
| 44 | 23.639 | −70.5% |
| 40 | 19.547 | −75.6% |
| 36 | 17.443 | −78.2% |
| 34 | 15.818 | −80.3% |
| 32 | 15.108 | −81.2% |

Cliff between the tested points 48 and 44, and it's **silent**: no OOM, no error, GPU reports busy, power actually drops below full load.

### Curve 3 — input type (same config, 50 samples each)

| Input | standard median decode |
|---|---|
| Real text (10 different prompts) | **67.54 t/s** |
| Length-matched random tokens | **93.61 t/s** |

~**38%** apart.

---

## A simple expression that reproduces the measurement

```
per_token_bytes = active_expert_bytes × (1 − hit_rate)
tps ≈ PCIe_effective_bw / per_token_bytes
```

Plugging in (PCIe 4.0 ×16 effective bandwidth at the common 24.45 GB/s estimate, `active_expert_bytes ≈ 1.75 GB`, `hit_rate ≈ 0.827`):

```
24.45 / (1.75 × 0.173) ≈ 80.8 t/s     measured 80.673
```

> To be explicit: the `hit_rate` there is **back-solved under the assumption that PCIe is saturated** — it is not a measurement. The expression demonstrates that the data is self-consistent with this model, **not that the model is proven**. I don't want to overstate it.

---

## If you want to support this regime

Probably a third offload mode:

| Mode | Flags | What spills | Dominated by |
|---|---|---|---|
| Layer offload (existing) | `-ngl N` | whole layers to system RAM | spilled fraction × RAM bandwidth |
| **Expert offload (missing)** | `-ncmoe N` + `--moe-cache-mib` | experts within a layer | **PCIe bandwidth × (1 − hit rate)** |

New inputs needed: **cache size** and **VRAM budget**. `hit_rate` depends on how concentrated the expert routing is for a given input, which is hard to predict a priori — a slider, or two presets ("repeated prompt" / "diverse real text"), would be more realistic than a single number.

Two smaller observations:

- The `usable × 2.4` ceiling cuts this whole class of model to `no`. Could "expert cache available" become a new fit state rather than a hard rejection?
- **Small caches are a pessimization**: 512 MiB is slower than no cache. If the default is "throw some cache at it," the 512–1024 MiB range will predict optimistically.

---

## About `submissions.csv`

I read the contribution guide — data goes in via a PR to `benchmarks/submissions.csv`. This dataset doesn't fit the schema:

- No field for **cache size**, which is the main variable here
- The existing collection uses `llama-bench -p 512 -n 128`, but `llama-bench` doesn't support `--moe-cache-mib`, and it **regenerates random tokens per sample** — curve 3 shows that's ~38% faster than real text, so mixing these would make rows non-comparable

So I didn't open a PR. Two options — tell me which and I'll do it:

1. Add an optional field (e.g. `moe_cache_mib`) and I'll submit the 10 rows above in the current format, with the protocol noted in `notes`
2. I re-run these configs in `tg128` format and see whether they fit as-is

---

## Provenance

- Full report + per-run raw logs (Chinese, with an English edition in progress): https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617/discussions/1
- Repository: https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617

Every number maps to a source file. If anything disagrees with the repo, the repo wins.
