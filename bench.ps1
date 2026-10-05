<#
.SYNOPSIS
  Speed benchmark for models served by Ollama: prefill and generation tokens/s at several prompt sizes, VRAM use.

.EXAMPLE
  .\bench.ps1 -OllamaHost 127.0.0.1:11434 -Models gemma4-32k,qwen3-coder-32k -Hardware "1x Tesla V100 32GB, 28 GiB RAM"

  Notes
  - Each repetition uses a different random prompt so Ollama's prompt cache cannot make prefill look instant.
  - Prompt size is checked against prompt_eval_count: if Ollama cut the prompt (it silently keeps about half of
    num_ctx when a prompt overflows), the row is marked "truncated" and left out of the medians.
#>
param(
  [string]$OllamaHost = "127.0.0.1:11434",
  [string[]]$Models = @(),
  [int[]]$Sizes = @(1024, 4096, 16384, 32768),
  [int]$Reps = 3,
  [int]$GenTokens = 128,
  [string]$OutDir = (Join-Path $PSScriptRoot "results"),
  [string]$Hardware = "",
  [int]$TimeoutSec = 1800
)

$ErrorActionPreference = "Stop"
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
$base = "http://$OllamaHost"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Invoke-Api([string]$Path, $Body = $null, [string]$Method = "POST") {
  $uri = "$base$Path"
  if ($null -eq $Body) { return Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $TimeoutSec }
  $json = $Body | ConvertTo-Json -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  return Invoke-RestMethod -Uri $uri -Method $Method -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec
}

$words = @("system","window","river","signal","garden","engine","pattern","market","bridge","story","planet","memory","forest","number",
 "letter","window","paper","music","island","castle","silver","orange","public","simple","modern","quiet","bright","narrow","heavy","early",
 "travel","build","measure","repair","collect","imagine","follow","decide","remain","reduce","contract","budget","invoice","account","report",
 "balance","ledger","payment","salary","warehouse","document","register","interface","process","handler","module","variable","function",
 "network","storage","latency","bandwidth","kernel","thread","buffer","packet","sensor","voltage","current","battery","cooling","pump","valve")

function New-Filler([int]$wordCount, [int]$seed) {
  $rnd = New-Object System.Random($seed)
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $wordCount; $i++) {
    [void]$sb.Append($words[$rnd.Next(0, $words.Count)])
    if ($i % 17 -eq 16) { [void]$sb.Append(". ") } else { [void]$sb.Append(" ") }
  }
  return $sb.ToString()
}

function Get-Median([double[]]$v) {
  if (-not $v -or $v.Count -eq 0) { return $null }
  $s = $v | Sort-Object
  $n = $s.Count
  if ($n % 2 -eq 1) { return [math]::Round($s[($n - 1) / 2], 1) }
  return [math]::Round(($s[$n / 2 - 1] + $s[$n / 2]) / 2, 1)
}

function Invoke-Gen([string]$model, [string]$prompt, [int]$numCtx, [int]$numPredict, [string]$keepAlive = "10m") {
  $body = @{
    model = $model; prompt = $prompt; stream = $false; keep_alive = $keepAlive
    options = @{ num_ctx = $numCtx; num_predict = $numPredict; temperature = 0 }
  }
  return Invoke-Api "/api/generate" $body
}

$version = (Invoke-Api "/api/version").version
$all = (Invoke-Api "/api/tags").models | ForEach-Object { $_.name }
if ($Models.Count -eq 0) { $Models = $all }

$rows = New-Object System.Collections.Generic.List[object]
$summary = New-Object System.Collections.Generic.List[object]
$started = Get-Date -Format "yyyy-MM-dd HH:mm"
Write-Host "Ollama $version, models: $($Models -join ', ')"

