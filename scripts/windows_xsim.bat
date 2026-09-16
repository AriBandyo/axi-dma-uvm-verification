@echo off
setlocal EnableExtensions

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=compile"
set "TEST=%~2"
if "%TEST%"=="" set "TEST=dma_smoke_test"
set "SEED=%~3"
if "%SEED%"=="" set "SEED=1"

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "ROOT_TCL=%ROOT:\=/%"
set "PATH=C:\AMDDesignTools\2025.2\Vivado\tps\mingw\6.2.0\win64.o\nt\bin;%PATH%"
set "BUILD=%ROOT%\build\xsim_windows"
set "RESULTS=%ROOT%\results\manual"

where xvlog >nul 2>nul || (
  echo ERROR: xvlog was not found. Run this script from the Vivado 2025.2 command shell.
  exit /b 2
)

if not exist "%BUILD%" mkdir "%BUILD%"
if not exist "%RESULTS%" mkdir "%RESULTS%"
pushd "%BUILD%"

echo [1/3] Compiling the C++ DPI reference model
call xsc "%ROOT%\model\dma_ref.cpp"
if errorlevel 1 goto :failed

echo [2/3] Compiling SystemVerilog and UVM sources
call xvlog -sv -L uvm ^
  -i "%ROOT%\rtl" ^
  -i "%ROOT%\tb" ^
  -i "%ROOT%\tb\uvc\axil" ^
  -i "%ROOT%\tb\uvc\axi_mem" ^
  -i "%ROOT%\tb\env" ^
  -i "%ROOT%\tb\seq" ^
  -i "%ROOT%\tb\tests" ^
  "%ROOT%\rtl\dma_pkg.sv" ^
  "%ROOT%\rtl\dma_fifo.sv" ^
  "%ROOT%\rtl\dma_regs.sv" ^
  "%ROOT%\rtl\dma_read_engine.sv" ^
  "%ROOT%\rtl\dma_write_engine.sv" ^
  "%ROOT%\rtl\dma_ctrl_fsm.sv" ^
  "%ROOT%\rtl\dma_crc32.sv" ^
  "%ROOT%\rtl\dma_top.sv" ^
  "%ROOT%\tb\interfaces\axil_if.sv" ^
  "%ROOT%\tb\interfaces\axi_if.sv" ^
  "%ROOT%\tb\interfaces\reset_ctrl_if.sv" ^
  "%ROOT%\tb\interfaces\dma_probe_if.sv" ^
  "%ROOT%\model\dma_ref_pkg.sv" ^
  "%ROOT%\tb\uvc\axil\axil_uvc_pkg.sv" ^
  "%ROOT%\tb\uvc\axi_mem\axi_mem_uvc_pkg.sv" ^
  "%ROOT%\tb\env\dma_env_pkg.sv" ^
  "%ROOT%\tb\seq\dma_seq_pkg.sv" ^
  "%ROOT%\tb\tests\dma_test_pkg.sv" ^
  "%ROOT%\tb\sva\dma_sva.sv" ^
  "%ROOT%\tb\top\tb_top.sv"
if errorlevel 1 goto :failed

echo [3/3] Elaborating the simulation snapshot
call xelab -L uvm -debug typical -timescale 1ns/1ps -cc_type bcst ^
  -sv_lib dpi tb_top -s tb_top_snapshot
if errorlevel 1 goto :failed

echo VERIDMA XSIM COMPILE PASSED
if /I "%ACTION%"=="compile" goto :success
if /I not "%ACTION%"=="test" (
  echo ERROR: action must be compile or test.
  goto :failed
)

set "VERIDMA_COV_DIR=%RESULTS%\coverage"
set "VERIDMA_COV_NAME=%TEST%_%SEED%"
echo Running %TEST% with seed %SEED%
call xsim tb_top_snapshot ^
  -tclbatch "%ROOT_TCL%/scripts/xsim_run.tcl" ^
  -sv_seed %SEED% ^
  -testplusarg "UVM_TESTNAME=%TEST%" ^
  -testplusarg "VERIDMA_SEED=%SEED%" ^
  -log "%RESULTS%\%TEST%_%SEED%.log"
if errorlevel 1 goto :failed
goto :success

:failed
echo VERIDMA XSIM COMMAND FAILED
popd
exit /b 1

:success
popd
exit /b 0
