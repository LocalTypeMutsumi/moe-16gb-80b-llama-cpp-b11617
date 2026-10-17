# 一组 MoE 专家缓存的实测数据：有一类配置被判定为「跑不动」，实测 80.7 t/s

> English summary at the bottom.

先说清楚来意：**提供一组实测数据给项目参考**，顺带指出它撞上的一个边界。

另外先自我更正一句——我最初以为项目没考虑 MoE，读了 `calc.ts` 之后发现**是考虑的**（`active_params_b` 参与计算，DeepSeek V4 / GPT-OSS 120B / Gemma 4 26B A4B 这些 MoE 模型也都在库里）。真正的问题在别处，见下。

我这是这个仓库的第一个 issue，如果内容不合适或者不需要，直接关掉就行。

---

## 撞到的是 `fit` 判定和 offload 模型，不是 MoE 支持

`src/calc.ts` 里的判定：

```js
const usable = hw.vram_gb * 0.93;                       // 16 GB 卡 ≈ 15.2 GB
const total  = w + kv + 0.6;                            // 权重 + KV + 开销
const fit = total <= usable ? 'fits'
  : (hw.vendor !== 'apple' && total <= usable * 2.4 ? 'partial' : 'no');
```

上面这个模型文件是 **46.64 GB**。对 16 GB 卡：

- `usable ≈ 15.2 GB`
- `partial` 的上限是 `usable × 2.4 ≈ 36.5 GB`
- 46.64 GB **超过上限** → `fit = 'no'` → 页面上是「跑不动」

**但实测它能跑，而且不慢。**

`partial` 分支的双带宽模型（L84–L93）也覆盖不到这个场景：

```js
gpuShare = usable / total;
t = (gpuShare * aw) / (gpu_bw * eff) + ((1 - gpuShare) * aw) / OFFLOAD.ram_bw_gbs;
```

它假设「放不下的那部分权重在**系统内存**里，按 ~55 GB/s 流式读取」。而实际的 **专家 offload** 是另一回事：专家权重常驻内存，但每个 token **只取当前路由到的那一小部分**，而且其中大部分能在显存里的专家缓存中命中。所以真正走 PCIe 的数据量远小于「溢出份额 × 全量激活权重」。

---

## 数据

**硬件 / 软件**

| 项 | 值 |
|---|---|
| GPU | RTX 4070 Ti SUPER，**16376 MiB** |
| CPU | Threadripper PRO 5975WX（32C/64T） |
| 内存 | 4 × 32 GB DDR4-3200（4 通道） |
| 引擎 | llama.cpp **b11617**（commit `14310190c`，CUDA 12.4） |
| 模型 | Qwen3-Next-80B-A3B-Instruct **Q4_K_M**（80B 总 / 3B 激活，512 专家，每 token 用 10 个，**46.64 GB**） |
| PCIe | 4.0 ×16（负载下 3/3 采样为 gen4 ×16） |

**测试协议**（影响数字解读）：每个配置一个 `llama-server` 进程，进程内 3 次计分请求取中位数；每次计分请求前后各一次 128-token 同提示基线。⇒ **warm-cache 口径，不是冷启动。**

### 曲线 1：专家缓存容量 → 速度（`-ncmoe 48` 固定）

| `--moe-cache-mib` | decode t/s | 显存峰值 MiB |
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

1. **曲线是 V 型**：512 MiB 比完全不开缓存**还慢 23.8%**
2. 到 10752 MiB 仍在上升，**未见饱和**

### 曲线 2：`-ncmoe` → 速度（`cache 10752` 固定）

| `-ncmoe` | decode t/s | 相对 48 |
|---|---|---|
| **48** | **80.144** | — |
| 44 | 23.639 | −70.5% |
| 40 | 19.547 | −75.6% |
| 36 | 17.443 | −78.2% |
| 34 | 15.818 | −80.3% |
| 32 | 15.108 | −81.2% |

断崖在已测点 48 与 44 之间，**静默失效**：无 OOM、无报错，GPU 报忙，功耗反而低于满载。

### 曲线 3：输入类型（同配置，各 50 样本）

| 输入 | 标准中位数 decode |
|---|---|
| 真实文本（10 条不同 prompt） | **67.54 t/s** |
| 等长随机 token | **93.61 t/s** |

差约 **38%**。

---

## 一个能重现实测的简化式

```
per_token_bytes = active_expert_bytes × (1 − hit_rate)
tps ≈ PCIe_effective_bw / per_token_bytes
```

回代（`PCIe 4.0 ×16` 有效带宽按常见估值 24.45 GB/s，`active_expert_bytes ≈ 1.75 GB`，`hit_rate ≈ 0.827`）：

```
24.45 / (1.75 × 0.173) ≈ 80.8 t/s     实测 80.673
```

