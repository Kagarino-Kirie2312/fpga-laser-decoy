<#
.SYNOPSIS
  编译并运行全部 FPGA 实验的测试台，输出 PASS / FAIL 汇总。

.DESCRIPTION
  用 Icarus Verilog（iverilog + vvp）逐个编译运行 tb\ 下的测试台。
  每个测试台自己判断对错并打印 PASS/FAIL，本脚本只负责调度和汇总。

  每个仿真都有超时保护：测试台写错导致仿真永不结束时，
  会被杀掉并记为「超时」，而不是把整轮跑卡死。
  （加这个保护是因为我自己第一版 UART 测试台就挂死过一次。）

.PARAMETER Lab
  只跑名字包含该字符串的测试台（例如 -Lab dpim）。不传就跑全部。

.PARAMETER TimeoutSec
  单个仿真的超时秒数，默认 30。

.PARAMETER KeepVcd
  保留 .vcd 波形文件（默认保留在 work\ 下，可用 vcd2txt.py 看文本波形）。

.EXAMPLE
  .\run_all.ps1
  .\run_all.ps1 -Lab dpim -KeepVcd
#>
[CmdletBinding()]
param(
  [string]$Lab = '',
  [int]$TimeoutSec = 30,
  [switch]$KeepVcd
)

$ErrorActionPreference = 'Stop'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ---- 找 iverilog ----
$cands = @('C:\iverilog\bin\iverilog.exe')
$cmd = Get-Command iverilog.exe -ErrorAction SilentlyContinue
if ($cmd) { $cands += $cmd.Source }
$iverilog = $cands | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $iverilog) { throw '找不到 iverilog.exe。请确认已安装 Icarus Verilog（本机默认在 C:\iverilog\bin）。' }
$vvp = Join-Path (Split-Path $iverilog -Parent) 'vvp.exe'
if (-not (Test-Path -LiteralPath $vvp)) { throw '找不到 vvp.exe（应与 iverilog.exe 同目录）' }

$rtl = Join-Path $here 'rtl'
$tbs = Join-Path $here 'tb'
$work = Join-Path $here 'work'
if (-not (Test-Path -LiteralPath $work)) { New-Item -ItemType Directory -Path $work -Force | Out-Null }

$tbFiles = @(Get-ChildItem -LiteralPath $tbs -Filter 'tb_*.v' | Sort-Object Name)
if ($Lab) { $tbFiles = @($tbFiles | Where-Object { $_.Name -match [regex]::Escape($Lab) }) }
if ($tbFiles.Count -eq 0) { throw "没有匹配的测试台（-Lab '$Lab'）" }

$rtlFiles = @(Get-ChildItem -LiteralPath $rtl -Filter '*.v' | ForEach-Object { $_.FullName })

"iverilog  : $iverilog"
"rtl       : $($rtlFiles.Count) 个模块"
"测试台    : $($tbFiles.Count) 个（单个超时 ${TimeoutSec}s）"
""

$results = @()
foreach ($tb in $tbFiles) {
  $name = $tb.BaseName
  $vvpFile = Join-Path $work "$name.vvp"
  $outFile = Join-Path $work "$name.out.txt"
  $errFile = Join-Path $work "$name.err.txt"

  # ---- 编译 ----
  $compileOut = & $iverilog -g2005 -o $vvpFile -s $name @rtlFiles $tb.FullName 2>&1
  if ($LASTEXITCODE -ne 0) {
    $results += [pscustomobject]@{ 测试台 = $name; 结果 = '编译失败'; 说明 = (($compileOut -join ' ') -replace '\s+', ' ').Trim() }
    continue
  }

  # ---- 运行（带超时）----
  $proc = Start-Process -FilePath $vvp -ArgumentList $vvpFile -WorkingDirectory $work `
    -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  $finished = $proc.WaitForExit($TimeoutSec * 1000)
  if (-not $finished) {
    try { $proc.Kill() } catch { }
    $results += [pscustomobject]@{ 测试台 = $name; 结果 = '超时'; 说明 = "超过 ${TimeoutSec}s 未结束（多半是在 @(posedge ...) 等一个已经过去的边沿）" }
    continue
  }

  # iverilog 把源码字节原样打印，源码是 UTF-8，必须按 UTF-8 读回来
  $runOut = @(Get-Content -LiteralPath $outFile -Encoding UTF8 -ErrorAction SilentlyContinue)
  $text = ($runOut -join "`n")
  $verdict = if ($text -match 'PASS') { 'PASS' } elseif ($text -match 'FAIL') { 'FAIL' } else { '无结论' }
  $detail = (($runOut | Where-Object { $_ -match '^\s{2}' }) -join ' / ').Trim()
  if (-not $detail) { $detail = (($runOut | Select-Object -First 2) -join ' ').Trim() }
  $results += [pscustomobject]@{ 测试台 = $name; 结果 = $verdict; 说明 = $detail }

  if (-not $KeepVcd) {
    Get-ChildItem -LiteralPath $work -Filter "$name.vcd" -ErrorAction SilentlyContinue | Remove-Item -Force
  }
}

""
"================ 汇总 ================"
foreach ($r in $results) {
  $mark = switch ($r.结果) { 'PASS' { '[PASS]' } 'FAIL' { '[FAIL]' } '超时' { '[TIME]' } '编译失败' { '[COMP]' } default { '[??? ]' } }
  "{0} {1,-22} {2}" -f $mark, $r.测试台, $r.说明
}
$pass = @($results | Where-Object 结果 -eq 'PASS').Count
$bad = @($results | Where-Object { $_.结果 -ne 'PASS' }).Count
""
"通过 $pass / 未通过 $bad"
if (-not $KeepVcd) { "（波形已清理；加 -KeepVcd 保留，再用 vcd2txt.py 看文本波形）" }
exit $bad
