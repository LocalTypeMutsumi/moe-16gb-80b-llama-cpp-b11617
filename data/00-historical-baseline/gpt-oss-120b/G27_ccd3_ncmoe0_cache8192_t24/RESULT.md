# G27  ·  ccd3 / ncmoe 0 / moe-cache 8192 / -t 24

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | gpt-oss-120b |
| 模型路径 | `D:\Models\LMStudio\local\gpt-oss-120b\gpt-oss-120b-MXFP4.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
| 线程数 | 24（batch 24） |
| CCD 数 | 3 |
| 亲和掩码 请求 / 实际 | `0x00FFFFFF00FFFFFF` / `0x00FFFFFF00FFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 90 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=36, n_expert=128, n_expert_used=4, n_embd=2880, type=120B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 131.565 | 6.336 | 4051.225 | 30146.876 | 533 | 192 | 34.4 |
| 2 | 143.084 | 6.352 | 3725.084 | 30066.959 | 533 | 192 | 33.8 |
| 3 | 143.21 | 6.351 | 3721.797 | 30073.39 | 533 | 192 | 33.8 |
| **中位数** | **143.084** | **6.351** | | | | | **33.8** |
| **极差** | 11.645 | 0.017 | | | | | 0.6 |
| 首遍偏差 | -8.1% | -0.2% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 2025 / 2025，pp bs=None / tg bs=None
- **权重账本**：CUDA 61223.7 MiB + CPU_Mapped 1104.6 MiB = **62328.3 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**37/37**
- CPU 占用：nbusy max **11** / avg **2.26**；进程核数 max **1.05**（采样 192 个，实际 **1.0 Hz**）
- 每核占用：曾有负载 **8** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35, 50`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35, 50, 51`
- VRAM 峰值 **15651 MiB**；GPU 利用率 avg 61.7 / max 100；功耗 avg 51.76 W / max 91.6 W；进程线程数 max 73
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（62328.3 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（192 个 / 191.71 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[533]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
1.28.299.627 I sched_reserve: reserving ...
1.28.344.314 I sched_reserve:      CUDA0 compute buffer size =    99.02 MiB
1.28.344.324 I sched_reserve:  CUDA_Host compute buffer size =    31.53 MiB
1.28.344.328 I sched_reserve: graph: nodes = 2025, splits = 2, input objects = 4, input tensors = 12
1.28.344.330 I sched_reserve: reserve took 44.70 ms, sched copies = 1
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
  "samples": 192,
  "span_s": 191.71,
  "rate_hz": 1.0,
  "nbusy_max": 11,
  "nbusy_avg": 2.26,
  "nbusy_p95": 5,
  "nbusy50_max": 3,
  "nbusy50_avg": 1.02,
  "nbusy50_p95": 2,
  "nbusy1_max": 57,
  "nbusy1_avg": 23.79,
  "nbusy1_p95": 43,
  "pcores_max": 1.05,
  "pcores_avg": 0.82,
  "pcores_p95": 1.03,
  "cpu_max": 10,
  "cpu_avg": 3.69,
  "cpu_p95": 7,
  "mem_max": 15651,
  "mem_avg": 13822.72,
  "mem_p95": 15647,
  "gu_max": 100,
  "gu_avg": 61.7,
  "gu_p95": 100,
  "pw_max": 91.6,
  "pw_avg": 51.76,
  "pw_p95": 79.9,
  "pws_max": 109267,
  "pws_avg": 68533.9,
  "pws_p95": 109266,
  "pthr_max": 73,
  "pthr_avg": 71.51,
  "pthr_p95": 73,
  "maxcore_max": 100,
  "maxcore_avg": 77.74,
  "maxcore_p95": 100,
  "pcpu_max": 156.92,
  "pcpu_avg": 70.03,
  "pcpu_p95": 147.83,
  "core_count": 64,
  "per_core_busy_avg": [
    0.01,
    0.02,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.02,
    0.04,
    0.03,
    0.02,
    0.01,
    0.02,
    0.04,
    0.01,
    0.01,
    0.01,
    0.01,
    0.02,
    0.01,
    0.02,
    0.01,
    0.02,
    0.2,
    0.32,
    0.22,
    0.34,
    0.02,
    0.02,
    0.0,
    0.0,
    0.02,
    0.01,
    0.0,
    0.01,
    0.0,
    0.01,
    0.0,
    0.0,
    0.03,
    0.02,
    0.41,
    0.07,
    0.01,
    0.01,
    0.02,
    0.02,
    0.03,
    0.01,
    0.1,
    0.0,
    0.01,
    0.0,
    0.02,
    0.07
  ],
  "per_core_load_avg": [
    0.7,
    4.6,
    3.1,
    3.2,
    3.3,
    3.3,
    3.3,
    3.2,
    2.8,
    3.3,
    3.0,
    3.1,
    3.0,
    3.3,
    3.3,
    3.3,
    1.4,
    2.7,
    3.0,
    2.0,
    2.0,
    2.0,
    2.7,
    1.9,
    2.5,
    1.8,
    1.9,
    1.7,
    1.8,
    2.7,
    1.6,
    1.9,
    15.5,
    25.9,
    14.7,
    28.6,
    3.4,
    3.4,
    3.2,
    3.3,
    2.9,
    2.4,
    2.4,
    2.4,
    3.0,
    3.3,
    3.5,
    3.3,
    2.6,
    2.4,
    23.2,
    5.2,
    1.8,
    2.3,
    2.0,
    2.1,
    2.2,
    2.0,
    3.8,
    1.4,
    1.8,
    1.4,
    1.9,
    3.8
  ],
  "busy_core_span": {
    "cores_ever_busy": 8,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    32,
    33,
    34,
    35,
    50
  ],
  "peak_core_list": [
    32,
    33,
    34,
    35,
    50,
    51
  ]
}
```
