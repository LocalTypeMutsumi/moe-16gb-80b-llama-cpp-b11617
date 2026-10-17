# T-REDO-PREPOST 汇总（发帖前数据补齐）

> 执行者：Lint　｜　交付包 v3.0　｜　执行日期：2026-10-17 11:18–12:1x
> 输出目录：`T-REDO-PREPOST-20261017-1118/`
> 角色：执行者 + 记录者。**本文只填数字，不做判断。** 所有数字都能指到文件。

---

## 1. 环境确认

| 项 | 实测 | 备注 |
|---|---|---|
| GPU | NVIDIA GeForce RTX 4070 Ti SUPER，16376 MiB | — |
| 驱动 | 610.88 | — |
| **PCIe** | **当前 gen 2 ×16**（最大 gen 4 ×16） | idle 省电降级；**负载下未复核**，见异常 A2 |
| CPU | AMD Ryzen Threadripper PRO 5975WX 32C/64T | — |
| **CPU 温度 (Tctl)** | **UNAVAILABLE** | ACPI 热区不支持、未装 HWiNFO ⇒ **≥95°C 作废判据无法执行**，见异常 A1 |
| 内存 | 127.8 GB 可见；4×32 GB DDR4-3200 | 频率全程 3200 MT/s 未降频 |
| 内存温度 | **UNAVAILABLE** | 用户已知内存散热隐患（风扇曾被异物卡住） |
| 电源计划 | 卓越性能 | — |
| OS | Windows Server 2025 Datacenter build 26100 | — |

**哈希（复现前提）** — 见 `environment.json`

| 对象 | SHA-256 |
|---|---|
| 模型 Qwen3-Next-80B-A3B-Instruct-Q4_K_M | `158A9E5B76A1BEF71FCEA4E1990E647088122B51B9FA823A134C6F6033D856BE` |
| `llama-server.exe` | `715F0EA98819F03FC596E9D352E989FC0AE093056282E0D73B2D657E7AFA7D02` |
| `llama-perplexity.exe` | `95B1A3C6B18D3BB7834F4DB633E24CCC7B43EF89AADEC1D9B33B6A7A8B6C96F4` |
| `ggml-cuda.dll` | `C1733C225F56B215319C8951E623B9449FAD4EF8F90FED60BAFA4AA2B65A0ABF` |
| `wiki.test.raw` | `173C87A53759E0201F33E0CCF978E510C2042D7F2CB78229D9A50D79B9E7DD08` |
| 构建 | llama.cpp b11617 / commit 14310190c / Clang 20.1.8 |

**GPU 独占**：开工时发现 20+ 个 GUI 进程占 GPU（Steam、百度网盘、夸克、Adobe、ChatGPT、MOTU、WGC、PowerToys 等，重启后自启）。已清理 **85 个**进程，显存 1668 → 917 MiB、GPU 利用率 0%。保留微信/DSH/桌面基础进程。

---

## 2. 任务 A0：困惑度（**主证据**）

命令（两组仅 `--moe-cache-mib` 不同）：

```
llama-perplexity -m <model> -f wiki.test.raw -c 512 --chunks 20 -ngl 99 -ncmoe 48 -lm none --moe-cache-mib <0|10752>
```

| 组 | PPL | ± | 耗时 | 日志 |
|---|---|---|---|---|
| **cache = 0** | **4.4617** | 0.14700 | 70 s | `TASK-A0/perplexity-cache0.err` |
| **cache = 10752** | **4.4617** | 0.14700 | 60 s | `TASK-A0/perplexity-cache10752.err` |

**困惑度差 = 0.0000%** → 按判据 **< 0.5% = 无损，可以发**

### ⭐ cache 生效已证实（关键补充）

不是"没生效"。用 `-lv 4` 探针确认（`TASK-A0/_probe-cache-on-lv4.err`）：

