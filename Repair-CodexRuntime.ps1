#requires -version 5.1

<#
.SYNOPSIS
    Repairs the Codex Desktop cua_node runtime on Windows.

.DESCRIPTION
    Fixes the Codex Desktop startup failure where ChatGPT.exe keeps running in
    the background but no application window appears. The script rebuilds the
    missing cua_node runtime from the files shipped inside the installed
    package, verifies the copy, and then removes the failed staging folders.

    Run this script from a normal user session. Do not use "Run as
    administrator": the Codex runtime lives in the current user's LOCALAPPDATA
    folder, and an elevated session may point at a different profile.

.NOTES
    Version : 1.0.0
    License : MIT (see LICENSE)
#>

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Configuration
# Change these values only if OpenAI renames the package or changes the layout.
# -----------------------------------------------------------------------------
$PackageName         = "OpenAI.Codex"
$InstallRelativePath = "app\resources\cua_node"
$AppDataFolder       = "OpenAI\Codex"
$RuntimeName         = "cua_node"
$ProcessName         = "ChatGPT"
$CoreFiles           = @("bin\node.exe", "bin\node_repl.exe")
# -----------------------------------------------------------------------------

function Write-Step {
    param([string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Fail {
    param([string]$Text)
    Write-Host "`n[FAILED] $Text" -ForegroundColor Red
    exit 1
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[WARNING] This window is elevated. The Codex runtime is stored per user;" -ForegroundColor Yellow
    Write-Host "          if Codex was installed for another account, this script may look in the wrong profile." -ForegroundColor Yellow
}

Write-Step "1. Locate the Codex package"
$pkg = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pkg) {
    Fail "Package '$PackageName' was not found. Install Codex Desktop for the current Windows user first."
}
if (-not $pkg.InstallLocation) {
    Fail "The package has no install location. Repair or reinstall Codex Desktop."
}

Write-Host "Version: $($pkg.Version)"
Write-Host "Install: $($pkg.InstallLocation)"
Write-Host "Status:  $($pkg.Status)"

$srcRoot = Join-Path $pkg.InstallLocation $InstallRelativePath
if (-not (Test-Path -LiteralPath $srcRoot)) {
    Fail "Official runtime source not found: $srcRoot"
}

Write-Step "2. Find the newest staging runtime"
$runtimeBase = Join-Path $env:LOCALAPPDATA (Join-Path $AppDataFolder "runtimes\$RuntimeName")
if (-not (Test-Path -LiteralPath $runtimeBase)) {
    New-Item -ItemType Directory -Path $runtimeBase -Force | Out-Null
}

$staging = Get-ChildItem -LiteralPath $runtimeBase -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like ".staging-*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $staging) {
    Write-Host "[INFO] No .staging-* directory found." -ForegroundColor Yellow
    Write-Host "If Codex opens normally, no repair is needed."
    Write-Host "If it still does not open, start Codex once to reproduce the failure, then run this script again."
    exit 0
}

if ($staging.Name -notmatch '^\.staging-([0-9a-fA-F]+)-') {
    Fail "Could not parse a runtime ID from the staging directory: $($staging.Name)"
}

$runtimeId = $matches[1]
$dstRoot = Join-Path $runtimeBase $runtimeId

Write-Host "Staging:    $($staging.Name)"
Write-Host "Runtime ID: $runtimeId"
Write-Host "Target:     $dstRoot"

Write-Step "3. Stop Codex processes"
$allProcesses = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
$codexProcesses = @($allProcesses | Where-Object {
    try {
        $_.Path -and $_.Path.StartsWith($pkg.InstallLocation, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        $false
    }
})

if ($codexProcesses.Count -gt 0) {
    $codexProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped $($codexProcesses.Count) Codex process(es)."
} else {
    Write-Host "No Codex processes are running."
}

$unmatchedCount = $allProcesses.Count - $codexProcesses.Count
if ($unmatchedCount -gt 0) {
    Write-Host "[WARNING] $unmatchedCount other '$ProcessName' process(es) were left running because they are not part of this Codex install." -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

Write-Step "4. Create the runtime directory"
New-Item -ItemType Directory -Path $dstRoot -Force | Out-Null

Write-Step "5. Copy the cua_node runtime"
Write-Host "From: $srcRoot"
Write-Host "To:   $dstRoot"
Write-Host "This can take several minutes because the runtime contains many files."

$srcPattern = Join-Path $srcRoot "*"
& xcopy.exe $srcPattern $dstRoot /E /I /H /Y /G /Q | Out-Null
$copyExitCode = $LASTEXITCODE
if ($copyExitCode -gt 1) {
    Fail "xcopy failed with exit code $copyExitCode."
}

Write-Step "6. Verify core files"
$missingFiles = @()
foreach ($relativePath in $CoreFiles) {
    $fullPath = Join-Path $dstRoot $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        Write-Host "$relativePath : OK"
    } else {
        Write-Host "$relativePath : MISSING" -ForegroundColor Red
        $missingFiles += $relativePath
    }
}

if ($missingFiles.Count -gt 0) {
    Fail "Core files are incomplete. Staging files were not removed."
}

Write-Step "7. Compare file counts"
$srcCount = @(Get-ChildItem -LiteralPath $srcRoot -Recurse -File -Force -ErrorAction SilentlyContinue).Count
$dstCount = @(Get-ChildItem -LiteralPath $dstRoot -Recurse -File -Force -ErrorAction SilentlyContinue).Count

Write-Host "Source files:      $srcCount"
Write-Host "Destination files: $dstCount"

if ($dstCount -lt $srcCount) {
    Write-Host "[WARNING] The destination has fewer files than the source. Staging files were not removed." -ForegroundColor Yellow
    Write-Host "Run the script again, or inspect the copy manually."
    exit 2
}

Write-Step "8. Remove failed staging directories"
$stagingDirs = @(Get-ChildItem -LiteralPath $runtimeBase -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like ".staging-*" })

if ($stagingDirs.Count -gt 0) {
    $stagingDirs | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $($stagingDirs.Count) staging director(ies)."
} else {
    Write-Host "Nothing to clean up."
}

Write-Step "Repair complete"
Write-Host "Codex version: $($pkg.Version)"
Write-Host "Runtime ID:    $runtimeId"
Write-Host "Runtime path:  $dstRoot"
Write-Host ""
Write-Host "Start Codex normally (do not run it as administrator)." -ForegroundColor Green
exit 0
