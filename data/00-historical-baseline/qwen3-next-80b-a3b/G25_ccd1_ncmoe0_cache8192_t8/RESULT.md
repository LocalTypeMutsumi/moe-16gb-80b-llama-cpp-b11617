# G25  ·  ccd1 / ncmoe 0 / moe-cache 8192 / -t 8

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
| 线程数 | 8（batch 8） |
| CCD 数 | 1 |
| 亲和掩码 请求 / 实际 | `0x000000FF000000FF` / `0x000000FF000000FF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 34 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 119.668 | 10.469 | 3635.042 | 17957.654 | 435 | 189 | 21.68 |
| 2 | 121.365 | 10.476 | 3584.215 | 17946.125 | 435 | 189 | 21.53 |
| 3 | 121.066 | 10.479 | 3593.086 | 17940.651 | 435 | 189 | 21.54 |
| **中位数** | **121.066** | **10.476** | | | | | **21.54** |
| **极差** | 1.697 | 0.01 | | | | | 0.15 |
| 首遍偏差 | -1.2% | -0.1% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 5433 / 5433，pp bs=None / tg bs=None
- **权重账本**：CUDA 47582.7 MiB + CPU_Mapped 166.9 MiB = **47749.6 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **7** / avg **2.04**；进程核数 max **1.08**（采样 100 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **7** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`1, 32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`1, 28, 32, 33, 34, 35`
- VRAM 峰值 **15518 MiB**；GPU 利用率 avg 70.43 / max 100；功耗 avg 63.41 W / max 80.5 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（100 个 / 99.36 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.33.567.526 I sched_reserve: reserving ...
0.33.586.785 I sched_reserve:      CUDA0 compute buffer size =   139.01 MiB
0.33.586.792 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.33.586.795 I sched_reserve: graph: nodes = 5433, splits = 2, input objects = 4, input tensors = 10
0.33.586.797 I sched_reserve: reserve took 19.27 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 47582.7 |
| CPU_Mapped (mmap) | 1 | 166.9 |
| Host | - | 0.0 |
| **合计** | | **47749.6** |

CPU 侧张量块尺寸种类：166.92 MiB

### 7. 采样统计

```json
{
  "samples": 100,
  "span_s": 99.36,
  "rate_hz": 1.01,
  "nbusy_max": 7,
  "nbusy_avg": 2.04,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.96,
  "nbusy50_p95": 2,
  "nbusy1_max": 45,
  "nbusy1_avg": 21.41,
  "nbusy1_p95": 40,
  "pcores_max": 1.08,
  "pcores_avg": 0.85,
  "pcores_p95": 1.03,
  "cpu_max": 8,
  "cpu_avg": 3.55,
  "cpu_p95": 8,
  "mem_max": 15518,
  "mem_avg": 13317.66,
  "mem_p95": 15513,
  "gu_max": 100,
  "gu_avg": 70.43,
  "gu_p95": 100,
  "pw_max": 80.5,
  "pw_avg": 63.41,
  "pw_p95": 78,
  "pws_max": 82894,
  "pws_avg": 64706.9,
  "pws_p95": 82893,
  "pthr_max": 74,
  "pthr_avg": 72.64,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 80.92,
  "maxcore_p95": 100,
  "pcpu_max": 84.09,
  "pcpu_avg": 39.12,
  "pcpu_p95": 80,
  "core_count": 64,
  "per_core_busy_avg": [
    0.02,
    0.14,
    0.01,
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
    0.02,
    0.04,
    0.01,
    0.0,
    0.01,
    0.01,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.08,
    0.0,
    0.0,
    0.0,
    0.26,
    0.51,
    0.3,
    0.4,
    0.01,
    0.0,
    0.01,
    0.0,
    0.01,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.01,
    0.02,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.01,
    0.06,
    0.0,
    0.02,
    0.01,
    0.0,
    0.02
  ],
  "per_core_load_avg": [
    3.0,
    7.0,
    2.4,
    2.7,
    3.6,
    3.7,
    3.5,
    3.4,
    3.1,
    3.2,
    3.3,
    3.3,
    3.0,
    3.3,
    3.4,
    3.5,
    3.0,
    3.4,
    2.4,
    1.7,
    1.5,
    1.8,
    1.0,
    1.4,
    1.7,
    0.8,
    0.9,
    0.8,
    6.0,
    2.0,
    0.8,
    1.3,
    16.9,
    41.9,
    19.1,
    31.3,
    3.9,
    3.3,
    3.2,
    3.3,
    3.3,
    1.4,
    1.2,
    2.4,
    3.3,
    3.3,
    3.3,
    3.3,
    1.2,
    1.0,
    1.9,
    2.0,
    1.0,
    1.5,
    1.1,
    1.3,
    1.3,
    2.6,
    3.0,
    1.3,
    2.0,
    1.8,
    1.1,
    2.0
  ],
  "busy_core_span": {
    "cores_ever_busy": 7,
    "cores_mostly_busy": 1
  },
  "busy_core_list": [
    1,
    32,
    33,
    34,
    35
  ],
  "peak_core_list": [
    1,
    28,
    32,
    33,
    34,
    35
  ]
}
```
