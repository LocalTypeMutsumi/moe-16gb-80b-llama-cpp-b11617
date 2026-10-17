# G19  ·  ccd3 / ncmoe 40 / moe-cache 6144 / -t 24

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 40 |
| moe-cache-mib | 6144 |
| 线程数 | 24（batch 24） |
| CCD 数 | 3 |
| 亲和掩码 请求 / 实际 | `0x00FFFFFF00FFFFFF` / `0x00FFFFFF00FFFFFF` |
| 亲和判定 | **通过** |
| 上下文 / 生成长度 | 8192 / 192 |
| 加载耗时 | 19 s |
| 退出方式 | 优雅 |
| 模型形状 | n_layer=48, n_expert=512, n_expert_used=10, n_embd=2048, type=80B.A3B |

### 2. 三次结果

| 遍 | prefill t/s | decode t/s | prefill ms | decode ms | prompt_n | predicted_n | wall s |
|---|---|---|---|---|---|---|---|
| 1 | 48.906 | 18.54 | 8894.6 | 10140.245 | 435 | 189 | 19.07 |
| 2 | 85.51 | 19.505 | 5087.122 | 9638.442 | 435 | 189 | 14.73 |
| 3 | 85.131 | 19.397 | 5109.788 | 9692.298 | 435 | 189 | 14.81 |
| **中位数** | **85.131** | **19.397** | | | | | **14.81** |
| **极差** | 36.604 | 0.965 | | | | | 4.34 |
| 首遍偏差 | -42.6% | -4.4% | | | | | |

### 3. 关键观测

- `tg_splits = 42`（cache>0，期望塌缩为常量 46）
- `pp_splits = 122`，graph nodes = 5433 / 5713，pp bs=512 / tg bs=4
- **权重账本**：CUDA 8930.6 MiB + CPU_Mapped 38818.9 MiB = **47749.5 MiB**（121 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **7** / avg **2.3**；进程核数 max **1.06**（采样 70 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **8** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`18, 32, 33, 34, 35, 40`
- 高负载核索引（平均≥5%）：`18, 32, 33, 34, 35, 40`
- VRAM 峰值 **15610 MiB**；GPU 利用率 avg 57.53 / max 100；功耗 avg 66.83 W / max 89 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.5 MiB）
- [x] tg_splits 符合预期（42）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（70 个 / 69.26 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.18.270.883 I sched_reserve: reserving ...
0.18.292.923 I sched_reserve:      CUDA0 compute buffer size =   874.00 MiB
0.18.292.930 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.18.292.938 I sched_reserve: graph (pp bs=512, tg bs=4): nodes = 5433 / 5713, splits = 122 / 42, input objects = 4 / 4, input tensors = 10 / 10
0.18.292.940 I sched_reserve: reserve took 22.05 ms, sched copies = 1
```

### 6. 权重分布

| 设备 | 张量块数 | 合计 MiB |
|---|---|---|
| CUDA0 | 1 | 8930.6 |
| CPU_Mapped (mmap) | 121 | 38818.9 |
| Host | - | 0.0 |
| **合计** | | **47749.5** |

CPU 侧张量块尺寸种类：166.92 MiB, 288 MiB, 420 MiB

### 7. 采样统计

```json
{
  "samples": 70,
  "span_s": 69.26,
  "rate_hz": 1.01,
  "nbusy_max": 7,
  "nbusy_avg": 2.3,
  "nbusy_p95": 5,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.99,
  "nbusy50_p95": 1,
  "nbusy1_max": 44,
  "nbusy1_avg": 18.1,
  "nbusy1_p95": 40,
  "pcores_max": 1.06,
  "pcores_avg": 0.88,
  "pcores_p95": 1.03,
  "cpu_max": 8,
  "cpu_avg": 3.03,
  "cpu_p95": 7,
  "mem_max": 15610,
  "mem_avg": 12016.6,
  "mem_p95": 15610,
  "gu_max": 100,
  "gu_avg": 57.53,
  "gu_p95": 94,
  "pw_max": 89,
  "pw_avg": 66.83,
  "pw_p95": 88.6,
  "pws_max": 31847,
  "pws_avg": 22157.29,
  "pws_p95": 31847,
  "pthr_max": 74,
  "pthr_avg": 72.1,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 89.04,
  "maxcore_p95": 100,
  "pcpu_max": 60.44,
  "pcpu_avg": 27.44,
  "pcpu_p95": 57.69,
  "core_count": 64,
  "per_core_busy_avg": [
    0.03,
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
    0.03,
    0.03,
    0.13,
    0.0,
    0.01,
    0.01,
    0.01,
    0.0,
    0.01,
    0.01,
    0.0,
    0.0,
    0.03,
    0.03,
    0.0,
    0.0,
    0.27,
    0.39,
    0.49,
    0.39,
    0.0,
    0.0,
    0.0,
    0.0,
    0.16,
    0.03,
    0.0,
    0.07,
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
    0.0,
    0.03,
    0.0,
    0.0,
    0.1,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01
  ],
  "per_core_load_avg": [
    1.1,
    2.7,
    1.4,
    2.3,
    1.8,
    2.6,
    2.1,
    2.4,
    2.5,
    2.3,
    2.2,
    2.3,
    2.6,
    2.3,
    2.3,
    2.2,
    1.7,
    3.7,
    5.4,
    1.4,
    1.7,
    1.6,
    1.7,
    1.2,
    1.7,
    1.4,
    0.6,
    1.3,
    4.4,
    1.8,
    1.3,
    1.7,
    15.9,
    34.5,
    32.2,
    30.8,
    2.5,
    2.7,
    2.3,
    2.3,
    6.9,
    2.9,
    1.3,
    4.2,
    2.4,
    2.5,
    2.4,
    2.3,
    1.0,
    0.9,
    1.6,
    1.2,
    0.8,
    1.5,
    1.7,
    1.8,
    1.1,
    1.4,
    3.9,
    1.1,
    0.5,
    1.0,
    1.1,
    1.5
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
    35,
    40
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
