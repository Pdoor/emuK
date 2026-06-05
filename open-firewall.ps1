$ErrorActionPreference = "Stop"

$ruleName = "emuK keyboard companion"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (!$isAdmin) {
    Write-Host "Questo script deve essere eseguito come amministratore."
    Write-Host "Clic destro su PowerShell -> Esegui come amministratore, poi:"
    Write-Host "cd `"$PSScriptRoot`""
    Write-Host ".\open-firewall.ps1"
    exit 1
}

Get-NetFirewallRule -DisplayName "$ruleName*" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

New-NetFirewallRule `
    -DisplayName "$ruleName TCP 8787-8788" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 8787-8788 `
    -Profile Any | Out-Null

New-NetFirewallRule `
    -DisplayName "$ruleName TCP 5000" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 5000 `
    -Profile Any | Out-Null

Write-Host "Firewall aperto per TCP 8787-8788 e 5000 su tutti i profili."
Write-Host "Riavvia start-http-5000.bat e prova dal tablet l'indirizzo HTTP 5000."
