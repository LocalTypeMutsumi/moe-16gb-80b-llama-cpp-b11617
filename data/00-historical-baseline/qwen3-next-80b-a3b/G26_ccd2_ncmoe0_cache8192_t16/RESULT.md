# G26  ·  ccd2 / ncmoe 0 / moe-cache 8192 / -t 16

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
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
| 1 | 118.308 | 10.426 | 3676.843 | 18031.225 | 435 | 189 | 21.74 |
| 2 | 119.39 | 10.421 | 3643.516 | 18040.799 | 435 | 189 | 21.69 |
| 3 | 119.124 | 10.43 | 3651.659 | 18024.556 | 435 | 189 | 21.68 |
| **中位数** | **119.124** | **10.426** | | | | | **21.69** |
| **极差** | 1.082 | 0.009 | | | | | 0.06 |
| 首遍偏差 | -0.7% | +0.0% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 5433 / 5433，pp bs=None / tg bs=None
- **权重账本**：CUDA 47582.7 MiB + CPU_Mapped 166.9 MiB = **47749.6 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **5** / avg **2.12**；进程核数 max **1.05**（采样 88 个，实际 **1.0 Hz**）
- 每核占用：曾有负载 **6** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35, 58`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35`
- VRAM 峰值 **15533 MiB**；GPU 利用率 avg 77.23 / max 100；功耗 avg 68.02 W / max 80.4 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（88 个 / 87.9 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.21.584.470 I sched_reserve: reserving ...
0.21.603.743 I sched_reserve:      CUDA0 compute buffer size =   139.01 MiB
0.21.603.749 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.21.603.752 I sched_reserve: graph: nodes = 5433, splits = 2, input objects = 4, input tensors = 10
0.21.603.754 I sched_reserve: reserve took 19.28 ms, sched copies = 1
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
  "samples": 88,
  "span_s": 87.9,
  "rate_hz": 1.0,
  "nbusy_max": 5,
  "nbusy_avg": 2.12,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.99,
  "nbusy50_p95": 1,
  "nbusy1_max": 58,
  "nbusy1_avg": 20.44,
  "nbusy1_p95": 39,
  "pcores_max": 1.05,
  "pcores_avg": -0.07,
  "pcores_p95": 1.03,
  "cpu_max": 8,
  "cpu_avg": 3.26,
  "cpu_p95": 6,
  "mem_max": 15533,
  "mem_avg": 14691.2,
  "mem_p95": 15533,
  "gu_max": 100,
  "gu_avg": 77.23,
  "gu_p95": 100,
  "pw_max": 80.4,
  "pw_avg": 68.02,
  "pw_p95": 77.7,
  "pws_max": 82893,
  "pws_avg": 72470.06,
  "pws_p95": 82893,
  "pthr_max": 74,
  "pthr_avg": 71.95,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 90.36,
  "maxcore_p95": 100,
  "pcpu_max": 87.83,
  "pcpu_avg": 41.42,
  "pcpu_p95": 78.42,
  "core_count": 64,
  "per_core_busy_avg": [
    0.0,
    0.01,
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
    0.02,
    0.0,
    0.03,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.01,
    0.03,
    0.01,
    0.01,
    0.27,
    0.39,
    0.45,
    0.47,
    0.0,
    0.0,
    0.0,
    0.0,
    0.08,
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
    0.01,
    0.0,
    0.01,
    0.15,
    0.01,
    0.02,
    0.02,
    0.01,
    0.01
  ],
  "per_core_load_avg": [
    0.6,
    3.9,
    2.5,
    3.3,
    2.2,
    2.4,
    2.1,
    2.1,
    2.3,
    2.3,
    2.5,
    2.3,
    2.4,
    2.4,
    2.3,
    2.3,
    2.2,
    1.5,
    2.1,
    1.6,
    2.7,
    2.5,
    1.1,
    1.4,
    0.9,
    0.6,
    1.0,
    1.1,
    3.8,
    2.7,
    1.6,
    2.1,
    19.7,
    31.2,
    29.8,
    37.2,
    1.9,
    2.4,
    2.6,
    2.4,
    4.1,
    1.7,
    1.0,
    2.4,
    2.3,
    2.0,
    2.3,
    2.5,
    1.3,
    1.3,
    0.8,
    0.9,
    1.8,
    2.5,
    0.9,
    2.3,
    1.5,
    1.8,
    4.6,
    1.5,
    1.8,
    2.4,
    2.4,
    2.1
  ],
  "busy_core_span": {
    "cores_ever_busy": 6,
    "cores_mostly_busy": 0
  },
  "busy_core_list": [
    32,
    33,
    34,
    35,
    58
  ],
  "peak_core_list": [
    32,
    33,
    34,
    35
  ]
}
```
