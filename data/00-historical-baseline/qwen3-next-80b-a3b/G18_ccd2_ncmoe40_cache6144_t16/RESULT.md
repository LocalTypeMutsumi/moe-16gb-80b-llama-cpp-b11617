# G18  ·  ccd2 / ncmoe 40 / moe-cache 6144 / -t 16

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 40 |
| moe-cache-mib | 6144 |
| 线程数 | 16（batch 16） |
| CCD 数 | 2 |
| 亲和掩码 请求 / 实际 | `0x0000FFFF0000FFFF` / `0x0000FFFF0000FFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 19 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 49.63 | 18.348 | 8764.784 | 10246.324 | 435 | 189 | 19.05 |
| 2 | 87.543 | 19.321 | 4968.977 | 9730.12 | 435 | 189 | 14.7 |
| 3 | 87.511 | 19.216 | 4970.809 | 9783.667 | 435 | 189 | 14.76 |
| **中位数** | **87.511** | **19.216** | | | | | **14.76** |
| **极差** | 37.913 | 0.973 | | | | | 4.35 |
| 首遍偏差 | -43.3% | -4.5% | | | | | |

### 3. 关键观测

- `tg_splits = 42`（cache>0，期望塌缩为常量 46）
- `pp_splits = 122`，graph nodes = 5433 / 5713，pp bs=512 / tg bs=4
- **权重账本**：CUDA 8930.6 MiB + CPU_Mapped 38818.9 MiB = **47749.5 MiB**（121 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **8** / avg **2.13**；进程核数 max **1.05**（采样 70 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **8** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`2, 32, 33, 34, 35, 40`
- 高负载核索引（平均≥5%）：`2, 28, 32, 33, 34, 35, 40, 43`
- VRAM 峰值 **15604 MiB**；GPU 利用率 avg 57.79 / max 100；功耗 avg 66.6 W / max 88.9 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（42）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（70 个 / 69.24 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.18.016.493 I sched_reserve: reserving ...
0.18.041.422 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.18.041.430 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.18.041.435 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5713, splits = 122 / 42, input objects = 4 / 4, input tensors = 10 / 10
0.18.041.437 I sched_reserve: reserve took 24.94 ms, sched copies = 1
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
  "span_s": 69.24,
  "rate_hz": 1.01,
  "nbusy_max": 8,
  "nbusy_avg": 2.13,
  "nbusy_p95": 5,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.87,
  "nbusy50_p95": 1,
  "nbusy1_max": 45,
  "nbusy1_avg": 24.29,
  "nbusy1_p95": 40,
  "pcores_max": 1.05,
  "pcores_avg": 0.86,
  "pcores_p95": 1.03,
  "cpu_max": 9,
  "cpu_avg": 3.64,
  "cpu_p95": 6,
  "mem_max": 15604,
  "mem_avg": 12041.07,
  "mem_p95": 15604,
  "gu_max": 100,
  "gu_avg": 57.79,
  "gu_p95": 94,
  "pw_max": 88.9,
  "pw_avg": 66.6,
  "pw_p95": 88.3,
  "pws_max": 31842,
  "pws_avg": 22202.96,
  "pws_p95": 31842,
  "pthr_max": 74,
  "pthr_avg": 72.12,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 79.5,
  "maxcore_p95": 100,
  "pcpu_max": 59.48,
  "pcpu_avg": 26.7,
  "pcpu_p95": 56.69,
  "core_count": 64,
  "per_core_busy_avg": [
    0.01,
    0.01,
    0.14,
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
    0.01,
    0.01,
    0.04,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.03,
    0.0,
    0.01,
    0.0,
    0.07,
    0.01,
    0.0,
    0.0,
    0.24,
    0.33,
    0.37,
    0.44,
    0.0,
    0.0,
    0.01,
    0.0,
    0.13,
    0.0,
    0.0,
    0.07,
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
    0.01,
    0.0,
    0.01,
    0.04,
    0.0,
    0.01,
    0.01,
    0.01,
    0.0
  ],
  "per_core_load_avg": [
    0.5,
    3.9,
    6.8,
    4.0,
    3.6,
    3.8,
    4.0,
    4.5,
    3.8,
    3.7,
    3.8,
    3.7,
    3.7,
    3.7,
    3.9,
    3.7,
    1.7,
    2.1,
    3.3,
    1.7,
    2.4,
    1.6,
    2.4,
    1.7,
    1.6,
    2.0,
    2.4,
    1.2,
    5.4,
    2.2,
    1.5,
    1.3,
    20.2,
    24.0,
    22.4,
    35.7,
    2.8,
    3.0,
    4.2,
    3.9,
    7.3,
    2.7,
    2.2,
    5.3,
    3.4,
    3.7,
    4.0,
    3.4,
    0.9,
    0.5,
    2.0,
    1.5,
    0.5,
    1.0,
    2.0,
    2.4,
    1.0,
    2.2,
    2.4,
    1.1,
    1.0,
    1.9,
    2.1,
    1.5
  ],
  "busy_core_span": {
    "cores_ever_busy": 8,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    2,
    32,
    33,
    34,
    35,
    40
  ],
  "peak_core_list": [
    2,
    28,
    32,
    33,
    34,
    35,
    40,
    43
  ]
}
```
