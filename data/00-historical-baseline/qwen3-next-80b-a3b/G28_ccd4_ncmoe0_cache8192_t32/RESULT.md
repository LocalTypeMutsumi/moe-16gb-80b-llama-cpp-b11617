# G28  ·  ccd4 / ncmoe 0 / moe-cache 8192 / -t 32

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
| 线程数 | 32（batch 32） |
| CCD 数 | 4 |
| 亲和掩码 请求 / 实际 | `0xFFFFFFFFFFFFFFFF` / `0xFFFFFFFFFFFFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 22 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 117.312 | 10.413 | 3708.053 | 18053.919 | 435 | 189 | 21.8 |
| 2 | 118.726 | 10.409 | 3663.906 | 18060.747 | 435 | 189 | 21.73 |
| 3 | 118.846 | 10.419 | 3660.194 | 18043.978 | 435 | 189 | 21.71 |
| **中位数** | **118.726** | **10.413** | | | | | **21.73** |
| **极差** | 1.534 | 0.01 | | | | | 0.09 |
| 首遍偏差 | -1.2% | +0.0% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 5433 / 5433，pp bs=None / tg bs=None
- **权重账本**：CUDA 47582.7 MiB + CPU_Mapped 166.9 MiB = **47749.6 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **5** / avg **1.94**；进程核数 max **1.05**（采样 89 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **5** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35`
- VRAM 峰值 **15533 MiB**；GPU 利用率 avg 77.1 / max 100；功耗 avg 67.69 W / max 80.2 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（89 个 / 88.28 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.21.623.611 I sched_reserve: reserving ...
0.21.648.507 I sched_reserve:      CUDA0 compute buffer size =   139.01 MiB
0.21.648.515 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.21.648.518 I sched_reserve: graph: nodes = 5433, splits = 2, input objects = 4, input tensors = 10
0.21.648.520 I sched_reserve: reserve took 24.91 ms, sched copies = 1
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
  "samples": 89,
  "span_s": 88.28,
  "rate_hz": 1.01,
  "nbusy_max": 5,
  "nbusy_avg": 1.94,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 1.03,
  "nbusy50_p95": 2,
  "nbusy1_max": 50,
  "nbusy1_avg": 17.76,
  "nbusy1_p95": 40,
  "pcores_max": 1.05,
  "pcores_avg": -0.04,
  "pcores_p95": 1.03,
  "cpu_max": 8,
  "cpu_avg": 2.91,
  "cpu_p95": 7,
  "mem_max": 15533,
  "mem_avg": 14694.09,
  "mem_p95": 15533,
  "gu_max": 100,
  "gu_avg": 77.1,
  "gu_p95": 100,
  "pw_max": 80.2,
  "pw_avg": 67.69,
  "pw_p95": 77.7,
  "pws_max": 82893,
  "pws_avg": 72576.06,
  "pws_p95": 82893,
  "pthr_max": 74,
  "pthr_avg": 70.36,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 82.28,
  "maxcore_p95": 100,
  "pcpu_max": 85.78,
  "pcpu_avg": 42.78,
  "pcpu_p95": 79.95,
  "core_count": 64,
  "per_core_busy_avg": [
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
    0.0,
    0.0,
    0.0,
    0.0,
    0.03,
    0.01,
    0.0,
    0.01,
    0.04,
    0.02,
    0.0,
    0.01,
    0.01,
    0.0,
    0.01,
    0.0,
    0.01,
    0.02,
    0.36,
    0.45,
    0.35,
    0.35,
    0.0,
    0.0,
    0.0,
    0.0,
    0.02,
    0.02,
    0.01,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.02,
    0.0,
    0.01,
    0.01,
    0.0,
    0.07,
    0.01,
    0.02,
    0.0,
    0.0,
    0.02
  ],
  "per_core_load_avg": [
    0.1,
    2.2,
    2.2,
    2.3,
    2.5,
    2.3,
    2.4,
    2.3,
    2.4,
    2.3,
    2.2,
    2.3,
    2.3,
    2.8,
    2.4,
    2.3,
    1.1,
    0.9,
    3.0,
    2.3,
    1.7,
    1.6,
    2.7,
    2.0,
    1.1,
    1.1,
    0.9,
    0.4,
    3.9,
    1.7,
    1.5,
    2.5,
    26.0,
    33.6,
    23.7,
    24.9,
    2.2,
    2.3,
    2.3,
    2.4,
    2.8,
    1.8,
    1.4,
    2.5,
    2.2,
    2.1,
    2.1,
    2.1,
    1.7,
    1.5,
    1.1,
    1.2,
    0.6,
    2.3,
    1.0,
    2.0,
    1.3,
    1.3,
    3.3,
    1.5,
    2.0,
    2.1,
    2.3,
    2.6
  ],
  "busy_core_span": {
    "cores_ever_busy": 5,
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
