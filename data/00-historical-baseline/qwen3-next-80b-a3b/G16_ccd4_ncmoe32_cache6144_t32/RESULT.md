# G16  ·  ccd4 / ncmoe 32 / moe-cache 6144 / -t 32

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 32 |
| moe-cache-mib | 6144 |
| 线程数 | 32（batch 32） |
| CCD 数 | 4 |
| 亲和掩码 请求 / 实际 | `0xFFFFFFFFFFFFFFFF` / `0xFFFFFFFFFFFFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 23 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 53.285 | 12.758 | 8163.641 | 14735.517 | 435 | 189 | 22.94 |
| 2 | 86.809 | 13.119 | 5011.027 | 14330.151 | 435 | 189 | 19.35 |
| 3 | 86.587 | 13.111 | 5023.852 | 14339.17 | 435 | 189 | 19.37 |
| **中位数** | **86.587** | **13.111** | | | | | **19.37** |
| **极差** | 33.524 | 0.361 | | | | | 3.59 |
| 首遍偏差 | -38.5% | -2.7% | | | | | |

### 3. 关键观测

- `tg_splits = 34`（cache>0，期望塌缩为常量 46）
- `pp_splits = 98`，graph nodes = 5433 / 5657，pp bs=512 / tg bs=4
- **权重账本**：CUDA 16370.6 MiB + CPU_Mapped 31378.9 MiB = **47749.5 MiB**（97 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **8** / avg **2.16**；进程核数 max **1.12**（采样 86 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **7** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35, 40`
- VRAM 峰值 **15642 MiB**；GPU 利用率 avg 66.85 / max 100；功耗 avg 65.35 W / max 81.8 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（34）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（86 个 / 85.33 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.21.914.313 I sched_reserve: reserving ...
0.21.935.853 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.21.935.860 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.21.935.865 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5657, splits = 98 / 34, input objects = 4 / 4, input tensors = 10 / 10
0.21.935.867 I sched_reserve: reserve took 21.55 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 16370.6 |
| CPU_Mapped (mmap) | 97 | 31378.9 |
| Host | - | 0.0 |
| **合计** | | **47749.5** |

CPU 侧张量块尺寸种类：166.92 MiB, 288 MiB, 420 MiB

### 7. 采样统计

```json
{
  "samples": 86,
  "span_s": 85.33,
  "rate_hz": 1.01,
  "nbusy_max": 8,
  "nbusy_avg": 2.16,
  "nbusy_p95": 5,
  "nbusy50_max": 3,
  "nbusy50_avg": 1.03,
  "nbusy50_p95": 2,
  "nbusy1_max": 59,
  "nbusy1_avg": 20.95,
  "nbusy1_p95": 43,
  "pcores_max": 1.12,
  "pcores_avg": 0.89,
  "pcores_p95": 1.03,
  "cpu_max": 9,
  "cpu_avg": 3.48,
  "cpu_p95": 7,
  "mem_max": 15642,
  "mem_avg": 12896.47,
  "mem_p95": 15642,
  "gu_max": 100,
  "gu_avg": 66.85,
  "gu_p95": 97,
  "pw_max": 81.8,
  "pw_avg": 65.35,
  "pw_p95": 81.6,
  "pws_max": 43415,
  "pws_avg": 32299.11,
  "pws_p95": 43415,
  "pthr_max": 74,
  "pthr_avg": 72.67,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 84.94,
  "maxcore_p95": 100,
  "pcpu_max": 75.77,
  "pcpu_avg": 34.45,
  "pcpu_p95": 71.72,
  "core_count": 64,
  "per_core_busy_avg": [
    0.01,
    0.02,
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
    0.03,
    0.06,
    0.01,
    0.03,
    0.01,
    0.01,
    0.01,
    0.0,
    0.0,
    0.02,
    0.01,
    0.01,
    0.03,
    0.0,
    0.0,
    0.16,
    0.23,
    0.7,
    0.44,
    0.0,
    0.0,
    0.0,
    0.0,
    0.08,
    0.0,
    0.0,
    0.05,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.01,
    0.01,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.01,
    0.07,
    0.01,
    0.01,
    0.0,
    0.0,
    0.02
  ],
  "per_core_load_avg": [
    0.6,
    3.3,
    2.2,
    2.3,
    2.4,
    2.5,
    2.6,
    2.4,
    2.5,
    2.7,
    2.5,
    2.7,
    2.4,
    2.7,
    2.4,
    2.5,
    2.1,
    1.8,
    3.7,
    2.9,
    2.5,
    2.6,
    2.4,
    2.2,
    1.6,
    1.6,
    2.7,
    2.2,
    4.3,
    2.3,
    1.2,
    1.8,
    12.3,
    18.3,
    52.6,
    28.9,
    2.8,
    2.8,
    2.5,
    2.7,
    6.5,
    2.7,
    1.7,
    3.9,
    2.7,
    2.6,
    2.6,
    2.6,
    1.4,
    1.1,
    2.1,
    1.5,
    1.7,
    2.2,
    2.3,
    1.8,
    1.3,
    1.4,
    3.3,
    1.5,
    2.3,
    2.0,
    1.8,
    2.6
  ],
  "busy_core_span": {
    "cores_ever_busy": 7,
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
    35,
    40
  ]
}
```
