@echo off
setlocal enabledelayedexpansion
title SilTech Flash Tool
color 0A
mode con: cols=70 lines=40

:: ============================================================
::  SilTech Industries - Flash Tool
::  Production floor firmware flashing
::
::  - Scans firmware\ folder for available devices
::  - Select device once, then ENTER to flash repeatedly
::  - Full flash: bootloader + partitions + app
::  - Auto hard-reset + serial monitor after each flash
::  - Press Q to stop monitor, ENTER to flash next device
:: ============================================================

:STARTUP
cls
echo.
echo   ====================================================
echo    SilTech Industries - Flash Tool
echo   ====================================================
echo.

:: ── Auto-detect COM port ────────────────────────────────────
set COMPORT=
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'CH340|CP210|FTDI|USB.Serial|Silicon Labs' -and $_.Name -match 'COM\d+' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { $Matches[1] } } | Select-Object -First 1"') do set COMPORT=%%a

if "%COMPORT%"=="" (
    echo   [ERROR] No USB adapter detected!
    echo   Plug in the CH340/CP2102 cable and try again.
    echo.
    pause
    goto :STARTUP
)
echo   [OK] USB Adapter: %COMPORT%
echo.

:: ── Scan firmware folder ────────────────────────────────────
echo   Available Devices:
echo   ------------------
set IDX=0
for /d %%d in (firmware\*) do (
    :: Only list folders that have firmware.bin
    if exist "firmware\%%~nxd\firmware.bin" (
        set /a IDX+=1
        set "DEV_!IDX!=%%~nxd"
        
        :: Show what files are available
        set "HAS_BL= "
        set "HAS_PT= "
        if exist "firmware\%%~nxd\bootloader.bin" set "HAS_BL=B"
        if exist "firmware\%%~nxd\partitions.bin" set "HAS_PT=P"
        
        echo     !IDX!. %%~nxd  [!HAS_BL!!HAS_PT!A]
    )
)
echo.
echo   [B]=bootloader [P]=partitions [A]=app
echo.

if %IDX% EQU 0 (
    echo   [ERROR] No firmware found!
    echo   Place device folders in firmware\ with firmware.bin inside.
    echo.
    pause
    goto :EOF
)

set /p DEVNUM="   Select device number: "
set DEVNAME=!DEV_%DEVNUM%!
if "!DEVNAME!"=="" (
    echo   [ERROR] Invalid selection!
    timeout /t 2 >nul
    goto :STARTUP
)

:: ── Verify files and build flash command ────────────────────
set HAS_BOOTLOADER=0
set HAS_PARTITIONS=0

if exist "firmware\!DEVNAME!\bootloader.bin" set HAS_BOOTLOADER=1
if exist "firmware\!DEVNAME!\partitions.bin" set HAS_PARTITIONS=1

if !HAS_BOOTLOADER!==1 if !HAS_PARTITIONS!==1 (
    set FLASH_TYPE=FULL
    echo.
    echo   [OK] Full flash: bootloader + partitions + app
) else (
    set FLASH_TYPE=APP
    echo.
    echo   [INFO] App-only flash (no bootloader/partitions found)
)

:: ── Detect flash size from partition file ───────────────────
:: Default 4MB, auto-detect from partitions.bin size if available
set FLASH_SIZE=detect

:: ── Setup ───────────────────────────────────────────────────
if not exist "logs" mkdir logs
set COUNT=0
set FAIL_COUNT=0

:: Get date safely (locale-independent)
for /f "tokens=*" %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set LOGDATE=%%d
set LOGFILE=logs\flash_!LOGDATE!.log

:: ── Production Loop ─────────────────────────────────────────
:FLASH_LOOP
cls
echo.
echo   ====================================================
echo    SilTech Flash Tool
echo   ====================================================
echo.
echo   Device:     !DEVNAME!
echo   Flash Mode: !FLASH_TYPE!
echo   COM Port:   %COMPORT%
echo.
echo   Session:    !COUNT! OK  /  !FAIL_COUNT! FAILED
echo.
echo   ====================================================
echo.
echo     ENTER = Flash next device
echo     X     = Change device / Exit
echo.
set /p ACTION="   Press ENTER to flash: "

if /i "!ACTION!"=="X" goto :STARTUP

:: ── Re-check COM port ───────────────────────────────────────
set COMPORT=
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'CH340|CP210|FTDI|USB.Serial|Silicon Labs' -and $_.Name -match 'COM\d+' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { $Matches[1] } } | Select-Object -First 1"') do set COMPORT=%%a

if "%COMPORT%"=="" (
    echo.
    echo   [ERROR] USB adapter disconnected! Plug it back in.
    echo.
    pause
    goto :FLASH_LOOP
)

:: ── Flash ───────────────────────────────────────────────────
echo.
echo   --------------------------------------------------------
echo    FLASHING !DEVNAME! ... Do NOT unplug!
echo   --------------------------------------------------------
echo.

if "!FLASH_TYPE!"=="FULL" (
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 --after hard-reset ^
      write-flash --flash-mode dio --flash-size !FLASH_SIZE! ^
      0x1000  firmware\!DEVNAME!\bootloader.bin ^
      0x8000  firmware\!DEVNAME!\partitions.bin ^
      0x10000 firmware\!DEVNAME!\firmware.bin
) else (
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 --after hard-reset ^
      write-flash 0x10000 firmware\!DEVNAME!\firmware.bin
)

if %ERRORLEVEL% NEQ 0 (
    set /a FAIL_COUNT+=1
    echo.
    echo   ########################################
    echo   #         FLASH FAILED!                #
    echo   #   Check cable and try again.          #
    echo   ########################################
    echo.
    echo   [%date% %time%] FAIL #!FAIL_COUNT! - !DEVNAME! on %COMPORT% >> !LOGFILE!
    pause
    goto :FLASH_LOOP
)

:: ── Success ─────────────────────────────────────────────────
set /a COUNT+=1
echo.
echo   ========================================
echo    FLASH OK!   #!COUNT!
echo   ========================================
echo.
echo   [%date% %time%] OK #!COUNT! - !DEVNAME! on %COMPORT% >> !LOGFILE!

:: ── Serial Monitor ──────────────────────────────────────────
echo   Starting monitor... (Q + Enter to stop)
echo   --------------------------------------------------------
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0monitor.ps1" -ComPort %COMPORT%

echo.
echo   Ready for next device.
goto :FLASH_LOOP
