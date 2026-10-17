# G26  ·  ccd2 / ncmoe 0 / moe-cache 8192 / -t 16

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | gpt-oss-120b |
| 模型路径 | `D:\Models\LMStudio\local\gpt-oss-120b\gpt-oss-120b-MXFP4.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
| 线程数 | 16（batch 16） |
| CCD 数 | 2 |
| 亲和掩码 请求 / 实际 | `0x0000FFFF0000FFFF` / `0x0000FFFF0000FFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 82 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=36, n_expert=128, n_expert_used=4, n_embd=2880, type=120B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 132.175 | 6.344 | 4032.546 | 30105.823 | 533 | 192 | 34.2 |
| 2 | 143.088 | 6.35 | 3724.984 | 30076.996 | 533 | 192 | 33.81 |
| 3 | 142.789 | 6.353 | 3732.774 | 30066.281 | 533 | 192 | 33.8 |
| **中位数** | **142.789** | **6.35** | | | | | **33.81** |
| **极差** | 10.913 | 0.008 | | | | | 0.4 |
| 首遍偏差 | -7.4% | -0.1% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 2025 / 2025，pp bs=None / tg bs=None
- **权重账本**：CUDA 61223.7 MiB + CPU_Mapped 1104.6 MiB = **62328.3 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**37/37**
- CPU 占用：nbusy max **10** / avg **2.64**；进程核数 max **1.08**（采样 184 个，实际 **1.0 Hz**）
- 每核占用：曾有负载 **8** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35`
- VRAM 峰值 **15672 MiB**；GPU 利用率 avg 64.16 / max 100；功耗 avg 55.21 W / max 94.2 W；进程线程数 max 73
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（62328.3 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（184 个 / 183.61 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[533]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
1.20.091.335 I sched_reserve: reserving ...
1.20.129.322 I sched_reserve:      CUDA0 compute buffer size =    99.02 MiB
1.20.129.332 I sched_reserve:  CUDA_Host compute buffer size =    31.53 MiB
1.20.129.335 I sched_reserve: graph: nodes = 2025, splits = 2, input objects = 4, input tensors = 12
1.20.129.336 I sched_reserve: reserve took 38.00 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 61223.7 |
| CPU_Mapped (mmap) | 1 | 1104.6 |
| Host | - | 0.0 |
| **合计** | | **62328.3** |

CPU 侧张量块尺寸种类：1104.61 MiB

### 7. 采样统计

```json
{
  "samples": 184,
  "span_s": 183.61,
  "rate_hz": 1.0,
  "nbusy_max": 10,
  "nbusy_avg": 2.64,
  "nbusy_p95": 5,
  "nbusy50_max": 3,
  "nbusy50_avg": 0.98,
  "nbusy50_p95": 2,
  "nbusy1_max": 64,
  "nbusy1_avg": 22.61,
  "nbusy1_p95": 39,
  "pcores_max": 1.08,
  "pcores_avg": 0.83,
  "pcores_p95": 1.03,
  "cpu_max": 10,
  "cpu_avg": 3.59,
  "cpu_p95": 7,
  "mem_max": 15672,
  "mem_avg": 13927.11,
  "mem_p95": 15672,
  "gu_max": 100,
  "gu_avg": 64.16,
  "gu_p95": 100,
  "pw_max": 94.2,
  "pw_avg": 55.21,
  "pw_p95": 83.5,
  "pws_max": 108781,
  "pws_avg": 71152.89,
  "pws_p95": 108780,
  "pthr_max": 73,
  "pthr_avg": 71.64,
  "pthr_p95": 73,
  "maxcore_max": 100,
  "maxcore_avg": 78.9,
  "maxcore_p95": 100,
  "pcpu_max": 151.64,
  "pcpu_avg": 67.62,
  "pcpu_p95": 142.62,
  "core_count": 64,
  "per_core_busy_avg": [
    0.0,
    0.0,
    0.0,
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
    0.08,
    0.03,
    0.01,
    0.01,
    0.03,
    0.02,
    0.0,
    0.02,
    0.02,
    0.01,
    0.01,
    0.02,
    0.04,
    0.02,
    0.01,
    0.34,
    0.3,
    0.8,
    0.35,
    0.0,
    0.0,
    0.0,
    0.0,
    0.04,
    0.03,
    0.02,
    0.01,
    0.02,
    0.01,
    0.01,
    0.01,
    0.0,
    0.01,
    0.08,
    0.02,
    0.01,
    0.02,
    0.01,
    0.0,
    0.03,
    0.0,
    0.09,
    0.0,
    0.01,
    0.02,
    0.0,
    0.08
  ],
  "per_core_load_avg": [
    0.1,
    2.8,
    0.7,
    1.6,
    3.1,
    3.2,
    3.1,
    3.1,
    3.1,
    3.1,
    3.5,
    3.4,
    3.2,
    3.2,
    2.9,
    3.1,
    1.4,
    3.2,
    2.5,
    1.1,
    1.8,
    2.5,
    2.0,
    1.3,
    1.9,
    2.2,
    1.8,
    1.9,
    2.0,
    3.7,
    2.2,
    1.7,
    18.6,
    23.1,
    54.3,
    19.6,
    3.1,
    3.4,
    3.2,
    3.3,
    3.7,
    2.3,
    2.7,
    2.8,
    3.6,
    3.5,
    3.4,
    3.3,
    1.0,
    1.9,
    4.1,
    2.1,
    1.9,
    2.1,
    1.3,
    1.3,
    2.0,
    1.4,
    3.6,
    1.0,
    2.7,
    1.6,
    1.6,
    3.7
  ],
  "busy_core_span": {
    "cores_ever_busy": 8,
    "cores_mostly_busy": 1
  },
  "busy_core_list": [
    32,
    33,
    34,
    35
  ],
  "peak_core_list": [
    32,
    33,
    34,
    35
  ]
}
```
