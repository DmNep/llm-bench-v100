<#
.SYNOPSIS
  Builds results\RESULTS.md (one row per model, one column per prompt size) from a summary-*.csv written by bench.ps1.
.EXAMPLE
  .\make-report.ps1 -Csv .\results\summary-20261005-1125.csv -Culture ru-RU
  (the culture is the one the CSV was written with; new runs of bench.ps1 use InvariantCulture)
#>
param(
  [Parameter(Mandatory = $true)][string]$Csv,
  [string]$Culture = "en-US",
  [string]$Out = (Join-Path (Split-Path $Csv -Parent) "RESULTS.md"),
  [string]$Header = "",
  [string[]]$Notes = @()
)
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$ci = [System.Globalization.CultureInfo]::GetCultureInfo($Culture)
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function Num($s) { if ([string]::IsNullOrWhiteSpace($s)) { return $null }; return [double]::Parse($s, $ci) }
function F($v, [string]$fmt = "N0") { if ($null -eq $v) { return "n/a" }; return $v.ToString($fmt, $inv) }

$rows = Import-Csv -Path $Csv -Encoding UTF8 | ForEach-Object {
  [pscustomobject]@{
    model = $_.model; params = $_.params; quant = $_.quant; ctx = [int]$_.ctx
    vram = Num $_.vram_gb; size = Num $_.size_gb
    prompt = [int](Num $_.prompt_tokens); prefill = Num $_.prefill_tps; gen = Num $_.gen_tps
  }
}
$models = $rows | Select-Object -ExpandProperty model -Unique
$allBuckets = @(1000, 4000, 16000, 25000, 33000, 67000, 115000)
function Bucket([int]$tok) { foreach ($b in $allBuckets) { if ($tok -le $b * 1.1) { return $b } }; return $allBuckets[-1] }
$buckets = @($allBuckets | Where-Object { $b = $_; $rows | Where-Object { (Bucket $_.prompt) -eq $b } })
$labels = @{ 1000 = "1K"; 4000 = "4K"; 16000 = "16K"; 25000 = "25K"; 33000 = "33K"; 67000 = "67K"; 115000 = "115K" }

$sb = New-Object System.Text.StringBuilder
if ($Header) { [void]$sb.AppendLine($Header); [void]$sb.AppendLine("") }
foreach ($kind in @(@("gen", "Generation speed, tokens/s (prompt of the given size already in context)"), @("prefill", "Prompt reading (prefill) speed, tokens/s"))) {
  [void]$sb.AppendLine("### $($kind[1])")
  [void]$sb.AppendLine("")
  $head = "| Model | Params | Quant | Ctx | " + (($buckets | ForEach-Object { $labels[$_] }) -join " | ") + " |"
  [void]$sb.AppendLine($head)
  [void]$sb.AppendLine("|---|---|---|---:|" + ((1..$buckets.Count | ForEach-Object { "---:" }) -join "|") + "|")
  foreach ($m in $models) {
    $r = $rows | Where-Object { $_.model -eq $m }
    $first = $r | Select-Object -First 1
    $cells = foreach ($b in $buckets) {
      $x = $r | Where-Object { (Bucket $_.prompt) -eq $b } | Select-Object -First 1
      if ($x) { F $x.($kind[0]) "N1" } else { "-" }
    }
    [void]$sb.AppendLine("| $m | $($first.params) | $($first.quant) | $($first.ctx) | " + ($cells -join " | ") + " |")
  }
  [void]$sb.AppendLine("")
}
[void]$sb.AppendLine("### Memory reported by the engine after the runs (Ollama; for llama.cpp the value is given by hand from nvidia-smi, if any)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Model | Reported VRAM, GB | Reported total, GB |")
[void]$sb.AppendLine("|---|---:|---:|")
foreach ($m in $models) { $first = $rows | Where-Object { $_.model -eq $m } | Select-Object -First 1; [void]$sb.AppendLine("| $m | $(F $first.vram 'N1') | $(F $first.size 'N1') |") }
[void]$sb.AppendLine("")
if ($Notes.Count -gt 0) { [void]$sb.AppendLine("### Notes"); [void]$sb.AppendLine(""); foreach ($n in $Notes) { [void]$sb.AppendLine("- $n") } }
[System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Written $Out"
