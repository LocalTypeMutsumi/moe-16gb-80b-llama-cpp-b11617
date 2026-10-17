# Reddit 回复草稿（llmspeed 那个帖子）

帖子：https://www.reddit.com/r/LocalLLaMA/comments/1x83321/i_built_a_tiny_site_that_lets_you_feel_the/

**口径已按核实结果修正**：不说「没考虑 MoE」（它考虑了，用 `active_params_b`），
改说「一类配置被 `fit` 判定成跑不动」。

---

## 版本 A · 超短版（推荐先发）

> Nice framing — "feel it before you buy" beats another t/s table.
>
> One edge case worth a look: `fit` puts big-MoE-on-small-card at "won't run" — a 46.6 GB MoE (Qwen3-Next-80B, 80B total / 3B active) on a 16 GB card lands around 3× the usable VRAM, past the `usable * 2.4` cutoff. But with expert offload (`-ncmoe` + `--moe-cache-mib`) it actually runs at **80.7 t/s** (26.8 with cache off). Offload there streams only the *non-hit* experts over PCIe, not the whole spilled share from RAM — so the 55 GB/s RAM term overshoots what that path really costs.
>
> Minor too: if `gen_tps` comes from `llama-bench`, its `tg128` regenerates random tokens per sample, and random tokens ran **38% faster** than real text here (93.6 vs 67.5 t/s). Might be worth noting provenance on those rows.

约 110 词。

---

## 版本 B · 详细版（帖子底下已经在认真讨论时用）

> Nice execution. "Feel it before you buy" is a much better framing than another leaderboard — the measured / derived / projected labels are also more honest than most of what gets posted here.
>
> One edge case: the `fit` logic treats big-MoE-on-small-card as "won't run". `usable` is ~15 GB on a 16 GB card, `partial` only extends to `usable * 2.4`, and a 46.6 GB MoE model (Qwen3-Next-80B-A3B Q4_K_M) comes out at ~3× — so it lands on `no`.
>
> Measured, that config actually runs, with expert offload (`-ncmoe 48 --moe-cache-mib 10752`) on llama.cpp b11617:
>
> | expert cache | decode |
> |---|---|
> | 0 | 26.8 t/s |
> | 512 MiB | 20.4 t/s (slower than no cache!) |
> | 10752 MiB | **80.7 t/s** |
>
> The `partial` branch can't reach this case either: it models the spilled share as streaming from system RAM at ~55 GB/s. Expert offload is different — experts sit in RAM but only the *non-hit* ones cross PCIe per token, and a resident cache absorbs most of the traffic.
>
> Also, minor: if `gen_tps` comes from `llama-bench`, note `tg128` regenerates random token IDs per sample — random tokens ran **38% faster** than real text here (93.6 vs 67.5 t/s). Might be inflating part of the dataset.

---

## 版本 C · 带链接（只在对方主动问「数据在哪」时用）

在 A 或 B 末尾追加：

> Wrote it up with the raw per-run logs if it's useful for calibrating the offload path: https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617/discussions/1

---

## 策略说明

| 版本 | 什么时候用 |
|---|---|
| **A** | 默认。一屏读完，也最不像广告 |
| **B** | 帖子下面已经有人在深入讨论，或作者本人回复了 |
| **C** | 只有对方问起数据出处时才给 |

**不要一上来就放链接。** r/LocalLLaMA 对自我推广非常敏感。先纯技术交流，对方问了再给——那时候链接是「回答」，不是「推广」。

---

## 措辞上要注意的两点

1. **别写「your model doesn't handle MoE」** —— 它处理了（`active_params_b`）。写成这样会被作者一句话反驳，整条评论就废了。
2. **要点在「被判成跑不动」，不是「估得偏低」** —— 这是事实差异：`fit = 'no'` 是判定结论，不是数值误差。说「估低」反而显得我没读代码。

---

## 与 GitHub issue 的关系

GitHub 那边已经发了 issue #1（数据为主 + 指出 `fit` 边界 + 说明为什么没开 PR）。
Reddit 评论**不用重复长文**，只要做到两件事：

1. 让作者知道「有一类配置会被判死」
2. 给一个能自己验证的数字

剩下的他自己会去看 issue。
