# task-a.ps1 -- T-REDO-PREPOST task A: 10-prompt generation check (secondary evidence).
#
# SPEC (handoff pack 5.1 + appendix C)
#   Two arms: A1 cache=0, A2 cache=10752. Everything else identical:
#   ncmoe 48 / load-mode none / cpu-mask 0x5555 / -t 8 / temperature 0 / top_k 1 / seed 42
#   Prompts copied VERBATIM from the pack (rule 7). Grading is separate (grade-a.py).
#
# WHY HERE-STRINGS: the first version embedded the HumanEval snippets in normal double-quoted
# strings, so Python docstring quotes and backticks collided with PowerShell escaping and the
# whole script failed to parse. Here-strings are literal.
#
# ASCII ONLY.

param(
  [Parameter(Mandatory=$true)][string]$OutRoot,
  [string]$ModelPath = 'D:\Models\LMStudio\local\Qwen3-Next-80B-A3B-Instruct\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf',
  [int]$MaxTokens = 256,
  [int]$Port = 9977
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$exe = 'E:\Apps\llama.cpp\b11617\llama-server.exe'
$taskDir = Join-Path $OutRoot 'TASK-A'
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null

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

$gsmTpl = "`n`nSolve step by step. End your answer with: #### <number>"
$mmluTpl = "`n`nAnswer with a single letter."

$he0 = @'
from typing import List


def has_close_elements(numbers: List[float], threshold: float) -> bool:
    """ Check if in given list of numbers, are any two numbers closer to each other than
    given threshold.
    >>> has_close_elements([1.0, 2.0, 3.0], 0.5)
    False
    >>> has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)
    True
    """
'@

$he1 = @'
from typing import List


def separate_paren_groups(paren_string: str) -> List[str]:
    """ Input to this function is a string containing multiple groups of nested parentheses. Your goal is to
    separate those group into separate strings and return the list of those.
    Separate groups are balanced (each open brace is properly closed) and not nested within each other
    Ignore any spaces in the input string.
    >>> separate_paren_groups('( ) (( )) (( )( ))')
    ['()', '(())', '(()())']
    """
'@

$he2 = @'

def truncate_number(number: float) -> float:
    """ Given a positive floating point number, it can be decomposed into
    and integer part (largest integer smaller than given number) and decimals
    (leftover part always smaller than 1).

    Return the decimal part of the number.
    >>> truncate_number(3.5)
    0.5
    """
'@

$he3 = @'
from typing import List


def below_zero(operations: List[int]) -> bool:
    """ You're given a list of deposit and withdrawal operations on a bank account that starts with
    zero balance. Your task is to detect if at any point the balance of account fallls below zero, and
    at that point function should return True. Otherwise it should return False.
    >>> below_zero([1, 2, 3])
    False
    >>> below_zero([1, 2, -4, 5])
    True
    """
'@

$gsm0 = "Janet's ducks lay 16 eggs per day. She eats three for breakfast every morning and bakes muffins for her friends every day with four. She sells the remainder at the farmers' market daily for `$2 per fresh duck egg. How much in dollars does she make every day at the farmers' market?"
$gsm1 = "A robe takes 2 bolts of blue fiber and half that much white fiber.  How many bolts in total does it take?"
$gsm2 = "Josh decides to try flipping a house.  He buys a house for `$80,000 and then puts in `$50,000 in repairs.  This increased the value of the house by 150%.  How much profit did he make?"
$gsm3 = "James decides to run 3 sprints 3 times a week.  He runs 60 meters each sprint.  How many total meters does he run a week?"

$mmluCS = @'
The access matrix approach to protection has the difficulty that

A) the matrix, if stored directly, is large and can be clumsy to manage
B) it is not capable of expressing complex protection requirements
C) deciding whether a process has access to a resource is undecidable
D) there is no way to express who has rights to change the access matrix itself
'@

$mmluPHY = @'
The plates of a capacitor are charged to a potential difference of 5 V. If the capacitance is 2 mF, what is the charge on the positive plate?

A) 0.005 C
B) 0.01 C
C) 0.02 C
D) 0.5 C
'@

$prompts = @(
  [ordered]@{ id='GSM-0'; kind='gsm'; gold='18'; text=$gsm0 }
  [ordered]@{ id='GSM-1'; kind='gsm'; gold='3'; text=$gsm1 }
  [ordered]@{ id='GSM-2'; kind='gsm'; gold='70000'; text=$gsm2 }
  [ordered]@{ id='GSM-3'; kind='gsm'; gold='540'; text=$gsm3 }
  [ordered]@{ id='HumanEval-0'; kind='code'; gold='has_close_elements'; text=$he0 }
  [ordered]@{ id='HumanEval-1'; kind='code'; gold='separate_paren_groups'; text=$he1 }
  [ordered]@{ id='HumanEval-2'; kind='code'; gold='truncate_number'; text=$he2 }
  [ordered]@{ id='HumanEval-3'; kind='code'; gold='below_zero'; text=$he3 }
  [ordered]@{ id='MMLU-CS'; kind='mmlu'; gold='A'; text=$mmluCS }
  [ordered]@{ id='MMLU-PHY'; kind='mmlu'; gold='B'; text=$mmluPHY }
)