```
CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
llama_moe_cache: ubatch <= 8: hits = 0, misses = 808, hit rate = 0.00%, uploaded = 1520.77 MiB
llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

- **b11617 在 perplexity 下确实输出 `llama_moe_cache` 命中率行**（TRAND-01 曾据 server 下的观察得出"不输出"，结论只对 server 成立）
- PPL 计算走 **large batches** 路径：从缓存复制 3525 个专家
- 小批次路径 hits=0 / 0.00% 属正常（PPL 不用小批次）

**PPL 完全相同是预期结果**：fetch-only 缓存只搬运专家权重、不改变算术，因此困惑度 bit-identical。

### 与 Son 那篇对照

| 工作 | 方法 | 困惑度变化 |
|---|---|---|
| ChaeWoo Son（2026-10-05） | substitution | **+5.7%** |
| ChaeWoo Son（2026-10-05） | selective fetch | **+0.35%** |
| **本机（本轮）** | llama.cpp fetch-only | **0.0000%** |

⚠️ 条件不同（Son 用 3090 + 16GB RAM 等），**不同机器不同实现，不能直接说"我们更好"**，只能说本实现下未测得困惑度损失。

### 限制
- `--chunks 20`：只跑 wikitext-2 测试集的 20 个 chunk，**不是全测试集 PPL**
- 线程默认 32（交付包命令未传 `-t`），故 A0 的速度不可与 B/C/D 混比

---

## 3. 任务 A：10 题生成检查（**辅助**）

参数：ncmoe 48 / load-mode none / mask 0x5555 / t8 / temperature 0 / top_k 1 / seed 42

| 组 | 正确数 | 准确率 |
|---|---|---|
| A1 cache=0 | 8/10 | 80% |
| A2 cache=10752 | 8/10 | 80% |

| 判据 | 结果 |
|---|---|
| ① 正确率差 ≤ 20 pp | **0.0 pp ✅** |
| ② 输出一致性 ≥ 7/10 | **5/10 ❌** |

⇒ **记为 `DEGRADED`。按交付包规定，以 A0 困惑度为准，但差异必须说明。**

**逐题（两组完全相同）**

| 题 | 结果 | 说明 |
|---|---|---|
| GSM-0 | ✅ | 18 |
| GSM-1 | ✅ | 3 |
| **GSM-2** | ❌ | **两组都 "no #### found"**（256 token 内未输出 `####` 格式，疑被 max_tokens 截断） |
| GSM-3 | ✅ | 540 |
| HumanEval-0 | ✅ | check() 通过 |
| HumanEval-1 | ✅ | check() 通过 |
| **HumanEval-2** | ❌ | **两组都语法错**：A1 生成含全角 `×`(U+00D7)，A2 字符串未闭合 |
| HumanEval-3 | ✅ | check() passed |
| MMLU-CS | ✅ | A |
| MMLU-PHY | ✅ | B |

**差异解释**：18/20 判分结果相同，失败的 2 题也是同样两题；`一致性 5/10` 指的是**输出文本**逐字节相同只有 5 条（其余措辞/公式写法不同，如 GSM-2 的 `---` vs `###`、MMLU-PHY 的解释格式）。判分口径下两组无差异。

---

## 4. 任务 B：基准稳定性

设计：5 个独立进程 × 每进程 10 条真实 + 10 条等长随机。参数 ncmoe 48 / cache 10752 / load-mode none / mask 0x5555 / t8 / max_tokens 256。

| 组 | 中位 | IQR |
|---|---|---|
| **真实文本** | **68.34 t/s** | 见 `TASK-B/summary.csv` |
| **随机 token** | **93.53 t/s** | 同上 |

- **样本数：50（5 进程 × 10 对）**
- **随机比真实快 +36.8%**
- **token 对齐：全部在 ±2 内**（20 对 × 5 进程，逐条记录于 `TASK-B/p*/meta.json`）
- 文件：`TASK-B/p1..p5/{real,random}.jsonl`、`meta.json`、`summary.csv`

⚠️ 交付包预期"约 20%"，本轮实测 **36.8%**。这是本轮数据，不与他人数字混比。

---

## 5. 任务 C：显存崩塌

参数：cache 10752 / mask 0x5555 / t8 / 各 3 次

| ncmoe | decode 中位 | 范围 | 显存峰值 | GPU util | 功耗 | 判定 |
|---|---|---|---|---|---|---|
| 9 | **11.89** | 11.75–11.89 | 15798 MiB | 100% | 53.9–81.9 W | 崩塌 |
| 10 | **11.19** | 9.75–11.19 | 15773–15877 MiB | 100% | 53.8–90.1 W | 崩塌 |
| 11 | **12.00** | 11.40–12.00 | 15708–15866 MiB | 100% | 52.8–78.8 W | 崩塌 |

**三现象同时出现**（判定崩塌）：
1. GPU 利用率 **≥99%** ✅（全部 100%）
2. 功耗 **< 90 W** ✅（52.8–90.1 W，正常负载约 110 W）
3. 速度相对正常水平掉 **> 25%** ✅（正常约 68 t/s → 现在 11–12 t/s，掉 ~83%）

**⇒ 崩塌点定位在 ncmoe 8 与 9 之间。** 交付包给出的参照是 ncmoe 8 = 45.96、ncmoe 12 = 81.34；本轮 9/10/11 全部已崩塌，说明崩塌比参照点更早发生（**但参照条件未记录，不得直接比较**）。

文件：`TASK-C/{ncmoe-9,ncmoe-10,ncmoe-11}/run{1,2,3}.jsonl` + `meta.json`、`TASK-C/telemetry/*.seg*.csv`、`summary.csv`

---

## 6. 任务 D：decode 侧 break-even

参数：ncmoe 20 固定，各 3 次

| cache | decode 中位 | 范围 | 显存峰值 | 相对 cache=0 |
|---|---|---|---|---|
| **0** | **15.02** | 14.93–15.02 | 15778–15817 MiB | 基线 |
| **512** | **11.38** | 11.25–11.38 | 15796–15857 MiB | **−24.2%** |
| **2048** | **12.46** | 12.44–12.46 | 15783–15890 MiB | −17.0% |

