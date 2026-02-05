Write-Host "Starting Polaris system..."

# 1. Start Valkey if not running
$valkeyRunning = docker ps --format "{{.Names}}" | Select-String "polaris-valkey"

if (-not $valkeyRunning) {
    Write-Host "Starting Valkey..."
    docker start polaris-valkey 2>$null

    if ($LASTEXITCODE -ne 0) {
        docker run -d `
            --name polaris-valkey `
            -p 6379:6379 `
            valkey/valkey:latest
    }
} else {
    Write-Host "Valkey already running."
}

# 2. Activate venv
Set-Location D:\Polaris
.\.venv\Scripts\Activate.ps1

# 3. Start backend
Write-Host "Starting backend..."
Start-Process powershell -ArgumentList "uvicorn app.main:app --reload"

# 4. Start Valkey router
Write-Host "Starting Valkey router..."
python -m app.notifications.valkey_router
