$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$toolsDir = Join-Path $root "tools"
$cloudflared = Join-Path $toolsDir "cloudflared.exe"
$tunnelName = if ($env:EMUK_TUNNEL_NAME) { $env:EMUK_TUNNEL_NAME } else { "emuk" }
$hostname = $env:EMUK_HOSTNAME

if (!(Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

if (!(Test-Path $cloudflared)) {
    Write-Host "Scarico cloudflared..."
    $url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    curl.exe -L --fail -o $cloudflared $url
}

if ([string]::IsNullOrWhiteSpace($hostname)) {
    $hostname = Read-Host "Hostname stabile da usare, per esempio emuk.example.com"
}

if ([string]::IsNullOrWhiteSpace($hostname) -or $hostname -notmatch "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$") {
    throw "Hostname non valido. Esempio valido: emuk.example.com"
}

Write-Host ""
Write-Host "1/3 Login Cloudflare"
Write-Host "Si aprira il browser: scegli il dominio Cloudflare che contiene $hostname."
& $cloudflared tunnel login

Write-Host ""
Write-Host "2/3 Creo/verifico tunnel nominato '$tunnelName'"
& $cloudflared tunnel info $tunnelName *> $null
if ($LASTEXITCODE -ne 0) {
    & $cloudflared tunnel create $tunnelName
} else {
    Write-Host "Tunnel '$tunnelName' gia presente."
}

Write-Host ""
Write-Host "3/3 Associo DNS $hostname -> tunnel $tunnelName"
& $cloudflared tunnel route dns --overwrite-dns $tunnelName $hostname

Write-Host ""
Write-Host "Setup completato."
Write-Host "Da ora puoi avviare:"
Write-Host ".\start-smart-tunnel.bat"
Write-Host ""
Write-Host "URL stabile:"
Write-Host "https://$hostname"
