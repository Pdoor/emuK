$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$toolsDir = Join-Path $root "tools"
$cloudflared = Join-Path $toolsDir "cloudflared.exe"
$port = if ($env:EMUK_PORT) { $env:EMUK_PORT } else { "5000" }
$tunnelName = if ($env:EMUK_TUNNEL_NAME) { $env:EMUK_TUNNEL_NAME } else { "emuk" }

if (!(Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

if (!(Test-Path $cloudflared)) {
    Write-Host "Scarico cloudflared..."
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    curl.exe -L --fail -o $cloudflared $url
}

Write-Host "Avvio emuK locale su http://127.0.0.1:$port ..."

$env:EMUK_HTTPS = "0"
$env:EMUK_HTTP_FALLBACK = "0"
$env:EMUK_PORT = $port

$existing = Get-CimInstance Win32_Process |
    Where-Object { $_.Name -like "python*" -and $_.CommandLine -like "*companion.py*" }
foreach ($proc in $existing) {
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

try {
    $pyLauncher = Get-Command py -ErrorAction Stop
    $server = Start-Process -FilePath $pyLauncher.Source -ArgumentList "-3", "companion.py" -WorkingDirectory $root -PassThru -WindowStyle Hidden
} catch {
    $server = Start-Process -FilePath "python" -ArgumentList "companion.py" -WorkingDirectory $root -PassThru -WindowStyle Hidden
}

Start-Sleep -Seconds 2

try {
    $local = Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$port/api/info" -TimeoutSec 5
    Write-Host "Server locale OK: $($local.Content)"
} catch {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    throw "Il server locale non risponde su http://127.0.0.1:$port"
}

function Test-NamedTunnel {
    param([string]$Name)

    try {
        & $cloudflared tunnel info $Name *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

Write-Host ""
if (Test-NamedTunnel $tunnelName) {
    Write-Host "Tunnel Cloudflare nominato trovato: $tunnelName"
    Write-Host "Avvio URL stabile configurato su Cloudflare."
    Write-Host "Premi Ctrl+C per chiudere tunnel e server."
    Write-Host ""
    try {
        & $cloudflared tunnel run $tunnelName
    } finally {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Tunnel nominato '$tunnelName' non configurato o login Cloudflare mancante."
    Write-Host "Uso quick tunnel temporaneo come fallback."
    Write-Host "Copia sul telefono l'URL https://...trycloudflare.com che apparira qui sotto."
    Write-Host "Premi Ctrl+C per chiudere tunnel e server."
    Write-Host ""
    try {
        & $cloudflared tunnel --url "http://127.0.0.1:$port"
    } finally {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
}
