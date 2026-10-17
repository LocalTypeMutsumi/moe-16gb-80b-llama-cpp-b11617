# G13  ·  ccd1 / ncmoe 32 / moe-cache 6144 / -t 8

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 32 |
| moe-cache-mib | 6144 |
| 线程数 | 8（batch 8） |
| CCD 数 | 1 |
| 亲和掩码 请求 / 实际 | `0x000000FF000000FF` / `0x000000FF000000FF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 22 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 55.429 | 13.032 | 7847.878 | 14426.397 | 435 | 189 | 22.31 |
| 2 | 87.248 | 13.393 | 4985.776 | 14036.795 | 435 | 189 | 19.03 |
| 3 | 87.403 | 13.383 | 4976.938 | 14047.237 | 435 | 189 | 19.03 |
| **中位数** | **87.248** | **13.383** | | | | | **19.03** |
| **极差** | 31.974 | 0.362 | | | | | 3.28 |
| 首遍偏差 | -36.5% | -2.6% | | | | | |

### 3. 关键观测

- `tg_splits = 34`（cache>0，期望塌缩为常量 46）
- `pp_splits = 98`，graph nodes = 5433 / 5657，pp bs=512 / tg bs=4
- **权重账本**：CUDA 16370.6 MiB + CPU_Mapped 31378.9 MiB = **47749.5 MiB**（97 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **6** / avg **1.72**；进程核数 max **2.22**（采样 83 个，实际 **1.0 Hz**）
- 每核占用：曾有负载 **5** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 34, 35`
- 高负载核索引（平均≥5%）：`28, 32, 34, 35, 40`
- VRAM 峰值 **15702 MiB**；GPU 利用率 avg 68.02 / max 100；功耗 avg 68.37 W / max 86.1 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（34）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（83 个 / 82.9 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.20.527.482 I sched_reserve: reserving ...
0.20.545.841 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.20.545.849 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.20.545.853 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5657, splits = 98 / 34, input objects = 4 / 4, input tensors = 10 / 10
0.20.545.854 I sched_reserve: reserve took 18.37 ms, sched copies = 1
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
  "samples": 83,
  "span_s": 82.9,
  "rate_hz": 1.0,
  "nbusy_max": 6,
  "nbusy_avg": 1.72,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.98,
  "nbusy50_p95": 1,
  "nbusy1_max": 46,
  "nbusy1_avg": 21.41,
  "nbusy1_p95": 40,
  "pcores_max": 2.22,
  "pcores_avg": 0.89,
  "pcores_p95": 1.03,
  "cpu_max": 7,
  "cpu_avg": 3.22,
  "cpu_p95": 7,
  "mem_max": 15702,
  "mem_avg": 13022.67,
  "mem_p95": 15697,
  "gu_max": 100,
  "gu_avg": 68.02,
  "gu_p95": 97,
  "pw_max": 86.1,
  "pw_avg": 68.37,
  "pw_p95": 85.8,
  "pws_max": 43351,
  "pws_avg": 32469.18,
  "pws_p95": 43351,
  "pthr_max": 74,
  "pthr_avg": 72.73,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 92.82,
  "maxcore_p95": 100,
  "pcpu_max": 72.8,
  "pcpu_avg": 32.96,
  "pcpu_p95": 68.84,
  "core_count": 64,
  "per_core_busy_avg": [
    0.01,
    0.04,
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
    0.01,
    0.01,
    0.0,
    0.01,
    0.01,
    0.01,
    0.01,
    0.0,
    0.01,
    0.0,
    0.04,
    0.04,
    0.01,
    0.0,
    0.01,
    0.95,
    0.02,
    0.12,
    0.13,
    0.02,
    0.01,
    0.0,
    0.0,
    0.06,
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
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.08,
    0.0,
    0.01,
    0.0,
    0.01,
    0.01
  ],
  "per_core_load_avg": [
    0.6,
    4.0,
    3.7,
    2.8,
    2.9,
    2.9,
    2.7,
    2.8,
    2.7,
    2.9,
    2.7,
    2.7,
    2.7,
    2.7,
    2.6,
    2.9,
    2.8,
    2.2,
    3.4,
    1.5,
    1.6,
    2.1,
    2.1,
    1.6,
    1.2,
    2.1,
    1.0,
    2.2,
    5.7,
    2.5,
    1.4,
    2.6,
    85.1,
    3.1,
    9.6,
    10.2,
    1.6,
    3.1,
    2.5,
    2.7,
    5.1,
    2.4,
    1.6,
    3.0,
    2.8,
    3.1,
    2.7,
    2.6,
    1.2,
    1.5,
    2.0,
    1.9,
    1.2,
    1.1,
    1.3,
    1.9,
    1.7,
    0.9,
    4.2,
    1.4,
    1.5,
    1.0,
    2.2,
    1.8
  ],
  "busy_core_span": {
    "cores_ever_busy": 5,
    "cores_mostly_busy": 1
  },
  "busy_core_list": [
    32,
    34,
    35
  ],
  "peak_core_list": [
    28,
    32,
    34,
    35,
    40
  ]
}
```
