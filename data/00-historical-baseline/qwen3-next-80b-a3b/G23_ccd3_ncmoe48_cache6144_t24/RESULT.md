# G23  ·  ccd3 / ncmoe 48 / moe-cache 6144 / -t 24

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 48 |
| moe-cache-mib | 6144 |
| 线程数 | 24（batch 24） |
| CCD 数 | 3 |
| 亲和掩码 请求 / 实际 | `0x00FFFFFF00FFFFFF` / `0x00FFFFFF00FFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 16 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 67.149 | 39.328 | 6478.177 | 4780.285 | 435 | 189 | 11.3 |
| 2 | 272.12 | 45.862 | 1598.56 | 4099.233 | 435 | 189 | 5.7 |
| 3 | 280.605 | 45.925 | 1550.221 | 4093.672 | 435 | 189 | 5.65 |
| **中位数** | **272.12** | **45.862** | | | | | **5.7** |
| **极差** | 213.457 | 6.596 | | | | | 5.65 |
| 首遍偏差 | -75.3% | -14.2% | | | | | |

### 3. 关键观测

- `tg_splits = 50`（cache>0，期望塌缩为常量 46）
- `pp_splits = 144`，graph nodes = 5440 / 5769，pp bs=512 / tg bs=4
- **权重账本**：CUDA 1358.7 MiB + CPU_Mapped 46390.9 MiB = **47749.6 MiB**（145 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **9** / avg **3.34**；进程核数 max **1.12**（采样 41 个，实际 **1.02 Hz**）
- 每核占用：曾有负载 **9** 核，长期繁忙 **1** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`18, 19, 32, 33, 34, 35, 40, 43`
- 高负载核索引（平均≥5%）：`18, 19, 32, 33, 34, 35, 40, 43, 58`
- VRAM 峰值 **10788 MiB**；GPU 利用率 avg 30.46 / max 84；功耗 avg 62.51 W / max 119.7 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（50）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（41 个 / 40.13 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.15.217.987 I sched_reserve: reserving ...
0.15.239.368 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.15.239.375 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.15.239.381 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5440 / 5769, splits = 144 / 50, input objects = 4 / 4, input tensors = 10 / 10
0.15.239.383 I sched_reserve: reserve took 21.39 ms, sched copies = 1
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
  "span_s": 40.13,
  "rate_hz": 1.02,
  "nbusy_max": 9,
  "nbusy_avg": 3.34,
  "nbusy_p95": 6,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.76,
  "nbusy50_p95": 2,
  "nbusy1_max": 64,
  "nbusy1_avg": 29.15,
  "nbusy1_p95": 62,
  "pcores_max": 1.12,
  "pcores_avg": 0.79,
  "pcores_p95": 1.08,
  "cpu_max": 11,
  "cpu_avg": 4.27,
  "cpu_p95": 6,
  "mem_max": 10788,
  "mem_avg": 7032.59,
  "mem_p95": 10788,
  "gu_max": 84,
  "gu_avg": 30.46,
  "gu_p95": 69,
  "pw_max": 119.7,
  "pw_avg": 62.51,
  "pw_p95": 115.6,
  "pws_max": 24121,
  "pws_avg": 12631.23,
  "pws_p95": 24121,
  "pthr_max": 74,
  "pthr_avg": 71.4,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 68.24,
  "maxcore_p95": 100,
  "pcpu_max": 31.45,
  "pcpu_avg": 13.75,
  "pcpu_p95": 30.72,
  "core_count": 64,
  "per_core_busy_avg": [
    0.02,
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
    0.05,
    0.05,
    0.37,
    0.15,
    0.05,
    0.02,
    0.02,
    0.02,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.05,
    0.0,
    0.0,
    0.24,
    0.41,
    0.51,
    0.39,
    0.0,
    0.0,
    0.0,
    0.0,
    0.32,
    0.0,
    0.0,
    0.2,
    0.02,
    0.0,
    0.0,
    0.0,
    0.02,
    0.02,
    0.02,
    0.05,
    0.0,
    0.02,
    0.02,
    0.02,
    0.05,
    0.02,
    0.1,
    0.0,
    0.0,
    0.0,
    0.05,
    0.0
  ],
  "per_core_load_avg": [
    1.1,
    3.4,
    2.8,
    2.5,
    4.2,
    2.9,
    3.1,
    2.8,
    3.1,
    3.2,
    3.1,
    3.1,
    3.2,
    3.1,
    3.0,
    2.9,
    4.6,
    4.6,
    12.8,
    7.9,
    4.4,
    4.4,
    4.1,
    2.6,
    1.9,
    1.4,
    1.9,
    2.0,
    3.6,
    3.3,
    2.4,
    2.9,
    16.1,
    26.9,
    28.3,
    24.4,
    3.2,
    3.1,
    2.8,
    3.1,
    11.5,
    2.2,
    2.6,
    7.4,
    3.5,
    3.2,
    3.1,
    3.1,
    2.2,
    1.4,
    4.1,
    3.2,
    3.3,
    3.5,
    2.4,
    2.1,
    3.0,
    2.3,
    5.5,
    1.9,
    1.6,
    1.7,
    2.9,
    2.2
  ],
  "busy_core_span": {
    "cores_ever_busy": 9,
    "cores_mostly_busy": 1
  },
  "busy_core_list": [
    18,
    19,
    32,
    33,
    34,
    35,
    40,
    43
  ],
  "peak_core_list": [
    18,
    19,
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
