# =============================================================================
# Sortio AI - Android emulator runner
#
# Launches an Android emulator (AVD), waits for it to boot, then runs the
# Flutter app on it. Works without adb on PATH.
#
# Usage:
#   .\run_android_emulator.ps1                 # first Android AVD found
#   .\run_android_emulator.ps1 -EmulatorId Medium_Phone
#   .\run_android_emulator.ps1 -ListOnly       # just list available emulators
#
# (or double-click run_android_emulator.bat)
# =============================================================================

param(
    [string]$EmulatorId = "",
    [switch]$ListOnly
)

function Write-Step($msg) { Write-Host "== $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "   $msg" }

# --- 0. Sanity checks ---------------------------------------------------------
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: flutter was not found on PATH." -ForegroundColor Red
    exit 1
}

# --- 1. Detect emulators ------------------------------------------------------
# Primary source: the AVD folder (%USERPROFILE%\.android\avd\*.ini) - each
# .ini file is one Android Virtual Device and its base name is the emulator id.
# Fallback: parse the `flutter emulators` table (id • name • maker • platform).
# (Parsing the table directly is unreliable: PowerShell 5.1 mangles the bullet
#  separator's encoding, so the filesystem listing is preferred.)
function Get-Emulators {
    $rows = @()

    $avdDir = Join-Path $env:USERPROFILE ".android\avd"
    if (Test-Path $avdDir) {
        foreach ($ini in (Get-ChildItem $avdDir -Filter "*.ini" -ErrorAction SilentlyContinue)) {
            $rows += [pscustomobject]@{ Id = $ini.BaseName; Name = $ini.BaseName; Platform = "android" }
        }
    }

    if ($rows.Count -eq 0) {
        $out = (& flutter emulators) -join "`n"
        foreach ($line in ($out -split "`n")) {
            if ($line -notmatch "\S\s+\S\s+\S\s+\S") { continue }
            if ($line -match "^\s*Id\s") { continue }               # header row
            $parts = ($line -split "\W+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
            if ($parts.Count -ge 4 -and $parts[3] -match "android") {
                $rows += [pscustomobject]@{ Id = $parts[0]; Name = $parts[1]; Platform = "android" }
            }
        }
    }

    return ,$rows
}

function Get-ConnectedEmulator {
    # A booted emulator shows up like:
    #   Medium Phone (mobile) - emulator-5554 - android-arm64 - Android 16 (API 36) (emulator)
    $out = (& flutter devices) -join "`n"
    foreach ($line in ($out -split "`n")) {
        if ($line -match [regex]::Escape("(emulator)") -and $line -match "emulator-\d+") {
            return $Matches[0]
        }
    }
    return $null
}

Write-Step "Sortio AI - Android emulator runner"
Write-Step "Detecting Android emulators..."
$emus = Get-Emulators

foreach ($e in $emus) { Write-Info ("found: {0}  ({1})" -f $e.Id, $e.Name) }

if ($ListOnly) {
    if ($emus.Count -eq 0) { Write-Info "no Android emulators found" }
    return
}

# --- 2. Skip launch if one is already running ---------------------------------
$deviceId = $null
$running = Get-ConnectedEmulator
if ($running) {
    $deviceId = $running
    Write-Step "An emulator is already running: $deviceId"
} else {
    if ($emus.Count -eq 0) {
        Write-Host ""
        Write-Host "No Android emulator found." -ForegroundColor Yellow
        Write-Host "Create one with:" -ForegroundColor Yellow
        Write-Host "    flutter emulators --create --name SortioAI" -ForegroundColor Yellow
        Write-Host "or in Android Studio: Tools > Device Manager > Create Device."
        Write-Host "Then run this script again."
        exit 1
    }

    if ($EmulatorId -eq "") {
        $EmulatorId = $emus[0].Id
        Write-Step "No -EmulatorId given, using the first available: $EmulatorId"
    } else {
        $known = @($emus | Where-Object { $_.Id -eq $EmulatorId })
        if ($known.Count -eq 0) {
            Write-Host "ERROR: emulator id '$EmulatorId' not found. Run with -ListOnly to see ids." -ForegroundColor Red
            exit 1
        }
        Write-Step "Launching requested emulator: $EmulatorId"
    }

    & flutter emulators --launch $EmulatorId
    Write-Info "launch command issued, waiting for boot..."
}

# --- 3. Wait for boot ----------------------------------------------------------
Write-Step "Waiting for the emulator to appear in 'flutter devices' (up to ~3 min)..."
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 3
    $dev = Get-ConnectedEmulator
    if ($dev) {
        $deviceId = $dev
        Write-Host ("   emulator online: {0}" -f $dev) -ForegroundColor Green
        $ready = $true
        break
    }
    Write-Info ("still booting... ({0}s)" -f ($i * 3))
}
if (-not $ready) {
    Write-Warning "Emulator did not come online in time. It may still be booting - run 'flutter run' manually."
    exit 1
}

# --- 4. Run the app -------------------------------------------------------------
Write-Step "Starting Sortio AI on $deviceId (hot reload: press 'r' in this window)..."
Set-Location -Path $PSScriptRoot
& flutter run -d $deviceId
