# Hacker News 发帖稿（Show HN）

**注意**：HN 的正文框是**纯文本**，不支持 Markdown。下面的正文已经按纯文本排好，
可以直接粘贴；**不要**往里贴 Markdown 表格，会变成一堆竖线。

---

## 标题

```
Show HN: MoE expert caching on a 16 GB card – 26.8 to 80.7 t/s, measured
```

（HN 标题上限 80 字符，这个 65 字符。）

---

## URL 字段

如果你用「标题 + URL」的形式发，填：

```
https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617/discussions/1
```

或者留空、用下面的正文自带链接。

---

## 正文（纯文本，直接粘贴）

```
I measured --moe-cache-mib and -ncmoe on a single RTX 4070 Ti SUPER (16 GB)
running Qwen3-Next-80B-A3B-Instruct Q4_K_M through llama.cpp b11617. The model
file is 46.64 GB, so it obviously doesn't fit; the point was to see what the
expert cache actually buys.

Short version: decode went from 26.806 t/s with the cache off to 80.673 t/s with
--moe-cache-mib 10752, at ncmoe 48. About 3x. Same flags otherwise.

Three things surprised me.

1. A small cache is worse than nothing. 512 MiB came out 23.8% SLOWER than
   cache=0 (20.414 vs 26.806 t/s). Break-even is somewhere between 512 and
   1024 MiB. The intuitive move -- "let me give it a few hundred MB" -- costs
   you throughput.

2. There's a silent cliff on ncmoe. Cache pinned at 10752: ncmoe 48 gives
   80.144 t/s, but 44 gives 23.639 (-70.5%), and it keeps falling to 15.108 at
   ncmoe 32. No OOM, no error, GPU reports busy, and power draw actually drops
   below what you'd see at full load. If you tune by watching nvidia-smi you
   will read that as success.

3. Input type moves the number by ~38%. Same config, 50 samples each: real text
   67.54 t/s, length-matched random token IDs 93.61 t/s. Relevant because
   llama-bench regenerates random tokens per sample, so its numbers sit on the
   high side of that gap.

What I could NOT establish: an explanation. The numbers are consistent with the
PCIe link being the binding constraint (roughly: 141 GB/s required if every
token missed, 24.45 GB/s available), and that back-solves to an ~83% implied hit
rate. But that hit rate is derived from the same speeds and the same bandwidth
constants it's supposed to explain -- circular. I couldn't get a per-token hit
rate out of llama-server under the termination method I used, and the
1.75 GB/token figure is a parameter-ratio estimate, not a tensor ledger. So:
measurements are measured, mechanism is open.

Other limits: one machine, one quantization, weights offloaded to system RAM
(4x32GB DDR4-3200, four channels), and the CPU mask I used (0x5555) happens to
land entirely inside one CCD on this CPU -- 8 threads, single CCD. So I have not
actually tested whether more CCDs help or not.

Report, raw per-run JSON, telemetry CSVs and the serve config:
https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617

Happy to run other cache/ncmoe combinations if anyone wants a specific point.
```

---

## 发帖注意

| 项 | 说明 |
|---|---|
| **账号** | HN 需要登录，新账号第一条也可能是「示好」性质的评论更容易通过 |
| **时间** | HN 的黄金时段是美东上午（北京时间 20:00–23:00），别在凌晨发 |
| **标题** | 别改太多。HN 反感标题党，`Show HN:` 前缀必须保留 |
| **正文** | 不要出现「revolutionary」「game-changing」这类词，HN 会直接踩 |
| **链接** | 正文里放 GitHub 链接没问题，HN 对开源项目很宽容 |
| **礼貌** | 如果有人质疑，回复要短、要给数据，不要辩论 |

---

## 为什么 HN 版要这么写

HN 的读者和 Reddit 完全不同：

| | Reddit | HN |
|---|---|---|
| 关心 | 「这东西好玩吗」 | 「你的方法站得住吗」 |
| 反感 | 营销腔、夸大 | 没有边界、不给数据 |
| 加分 | 故事、体验 | **明确说明你没验证什么** |

所以 HN 版我刻意把「**What I could NOT establish**」单独成段——那一段在 HN 是加分项，
在 Reddit 是减分项（那边的人会觉得你不自信）。同一个事实，两种写法。
