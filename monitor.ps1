# SilTech Industries - Serial Monitor
# Auto-connects, Q + Enter to quit
# Usage: monitor.ps1 [-ComPort COM3]

param(
    [string]$ComPort = ""
)

$BAUD = 115200
$LOG_DIR = Join-Path $PSScriptRoot "logs"

# --- Auto-detect if not specified ---
if (-not $ComPort) {
    $ports = Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.Name -match "CH340|CP210|FTDI|USB.Serial|USB-SERIAL|Silicon Labs" -and $_.Name -match "COM\d+"
    }
    foreach ($p in $ports) {
        if ($p.Name -match "(COM\d+)") {
            $ComPort = $Matches[1]
            break
        }
    }
    if (-not $ComPort) {
        Write-Host "  [ERROR] No COM port found!" -ForegroundColor Red
        Read-Host "  Press Enter"
        exit 1
    }
}

# --- Wait for device boot after hard reset ---
Start-Sleep -Seconds 2

# --- Log setup ---
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR | Out-Null }
$logFile = Join-Path $LOG_DIR ("monitor_" + (Get-Date -Format "yyyy-MM-dd") + ".log")

# --- Open serial port ---
$port = New-Object System.IO.Ports.SerialPort $ComPort, $BAUD, "None", 8, "One"
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = -1
$port.Encoding = [System.Text.Encoding]::UTF8

try {
    $port.Open()
} catch {
    Write-Host "  [ERROR] Cannot open $ComPort" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
    Start-Sleep -Seconds 2
    exit 1
}

[Console]::TreatControlCAsInput = $true

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "   Serial Monitor - $ComPort @ $BAUD" -ForegroundColor Green
Write-Host "   Press Q + Enter to stop" -ForegroundColor Yellow
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""

# --- Hard reset device so boot output is captured ---
Write-Host "  Resetting device..." -ForegroundColor Yellow
$port.DtrEnable = $false
$port.RtsEnable = $true
Start-Sleep -Milliseconds 100
$port.RtsEnable = $false
Start-Sleep -Milliseconds 100
Write-Host ""

Add-Content -Path $logFile -Value "`n=== Monitor $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $ComPort ==="

$inputBuffer = ""
$running = $true
$lineCount = 0

while ($running -and $port.IsOpen) {
    # --- Read serial data ---
    if ($port.BytesToRead -gt 0) {
        $data = $port.ReadExisting()
        if ($data) {
            $lines = $data -split "`n"
            foreach ($rawLine in $lines) {
                $line = $rawLine.TrimEnd("`r")
                if ($line.Length -eq 0) { continue }
                $ts = Get-Date -Format "HH:mm:ss.fff"
                $display = "[$ts] $line"

                if ($line -match "\[E\]|\[ERROR\]|ERROR") {
                    Write-Host $display -ForegroundColor Red
                } elseif ($line -match "\[W\]|\[WARN\]|WARNING") {
                    Write-Host $display -ForegroundColor Yellow
                } elseif ($line -match "WiFi|MQTT|connected|IP:|OTA|version|MAC|Serial:") {
                    Write-Host $display -ForegroundColor Cyan
                } else {
                    Write-Host $display
                }

                Add-Content -Path $logFile -Value $display
                $lineCount++
            }
        }
    }

    # --- Keyboard input ---
    while ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)

        if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq "C") {
            $running = $false
            break
        }

        if ($key.Key -eq "Enter") {
            Write-Host ""
            if ($inputBuffer -eq "q" -or $inputBuffer -eq "Q") {
                $running = $false
                break
            }
            if ($inputBuffer.Length -gt 0) {
                $port.WriteLine($inputBuffer)
                $ts = Get-Date -Format "HH:mm:ss.fff"
                Write-Host "[$ts] >> $inputBuffer" -ForegroundColor Yellow
                Add-Content -Path $logFile -Value "[$ts] >> $inputBuffer"
            }
            $inputBuffer = ""
        }
        elseif ($key.Key -eq "Backspace") {
            if ($inputBuffer.Length -gt 0) {
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
        }
        else {
            $inputBuffer += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline -ForegroundColor Yellow
        }
    }

    Start-Sleep -Milliseconds 50
}

# --- Cleanup ---
[Console]::TreatControlCAsInput = $false
if ($port.IsOpen) { $port.Close() }
$port.Dispose()
Add-Content -Path $logFile -Value "=== Stopped $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ($lineCount lines) ==="
Write-Host ""
Write-Host "  Monitor stopped. ($lineCount lines)" -ForegroundColor Cyan
Write-Host ""
