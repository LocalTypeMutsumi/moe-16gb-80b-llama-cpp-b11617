# G28  ·  ccd4 / ncmoe 0 / moe-cache 8192 / -t 32

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | gpt-oss-120b |
| 模型路径 | `D:\Models\LMStudio\local\gpt-oss-120b\gpt-oss-120b-MXFP4.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
| 线程数 | 32（batch 32） |
| CCD 数 | 4 |
| 亲和掩码 请求 / 实际 | `0xFFFFFFFFFFFFFFFF` / `0xFFFFFFFFFFFFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 85 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=36, n_expert=128, n_expert_used=4, n_embd=2880, type=120B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 128.195 | 6.325 | 4157.714 | 30197.911 | 533 | 192 | 34.57 |
| 2 | 141.814 | 6.346 | 3758.433 | 30099.49 | 533 | 192 | 33.86 |
| 3 | 141.606 | 6.349 | 3763.962 | 30081.974 | 533 | 192 | 33.85 |
| **中位数** | **141.606** | **6.346** | | | | | **33.86** |
| **极差** | 13.619 | 0.024 | | | | | 0.72 |
| 首遍偏差 | -9.5% | -0.3% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 2025 / 2025，pp bs=None / tg bs=None
- **权重账本**：CUDA 61223.7 MiB + CPU_Mapped 1104.6 MiB = **62328.3 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**37/37**
- CPU 占用：nbusy max **13** / avg **2.22**；进程核数 max **1.68**（采样 187 个，实际 **1.0 Hz**）
- 每核占用：曾有负载 **12** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35`
- VRAM 峰值 **15646 MiB**；GPU 利用率 avg 64.07 / max 100；功耗 avg 54.68 W / max 92.3 W；进程线程数 max 73
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（62328.3 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（187 个 / 187.39 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[533]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
1.22.934.757 I sched_reserve: reserving ...
1.22.958.875 I sched_reserve:      CUDA0 compute buffer size =    99.02 MiB
1.22.958.883 I sched_reserve:  CUDA_Host compute buffer size =    31.53 MiB
1.22.958.890 I sched_reserve: graph: nodes = 2025, splits = 2, input objects = 4, input tensors = 12
1.22.958.892 I sched_reserve: reserve took 24.13 ms, sched copies = 1
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
  "samples": 187,
  "span_s": 187.39,
  "rate_hz": 1.0,
  "nbusy_max": 13,
  "nbusy_avg": 2.22,
  "nbusy_p95": 6,
  "nbusy50_max": 4,
  "nbusy50_avg": 0.86,
  "nbusy50_p95": 2,
  "nbusy1_max": 58,
  "nbusy1_avg": 23.17,
  "nbusy1_p95": 45,
  "pcores_max": 1.68,
  "pcores_avg": 0.84,
  "pcores_p95": 1.03,
  "cpu_max": 10,
  "cpu_avg": 3.47,
  "cpu_p95": 7,
  "mem_max": 15646,
  "mem_avg": 13642.28,
  "mem_p95": 15639,
  "gu_max": 100,
  "gu_avg": 64.07,
  "gu_p95": 100,
  "pw_max": 92.3,
  "pw_avg": 54.68,
  "pw_p95": 83.1,
  "pws_max": 109755,
  "pws_avg": 69146.19,
  "pws_p95": 109754,
  "pthr_max": 73,
  "pthr_avg": 71.2,
  "pthr_p95": 73,
  "maxcore_max": 100,
  "maxcore_avg": 74.1,
  "maxcore_p95": 100,
  "pcpu_max": 156.77,
  "pcpu_avg": 71.21,
  "pcpu_p95": 147.91,
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
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.06,
    0.03,
    0.05,
    0.04,
    0.01,
    0.06,
    0.04,
    0.05,
    0.06,
    0.05,
    0.06,
    0.06,
    0.04,
    0.04,
    0.03,
    0.14,
    0.2,
    0.47,
    0.26,
    0.01,
    0.0,
    0.01,
    0.01,
    0.02,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.02,
    0.01,
    0.09,
    0.02,
    0.0,
    0.03,
    0.01,
    0.02,
    0.01,
    0.02,
    0.07,
    0.01,
    0.01,
    0.01,
    0.01,
    0.09
  ],
  "per_core_load_avg": [
    0.7,
    3.9,
    3.2,
    3.2,
    3.3,
    3.1,
    3.0,
    3.0,
    3.1,
    3.2,
    3.0,
    3.3,
    3.2,
    3.3,
    3.1,
    3.2,
    1.5,
    2.6,
    3.5,
    2.7,
    2.8,
    1.4,
    3.9,
    3.1,
    4.3,
    4.1,
    3.7,
    3.7,
    3.2,
    3.2,
    3.0,
    2.3,
    10.9,
    17.4,
    37.2,
    20.5,
    3.6,
    3.4,
    3.2,
    3.2,
    3.0,
    2.4,
    2.4,
    2.4,
    3.3,
    3.1,
    3.2,
    3.0,
    2.1,
    1.6,
    4.1,
    2.1,
    1.3,
    2.4,
    1.1,
    1.6,
    1.9,
    1.8,
    4.3,
    1.2,
    1.0,
    1.1,
    1.3,
    3.8
  ],
  "busy_core_span": {
    "cores_ever_busy": 12,
    "cores_mostly_busy": 0
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
