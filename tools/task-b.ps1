# task-b.ps1 -- T-REDO-PREPOST task B: baseline stability.
#
# SPEC (handoff pack 5.2)
#   5 independent processes; each process runs 10 real-text prompts and 10 random-token prompts.
#   Params: ncmoe 48 / cache 10752 / load-mode none / cpu-mask 0x5555 / -t 8
#           temperature 0 / max_tokens 256
#   Token alignment: real prompts are tokenized to get their true length; random arrays are
#   generated at the SAME length with a fixed seed. prompt_tokens must agree within +-2.
#
# ROLE: executor + recorder, not judge. Every number must point at a file.
#
# OUTPUT
#   TASK-B/p<n>/real.jsonl, random.jsonl, meta.json
#   TASK-B/summary.csv
#
# ASCII ONLY.

param(
  [Parameter(Mandatory=$true)][string]$OutRoot,
  [Parameter(Mandatory=$true)][string]$CorpusRoot,
  [string]$ModelPath = 'D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf',
  [int]$ProcessFrom = 1,
  [int]$ProcessTo = 5,
  [int]$PortBase = 9970,
  [int]$MaxTokens = 256,
  [int]$SeedBase = 20261017
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$exe = 'E:\Apps\llama.cpp\b11617\llama-server.exe'

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

# 10 real prompts from set T (512 class), distinct classes
$realFiles = @(Get-ChildItem (Join-Path $CorpusRoot 'T') -Filter 'T*.txt' | Sort-Object Name | Select-Object -First 10)
if ($realFiles.Count -lt 10) { throw "need 10 real prompts under $CorpusRoot\T, found $($realFiles.Count)" }

$startAt = if ($StartAt) { 1 } else { 1 }
$results = @()

for ($pi = $ProcessFrom; $pi -le $ProcessTo; $pi++) {
  $port = $PortBase + $pi
  $dir = Join-Path $OutRoot ("TASK-B\p{0}" -f $pi)
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $log = Join-Path $dir 'server.log'

  if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    Write-Output ("p{0}: port {1} busy, skip (do NOT kill holder)" -f $pi, $port)
    continue
  }

  Write-Output ("=== process {0} (range {1}..{2})  port {3}  start {4} ===" -f $pi, $ProcessFrom, $ProcessTo, $port, (Get-Date -Format 'HH:mm:ss'))
  $srv = Start-Process -FilePath $exe -ArgumentList @(
           '-m',$ModelPath,'-c','4096','-ngl','99','-ncmoe','48',
           '-C','0000000000005555','-Cb','0000000000005555','--cpu-strict','1','--cpu-strict-batch','1',
           '-t','8','-tb','8','--moe-cache-mib','10752','-lm','none','-np','1',
           '--host','127.0.0.1','--port',"$port",'--log-file',$log
         ) -RedirectStandardOutput ($log + '.out') -RedirectStandardError ($log + '.err') -WindowStyle Hidden -PassThru

  try {
    $t0 = Get-Date; $ready = $false
    while (((Get-Date)-$t0).TotalSeconds -lt 300) {
      Start-Sleep -Milliseconds 800
      if ($srv.HasExited) { break }
      try { $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/health" -f $port) -TimeoutSec 3 -UseBasicParsing
            if ($r.StatusCode -eq 200) { $ready = $true; break } } catch { }
    }
    $loadS = [math]::Round(((Get-Date)-$t0).TotalSeconds,1)
    if (-not $ready) { Write-Output ("p{0}: server not ready after {1}s -- record FAILED" -f $pi, $loadS)
      [ordered]@{process=$pi; status='FAILED'; reason='server not ready'; load_s=$loadS} | ConvertTo-Json | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
      continue }
    Write-Output ("p{0}: ready in {1}s" -f $pi, $loadS)

    $realPath = Join-Path $dir 'real.jsonl'
    $randPath = Join-Path $dir 'random.jsonl'
    Remove-Item $realPath, $randPath -Force -ErrorAction SilentlyContinue

    $rng = [System.Random]::new($SeedBase + $pi)
    $pairs = @()
    foreach ($rf in $realFiles) {
      $text = [System.IO.File]::ReadAllText($rf.FullName, $utf8)
      # 1) tokenize to get true length
      $tb = '{"content":"' + (Esc-JS $text) + '"}'
      $tr = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/tokenize" -f $port) -Method Post `
              -ContentType 'application/json; charset=utf-8' -Body ($utf8.GetBytes($tb)) -TimeoutSec 120
      $nTok = @($tr.tokens).Count
      # 2) random array of the SAME length, fixed seed
      $arr = New-Object System.Collections.Generic.List[int]
      while ($arr.Count -lt $nTok) { $arr.Add($rng.Next(0, 151936)) }

      $common = ',"n_predict":' + $MaxTokens + ',"temperature":0,"top_k":1,"cache_prompt":false,"ignore_eos":true}'
      # real
      $bodyReal = '{"prompt":"' + (Esc-JS $text) + '"' + $common
      $rr = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $port) -Method Post `
              -ContentType 'application/json; charset=utf-8' -Body ($utf8.GetBytes($bodyReal)) -TimeoutSec 900
      $pnR = $rr.timings.prompt_n; $dR = [double]$rr.timings.predicted_per_second
      '{"id":"' + $rf.BaseName + '_real","prompt_tokens":' + $pnR + ',"decode_tps":' + $dR +
        ',"prompt_n":' + $pnR + ',"predicted_n":' + $rr.timings.predicted_n + '}' | Add-Content $realPath -Encoding UTF8

      # random
      $pj = '[' + (($arr | ForEach-Object { [string]$_ }) -join ',') + ']'
      $bodyRand = '{"prompt":' + $pj + $common
      $rg = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $port) -Method Post `
              -ContentType 'application/json; charset=utf-8' -Body ($utf8.GetBytes($bodyRand)) -TimeoutSec 900
      $pnG = $rg.timings.prompt_n; $dG = [double]$rg.timings.predicted_per_second
      '{"id":"' + $rf.BaseName + '_rand","prompt_tokens":' + $pnG + ',"decode_tps":' + $dG +
        ',"prompt_n":' + $pnG + ',"predicted_n":' + $rg.timings.predicted_n + '}' | Add-Content $randPath -Encoding UTF8

      $pairs += [ordered]@{ id=$rf.BaseName; real_tokens=[int]$pnR; rand_tokens=[int]$pnG
                            real_tps=[math]::Round($dR,3); rand_tps=[math]::Round($dG,3)
                            token_delta=[math]::Abs([int]$pnR-[int]$pnG) }
      Write-Output ("  {0,-6} real {1,5} tok {2,7:N2} t/s | rand {3,5} tok {4,7:N2} t/s | delta {5}" -f `
        $rf.BaseName, $pnR, $dR, $pnG, $dG, $pairs[-1].token_delta)
    }

    $meta = [ordered]@{
      process=$pi; status='VALID'; load_s=$loadS; port=$port
      pairs=$pairs
      token_alignment_ok=[bool](-not ($pairs | Where-Object { $_.token_delta -gt 2 }))
      finished_at=(Get-Date -Format 'o')
    }
    $meta | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'meta.json') -Encoding UTF8
    $results += $meta
  } finally {
    try { if (-not $srv.HasExited) { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } } catch { }
    for ($i=0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 300; if ($srv.HasExited) { break } }
    Start-Sleep -Seconds 2
  }
}

# summary
$rows = @()
foreach ($r in $results) {
  if ($r.status -ne 'VALID') { continue }
  foreach ($p in $r.pairs) {
    $rows += [pscustomobject]@{ process=$r.process; id=$p.id
      real_tokens=$p.real_tokens; rand_tokens=$p.rand_tokens
      real_tps=$p.real_tps; rand_tps=$p.rand_tps; token_delta=$p.token_delta }
  }
}
if ($rows.Count) {
  $rows | Export-Csv -Path (Join-Path $OutRoot 'TASK-B\summary.csv') -NoTypeInformation -Encoding UTF8
  $rt = @($rows | ForEach-Object { [double]$_.real_tps } | Sort-Object)
  $gt = @($rows | ForEach-Object { [double]$_.rand_tps } | Sort-Object)
  function Med($a) { if ($a.Count) { $a[[int]($a.Count/2)] } else { $null } }
  Write-Output ""
  Write-Output ("real   median {0:N2} t/s over {1} samples" -f (Med $rt), $rt.Count)
  Write-Output ("random median {0:N2} t/s over {1} samples" -f (Med $gt), $gt.Count)
  if ((Med $rt) -gt 0) { Write-Output ("diff: {0:N1}%" -f ((($gt[0] - $rt[0]) / $rt[0]) * 100)) }
}
Write-Output ("done at {0}" -f (Get-Date -Format 'HH:mm:ss'))
