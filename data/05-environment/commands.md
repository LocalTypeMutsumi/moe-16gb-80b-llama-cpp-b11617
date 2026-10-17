# Exact commands used

All commands assume Windows PowerShell 5.1 on the machine described in `README.md`.
Replace `<MODEL>` with the GGUF path and `<WT>` with `wiki.test.raw`.

## 0. Environment probes

```powershell
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.width.current --format=csv
nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.width.current --format=csv   # repeat DURING decode
Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator,Capacity,Speed,ConfiguredClockSpeed
Get-CimInstance -Namespace 'root\wmi' -ClassName MSAcpi_ThermalZoneTemperature    # returned "not supported" here
```

Hashes (recorded in `data/05-environment/environment.json`):

```powershell
Get-FileHash "<MODEL>" -Algorithm SHA256
Get-FileHash "<llama.cpp>\llama-server.exe" -Algorithm SHA256
Get-FileHash "<llama.cpp>\llama-perplexity.exe" -Algorithm SHA256
Get-FileHash "<WT>" -Algorithm SHA256
```

## 1. Perplexity (quality)

```powershell
# 20 chunks of WikiText-2 test, context 512, all experts on CPU except cache
llama-perplexity -m "<MODEL>" -f "<WT>" -c 512 --chunks 20 `
  -ngl 99 -ncmoe 48 -lm none --moe-cache-mib 0

# repeat with --moe-cache-mib 512 / 2048 / 10752
# add -lv 4 to see the MoE cache engagement line:
#   CUDA0 MoE cache size = 10750.99 MiB for 46224.00 MiB of host experts
#   llama_moe_cache: large batches: 3525 experts copied from the cache, 2209.95 MiB
```

`Final estimate: PPL = ...` is printed to **stderr**, not stdout.

## 2. Decode speed sweep (llama-server)

Server launch used for every speed measurement:

```powershell
llama-server.exe -m "<MODEL>" -c 4096 -ngl 99 -ncmoe 48 `
  -C 0000000000005555 -Cb 0000000000005555 --cpu-strict 1 --cpu-strict-batch 1 `
  -t 8 -tb 8 -lm none -np 1 `
  --host 127.0.0.1 --port 9991 --log-file server.log
```

Variants:

- cache sweep: add `--moe-cache-mib N` (omit entirely for cache = 0)
- ncmoe sweep: change `-ncmoe`

Request body (single completion, greedy):

```json
{"prompt": "<text>", "n_predict": 256, "temperature": 0, "cache_prompt": false, "ignore_eos": true}
```

Baseline before/after each run: same prompt with `"n_predict": 128`.

Health gate before any request:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:9991/health -UseBasicParsing
```

## 3. Scripts

| Script | Purpose |
|---|---|
| `tools/task-sweep-v32.ps1` | Generic config sweep with per-run before/after baseline drift check |
| `tools/task-sweep.ps1` | Same, without baseline |
| `tools/task-b.ps1` | Real-text vs random-token paired stability run (5 processes × 10 pairs) |
| `tools/task-a.ps1` | 10-prompt generation check (4 GSM8K + 4 HumanEval + 2 MMLU) |
| `tools/grade-a.py` | Grader for the 10-prompt check (executes HumanEval `check()`) |

Example — cache curve from 0 to 10752 with baseline drift measurement:

```powershell
$cfg = @(
  @{ label='cache-0';     ncmoe=48; cache=0 },
  @{ label='cache-512';   ncmoe=48; cache=512 },
  @{ label='cache-10752'; ncmoe=48; cache=10752 }
) | ConvertTo-Json -Depth 4 | Set-Content cfg.json -Encoding UTF8

.\task-sweep-v32.ps1 -OutRoot <OUT> -TaskName P3-cache-curve -ConfigsFile cfg.json `
  -PromptFile prompt.txt -Runs 3 -MaxTokens 256 -BaselineTokens 128 -PortBase 10010
```

Every run writes `run<N>.jsonl` with `decode_tps`, `prompt_n`, `predicted_n`,
`vram_peak_mib`, `gpu_util_max`, `power_min_w`/`power_max_w`, `base_before_tps`,
`base_after_tps`, `drift_pct`, `baseline_status`.

## 4. Collapse criterion

A configuration is marked **collapsed** only when all three hold in the same run:

1. GPU utilisation ≥ 99%
2. Power draw < 90 W (normal is ~108–165 W at 100% util here)
3. Decode throughput dropped > 25% versus the good configuration

This is what distinguished the real cliff (ncmoe 44: 23.7 t/s, 95–97% util, 63–92 W)
from ordinary slow-but-healthy configurations.
