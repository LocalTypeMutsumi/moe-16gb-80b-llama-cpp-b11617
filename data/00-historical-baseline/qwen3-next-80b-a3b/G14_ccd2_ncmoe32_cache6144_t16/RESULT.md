# G14  ·  ccd2 / ncmoe 32 / moe-cache 6144 / -t 16

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 32 |
| moe-cache-mib | 6144 |
| 线程数 | 16（batch 16） |
| CCD 数 | 2 |
| 亲和掩码 请求 / 实际 | `0x0000FFFF0000FFFF` / `0x0000FFFF0000FFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 22 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 55.142 | 13.04 | 7888.783 | 14417.02 | 435 | 189 | 22.34 |
| 2 | 87.089 | 13.41 | 4994.898 | 14019.853 | 435 | 189 | 19.02 |
| 3 | 87.058 | 13.378 | 4996.641 | 14053.228 | 435 | 189 | 19.05 |
| **中位数** | **87.058** | **13.378** | | | | | **19.05** |
| **极差** | 31.947 | 0.369 | | | | | 3.32 |
| 首遍偏差 | -36.7% | -2.5% | | | | | |

### 3. 关键观测

- `tg_splits = 34`（cache>0，期望塌缩为常量 46）
- `pp_splits = 98`，graph nodes = 5433 / 5657，pp bs=512 / tg bs=4
- **权重账本**：CUDA 16370.6 MiB + CPU_Mapped 31378.9 MiB = **47749.5 MiB**（97 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **7** / avg **1.74**；进程核数 max **1.05**（采样 84 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **6** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`28, 32, 33, 34, 40`
- 高负载核索引（平均≥5%）：`28, 32, 33, 34, 40`
- VRAM 峰值 **15706 MiB**；GPU 利用率 avg 67.85 / max 100；功耗 avg 69.69 W / max 87.5 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（34）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（84 个 / 83.28 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.20.369.095 I sched_reserve: reserving ...
0.20.388.310 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.20.388.317 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.20.388.321 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5657, splits = 98 / 34, input objects = 4 / 4, input tensors = 10 / 10
0.20.388.323 I sched_reserve: reserve took 19.23 ms, sched copies = 1
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
  "samples": 84,
  "span_s": 83.28,
  "rate_hz": 1.01,
  "nbusy_max": 7,
  "nbusy_avg": 1.74,
  "nbusy_p95": 3,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.87,
  "nbusy50_p95": 1,
  "nbusy1_max": 45,
  "nbusy1_avg": 23.92,
  "nbusy1_p95": 40,
  "pcores_max": 1.05,
  "pcores_avg": 0.88,
  "pcores_p95": 1.03,
  "cpu_max": 9,
  "cpu_avg": 3.43,
  "cpu_p95": 7,
  "mem_max": 15706,
  "mem_avg": 13134.67,
  "mem_p95": 15706,
  "gu_max": 100,
  "gu_avg": 67.85,
  "gu_p95": 97,
  "pw_max": 87.5,
  "pw_avg": 69.69,
  "pw_p95": 85.9,
  "pws_max": 43351,
  "pws_avg": 32630.61,
  "pws_p95": 43351,
  "pthr_max": 74,
  "pthr_avg": 71.9,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 87.01,
  "maxcore_p95": 100,
  "pcpu_max": 73.12,
  "pcpu_avg": 33.26,
  "pcpu_p95": 69.27,
  "core_count": 64,
  "per_core_busy_avg": [
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
    0.0,
    0.0,
    0.01,
    0.04,
    0.02,
    0.0,
    0.0,
    0.02,
    0.0,
    0.0,
    0.01,
    0.02,
    0.0,
    0.0,
    0.14,
    0.02,
    0.0,
    0.0,
    0.15,
    0.11,
    0.85,
    0.01,
    0.02,
    0.01,
    0.0,
    0.0,
    0.13,
    0.02,
    0.0,
    0.01,
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
    0.0,
    0.0,
    0.0,
    0.06,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01
  ],
  "per_core_load_avg": [
    0.8,
    3.6,
    1.0,
    3.8,
    3.3,
    3.6,
    3.2,
    4.2,
    3.6,
    3.7,
    3.5,
    3.5,
    3.6,
    3.7,
    3.5,
    3.1,
    1.5,
    2.7,
    3.1,
    2.1,
    1.6,
    1.7,
    2.1,
    1.5,
    1.9,
    1.8,
    1.7,
    2.6,
    8.5,
    3.3,
    1.1,
    2.3,
    13.6,
    8.2,
    75.2,
    3.9,
    3.7,
    3.8,
    3.6,
    3.6,
    6.2,
    2.3,
    2.6,
    3.7,
    3.7,
    3.8,
    3.7,
    3.3,
    2.1,
    2.2,
    2.4,
    1.5,
    1.5,
    2.3,
    1.3,
    1.8,
    1.0,
    1.3,
    3.0,
    0.9,
    1.7,
    1.0,
    1.3,
    1.3
  ],
  "busy_core_span": {
    "cores_ever_busy": 6,
    "cores_mostly_busy": 1
  },
  "busy_core_list": [
    28,
    32,
    33,
    34,
    40
  ],
  "peak_core_list": [
    28,
    32,
    33,
    34,
    40
  ]
}
```