function Build-Prompt($p) {
  if ($p.kind -eq 'gsm') { return $p.text + $gsmTpl }
  if ($p.kind -eq 'mmlu') { return $p.text + $mmluTpl }
  return $p.text
}

$arms = @(
  [ordered]@{ label='A1-cache0'; cache=0 }
  [ordered]@{ label='A2-cache10752'; cache=10752 }
)

foreach ($arm in $arms) {
  $dir = Join-Path $taskDir $arm.label
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $srvLog = Join-Path $dir 'server.log'
  if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    Write-Output ("{0}: port busy, skip" -f $arm.label); continue
  }
  Write-Output ("=== {0}  cache={1}  start {2} ===" -f $arm.label, $arm.cache, (Get-Date -Format 'HH:mm:ss'))
  $args = @('-m',$ModelPath,'-c','4096','-ngl','99','-ncmoe','48',
            '-C','0000000000005555','-Cb','0000000000005555','--cpu-strict','1','--cpu-strict-batch','1',
            '-t','8','-tb','8','-lm','none','-np','1',
            '--host','127.0.0.1','--port',"$Port",'--log-file',$srvLog)
  if ([int]$arm.cache -gt 0) { $args += @('--moe-cache-mib',"$($arm.cache)") }
  $srv = Start-Process -FilePath $exe -ArgumentList $args `
           -RedirectStandardOutput ($srvLog + '.out') -RedirectStandardError ($srvLog + '.err') `
           -WindowStyle Hidden -PassThru
  try {
    $t0 = Get-Date; $ready = $false
    while (((Get-Date)-$t0).TotalSeconds -lt 300) {
      Start-Sleep -Milliseconds 800
      if ($srv.HasExited) { break }
      try { $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/health" -f $Port) -TimeoutSec 3 -UseBasicParsing
            if ($r.StatusCode -eq 200) { $ready = $true; break } } catch { }
    }
    if (-not $ready) { Write-Output ("{0}: server not ready -> FAILED" -f $arm.label); continue }
    Write-Output ("{0}: ready in {1:N1}s" -f $arm.label, ((Get-Date)-$t0).TotalSeconds)

    $outPath = Join-Path $dir 'results.jsonl'
    Remove-Item $outPath -Force -ErrorAction SilentlyContinue
    foreach ($p in $prompts) {
      $fullPrompt = Build-Prompt $p
      $body = '{"prompt":"' + (Esc-JS $fullPrompt) + '","n_predict":' + $MaxTokens +
              ',"temperature":0,"top_k":1,"seed":42,"cache_prompt":false,"ignore_eos":true}'
      $resp = $null; $errMsg = $null
      try {
        $resp = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/completion" -f $Port) -Method Post `
                  -ContentType 'application/json; charset=utf-8' -Body ($utf8.GetBytes($body)) -TimeoutSec 900
      } catch { $errMsg = $_.Exception.Message }
      $gen = if ($resp) { [string]$resp.content } else { '' }
      if ($p.kind -eq 'code' -and $gen) {
        $cut = $gen.Length
        foreach ($mark in @("`ndef ", "`nclass ", "`nif __name__")) {
          $ix = $gen.IndexOf($mark, 1)
          if ($ix -gt 0 -and $ix -lt $cut) { $cut = $ix }
        }
        $gen = $gen.Substring(0, $cut)
      }
      $rec = [ordered]@{
        id=$p.id; kind=$p.kind; gold=$p.gold; arm=$arm.label; cache=$arm.cache
        ok=$(($null -eq $errMsg)); error=$errMsg
        prompt_n=$(if ($resp) { $resp.timings.prompt_n } else { $null })
        predicted_n=$(if ($resp) { $resp.timings.predicted_n } else { $null })
        stop_type=$(if ($resp) { $resp.stop_type } else { $null })
        output=$gen
        prompt_used=$fullPrompt
      }
      $rec | ConvertTo-Json -Compress | Add-Content $outPath -Encoding UTF8
      $head = if ($gen.Length -gt 60) { $gen.Substring(0,60) } else { $gen }
      Write-Output ("  {0,-12} pn={1,4} gen={2,4}  {3}" -f $p.id, $rec.prompt_n, $rec.predicted_n, $(if($errMsg){"ERR: $errMsg"}else{($head -replace "`r?`n",' ')}))
    }
  } finally {
    try { if (-not $srv.HasExited) { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue } } catch { }
    for ($i=0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 300; if ($srv.HasExited) { break } }
    Start-Sleep -Seconds 2
  }
}
Write-Output ("task A done at {0}" -f (Get-Date -Format 'HH:mm:ss'))
