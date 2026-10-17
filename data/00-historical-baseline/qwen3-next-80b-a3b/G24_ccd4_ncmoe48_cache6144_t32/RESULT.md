# G24  ·  ccd4 / ncmoe 48 / moe-cache 6144 / -t 32

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 48 |
| moe-cache-mib | 6144 |
| 线程数 | 32（batch 32） |
| CCD 数 | 4 |
| 亲和掩码 请求 / 实际 | `0xFFFFFFFFFFFFFFFF` / `0xFFFFFFFFFFFFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 17 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 64.548 | 38.782 | 6739.148 | 4847.554 | 435 | 189 | 11.62 |
| 2 | 267.978 | 44.859 | 1623.269 | 4190.905 | 435 | 189 | 5.82 |
| 3 | 274.978 | 45.055 | 1581.946 | 4172.66 | 435 | 189 | 5.76 |
| **中位数** | **267.978** | **44.859** | | | | | **5.82** |
| **极差** | 210.43 | 6.273 | | | | | 5.86 |
| 首遍偏差 | -75.9% | -13.5% | | | | | |

### 3. 关键观测

- `tg_splits = 50`（cache>0，期望塌缩为常量 46）
- `pp_splits = 144`，graph nodes = 5440 / 5769，pp bs=512 / tg bs=4
- **权重账本**：CUDA 1358.7 MiB + CPU_Mapped 46390.9 MiB = **47749.6 MiB**（145 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **7** / avg **2.88**；进程核数 max **1.08**（采样 42 个，实际 **1.02 Hz**）
- 每核占用：曾有负载 **10** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`18, 19, 32, 33, 34, 35, 40, 43, 58`
- 高负载核索引（平均≥5%）：`18, 19, 28, 32, 33, 34, 35, 40, 43, 58`
- VRAM 峰值 **10788 MiB**；GPU 利用率 avg 30.02 / max 67；功耗 avg 61.4 W / max 118.1 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（50）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（42 个 / 41.13 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.15.433.121 I sched_reserve: reserving ...
0.15.455.988 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.15.455.996 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.15.456.002 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5440 / 5769, splits = 144 / 50, input objects = 4 / 4, input tensors = 10 / 10
0.15.456.003 I sched_reserve: reserve took 22.88 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 1358.7 |
| CPU_Mapped (mmap) | 145 | 46390.9 |
| Host | - | 0.0 |
| **合计** | | **47749.6** |

CPU 侧张量块尺寸种类：166.92 MiB, 288 MiB, 420 MiB

### 7. 采样统计

```json
{
  "samples": 42,
  "span_s": 41.13,
  "rate_hz": 1.02,
  "nbusy_max": 7,
  "nbusy_avg": 2.88,
  "nbusy_p95": 6,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.69,
  "nbusy50_p95": 2,
  "nbusy1_max": 43,
  "nbusy1_avg": 24.26,
  "nbusy1_p95": 41,
  "pcores_max": 1.08,
  "pcores_avg": 0.77,
  "pcores_p95": 1.06,
  "cpu_max": 8,
  "cpu_avg": 3.93,
  "cpu_p95": 7,
  "mem_max": 10788,
  "mem_avg": 7168.88,
  "mem_p95": 10783,
  "gu_max": 67,
  "gu_avg": 30.02,
  "gu_p95": 65,
  "pw_max": 118.1,
  "pw_avg": 61.4,
  "pw_p95": 114.5,
  "pws_max": 24122,
  "pws_avg": 12502.93,
  "pws_p95": 24122,
  "pthr_max": 74,
  "pthr_avg": 71.46,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 64.29,
  "maxcore_p95": 100,
  "pcpu_max": 31.62,
  "pcpu_avg": 13.53,
  "pcpu_p95": 29.72,
  "core_count": 64,
  "per_core_busy_avg": [
    0.0,
    0.05,
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
    0.02,
    0.02,
    0.19,
    0.12,
    0.02,
    0.05,
    0.0,
    0.02,
    0.0,
    0.0,
    0.0,
    0.0,
    0.07,
    0.02,
    0.02,
    0.02,
    0.38,
    0.43,
    0.43,
    0.4,
    0.0,
    0.0,
    0.0,
    0.0,
    0.29,
    0.0,
    0.0,
    0.14,
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
    0.02,
    0.0,
    0.0,
    0.0,
    0.12,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0
  ],
  "per_core_load_avg": [
    0.5,
    4.9,
    3.4,
    3.4,
    3.5,
    3.8,
    3.9,
    3.8,
    4.0,
    3.7,
    3.7,
    3.7,
    3.5,
    3.7,
    3.7,
    3.5,
    1.9,
    2.7,
    7.0,
    5.8,
    3.1,
    2.5,
    1.6,
    1.5,
    1.8,
    1.4,
    1.5,
    1.0,
    6.0,
    3.4,
    2.2,
    2.2,
    20.2,
    26.9,
    20.4,
    26.5,
    3.4,
    3.8,
    3.7,
    3.7,
    12.1,
    2.7,
    2.2,
    6.2,
    3.7,
    3.5,
    3.7,
    3.7,
    0.9,
    0.7,
    2.0,
    1.8,
    1.4,
    1.0,
    1.9,
    1.5,
    1.8,
    1.8,
    5.2,
    0.9,
    1.5,
    1.5,
    1.0,
    1.5
  ],
  "busy_core_span": {
    "cores_ever_busy": 10,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    18,
    19,
    32,
    33,
    34,
    35,
    40,
    43,
    58
  ],
  "peak_core_list": [
    18,
    19,
    28,
    32,
    33,
    34,
    35,
    40,
    43,
    58
  ]
}
```
