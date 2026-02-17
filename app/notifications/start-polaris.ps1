param(
    [switch]$ShowTerminal
)

$ErrorActionPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pythonw = Join-Path $repoRoot ".venv\Scripts\pythonw.exe"
$python = Join-Path $repoRoot ".venv\Scripts\python.exe"
$runtimeDir = Join-Path $repoRoot "app\runtime"
$backendPidFile = Join-Path $runtimeDir "backend_pid.txt"

if (-not (Test-Path $runtimeDir)) {
    New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (-not (Test-Path $pythonw)) {
    $pythonw = "pythonw"
}
if (-not (Test-Path $python)) {
    $python = "python"
}

$enableReload = $env:POLARIS_UVICORN_RELOAD -eq "1"
$uvicornArgs = @("-m", "uvicorn", "app.main:app")
if ($enableReload) {
    $uvicornArgs += "--reload"
}

# 1. Start Valkey if not running
$valkeyRunning = docker ps --format "{{.Names}}" | Select-String "polaris-valkey"
if (-not $valkeyRunning) {
    docker start polaris-valkey 2>$null
    if ($LASTEXITCODE -ne 0) {
        docker run -d `
            --name polaris-valkey `
            -p 6379:6379 `
            valkey/valkey:latest | Out-Null
    }
}

# 2. Start backend (no visible shell)
if ($ShowTerminal) {
    $cmdParts = @("Set-Location '$repoRoot';", "& '$python'", "-m uvicorn app.main:app")
    if ($enableReload) {
        $cmdParts += "--reload"
    }
    $commandText = ($cmdParts -join " ")
    $backendProc = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"$commandText`"" `
        -WorkingDirectory $repoRoot `
        -PassThru
} else {
    $backendProc = Start-Process `
        -FilePath $pythonw `
        -WindowStyle Hidden `
        -ArgumentList $uvicornArgs `
        -WorkingDirectory $repoRoot `
        -PassThru
}

if ($backendProc -and $backendProc.Id) {
    Set-Content -Path $backendPidFile -Value $backendProc.Id
}