> 必须说明：这里的 `hit_rate` 是**在「PCIe 已跑满」假设下反解出来的**，不是测量值。所以这个式子证明的是「数据与该模型自洽」，**不是「模型已被证实」**。我不想把它说成比实际更强的证据。

---

## 如果要支持这类配置

大概是加第三种 offload 模式：

| 模式 | 参数 | 溢出对象 | 支配因素 |
|---|---|---|---|
| 层 offload（现有） | `-ngl N` | 整层在系统内存 | 溢出份额 × RAM 带宽 |
| **专家 offload（缺）** | `-ncmoe N` + `--moe-cache-mib` | 单层内的专家在系统内存 | **PCIe 带宽 × (1 − 命中率)** |

需要的新输入：**缓存容量**、**显存预算**。`hit_rate` 依赖输入内容的专家路由分布，很难先验预测，现实做法可能是按「固定提示重复 / 多样真实文本」给两档典型值，或者干脆做成滑块。

顺带两个容易踩的点：

- **`fit` 的 `usable × 2.4` 上限**会把这类型号一刀切成 `no`。是否可以把「有专家缓存可用」作为一档新的 fit 状态？
- **小缓存是负优化**：512 MiB 比不开还慢。如果默认给个「一点缓存」，在 512–1024 MiB 区间会偏乐观。

---

## 关于 `submissions.csv`

我看了贡献说明，数据走 PR 填 `benchmarks/submissions.csv`。但这组数据和现有字段对不上：

- 表里没有记录**缓存容量**的字段，而它正是这组数据的主变量
- 现有口径是 `llama-bench -p 512 -n 128`，而 `llama-bench` 不支持 `--moe-cache-mib`，且**每条样本重新随机生成 token** —— 曲线 3 显示随机 token 比真实文本快 38%，口径混在一起会和库里其它数据不可比

所以我没直接开 PR。两个方向，你挑一个我照做：

1. 给 `submissions.csv` 加一个可选字段（如 `moe_cache_mib`），我把上面 10 行按格式补进去，`notes` 里注明协议
2. 我按 `tg128` 口径重跑这几组，看能不能直接填

---

## 数据出处

- Discussion（完整报告 + 逐 run 原始记录）：https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617/discussions/1
- 仓库：https://github.com/LocalTypeMutsumi/moe-16gb-80b-llama-cpp-b11617

所有数字可指到原始文件；若与仓库数据不符，以原始数据为准。

---

## English summary

Correction first: **MoE is supported** — `active_params_b` is used in `calc()` and the library has DeepSeek V4, GPT-OSS 120B, Gemma 4 26B A4B. The gap is elsewhere.

**What breaks**: `fit` is `total <= usable ? 'fits' : (total <= usable * 2.4 ? 'partial' : 'no')`. On a 16 GB card `usable ≈ 15.2 GB`, so the `partial` ceiling is ~36.5 GB. A 46.64 GB MoE model (Qwen3-Next-80B-A3B Q4_K_M on a 4070 Ti SUPER) lands at **3.07×** and is classified **`no` — won't run**. It actually runs at **80.673 t/s**.

The `partial` branch also can't reach this case: it models spilled weights as streaming from **system RAM at ~55 GB/s**, but expert offload streams only the *non-hit* experts over **PCIe**, with a large resident cache absorbing most of the traffic.

**Measured** (llama.cpp b11617, one process per config, 3 scored requests, 128-token baselines around each — warm cache):

| `--moe-cache-mib` | 0 | 512 | 1024 | 2048 | 4096 | 6144 | 8192 | 10752 |
|---|---|---|---|---|---|---|---|---|
| decode t/s | 26.806 | **20.414** | 30.001 | 35.788 | 49.222 | 61.675 | 69.718 | **80.673** |

| `-ncmoe` | 48 | 44 | 40 | 36 | 34 | 32 |
|---|---|---|---|---|---|---|
| decode t/s | **80.144** | 23.639 | 19.547 | 17.443 | 15.818 | 15.108 |

Input type matters too: real text 67.54 vs random tokens 93.61 t/s over 50 samples each (**38%** gap).

A simple `tps ≈ PCIe_bw / (active_bytes × (1 − hit_rate))` reproduces the measurement (24.45 / (1.75 × 0.173) ≈ 80.8), though the hit rate is back-solved from the saturation assumption — so it demonstrates self-consistency, not proof.

Suggestion: add **expert offload** as a third mode (inputs: cache size, VRAM budget; hit rate as a tunable assumption), and consider letting expert-capable configs escape the `usable × 2.4` cutoff.

I didn't open a PR to `submissions.csv`: no field for cache size, and `llama-bench`'s `tg128` regenerates random tokens (the 38% gap above), which wouldn't be comparable with the existing rows. Happy to extend the schema or re-run in `tg128` format — whichever you prefer.