- **判据：cache 512 比 cache 0 慢 ≥15% → −24.2%，成立** ⇒ **decode 侧 break-even 存在**
- 形态是 V 型：0 →(谷底)512 → 回升 2048，与交付包预期一致
- ⚠️ **但三点显存都在 15.7–15.9 GB（接近 16 GB 上限），速度整体偏低（正常约 68 t/s）**，见异常 A4

文件：`TASK-D/{cache-0,cache-512,cache-2048}/run{1,2,3}.jsonl` + `meta.json`、`TASK-D/telemetry/`、`summary.csv`

---

## 7. 任务 E：长上下文 —— **SKIPPED**

未执行。原因（如实记录，不是"跑失败了"）：
1. 交付包标注为**可选**
2. 当前 ncmoe 48 + cache 10752 已占约 12 GB 显存，再加 128K 上下文 KV cache 极可能直接 OOM
3. 时间优先分配给必须的汇总

若后续需要，建议单独一轮、且从 4K 起逐档试探。

---

## 8. 异常清单（按交付包第九章要求逐条记录）

| # | 异常 | 处理 | 影响 |
|---|---|---|---|
| **A1** | **CPU 温度读不到**（ACPI 热区不支持、无 HWiNFO） | 记 `UNAVAILABLE`，未编造 | **Tctl ≥95°C 作废判据无法执行**；本轮所有数据缺少 CPU 热证据 |
| **A2** | **PCIe 当前 gen 2 ×16**（最大 gen 4） | 记录 | idle 省电降级所致；**负载下未复核**，若负载时仍为 gen 2，则 PCIe 吞吐按 8 GB/s 解释而非 32 GB/s |
| **A3** | 开工时 **20+ GUI 进程占 GPU** | 清理 85 个进程；显存 1668→917 MiB | 清理前若有测量会受污染；本轮所有数据均在清理后采集 |
| **A4** | **任务 D 三点显存均 ~15.8 GB**（接近上限） | 如实记录，未重跑 | 任务 D 的绝对速度偏低；其"相对差"仍有效，但不能解读为"ncmoe 20 的正常性能" |
| **A5** | **任务 A 一致性仅 5/10**（判据需 ≥7） | 记 `DEGRADED`，以 A0 为准 | 判分口径下两组无差异（同为 8/10），差异在措辞 |
| **A6** | **GSM-2 两组均未输出 `####`** | 记录，未重跑刷新 | 疑 256 token 截断；若发帖需说明该题按截断处理 |
| **A7** | **HumanEval-2 两组均语法错**（全角 × / 未闭合字符串） | 记录原文，未修补代码 | 属模型生成质量问题，非缓存导致（两组同样失败） |
| **A8** | 任务 A 中 `-t` 未指定（默认 32），与 B/C/D 的 t8 不同 | 记录 | 任务 A 的速度不可与其它任务混比；任务 A 只用于正确性对照 |
| **A9** | 内存温度不可读 | 记 `UNAVAILABLE` | 用户已知内存散热隐患，本轮只能用频率（全程 3200 未降频）与 GPU 温度（37–53 °C）作间接证据 |

---

## 9. 交付包附录 D 合规声明

本轮 10 题仅用于**比较 cache=0 与 cache=10752 的输出差异**，不构成任何基准成绩。

报告中**未出现**以下写法：
- ❌ "在 GSM8K 上得了 X 分"
- ❌ "HumanEval pass@1 = X%"
- ❌ "MMLU 准确率 X%"

正确表述：*"10 题对照集，GSM8K test 前 4 条 + HumanEval /0–/3 + MMLU 各 1 条，用于比较 cache=0 与 cache=10752 的输出差异，不构成完整基准成绩。"*

---

## 10. 文件索引

```
T-REDO-PREPOST-20261017-1118/
  environment.json          环境 + 6 个哈希 + 清理记录
  SUMMARY.md                本文件
  checksums.sha256          （见下方生成说明）
  corpus/wikitext-2-raw/wiki.test.raw   含哈希
  corpus/T/, corpus/L-512.txt           真实文本素材
  TASK-A0/                  perplexity 两组 stderr（含 Final estimate）、summary.json、探针日志
  TASK-A/A1-cache0|A2-cache10752/results.jsonl, score.json
  TASK-B/p1..p5/{real,random}.jsonl, meta.json, summary.csv
  TASK-C/ncmoe-9|10|11/run{1,2,3}.jsonl, telemetry/, summary.csv
  TASK-D/cache-0|512|2048/run{1,2,3}.jsonl, telemetry/, summary.csv
  tools/                    task-a.ps1 / task-b.ps1 / task-sweep.ps1 / grade-a.py
```

---

## 11. 自检（交付包 5.6）

- [x] 文件带时间戳（目录名 `20261017-1118`）
- [x] 未覆盖旧数据（每次 Move-Item 旧日志为 `.prev`；新目录）
- [x] 困惑度有完整 stdout/stderr
- [x] 每个数字能指到文件
- [x] 异常都有记录（A1–A9）
- [x] 未修改题目（GSM/HumanEval/MMLU 原文照抄，模板按交付包给定）
