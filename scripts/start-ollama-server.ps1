#!/usr/bin/env pwsh
# Windows startup script using Ollama as the vision inference backend.
# Equivalent to scripts/start-mlx-server.sh for macOS/MLX.
#
# Prerequisites:
#   - Ollama installed: https://ollama.com/download/windows
#   - Node >= 18 for the npm/API side

$ErrorActionPreference = 'Stop'

$rootDir    = Split-Path -Parent $PSScriptRoot
$envFile    = Join-Path $rootDir '.env'

# Load .env (only sets variables that are not already in the environment).
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=\s][^=]*?)\s*=\s*(.*?)\s*$') {
            $name  = $Matches[1]
            $value = $Matches[2] -replace '^["'']|["'']$'
            if (-not [System.Environment]::GetEnvironmentVariable($name, 'Process')) {
                [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
            }
        }
    }
}

$baseUrl              = if ($env:OLLAMA_BASE_URL)         { $env:OLLAMA_BASE_URL }         else { 'http://127.0.0.1:11434' }
$modelId              = if ($env:OLLAMA_MODEL)            { $env:OLLAMA_MODEL }            else { 'qwen2.5vl:3b' }
$warmupTimeoutSeconds = if ($env:WARMUP_TIMEOUT_SECONDS)  { [int]$env:WARMUP_TIMEOUT_SECONDS } else { 900 }
$warmupMaxTokens      = if ($env:WARMUP_MAX_TOKENS)       { [int]$env:WARMUP_MAX_TOKENS }      else { 12 }


# ------------------------------------------------------------------
# 1. Ensure Ollama is installed.
# ------------------------------------------------------------------
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Error 'ollama not found in PATH. Install Ollama from https://ollama.com/download/windows and reopen this terminal.'
    exit 1
}

# ------------------------------------------------------------------
# 2. Start ollama serve if it is not already listening.
# ------------------------------------------------------------------
$ollamaProcess = $null

$alreadyRunning = $false
try {
    $probe = Invoke-WebRequest -Uri "$baseUrl/v1/models" -TimeoutSec 3 -ErrorAction Stop
    $alreadyRunning = $probe.StatusCode -eq 200
} catch { }

if ($alreadyRunning) {
    Write-Host "Ollama is already running at $baseUrl."
} else {
    Write-Host "Starting Ollama server..."
    $ollamaProcess = Start-Process -FilePath 'ollama' -ArgumentList 'serve' -PassThru -WindowStyle Hidden

    Write-Host "Waiting for Ollama to become ready at $baseUrl..."
    $attempts = 0
    $ready = $false
    while ($attempts -lt 120) {
        try {
            $probe = Invoke-WebRequest -Uri "$baseUrl/v1/models" -TimeoutSec 2 -ErrorAction Stop
            if ($probe.StatusCode -eq 200) { $ready = $true; break }
        } catch { }

        if ($ollamaProcess -and -not (Get-Process -Id $ollamaProcess.Id -ErrorAction SilentlyContinue)) {
            Write-Error 'Ollama process exited unexpectedly.'
            exit 1
        }
        Start-Sleep -Seconds 1
        $attempts++
    }

    if (-not $ready) {
        Write-Error 'Timed out waiting for Ollama to become ready.'
        if ($ollamaProcess) { Stop-Process -Id $ollamaProcess.Id -Force -ErrorAction SilentlyContinue }
        exit 1
    }
}

# ------------------------------------------------------------------
# 3. Pull the model (no-op if it is already present locally).
# ------------------------------------------------------------------
Write-Host "Pulling model $modelId (skipped automatically if already downloaded)..."
ollama pull $modelId

# ------------------------------------------------------------------
# 4. Warm-up request so the first real video frame is not delayed.
# ------------------------------------------------------------------
Write-Host "Warming up model $modelId..."

$warmupBody = @{
    model       = $modelId
    stream      = $false
    temperature = 0
    max_tokens  = $warmupMaxTokens
    messages    = @(
        @{
            role    = 'system'
            content = 'You are a helpful assistant.'
        },
        @{
            role    = 'user'
            content = 'Reply with the single word: ready.'
        }
    )
} | ConvertTo-Json -Depth 10

try {
    Invoke-RestMethod `
        -Uri          "$baseUrl/v1/chat/completions" `
        -Method       Post `
        -ContentType  'application/json' `
        -Body         $warmupBody `
        -TimeoutSec   $warmupTimeoutSeconds | Out-Null
    Write-Host 'Warm-up complete.'
} catch {
    Write-Warning "Warm-up request failed. The server is still running, but the first live request may be slow. $_"
}

# ------------------------------------------------------------------
# 5. Keep the script alive so Ctrl-C shuts down ollama (if we started it).
# ------------------------------------------------------------------
if ($ollamaProcess) {
    Write-Host "Ollama is ready. Press Ctrl+C to stop."
    try {
        Wait-Process -Id $ollamaProcess.Id
    } catch {
        Stop-Process -Id $ollamaProcess.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Ollama is ready (using existing instance). Press Ctrl+C to exit this script."
    while ($true) { Start-Sleep -Seconds 60 }
}
