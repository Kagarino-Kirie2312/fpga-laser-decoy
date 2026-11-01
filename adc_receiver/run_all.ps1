$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path $here 'work'
if (-not (Test-Path $work)) { New-Item -ItemType Directory -Path $work | Out-Null }

$rtl = Join-Path $here 'rtl\acm9238_led_probe.v'

$tests = @(
    @{ name = 'tb_acm9238_probe';  file = 'tb\tb_acm9238_probe.v'  },
    @{ name = 'tb_laser_measure';  file = 'tb\tb_laser_measure.v'  },
    @{ name = 'tb_uart_report';    file = 'tb\tb_uart_report.v'    }
)

$fail = 0
foreach ($t in $tests) {
    Write-Host ''
    Write-Host ('=== ' + $t.name + ' ===') -ForegroundColor Cyan
    $tb  = Join-Path $here $t.file
    $vvp = Join-Path $work ($t.name + '.vvp')

    & iverilog -g2005 -Wall -o $vvp -s $t.name $rtl $tb
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  编译失败' -ForegroundColor Red
        $fail++
        continue
    }

    $out = & vvp $vvp 2>&1
    $out | Where-Object { $_ -match 'OK|PASS|FAIL|W=' } | ForEach-Object { Write-Host ('  ' + $_) }
    if ($out -match 'FAIL') { $fail++ }
}

Write-Host ''
if ($fail -eq 0) {
    Write-Host '全部测试台通过' -ForegroundColor Green
} else {
    Write-Host ('' + $fail + ' 组未通过') -ForegroundColor Red
}

exit $fail