foreach ($model in $Models) {
  Write-Host "=== $model"
  try {
    $show = Invoke-Api "/api/show" @{ model = $model }
    $paramCtx = $null
    foreach ($line in ($show.parameters -split "`n")) { if ($line -match "^\s*num_ctx\s+(\d+)") { $paramCtx = [int]$Matches[1] } }
    $modelMax = 0
    foreach ($p in $show.model_info.PSObject.Properties) { if ($p.Name -like "*.context_length") { $modelMax = [int]$p.Value } }
    $cap = if ($paramCtx) { $paramCtx } else { [math]::Min(32768, $(if ($modelMax) { $modelMax } else { 32768 })) }
    $family = $show.details.family; $quant = $show.details.quantization_level; $psize = $show.details.parameter_size
  } catch { Write-Warning "show failed: $($_.Exception.Message)"; continue }

  # calibration: tokens per word for this tokenizer
  try {
    $cal = Invoke-Gen $model ("Text: " + (New-Filler 1000 1)) ([math]::Min(8192, $cap)) 1
    $tpw = ($cal.prompt_eval_count - 30) / 1000.0
    if ($tpw -lt 0.5) { $tpw = 0.5 }
  } catch { Write-Warning "calibration failed: $($_.Exception.Message)"; continue }

  $vramGB = $null; $totalGB = $null
  $resultsModel = New-Object System.Collections.Generic.List[object]
  foreach ($size in $Sizes) {
    if ($size + $GenTokens + 512 -gt $cap) { Write-Host "  skip $size (context $cap)"; continue }
    $wordCount = [int][math]::Round($size / $tpw)
    $sizeRows = New-Object System.Collections.Generic.List[object]
    for ($rep = 1; $rep -le $Reps; $rep++) {
      $prompt = "Document id $([guid]::NewGuid().ToString('N').Substring(0,8)).`n" + (New-Filler $wordCount (1000 * $size + $rep)) +
        "`n`nWrite a long, detailed essay (at least 400 words) about how the topics in the document above relate to each other."
      $err = $null; $r = $null
      try { $r = Invoke-Gen $model $prompt $cap $GenTokens } catch { $err = $_.Exception.Message }
      if ($err) {
        Write-Warning "  size $size rep ${rep}: $err"
        $row = [pscustomobject]@{ model = $model; target_tokens = $size; rep = $rep; prompt_tokens = $null; prefill_tps = $null; gen_tokens = $null; gen_tps = $null; load_s = $null; status = "error: $err" }
      } else {
        $pt = [int]$r.prompt_eval_count; $pd = [double]$r.prompt_eval_duration / 1e9
        $et = [int]$r.eval_count; $ed = [double]$r.eval_duration / 1e9
        $trunc = ($pt -lt 0.8 * $size)
        $prefill = if ($pd -gt 0) { [math]::Round($pt / $pd, 1) } else { $null }
        $gen = if ($ed -gt 0 -and $et -ge 32) { [math]::Round($et / $ed, 1) } else { $null }
        $row = [pscustomobject]@{ model = $model; target_tokens = $size; rep = $rep; prompt_tokens = $pt; prefill_tps = $prefill; gen_tokens = $et; gen_tps = $gen; load_s = [math]::Round([double]$r.load_duration / 1e9, 1); status = $(if ($trunc) { "truncated" } else { "ok" }) }
        Write-Host ("  {0,6} tok  rep {1}: prompt {2}  prefill {3} t/s  gen {4} t/s  [{5}]" -f $size, $rep, $pt, $prefill, $gen, $row.status)
      }
      $rows.Add($row); $sizeRows.Add($row)
    }
    $ok = $sizeRows | Where-Object { $_.status -eq "ok" }
    $resultsModel.Add([pscustomobject]@{
      model = $model; target_tokens = $size
      prompt_tokens = (Get-Median ([double[]]($ok | ForEach-Object { $_.prompt_tokens })))
      prefill_tps = (Get-Median ([double[]]($ok | Where-Object { $_.prefill_tps } | ForEach-Object { $_.prefill_tps })))
      gen_tps = (Get-Median ([double[]]($ok | Where-Object { $_.gen_tps } | ForEach-Object { $_.gen_tps })))
      runs_ok = @($ok).Count; runs = $Reps
    })
  }
  try {
    $ps = Invoke-Api "/api/ps"
    $loaded = $ps.models | Where-Object { $_.name -like "$model*" } | Select-Object -First 1
    if ($loaded) { $vramGB = [math]::Round($loaded.size_vram / 1e9, 1); $totalGB = [math]::Round($loaded.size / 1e9, 1) }
  } catch {}
  foreach ($x in $resultsModel) { $summary.Add([pscustomobject]@{ model = $x.model; family = $family; params = $psize; quant = $quant; ctx = $cap; vram_gb = $vramGB; size_gb = $totalGB; target_tokens = $x.target_tokens; prompt_tokens = $x.prompt_tokens; prefill_tps = $x.prefill_tps; gen_tps = $x.gen_tps; runs_ok = $x.runs_ok; runs = $x.runs }) }
  try { [void](Invoke-Gen $model "x" 2048 1 "0") } catch {}   # unload before the next model
}

$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$rows | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $OutDir "raw-$stamp.json")
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir "summary-$stamp.csv")

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# Results ($started)")
[void]$md.AppendLine("")
[void]$md.AppendLine("Ollama $version. $Hardware")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Model | Params | Quant | Ctx | VRAM, GB | Prompt, tok | Prefill, tok/s | Generation, tok/s | OK runs |")
[void]$md.AppendLine("|---|---|---|---:|---:|---:|---:|---:|---:|")
foreach ($s in $summary) {
  [void]$md.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8}/{9} |" -f $s.model, $s.params, $s.quant, $s.ctx, $s.vram_gb, $s.prompt_tokens, $s.prefill_tps, $s.gen_tps, $s.runs_ok, $s.runs))
}
$md.ToString() | Set-Content -Encoding UTF8 (Join-Path $OutDir "summary-$stamp.md")
Write-Host "Saved to $OutDir"
