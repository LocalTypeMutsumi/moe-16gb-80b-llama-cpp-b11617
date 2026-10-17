# r/llamacpp 发帖稿

**标题候选**

1. `80B MoE on a 16GB card: what --moe-cache-mib and -ncmoe actually do (measured)`
2. `Tuning --moe-cache-mib / -ncmoe for Qwen3-Next-80B on a 4070 Ti Super 16GB`
3. `A config that runs 80B MoE on 16GB at 80 t/s, and the two settings that will silently ruin it`

推荐 **1**。

---

**正文**

Runs on a single 4070 Ti SUPER (16 GB), llama.cpp **b11617**. Model is Qwen3-Next-80B-A3B-Instruct Q4_K_M — 80B total, 3B active, 512 experts, 10 per token, 46.64 GB on disk. That obviously doesn't fit in 16 GB, which is the whole point of the two flags below.

## The config

```sh
llama-server \
  -m Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf \
  -c 4096 -ngl 99 \
  -ncmoe 48 \
  --moe-cache-mib 10752 \
  -C 0x5555 --cpu-strict 1 -t 8 -tb 8 \
  -lm none -np 1
```

Decode: **80.673 t/s** on a repeated prompt, **67.54 t/s** on diverse real text. Same model, same box, same flags — the input is the difference.

Two caveats before you copy this:

- **`-C 0x5555` is machine-specific.** On my 5975WX it selects logical CPUs 0,2,4,6,8,10,12,14, which are all inside **CCD0** — so it's 8 threads on a single CCD. Compute your own mask for your topology.
- **These are warm-cache numbers.** See the protocol note at the end. Cold one-shot requests are slower.

## What `--moe-cache-mib` actually does

It keeps a slice of the expert weights resident in VRAM as a cache. Experts that miss get pulled over PCIe from system RAM. The curve is **not monotonic**:

| `--moe-cache-mib` | decode t/s | VRAM peak |
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

**512 MiB is 23.8% slower than no cache at all.** Small caches are a pessimization: you pay the bookkeeping and the misses, and the hits don't cover it yet. Break-even against cache=0 sits between 512 and 1024 MiB.

No saturation at 10752 — it was still climbing. On a 16 GB card that's roughly the ceiling anyway.

## What `-ncmoe` does, and where it falls off a cliff

`-ncmoe` sets how many layers keep their MoE weights on the CPU. Higher = more layers offloaded, less VRAM used, more PCIe traffic. With cache pinned at 10752:

| `-ncmoe` | decode t/s | drop |
|---|---|---|
| **48** | **80.144** | — |
| 44 | 23.639 | −70.5% |
| 40 | 19.547 | −75.6% |
| 36 | 17.443 | −78.2% |
| 34 | 15.818 | −80.3% |
| 32 | 15.108 | −81.2% |

The cliff is between the tested points **48 and 44**, and it is **silent**: no OOM, no error, no warning. GPU reports busy, and power draws *less* than at full load. If you're tuning by watching `nvidia-smi`, you will read that as success.

Points 45/46/47 were not tested, so 48 is the best *tested* value, not a proven optimum.

## Two things that surprised me

**1. A tiny cache is worse than nothing.** Already covered above, but it's worth repeating because the intuitive move ("let me give it a few hundred MB") backfires.

**2. Random tokens are ~38% faster than real text.** Same config, 50 samples each:

| input | median decode |
|---|---|
| real text (10 different prompts) | **67.54 t/s** |
| length-matched random token IDs | **93.61 t/s** |

If your `tg` numbers come from `llama-bench`, note that it regenerates random token IDs per sample — that's the column on the right, not the left. Repeating a single prompt also inflates (80.9 t/s vs 68.0), though that one also changes the prompt content, so I wouldn't attribute the whole 19% to repetition.

A related gotcha if you diff numbers against other tools: llama.cpp's log lines report a median that is actually the **26th** value of 50, which runs ~0.2% above the true median (mean of 25th and 26th). Mine use the standard one.

## Protocol (so you can compare fairly)

One `llama-server` process per config, **3 scored requests** inside it, and a 128-token same-prompt baseline before and after each scored request (for drift monitoring). Those baselines warm the cache — so all numbers here are **warm-cache**, not cold start. Prompt: 435 tokens, 256 generated, temperature 0.

## Limitations

- One machine, one model, one quantization.
- Single CCD only (mask above). Cross-CCD behaviour untested here.
- PPL was checked on 20 chunks of WikiText-2 at 4-decimal precision — no change across the 4 cache sizes, but that's "no change at display precision," not a bit-identical claim.
- The "why" (PCIe vs memory bandwidth) is a hypothesis I can't confirm on one box — details in the repo if you care, but it's explicitly not a conclusion.

## Repo

Configs, per-run `run1/2/3.jsonl`, telemetry CSVs, and the write-up:
**https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617**

Happy to run other cache/ncmoe combinations if people want specific points.

---

## 发帖注意

- **不要贴 GitHub issue 那个链接**（llmspeed 的），跟这篇无关。
- r/llamacpp 对「贴自己的仓库」比 r/LocalLLaMA 宽容，但**仍然建议先把正文写全**，链接放最后。
- 如果账号 karma 还是不够，先在这个 sub 里回一两帖再发。
- 标题别再带 `"..."` 引号（Reddit 标题里没问题，但如果之后用 `gh` 或脚本发帖，引号会被 shell 吃掉）。
