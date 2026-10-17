# G22  ·  ccd2 / ncmoe 48 / moe-cache 6144 / -t 16

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 48 |
| moe-cache-mib | 6144 |
| 线程数 | 16（batch 16） |
| CCD 数 | 2 |
| 亲和掩码 请求 / 实际 | `0x0000FFFF0000FFFF` / `0x0000FFFF0000FFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 16 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 67.492 | 40.084 | 6445.169 | 4690.149 | 435 | 189 | 11.17 |
| 2 | 272.988 | 46.64 | 1593.476 | 4030.856 | 435 | 189 | 5.63 |
| 3 | 282.465 | 46.347 | 1540.013 | 4056.4 | 435 | 189 | 5.6 |
| **中位数** | **272.988** | **46.347** | | | | | **5.63** |
| **极差** | 214.973 | 6.556 | | | | | 5.57 |
| 首遍偏差 | -75.3% | -13.5% | | | | | |

### 3. 关键观测

- `tg_splits = 50`（cache>0，期望塌缩为常量 46）
- `pp_splits = 144`，graph nodes = 5440 / 5769，pp bs=512 / tg bs=4
- **权重账本**：CUDA 1358.7 MiB + CPU_Mapped 46390.9 MiB = **47749.6 MiB**（145 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **6** / avg **2.49**；进程核数 max **1.09**（采样 41 个，实际 **1.02 Hz**）
- 每核占用：曾有负载 **7** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`2, 32, 33, 34, 35, 40, 43`
- 高负载核索引（平均≥5%）：`2, 32, 33, 34, 35, 37, 40, 43`
- VRAM 峰值 **10788 MiB**；GPU 利用率 avg 30.39 / max 70；功耗 avg 62.61 W / max 119.1 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（50）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（41 个 / 40.15 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.14.980.246 I sched_reserve: reserving ...
0.15.001.703 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.15.001.710 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.15.001.715 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5440 / 5769, splits = 144 / 50, input objects = 4 / 4, input tensors = 10 / 10
0.15.001.718 I sched_reserve: reserve took 21.47 ms, sched copies = 1
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
  "samples": 41,
  "span_s": 40.15,
  "rate_hz": 1.02,
  "nbusy_max": 6,
  "nbusy_avg": 2.49,
  "nbusy_p95": 5,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.98,
  "nbusy50_p95": 2,
  "nbusy1_max": 49,
  "nbusy1_avg": 23.8,
  "nbusy1_p95": 44,
  "pcores_max": 1.09,
  "pcores_avg": 0.77,
  "pcores_p95": 1.08,
  "cpu_max": 9,
  "cpu_avg": 3.61,
  "cpu_p95": 7,
  "mem_max": 10788,
  "mem_avg": 7065.8,
  "mem_p95": 10788,
  "gu_max": 70,
  "gu_avg": 30.39,
  "gu_p95": 68,
  "pw_max": 119.1,
  "pw_avg": 62.61,
  "pw_p95": 117.3,
  "pws_max": 24122,
  "pws_avg": 12644.23,
  "pws_p95": 24122,
  "pthr_max": 74,
  "pthr_avg": 71.4,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 79.07,
  "maxcore_p95": 100,
  "pcpu_max": 31,
  "pcpu_avg": 13.37,
  "pcpu_p95": 30.09,
  "core_count": 64,
  "per_core_busy_avg": [
    0.0,
    0.02,
    0.2,
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
    0.05,
    0.05,
    0.02,
    0.0,
    0.0,
    0.0,
    0.02,
    0.05,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.24,
    0.44,
    0.49,
    0.44,
    0.0,
    0.0,
    0.0,
    0.0,
    0.24,
    0.0,
    0.0,
    0.17,
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
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0
  ],
  "per_core_load_avg": [
    0.5,
    4.6,
    9.5,
    3.9,
    3.7,
    3.6,
    4.1,
    4.4,
    4.6,
    4.1,
    3.9,
    4.2,
    4.0,
    4.0,
    4.3,
    4.0,
    2.3,
    2.2,
    2.1,
    1.7,
    0.5,
    0.5,
    2.3,
    1.9,
    1.2,
    1.1,
    0.9,
    1.3,
    3.2,
    1.2,
    1.3,
    0.8,
    14.8,
    26.9,
    33.6,
    32.7,
    4.9,
    5.0,
    3.9,
    2.6,
    11.5,
    3.9,
    2.1,
    6.1,
    3.8,
    4.4,
    4.0,
    4.4,
    0.8,
    0.9,
    1.5,
    1.6,
    0.5,
    1.0,
    2.0,
    1.8,
    1.5,
    1.6,
    2.8,
    0.9,
    0.6,
    2.0,
    0.8,
    2.0
  ],
  "busy_core_span": {
    "cores_ever_busy": 7,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    2,
    32,
    33,
    34,
    35,
    40,
    43
  ],
  "peak_core_list": [
    2,
    32,
    33,
    34,
    35,
    37,
    40,
    43
  ]
}
```
