# Hugging Face 发帖稿

**发在**：`https://huggingface.co/Qwen/Qwen3-Next-80B-A3B-Instruct-GGUF` → **Community** 标签 → New discussion

（选 GGUF 仓库而不是主模型页，因为这里的人就是用 llama.cpp 跑 GGUF 的，正好对得上。）

---

## 标题

```
Measured on a single 16 GB card: --moe-cache-mib / -ncmoe behaviour for Q4_K_M
```

---

## 正文

~~~markdown
Sharing a measurement in case it's useful for other people trying to fit this model on a small card.

**Setup**: RTX 4070 Ti SUPER 16 GB, Threadripper PRO 5975WX, 4×32 GB DDR4-3200, llama.cpp **b11617** (commit `14310190c`), this Q4_K_M GGUF (46.64 GB on disk), Windows Server 2025.

Decode on a single 4070 Ti Super: **26.806 t/s** with the expert cache off, **80.673 t/s** with `--moe-cache-mib 10752`. Roughly 3×. Same flags otherwise.

### What `--moe-cache-mib` does across its range

`-ncmoe 48` fixed, 3 scored requests per config:

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
| 10752 | **80.673** | 14749–14814 |

Two things that might save someone time:

**A small cache is worse than no cache.** 512 MiB came out 23.8% *slower* than cache=0. Break-even sits between 512 and 1024 MiB. "Let me set a few hundred MB" backfires.

**There's a cliff on `ncmoe`.** With cache pinned at 10752: 48 → 80.144 t/s, but 44 → 23.639 t/s (−70.5%), and it keeps falling to 15.108 at 32. It's silent — no OOM, no error, GPU looks busy and power draw actually *drops*.

### Input type matters more than I expected

50 samples each, same config:

| input | median decode |
|---|---|
| real text (10 different prompts) | **67.54 t/s** |
| length-matched random token IDs | **93.61 t/s** |

~38% apart. Worth knowing if you compare against `llama-bench` numbers — it regenerates random tokens per sample, so it lands on the right-hand number rather than the left.

### Full details

There's a longer write-up with all the raw per-run logs, telemetry CSVs, and the parts I could *not* verify:
https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617

I want to be explicit about one limit: the explanation for *why* this is fast (something about the PCIe link being the binding constraint) is **a hypothesis backed by arithmetic, not a proven mechanism**. I could not measure the cache hit rate directly on the decode path. So take the speed numbers as measured, and the mechanism as open.

Happy to run other `--moe-cache-mib` / `-ncmoe` points if anyone wants a specific config checked.
~~~

---

## 发帖说明

- **HF 的 Discussion 没有 karma 门槛**，但需要登录。
- 正文里带了 GitHub 链接，HF 对这类外链不敏感（不像 Reddit）。
- 结尾抛了「happy to run other points」——HF 的讨论氛围合适，会有人真的来问。
- **注意**：如果你要改标题，别用 `"..."` 引号包参数名，HF 标题会渲染成普通文本但看着乱。

---

## 如果 HF 也发不出去

那基本就是所有公开社区都卡「新账号」了。剩下的路只有：

1. **等**（Reddit 养号几周）
2. **找人代发**（在 GitHub Discussion 里请别人转发）
3. **自己建渠道**（GitHub Pages 或博客，这样链接是你自己的，贴哪儿都不受限）

第 3 条其实最稳——你现在已经有完整报告和仓库，加一个静态页面专门放这件事，成本很低。
