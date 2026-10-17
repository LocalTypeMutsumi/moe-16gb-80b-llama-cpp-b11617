# G27  ·  ccd3 / ncmoe 0 / moe-cache 8192 / -t 24

## 一、最终输出

### 1. 组配置

| 项 | 值 |
|---|---|
| 模型 | qwen3-next-80b-a3b |
| 模型路径 | `D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf` |
| ncmoe | 0 |
| moe-cache-mib | 8192 |
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
| 1 | 117.646 | 10.401 | 3697.528 | 18074.742 | 435 | 189 | 21.81 |
| 2 | 119.106 | 10.403 | 3652.211 | 18071.392 | 435 | 189 | 21.73 |
| 3 | 119.176 | 10.41 | 3650.05 | 18058.995 | 435 | 189 | 21.71 |
| **中位数** | **119.106** | **10.403** | | | | | **21.73** |
| **极差** | 1.53 | 0.009 | | | | | 0.1 |
| 首遍偏差 | -1.2% | -0.0% | | | | | |

### 3. 关键观测

- `tg_splits = 2`（cache>0，期望塌缩为常量 46）
- `pp_splits = 2`，graph nodes = 5433 / 5433，pp bs=None / tg bs=None
- **权重账本**：CUDA 47582.7 MiB + CPU_Mapped 166.9 MiB = **47749.6 MiB**（1 个 CPU 块 / 1 个 CUDA 块）
- GPU 层：**49/49**
- CPU 占用：nbusy max **6** / avg **1.78**；进程核数 max **1.06**（采样 89 个，实际 **1.01 Hz**）
- 每核占用：曾有负载 **5** 核，长期繁忙 **0** 核（共 64 逻辑核）
- 繁忙核索引（占用>10% 时间）：`32, 33, 34, 35`
- 高负载核索引（平均≥5%）：`32, 33, 34, 35`
- VRAM 峰值 **15533 MiB**；GPU 利用率 avg 77.35 / max 100；功耗 avg 67.81 W / max 79.7 W；进程线程数 max 74
- MoE cache 统计：无（cache=0 或未优雅退出）

### 4. 自洽校验

- [x] 权重账本闭合（47749.6 MiB）
- [x] tg_splits 符合预期（2）
- [x] 实际亲和性 == 请求掩码
- [x] 采样非空且覆盖全程（89 个 / 88.26 s）
- [x] prompt_n 三遍一致（无 KV 复用）：[435]

## 二、原始输出

### 5. 调度指纹（sched_reserve 原文）

```
0.21.696.206 I sched_reserve: reserving ...
0.21.715.745 I sched_reserve:      CUDA0 compute buffer size =   139.01 MiB
0.21.715.751 I sched_reserve:  CUDA_Host compute buffer size =    24.02 MiB
0.21.715.754 I sched_reserve: graph: nodes = 5433, splits = 2, input objects = 4, input tensors = 10
0.21.715.755 I sched_reserve: reserve took 19.55 ms, sched copies = 1
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
  "span_s": 88.26,
  "rate_hz": 1.01,
  "nbusy_max": 6,
  "nbusy_avg": 1.78,
  "nbusy_p95": 4,
  "nbusy50_max": 2,
  "nbusy50_avg": 0.97,
  "nbusy50_p95": 1,
  "nbusy1_max": 53,
  "nbusy1_avg": 18.06,
  "nbusy1_p95": 37,
  "pcores_max": 1.06,
  "pcores_avg": -0.04,
  "pcores_p95": 1.03,
  "cpu_max": 11,
  "cpu_avg": 2.9,
  "cpu_p95": 6,
  "mem_max": 15533,
  "mem_avg": 14733.27,
  "mem_p95": 15533,
  "gu_max": 100,
  "gu_avg": 77.35,
  "gu_p95": 100,
  "pw_max": 79.7,
  "pw_avg": 67.81,
  "pw_p95": 77.8,
  "pws_max": 82893,
  "pws_avg": 72572.57,
  "pws_p95": 82893,
  "pthr_max": 74,
  "pthr_avg": 71.17,
  "pthr_p95": 74,
  "maxcore_max": 100,
  "maxcore_avg": 85.29,
  "maxcore_p95": 100,
  "pcpu_max": 84.89,
  "pcpu_avg": 41.58,
  "pcpu_p95": 78.62,
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
    0.01,
    0.01,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.03,
    0.0,
    0.03,
    0.0,
    0.34,
    0.43,
    0.3,
    0.38,
    0.01,
    0.0,
    0.0,
    0.0,
    0.04,
    0.0,
    0.0,
    0.01,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.02,
    0.0,
    0.02,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.06,
    0.0,
    0.02,
    0.0,
    0.0,
    0.01
  ],
  "per_core_load_avg": [
    0.3,
    2.9,
    2.7,
    2.5,
    2.7,
    2.4,
    2.4,
    2.5,
    2.3,
    2.3,
    2.4,
    2.4,
    2.5,
    2.5,
    2.5,
    2.2,
    2.1,
    1.2,
    1.7,
    2.1,
    1.1,
    0.8,
    1.3,
    0.8,
    0.7,
    0.3,
    0.8,
    0.8,
    3.9,
    1.7,
    2.4,
    1.9,
    22.0,
    35.5,
    24.1,
    31.4,
    2.9,
    2.5,
    2.4,
    2.4,
    3.6,
    1.2,
    1.4,
    2.2,
    2.6,
    2.4,
    2.3,
    2.4,
    1.2,
    1.0,
    2.1,
    1.0,
    1.3,
    1.7,
    1.4,
    1.9,
    1.2,
    1.3,
    2.7,
    0.4,
    1.2,
    1.5,
    1.1,
    1.6
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
