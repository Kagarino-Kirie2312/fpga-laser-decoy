@echo off
rem 编译并运行全部 FPGA 实验的测试台。
rem 本机执行策略是 Restricted，所以显式 Bypass。
rem 参数原样传给 run_all.ps1，例如：run_all.cmd -Lab dpim -KeepVcd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_all.ps1" %*
echo.
pause
