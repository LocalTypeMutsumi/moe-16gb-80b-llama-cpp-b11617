# G20  ·  ccd4 / ncmoe 40 / moe-cache 6144 / -t 32

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 40 |
| moe-cache-mib | 6144 |
| 线程数 | 32（batch 32） |
| CCD 数 | 4 |
| 亲和掩码 请求 / 实际 | `0xFFFFFFFFFFFFFFFF` / `0xFFFFFFFFFFFFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 20 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 49.707 | 18.583 | 8751.346 | 10116.726 | 435 | 189 | 18.91 |
| 2 | 88.071 | 19.567 | 4939.22 | 9607.995 | 435 | 189 | 14.55 |
| 3 | 87.446 | 19.413 | 4974.502 | 9684.31 | 435 | 189 | 14.66 |
| **中位数** | **87.446** | **19.413** | | | | | **14.66** |
| **极差** | 38.364 | 0.984 | | | | | 4.36 |
| 首遍偏差 | -43.2% | -4.3% | | | | | |

### 3. 关键观测

- `tg_splits = 42`（cache>0，期望塌缩为常量 46）
- `pp_splits = 122`，graph nodes = 5433 / 5713，pp bs=512 / tg bs=4
- **权重账本**：CUDA 8930.6 MiB + CPU_Mapped 38818.9 MiB = **47749.5 MiB**（121 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **6** / avg **2.19**；进程核数 max **1.06**（采样 70 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **10** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35, 40`
- 高负载核索引（平均≥5%）：`18, 28, 32, 33, 34, 35, 40`
- VRAM 峰值 **15608 MiB**；GPU 利用率 avg 58.53 / max 100；功耗 avg 65.5 W / max 89.3 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（42）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（70 个 / 69.28 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.18.508.436 I sched_reserve: reserving ...
0.18.530.483 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.18.530.491 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.18.530.496 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5713, splits = 122 / 42, input objects = 4 / 4, input tensors = 10 / 10
0.18.530.498 I sched_reserve: reserve took 22.06 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 8930.6 |
| CPU_Mapped (mmap) | 121 | 38818.9 |
| Host | - | 0.0 |
| **合计** | | **47749.5** |

CPU 侧张量块尺寸种类：166.92 MiB, 288 MiB, 420 MiB

### 7. 采样统计

```json
{
  "samples": 70,
  "span_s": 69.28,
  "rate_hz": 1.01,
  "nbusy_max": 6,
  "nbusy_avg": 2.19,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.8,
  "nbusy50_p95": 1,
  "nbusy1_max": 42,
  "nbusy1_avg": 24.4,
  "nbusy1_p95": 41,
  "pcores_max": 1.06,
  "pcores_avg": 0.86,
  "pcores_p95": 1.05,
  "cpu_max": 8,
  "cpu_avg": 3.9,
  "cpu_p95": 8,
  "mem_max": 15608,
  "mem_avg": 12213.01,
  "mem_p95": 15603,
  "gu_max": 100,
  "gu_avg": 58.53,
  "gu_p95": 95,
  "pw_max": 89.3,
  "pw_avg": 65.5,
  "pw_p95": 88.3,
  "pws_max": 31894,
  "pws_avg": 22001.04,
  "pws_p95": 31894,
  "pthr_max": 74,
  "pthr_avg": 72.1,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 71.86,
  "maxcore_p95": 100,
  "pcpu_max": 59.16,
  "pcpu_avg": 26.46,
  "pcpu_p95": 56.33,
  "core_count": 64,
  "per_core_busy_avg": [
    0.01,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.1,
    0.07,
    0.03,
    0.03,
    0.01,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.07,
    0.03,
    0.0,
    0.03,
    0.31,
    0.39,
    0.34,
    0.34,
    0.0,
    0.0,
    0.0,
    0.0,
    0.14,
    0.07,
    0.0,
    0.04,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.01,
    0.06,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0
  ],
  "per_core_load_avg": [
    0.6,
    4.2,
    3.6,
    3.9,
    3.9,
    3.9,
    4.0,
    3.9,
    3.6,
    3.9,
    3.8,
    4.1,
    3.9,
    3.9,
    4.0,
    3.8,
    1.0,
    1.3,
    5.4,
    3.7,
    1.9,
    1.6,
    1.8,
    2.5,
    1.0,
    0.9,
    0.8,
    1.3,
    5.2,
    3.3,
    2.0,
    3.0,
    19.9,
    29.4,
    22.3,
    26.0,
    3.7,
    4.0,
    3.8,
    3.9,
    7.9,
    4.6,
    2.8,
    4.2,
    4.0,
    3.9,
    3.8,
    3.8,
    1.0,
    1.4,
    1.8,
    2.5,
    1.1,
    2.0,
    1.1,
    2.4,
    1.1,
    1.6,
    3.8,
    1.0,
    0.8,
    2.2,
    1.3,
    1.2
  ],
  "busy_core_span": {
    "cores_ever_busy": 10,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    32,
    33,
    34,
    35,
    40
  ],
  "peak_core_list": [
    18,
    28,
    32,
    33,
    34,
    35,
    40
  ]
}
```
