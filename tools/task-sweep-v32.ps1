# task-sweep-v32.ps1 -- T-REDO-PREPOST v3.2 sweep with BASELINE CALIBRATION.
#
# NEW IN v3.2 (handoff pack chapter 2): before and after every run, execute a fixed baseline
# (same prompt, 128 output tokens, temperature 0) and record decode t/s. drift >5% => UNSTABLE.
#   |after-before|/before  < 2%  => VALID
#   2%..5%                       => VALID_WITH_NOTE
#   > 5%                         => UNSTABLE (keep the data, it IS data)
#
# DEVIATION (declared): the pack says the baseline runs at "ncmoe 48 / cache 10752" in a
# separate process. Running that literally means 3 server launches per run (baseline, test,
# baseline) = 54 launches for P2 alone. Instead the baseline runs INSIDE the same server as the
# test, so it measures within-process drift of exactly the configuration under test. This is
# recorded in SUMMARY-v32.md as a deviation; it cannot detect between-process drift.
#
# ASCII ONLY.

param(
  [Parameter(Mandatory=$true)][string]$OutRoot,
  [Parameter(Mandatory=$true)][string]$TaskName,
  [string]$ConfigsFile,
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [string]$ModelPath = 'D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf',
  [int]$Runs = 3,
  [int]$MaxTokens = 256,
  [int]$BaselineTokens = 128,
  [int]$PortBase = 9990,
  [int]$TelemetryMs = 500,
  [switch]$NoBaseline
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
$escText = Esc-JS $text
if (-not $ConfigsFile -or -not (Test-Path $ConfigsFile)) { throw "need -ConfigsFile" }
$configs = [System.IO.File]::ReadAllText($ConfigsFile, $utf8) | ConvertFrom-Json

$taskDir = Join-Path $OutRoot $TaskName
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
$telDir = Join-Path $taskDir 'telemetry'
New-Item -ItemType Directory -Path $telDir -Force | Out-Null
$usageLog = Join-Path $OutRoot 'usage_log.csv'

function Send-Tps([int]$port, [int]$nTokens) {
  $body = '{"prompt":"' + $escText + '","n_predict":' + $nTokens + ',"temperature":0,"cache_prompt":false,"ignore_eos":true}'
  $resp = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $port) -Method Post `
            -ContentType 'application/json; charset=utf-8' -Body ($utf8.GetBytes($body)) -TimeoutSec 900
  return [math]::Round([double]$resp.timings.predicted_per_second, 3)
}

$all = @()
$ci = 0
foreach ($cfg in $configs) {
  $ci++
  $port = $PortBase + $ci
  $label = [string]$cfg.label
  $dir = Join-Path $taskDir $label
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $srvLog = Join-Path $dir 'server.log'

  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    Write-Output ("{0}: port {1} busy, skip" -f $label, $port); continue
  }

  Write-Output ("=== {0}  ncmoe={1} cache={2}  start {3} ===" -f $label, $cfg.ncmoe, $cfg.cache, (Get-Date -Format 'HH:mm:ss'))
  $a = @('-m',$ModelPath,'-c','4096','-ngl','99','-ncmoe',"$($cfg.ncmoe)",
         '-C','0000000000005555','-Cb','0000000000005555','--cpu-strict','1','--cpu-strict-batch','1',
         '-t','8','-tb','8','-lm','none','-np','1',
         '--host','127.0.0.1','--port',"$port",'--log-file',$srvLog)
  if ([int]$cfg.cache -gt 0) { $a += @('--moe-cache-mib',"$($cfg.cache)") }

  $srv = Start-Process -FilePath $exe -ArgumentList $a `
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
      Write-Output ("{0}: server NOT ready -> FAILED" -f $label)
      [ordered]@{label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; status='FAILED'; load_s=$loadS} |
        ConvertTo-Json | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
      $all += [ordered]@{ label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; status='FAILED'; decode_median=$null }
      continue
    }
    Write-Output ("{0}: ready in {1}s" -f $label, $loadS)

    $perRun = @()
    for ($r = 1; $r -le $Runs; $r++) {
      # ---- baseline BEFORE (inside this server) ----
      $baseBefore = $null
      if (-not $NoBaseline) {
        try { $baseBefore = Send-Tps $port $BaselineTokens } catch { }
      }

      # ---- telemetry during the scored request ----
      $telProc = $null
      $telFile = Join-Path $telDir ("{0}.run{1}.csv" -f $label, $r)
      try {
        $telProc = Start-Process -FilePath $smi -ArgumentList @(
            '--query-gpu=timestamp,memory.used,utilization.gpu,power.draw,temperature.gpu',
            '--format=csv,noheader,nounits',("--loop-ms={0}" -f $TelemetryMs)) `
          -RedirectStandardOutput $telFile -RedirectStandardError ($telFile + '.err') `
          -WindowStyle Hidden -PassThru
      } catch { }
      Start-Sleep -Milliseconds 500

      $baseBody = '{"prompt":"' + $escText + '","n_predict":' + $MaxTokens + ',"temperature":0,"cache_prompt":false,"ignore_eos":true}'
      $b = $utf8.GetBytes($baseBody)
      $t1 = Get-Date
      $errMsg = $null; $resp = $null
      try { $resp = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $port) -Method Post `
              -ContentType 'application/json; charset=utf-8' -Body $b -TimeoutSec 900
      } catch { $errMsg = $_.Exception.Message }
      $elapsed = [math]::Round(((Get-Date)-$t1).TotalSeconds,2)

      try { if ($telProc -and -not $telProc.HasExited) { Stop-Process -Id $telProc.Id -Force -ErrorAction SilentlyContinue } } catch { }
      Start-Sleep -Milliseconds 300

      # ---- baseline AFTER ----
      $baseAfter = $null
      if (-not $NoBaseline) {
        try { $baseAfter = Send-Tps $port $BaselineTokens } catch { }
      }

      $drift = $null; $bstatus = 'NO_BASELINE'
      if ($null -ne $baseBefore -and $null -ne $baseAfter -and $baseBefore -gt 0) {
        $drift = [math]::Round((($baseAfter - $baseBefore) / $baseBefore) * 100, 2)
        $ad = [math]::Abs($drift)
        $bstatus = if ($ad -lt 2) { 'VALID' } elseif ($ad -le 5) { 'VALID_WITH_NOTE' } else { 'UNSTABLE' }
      }

      # ---- telemetry summary ----
      $peakMem=$null; $maxUtil=$null; $maxPower=$null; $minPower=$null; $maxTemp=$null; $freeAtMin=$null; $samples=0
      if (Test-Path $telFile) {
        $mem=@(); $util=@(); $pw=@(); $tp=@()
        foreach ($ln in (Get-Content $telFile -Encoding ASCII)) {
          $f = $ln -split ','
          if ($f.Count -ge 5) {
            if ($f[1].Trim() -match '^\d+$') { $mem += [int]$f[1] }
            if ($f[2].Trim() -match '^\d+$') { $util += [int]$f[2] }
            if ($f[3].Trim() -match '^[\d.]+$') { $pw += [double]$f[3] }
            if ($f[4].Trim() -match '^\d+$') { $tp += [int]$f[4] }
          }
        }
        $samples = $mem.Count
        if ($mem.Count) { $peakMem = ($mem|Measure-Object -Maximum).Maximum; $freeAtMin = 16376 - $peakMem }
        if ($util.Count) { $maxUtil = ($util|Measure-Object -Maximum).Maximum }
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
        vram_peak_mib=$peakMem; vram_free_at_peak_mib=$freeAtMin
        gpu_util_max=$maxUtil; power_max_w=$maxPower; power_min_w=$minPower; temp_max_c=$maxTemp
        telemetry_samples=$samples; telemetry_file=("telemetry/{0}.run{1}.csv" -f $label, $r)
        base_before_tps=$baseBefore; base_after_tps=$baseAfter
        drift_pct=$drift; baseline_status=$bstatus
      }
      $rec | ConvertTo-Json -Compress | Add-Content (Join-Path $dir ("run{0}.jsonl" -f $r)) -Encoding UTF8
      '{0},{1},{2},{3},{4},{5},{6},{7}' -f (Get-Date -Format 'o'), ("{0}-run{1}" -f $label,$r),
        $(if($baseBefore){$baseBefore}else{'NA'}), $(if($baseAfter){$baseAfter}else{'NA'}),
        $(if($null -ne $drift){$drift}else{'NA'}), $bstatus, $rec.decode_tps, $rec.vram_peak_mib |
        Add-Content $usageLog -Encoding UTF8
      $perRun += $rec
      Write-Output ("  run{0}: decode {1,8} t/s | vram {2} | util {3}% | power {4}-{5} W | drift {6}% [{7}]" -f `
        $r, $rec.decode_tps, $rec.vram_peak_mib, $rec.gpu_util_max, $rec.power_min_w, $rec.power_max_w, $drift, $bstatus)
    }

    # MEDIAN BUG (found by external audit 2026-10-17): the original line was
    #   $ds[[int]($ds.Count/2)]
    # For 3 samples [int](3/2) = [int]1.5 = 2, so it selected the MAXIMUM, not the median.
    # All figures derived from that line were the max of 3 runs, systematically optimistic.
    # Fixed below; MEDIAN-CORRECTION.csv lists old-vs-corrected for every configuration.
    function Get-Median([double[]]$a) {
      if ($a.Count -eq 0) { return $null }
      $s = @($a | Sort-Object); $n = $s.Count
      if ($n % 2 -eq 1) { return $s[($n - 1) / 2] }
      return [math]::Round(($s[$n / 2 - 1] + $s[$n / 2]) / 2, 3)
    }

    $ds = @($perRun | Where-Object { $_.ok -and $null -ne $_.decode_tps } | ForEach-Object { [double]$_.decode_tps } | Sort-Object)
    $meta = [ordered]@{
      label=$label; ncmoe=$cfg.ncmoe; cache=$cfg.cache; status='VALID'
      load_s=$loadS; runs=$Runs; ok=$(@($perRun|Where-Object{$_.ok}).Count)
      decode_median=$(Get-Median $ds)
      decode_min=$(if ($ds.Count) { $ds[0] } else { $null })
      decode_max=$(if ($ds.Count) { $ds[-1] } else { $null })
      baseline_statuses=@($perRun | ForEach-Object { $_.baseline_status })
      drift_max_abs_pct=$(if (@($perRun | Where-Object { $null -ne $_.drift_pct }).Count) { (@($perRun | ForEach-Object { [math]::Abs($_.drift_pct) }) | Measure-Object -Maximum).Maximum } else { $null })
      finished_at=(Get-Date -Format 'o')
    }
    $meta | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
    $all += $meta
  } finally {
    try { if (-not $srv.HasExited) { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } } catch { }
    for ($i=0;$i -lt 20;$i++){ Start-Sleep -Milliseconds 300; if ($srv.HasExited) { break } }
    Start-Sleep -Seconds 2
  }
}

if ($all.Count) { $all | ForEach-Object { [pscustomobject]$_ } | Export-Csv -Path (Join-Path $taskDir 'summary.csv') -NoTypeInformation -Encoding UTF8 }
Write-Output ""
foreach ($m in $all) {
  Write-Output ("{0,-12} ncmoe={1,-3} cache={2,-6} median={3} [{4}-{5}] status={6}" -f $m.label, $m.ncmoe, $m.cache, $m.decode_median, $m.decode_min, $m.decode_max, $m.status)
}
Write-Output ("done at {0}" -f (Get-Date -Format 'HH:mm:ss'))
