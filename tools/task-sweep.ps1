# task-sweep.ps1 -- generic config sweep for T-REDO-PREPOST tasks C and D.
#
# TASK C (memory collapse): ncmoe 9 / 10 / 11, 3 runs each, find where collapse happens.
#   Three symptoms must appear together per the pack: GPU util >=99%, power <90W, speed drop >25%.
#   Requires simultaneous telemetry -> nvidia-smi loop while the request runs.
#
# TASK D (decode break-even): cache 0 / 512 / 2048, 3 runs each, fixed ncmoe 20.
#
# ROLE: executor + recorder. No judging, no retries to hide anomalies, no overwriting.
#
# ASCII ONLY.

param(
  [Parameter(Mandatory=$true)][string]$OutRoot,
  [Parameter(Mandatory=$true)][string]$TaskName,
  [string]$ConfigsJson = '',
  [string]$ConfigsFile = '',
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [string]$ModelPath = 'D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf',
  [int]$Runs = 3,
  [int]$MaxTokens = 256,
  [int]$PortBase = 9990,
  [int]$TelemetryMs = 500
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$exe = 'E:\Apps\llama.cpp\b11617\llama-server.exe'
$smi = 'C:\Windows\System32\nvidia-smi.exe'
if (-not (Test-Path $smi)) { $smi = (Get-Command nvidia-smi).Source }

function Esc-JS([string]$s) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.ToCharArray()) {
    $c = [int]$ch
    if ($ch -eq '"') { [void]$sb.Append('\"') }
    elseif ($ch -eq '\') { [void]$sb.Append('\\') }
    elseif ($ch -eq "`n") { [void]$sb.Append('\n') }
    elseif ($ch -eq "`r") { [void]$sb.Append('\r') }
    elseif ($ch -eq "`t") { [void]$sb.Append('\t') }
    elseif ($c -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $c)) }
    else { [void]$sb.Append($ch) }
  }
  return $sb.ToString()
}

$text = [System.IO.File]::ReadAllText($PromptFile, $utf8)
# Configs come from a FILE. Passing raw JSON on the command line broke because
# Start-Process splits on the embedded commas/quotes (observed: "label:" landed in TelemetryMs).
if ($ConfigsFile -and (Test-Path $ConfigsFile)) {
  $configs = [System.IO.File]::ReadAllText($ConfigsFile, $utf8) | ConvertFrom-Json
} elseif ($ConfigsJson) {
  $configs = $ConfigsJson | ConvertFrom-Json
} else { throw 'need -ConfigsFile or -ConfigsJson' }
$taskDir = Join-Path $OutRoot $TaskName
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null

