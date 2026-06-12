$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$toolsDir = Join-Path $root "tools"
$cloudflared = Join-Path $toolsDir "cloudflared.exe"
$port = if ($env:EMUK_PORT) { $env:EMUK_PORT } else { "5000" }
$telegramToken = $env:EMUK_TELEGRAM_BOT_TOKEN
$telegramChatId = $env:EMUK_TELEGRAM_CHAT_ID

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

$python = "python"
try {
    $pyLauncher = Get-Command py -ErrorAction Stop
    $python = $pyLauncher.Source
    $server = Start-Process -FilePath $python -ArgumentList "-3", "companion.py" -WorkingDirectory $root -PassThru -WindowStyle Hidden
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

Write-Host ""
Write-Host "Apro tunnel pubblico. Copia sul telefono l'URL https://...trycloudflare.com che apparira qui sotto."
Write-Host "Premi Ctrl+C per chiudere tunnel e server."
Write-Host ""

function Send-TelegramMessage {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($telegramToken) -or [string]::IsNullOrWhiteSpace($telegramChatId)) {
        return
    }

    try {
        $uri = "https://api.telegram.org/bot$telegramToken/sendMessage"
        $body = @{
            chat_id = $telegramChatId
            text = $Text
            disable_web_page_preview = $true
        }
        Invoke-RestMethod -Method Post -Uri $uri -Body $body | Out-Null
        Write-Host "Link inviato su Telegram."
    } catch {
        Write-Host "Invio Telegram fallito: $($_.Exception.Message)"
    }
}

$logFile = Join-Path $root "work-cloudflared.log"
Remove-Item $logFile -ErrorAction SilentlyContinue

try {
    $tunnel = Start-Process `
        -FilePath $cloudflared `
        -ArgumentList "tunnel", "--url", "http://127.0.0.1:$port", "--logfile", $logFile `
        -WorkingDirectory $root `
        -PassThru

    $sentUrl = $null
    while (!$tunnel.HasExited) {
        if (Test-Path $logFile) {
            $match = Get-Content $logFile -ErrorAction SilentlyContinue |
                Select-String -Pattern "https://[-a-z0-9]+\.trycloudflare\.com" |
                Select-Object -Last 1

            if ($match -and !$sentUrl) {
                $sentUrl = $match.Matches.Value
                Write-Host ""
                Write-Host "URL tunnel: $sentUrl"
                Send-TelegramMessage "emuK: $sentUrl"
            }
        }
        Start-Sleep -Seconds 1
        $tunnel.Refresh()
    }
} finally {
    if ($tunnel -and !$tunnel.HasExited) {
        Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
