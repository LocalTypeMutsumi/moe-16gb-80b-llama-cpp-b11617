@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem  Qwen3-Next-80B-A3B-Instruct Q4_K_M  /  llama.cpp b11617
rem  Best measured configuration (from the MoE expert-cache benchmark)
rem
rem  Measured on: RTX 4070 Ti SUPER 16GB + Threadripper PRO 5975WX
rem  Result:      decode 80.673 t/s (warm-cache protocol, repeated prompt)
rem               decode 67.54 t/s (real diverse text, P5 run)
rem  Quality:     perplexity 4.4617 across cache 0/512/2048/10752 (20 chunks)
rem
rem  IMPORTANT - what 0x5555 actually means here:
rem    It selects logical CPUs 0,2,4,6,8,10,12,14
rem    On this CPU those are ALL inside CCD0 -> 8 threads on one CCD.
rem    Adding CCDs was never tested in this benchmark, so do not read this
rem    as "one CCD is optimal".
rem
rem  VRAM budget:
rem    cache 10752 -> ~13.9 GB for the model+KV, plus desktop usage
rem    If desktop apps hold 2+ GB you may OOM. Fallback:  cache 8192
rem      (measured 69.718 t/s, -13.6% vs 10752, but ~2.5 GB more headroom)
rem
rem  Usage:
rem    serve-qwen3-next-80b.cmd           -> cache 10752 (best)
rem    serve-qwen3-next-80b.cmd 8192      -> cache 8192  (safe)
rem    serve-qwen3-next-80b.cmd 6144      -> cache 6144  (61.675 t/s)
rem ============================================================================

set "LLAMA=E:\Apps\llama.cpp\b11617"
set "MODEL=D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf"
set "CACHE=10752"
set "PORT=8080"

if not "%~1"=="" set "CACHE=%~1"
if not "%~2"=="" set "PORT=%~2"

if not exist "%LLAMA%\llama-server.exe" (
    echo [ERROR] llama-server.exe not found under %LLAMA%
    exit /b 1
)
if not exist "%MODEL%" (
    echo [ERROR] model not found:
    echo         %MODEL%
    exit /b 1
)

echo.
echo  model : Qwen3-Next-80B-A3B-Instruct Q4_K_M
echo  cache : %CACHE% MiB   ncmoe : 48   threads : 8   mask : 0x5555
echo  url   : http://127.0.0.1:%PORT%
echo  note  : warm-cache protocol. Cold one-shot requests will be slower.
echo.

"%LLAMA%\llama-server.exe" ^
  -m "%MODEL%" ^
  -c 4096 ^
  -ngl 99 ^
  -ncmoe 48 ^
  --moe-cache-mib %CACHE% ^
  -C 0x5555 ^
  --cpu-strict 1 ^
  -t 8 -tb 8 ^
  -lm none ^
  -np 1 ^
  --host 127.0.0.1 ^
  --port %PORT%

endlocal