$all = @()
$ci = 0
foreach ($cfg in $configs) {
  $ci++
  $port = $PortBase + $ci
  $label = [string]$cfg.label
  $dir = Join-Path $taskDir $label
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $srvLog = Join-Path $dir 'server.log'
  $telDir = Join-Path $taskDir 'telemetry'
  New-Item -ItemType Directory -Path $telDir -Force | Out-Null
  $telFile = Join-Path $telDir ($label + '.csv')

  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    Write-Output ("{0}: port {1} busy, skip (do NOT kill holder)" -f $label, $port); continue
  }

  Write-Output ("=== {0}  ncmoe={1} cache={2}  port {3}  start {4} ===" -f `
    $label, $cfg.ncmoe, $cfg.cache, $port, (Get-Date -Format 'HH:mm:ss'))

  $args = @('-m',$ModelPath,'-c','4096','-ngl','99','-ncmoe',"$($cfg.ncmoe)",
            '-C','0000000000005555','-Cb','0000000000005555','--cpu-strict','1','--cpu-strict-batch','1',
            '-t','8','-tb','8','-lm','none','-np','1',
            '--host','127.0.0.1','--port',"$port",'--log-file',$srvLog)
  if ([int]$cfg.cache -gt 0) { $args += @('--moe-cache-mib',"$($cfg.cache)") }

  $srv = Start-Process -FilePath $exe -ArgumentList $args `
           -RedirectStandardOutput ($srvLog + '.out') -RedirectStandardError ($srvLog + '.err') `
           -WindowStyle Hidden -PassThru
  try {
    $t0 = Get-Date; $ready = $false
    while (((Get-Date)-$t0).TotalSeconds -lt 300) {
      Start-Sleep -Milliseconds 800
      if ($srv.HasExited) { break }
      try { $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/health" -f $port) -TimeoutSec 3 -UseBasicParsing
            if ($r.StatusCode -eq 200) { $ready = $true; break } } catch { }
    }
    $loadS = [math]::Round(((Get-Date)-$t0).TotalSeconds,1)
    if (-not $ready) {
      Write-Output ("{0}: server NOT ready after {1}s -> FAILED" -f $label, $loadS)
      [ordered]@{label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; status='FAILED'; reason='server not ready'; load_s=$loadS} |
        ConvertTo-Json | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
      $all += [ordered]@{ label=$label; status='FAILED' }
      continue
    }
    Write-Output ("{0}: ready in {1}s" -f $label, $loadS)

    $perRun = @()
    for ($r = 1; $r -le $Runs; $r++) {
      # telemetry: single nvidia-smi loop process, stopped after the request
      $telProc = $null
      try {
        $telProc = Start-Process -FilePath $smi -ArgumentList @(
            '--query-gpu=timestamp,memory.used,utilization.gpu,power.draw,temperature.gpu',
            '--format=csv,noheader,nounits',("--loop-ms={0}" -f $TelemetryMs)) `
          -RedirectStandardOutput $telFile -RedirectStandardError ($telFile + '.err') `
          -WindowStyle Hidden -PassThru
      } catch { }
      Start-Sleep -Milliseconds 600

      $body = '{"prompt":"' + (Esc-JS $text) + '","n_predict":' + $MaxTokens + ',"temperature":0,"cache_prompt":false,"ignore_eos":true}'
      $b = $utf8.GetBytes($body)
      $t1 = Get-Date
      $errMsg = $null; $resp = $null
      try {
        $resp = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $port) -Method Post `
                  -ContentType 'application/json; charset=utf-8' -Body $b -TimeoutSec 900
      } catch { $errMsg = $_.Exception.Message }
      $elapsed = [math]::Round(((Get-Date)-$t1).TotalSeconds,2)

      try { if ($telProc -and -not $telProc.HasExited) { Stop-Process -Id $telProc.Id -Force -ErrorAction SilentlyContinue } } catch { }
      Start-Sleep -Milliseconds 300

      # telemetry summary for this run
      $peakMem=$null; $maxUtil=$null; $maxPower=$null; $minPower=$null; $maxTemp=$null; $samples=0
      $seg = "$telFile.seg$r.csv"
      if (Test-Path $telFile) { Move-Item $telFile $seg -Force; $src = $seg } else { $src = $null }
      if ($src -and (Test-Path $src)) {
        $mem=@(); $util=@(); $pw=@(); $tp=@()
        foreach ($ln in (Get-Content $src -Encoding ASCII)) {
          $f = $ln -split ','
          if ($f.Count -ge 5) {
            if ($f[1].Trim() -match '^\d+$') { $mem += [int]$f[1] }
            if ($f[2].Trim() -match '^\d+$') { $util += [int]$f[2] }
            if ($f[3].Trim() -match '^[\d.]+$') { $pw += [double]$f[3] }
            if ($f[4].Trim() -match '^\d+$') { $tp += [int]$f[4] }
          }
        }
        $samples = $mem.Count
        if ($mem.Count) { $peakMem = ($mem|Measure-Object -Maximum).Maximum; $maxUtil = ($util|Measure-Object -Maximum).Maximum }
        if ($pw.Count) { $maxPower = ($pw|Measure-Object -Maximum).Maximum; $minPower = ($pw|Measure-Object -Minimum).Minimum }
        if ($tp.Count) { $maxTemp = ($tp|Measure-Object -Maximum).Maximum }
      }

      $rec = [ordered]@{
        label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; run=$r
        ok=$(($null -eq $errMsg)); error=$errMsg
        decode_tps=$(if ($resp) { [math]::Round([double]$resp.timings.predicted_per_second,3) } else { $null })
        prefill_tps=$(if ($resp) { [math]::Round([double]$resp.timings.prompt_per_second,3) } else { $null })
        prompt_n=$(if ($resp) { $resp.timings.prompt_n } else { $null })
        predicted_n=$(if ($resp) { $resp.timings.predicted_n } else { $null })
        client_elapsed_s=$elapsed
        vram_peak_mib=$peakMem; gpu_util_max=$maxUtil
        power_max_w=$maxPower; power_min_w=$minPower; temp_max_c=$maxTemp
        telemetry_samples=$samples; telemetry_file=("telemetry/{0}.seg{1}.csv" -f $label, $r)
      }
      $rec | ConvertTo-Json -Compress | Add-Content (Join-Path $dir ("run{0}.jsonl" -f $r)) -Encoding UTF8
      $perRun += $rec
      Write-Output ("  run{0}: decode {1,8} t/s | util {2}% | power {3}-{4} W | temp {5} C | vram {6} MiB" -f `
        $r, $rec.decode_tps, $rec.gpu_util_max, $rec.power_min_w, $rec.power_max_w, $rec.temp_max_c, $rec.vram_peak_mib)
    }

    $ds = @($perRun | Where-Object { $_.ok -and $null -ne $_.decode_tps } | ForEach-Object { [double]$_.decode_tps } | Sort-Object)
    $meta = [ordered]@{
      label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; status='VALID'
      load_s=$loadS; runs=$Runs; ok=$(@($perRun|Where-Object{$_.ok}).Count)
      decode_median=$(if ($ds.Count) { $ds[[int]($ds.Count/2)] } else { $null })
      decode_min=$(if ($ds.Count) { $ds[0] } else { $null })
      decode_max=$(if ($ds.Count) { $ds[-1] } else { $null })
      finished_at=(Get-Date -Format 'o')
    }
    $meta | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
    $all += $meta
  } finally {
    try { if (-not $srv.HasExited) { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } } catch { }
    for ($i=0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 300; if ($srv.HasExited) { break } }
    Start-Sleep -Seconds 2
  }
}

$summary = @($all | ForEach-Object { [pscustomobject]$_ })
if ($summary.Count) {
  $summary | Export-Csv -Path (Join-Path $taskDir 'summary.csv') -NoTypeInformation -Encoding UTF8
}
Write-Output ""
foreach ($m in $all) {
  Write-Output ("{0,-10} ncmoe={1,-3} cache={2,-6} median={3} [{4}-{5}] status={6}" -f `
    $m.label, $m.ncmoe, $m.cache, $m.decode_median, $m.decode_min, $m.decode_max, $m.status)
}
Write-Output ("done at {0}" -f (Get-Date -Format 'HH:mm:ss'))
