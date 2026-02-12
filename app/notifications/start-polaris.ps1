param(
    [switch]$ShowTerminal
)

$ErrorActionPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pythonw = Join-Path $repoRoot ".venv\Scripts\pythonw.exe"
$python = Join-Path $repoRoot ".venv\Scripts\python.exe"
$runtimeDir = Join-Path $repoRoot "app\runtime"
$backendPidFile = Join-Path $runtimeDir "backend_pid.txt"
$routerPidFile = Join-Path $runtimeDir "router_pid.txt"

if (-not (Test-Path $runtimeDir)) {
    New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (-not (Test-Path $pythonw)) {
    $pythonw = "pythonw"
}
if (-not (Test-Path $python)) {
    $python = "python"
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
    $backendProc = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"Set-Location '$repoRoot'; & '$python' -m uvicorn app.main:app --reload`"" `
        -WorkingDirectory $repoRoot `
        -PassThru
} else {
    $backendProc = Start-Process `
        -FilePath $pythonw `
        -WindowStyle Hidden `
        -ArgumentList "-m uvicorn app.main:app --reload" `
        -WorkingDirectory $repoRoot `
        -PassThru
}

if ($backendProc -and $backendProc.Id) {
    Set-Content -Path $backendPidFile -Value $backendProc.Id
}

# 3. Start Valkey router (no visible shell)
$routerProc = Start-Process `
    -FilePath $pythonw `
    -WindowStyle Hidden `
    -ArgumentList "-m app.notifications.valkey_router" `
    -WorkingDirectory $repoRoot `
    -PassThru

if ($routerProc -and $routerProc.Id) {
    Set-Content -Path $routerPidFile -Value $routerProc.Id
}
