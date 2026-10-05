<#
.SYNOPSIS
  Speed benchmark for a running Strata server (OpenAI-style /v1/chat/completions): prefill and generation tokens/s.
  Writes the same summary CSV as bench.ps1 / bench-llamaserver.ps1, so make-report.ps1 can build the tables.

.EXAMPLE
  .\bench-strata.ps1 -Server 127.0.0.1:8090 -Label "Qwen3.8-Flash-Next IQ2_XS (Strata)" -Params 125B -Quant IQ2_XS -Ctx 32768 -VramGb 31

  Strata reports llama.cpp-style "timings" (prompt_per_second, predicted_per_second) plus the speculative-decoding draft
  counters (draft_n, draft_n_accepted); the acceptance rate depends on how predictable the text is, so it is saved too.
  Thinking is switched off (chat_template_kwargs.enable_thinking = false) so that the 128 generated tokens are answer text.
#>
param(
  [string]$Server = "127.0.0.1:8090",
  [Parameter(Mandatory = $true)][string]$Label,
  [string]$Params = "", [string]$Quant = "", [int]$Ctx = 32768, [double]$VramGb = 0,
  [int[]]$Sizes = @(1024, 4096, 16384, 24576),
  [int]$Reps = 3, [int]$GenTokens = 128, [int]$TimeoutSec = 3600,
  [string]$OutDir = (Join-Path $PSScriptRoot "results")
)
$ErrorActionPreference = "Stop"
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$words = @("system","window","river","signal","garden","engine","pattern","market","bridge","story","planet","memory","forest","number",
 "letter","paper","music","island","castle","silver","orange","public","simple","modern","quiet","bright","narrow","heavy","early",
 "travel","build","measure","repair","collect","imagine","follow","decide","remain","reduce","contract","budget","invoice","account","report",
 "balance","ledger","payment","salary","warehouse","document","register","interface","process","handler","module","variable","function",
 "network","storage","latency","bandwidth","kernel","thread","buffer","packet","sensor","voltage","current","battery","cooling","pump","valve")
function New-Filler([int]$n, [int]$seed) {
  $rnd = New-Object System.Random($seed); $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append($words[$rnd.Next(0, $words.Count)]); if ($i % 17 -eq 16) { [void]$sb.Append(". ") } else { [void]$sb.Append(" ") } }
  return $sb.ToString()
}
function Get-Median([double[]]$v) { if (-not $v -or $v.Count -eq 0) { return $null }; $s = $v | Sort-Object; $n = $s.Count
  if ($n % 2 -eq 1) { return [math]::Round($s[($n - 1) / 2], 1) }; return [math]::Round(($s[$n / 2 - 1] + $s[$n / 2]) / 2, 1) }
function Invoke-Chat([string]$prompt, [int]$maxTokens) {
  $body = @{ model = "strata"; messages = @(@{ role = "user"; content = $prompt }); max_tokens = $maxTokens; temperature = 0
             chat_template_kwargs = @{ enable_thinking = $false } } | ConvertTo-Json -Depth 6 -Compress
  return Invoke-RestMethod -Uri "http://$Server/v1/chat/completions" -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec
}

$null = Invoke-RestMethod -Uri "http://$Server/health" -TimeoutSec 20
$cal = Invoke-Chat ("Text: " + (New-Filler 1000 1)) 1
$tpw = [math]::Max(0.5, ($cal.usage.prompt_tokens - 30) / 1000.0)
Write-Host "${Label}: tokens per word $([math]::Round($tpw,2))"

$rows = New-Object System.Collections.Generic.List[object]; $summary = New-Object System.Collections.Generic.List[object]
foreach ($size in $Sizes) {
  if ($size + $GenTokens + 512 -gt $Ctx) { Write-Host "  skip $size (context $Ctx)"; continue }
  $words_n = [int][math]::Round($size / $tpw); $ok = New-Object System.Collections.Generic.List[object]
  for ($rep = 1; $rep -le $Reps; $rep++) {
    $prompt = "Document id $([guid]::NewGuid().ToString('N').Substring(0,8)).`n" + (New-Filler $words_n (1000 * $size + $rep)) + "`n`nWrite a long, detailed essay (at least 400 words) about how the topics in the document above relate to each other."
    try {
      $r = Invoke-Chat $prompt $GenTokens; $t = $r.timings
      $pt = [int]$r.usage.prompt_tokens; $pf = [math]::Round([double]$t.prompt_per_second, 1)
      $gen = if ([int]$t.predicted_n -ge 32) { [math]::Round([double]$t.predicted_per_second, 1) } else { $null }
      $acc = if ([int]$t.draft_n -gt 0) { [math]::Round(100.0 * [int]$t.draft_n_accepted / [int]$t.draft_n) } else { $null }
      # prompt_n is what was really read; cache_n > 0 means part of the prompt came from the conversation cache (not a clean prefill)
      $status = if ($pt -lt 0.8 * $size) { "truncated" } elseif ([int]$t.cache_n -gt 0) { "cached" } else { "ok" }
      Write-Host ("  {0,6} tok  rep {1}: prompt {2}  prefill {3} t/s  gen {4} t/s  draft accepted {5}%  [{6}]" -f $size, $rep, $pt, $pf, $gen, $acc, $status)
      $rows.Add([pscustomobject]@{ label = $Label; target_tokens = $size; rep = $rep; prompt_tokens = $pt; prefill_tps = $pf; gen_tokens = [int]$t.predicted_n; gen_tps = $gen; draft_accept_pct = $acc; cache_n = [int]$t.cache_n; status = $status })
      if ($status -eq "ok") { $ok.Add($rows[$rows.Count - 1]) }
    } catch { Write-Warning "  size $size rep ${rep}: $($_.Exception.Message)"; $rows.Add([pscustomobject]@{ label = $Label; target_tokens = $size; rep = $rep; status = "error: $($_.Exception.Message)" }) }
  }
  $summary.Add([pscustomobject]@{ model = $Label; family = "Strata"; params = $Params; quant = $Quant; ctx = $Ctx; vram_gb = $(if ($VramGb) { $VramGb } else { $null }); size_gb = $null
    target_tokens = $size; prompt_tokens = (Get-Median ([double[]]($ok | ForEach-Object { $_.prompt_tokens })))
    prefill_tps = (Get-Median ([double[]]($ok | ForEach-Object { $_.prefill_tps }))); gen_tps = (Get-Median ([double[]]($ok | Where-Object { $_.gen_tps } | ForEach-Object { $_.gen_tps })))
    draft_accept_pct = (Get-Median ([double[]]($ok | Where-Object { $null -ne $_.draft_accept_pct } | ForEach-Object { $_.draft_accept_pct })))
    runs_ok = $ok.Count; runs = $Reps })
}
$stamp = Get-Date -Format "yyyyMMdd-HHmm"; $safe = ($Label -replace '[^A-Za-z0-9._-]+', '_')
$rows | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $OutDir "raw-strata-$safe-$stamp.json")
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir "summary-strata-$safe-$stamp.csv")
Write-Host "Saved to $OutDir"
