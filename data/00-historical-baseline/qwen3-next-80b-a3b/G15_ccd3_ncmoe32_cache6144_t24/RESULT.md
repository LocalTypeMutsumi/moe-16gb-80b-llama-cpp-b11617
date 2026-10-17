# G15  ·  ccd3 / ncmoe 32 / moe-cache 6144 / -t 24

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 32 |
| moe-cache-mib | 6144 |
| 线程数 | 24（batch 24） |
| CCD 数 | 3 |
| 亲和掩码 请求 / 实际 | `0x00FFFFFF00FFFFFF` / `0x00FFFFFF00FFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 22 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 53.26 | 12.819 | 8167.417 | 14665.987 | 435 | 189 | 22.87 |
| 2 | 88.031 | 13.229 | 4941.447 | 14211.513 | 435 | 189 | 19.16 |
| 3 | 88.054 | 13.214 | 4940.14 | 14226.892 | 435 | 189 | 19.17 |
| **中位数** | **88.031** | **13.214** | | | | | **19.17** |
| **极差** | 34.794 | 0.41 | | | | | 3.71 |
| 首遍偏差 | -39.5% | -3.0% | | | | | |

### 3. 关键观测

- `tg_splits = 34`（cache>0，期望塌缩为常量 46）
- `pp_splits = 98`，graph nodes = 5433 / 5657，pp bs=512 / tg bs=4
- **权重账本**：CUDA 16370.6 MiB + CPU_Mapped 31378.9 MiB = **47749.5 MiB**（97 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **7** / avg **2.05**；进程核数 max **1.06**（采样 85 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **8** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`18, 32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`18, 32, 33, 34, 35, 40`
- VRAM 峰值 **15642 MiB**；GPU 利用率 avg 65.67 / max 100；功耗 avg 66.58 W / max 82.5 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（34）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（85 个 / 84.21 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.20.836.383 I sched_reserve: reserving ...
0.20.857.292 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.20.857.298 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.20.857.304 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5657, splits = 98 / 34, input objects = 4 / 4, input tensors = 10 / 10
0.20.857.310 I sched_reserve: reserve took 20.92 ms, sched copies = 1
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
  "samples": 85,
  "span_s": 84.21,
  "rate_hz": 1.01,
  "nbusy_max": 7,
  "nbusy_avg": 2.05,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.87,
  "nbusy50_p95": 1,
  "nbusy1_max": 60,
  "nbusy1_avg": 22.38,
  "nbusy1_p95": 44,
  "pcores_max": 1.06,
  "pcores_avg": 0.89,
  "pcores_p95": 1.05,
  "cpu_max": 9,
  "cpu_avg": 3.32,
  "cpu_p95": 7,
  "mem_max": 15642,
  "mem_avg": 13138.02,
  "mem_p95": 15642,
  "gu_max": 100,
  "gu_avg": 65.67,
  "gu_p95": 97,
  "pw_max": 82.5,
  "pw_avg": 66.58,
  "pw_p95": 82.3,
  "pws_max": 43415,
  "pws_avg": 32576.12,
  "pws_p95": 43415,
  "pthr_max": 74,
  "pthr_avg": 71.88,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 80.07,
  "maxcore_p95": 100,
  "pcpu_max": 74.56,
  "pcpu_avg": 34.06,
  "pcpu_p95": 70.83,
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
    0.01,
    0.01,
    0.15,
    0.02,
    0.02,
    0.05,
    0.01,
    0.0,
    0.0,
    0.0,
    0.01,
    0.0,
    0.06,
    0.01,
    0.0,
    0.0,
    0.36,
    0.4,
    0.26,
    0.35,
    0.0,
    0.0,
    0.0,
    0.0,
    0.07,
    0.0,
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
    0.04,
    0.01,
    0.0,
    0.0,
    0.0,
    0.08,
    0.01,
    0.01,
    0.01,
    0.0,
    0.0
  ],
  "per_core_load_avg": [
    0.7,
    3.5,
    1.9,
    3.2,
    2.9,
    3.3,
    2.9,
    2.8,
    3.0,
    3.4,
    3.4,
    3.2,
    3.0,
    3.2,
    3.4,
    3.3,
    0.8,
    1.9,
    6.8,
    3.2,
    3.0,
    2.9,
    2.8,
    2.0,
    1.4,
    1.6,
    1.6,
    1.1,
    4.5,
    2.6,
    1.4,
    1.8,
    22.3,
    30.2,
    22.7,
    28.1,
    3.3,
    3.0,
    3.0,
    3.1,
    5.1,
    2.3,
    2.1,
    4.0,
    3.3,
    3.1,
    3.3,
    3.1,
    1.1,
    1.9,
    1.6,
    1.5,
    1.5,
    2.2,
    2.0,
    1.0,
    1.3,
    1.4,
    3.3,
    1.0,
    1.1,
    1.3,
    1.2,
    1.8
  ],
  "busy_core_span": {
    "cores_ever_busy": 8,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    18,
    32,
    33,
    34,
    35
  ],
  "peak_core_list": [
    18,
    32,
    33,
    34,
    35,
    40
  ]
}
```
