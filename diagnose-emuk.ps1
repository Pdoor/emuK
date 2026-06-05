$ErrorActionPreference = "Continue"

Write-Host "== emuK diagnostic =="
Write-Host ""

Write-Host "IP locali:"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" } |
    Select-Object InterfaceAlias,IPAddress |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Profili rete:"
Get-NetConnectionProfile |
    Select-Object Name,InterfaceAlias,NetworkCategory,IPv4Connectivity |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Porte in ascolto:"
Get-NetTCPConnection -LocalPort 8787,8788 -State Listen -ErrorAction SilentlyContinue |
    Select-Object LocalAddress,LocalPort,OwningProcess |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Test locale HTTP:"
try {
    curl.exe -s --max-time 5 http://127.0.0.1:8788/api/info
    Write-Host ""
} catch {
    Write-Host $_
}

Write-Host ""
Write-Host "Test locale HTTPS:"
try {
    curl.exe -k -s --max-time 5 https://127.0.0.1:8787/api/info
    Write-Host ""
} catch {
    Write-Host $_
}

Write-Host ""
Write-Host "Regole firewall emuK:"
Get-NetFirewallRule -DisplayName "emuK*" -ErrorAction SilentlyContinue |
    Select-Object DisplayName,Enabled,Direction,Action,Profile |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Regole firewall emuK - porte:"
Get-NetFirewallRule -DisplayName "emuK*" -ErrorAction SilentlyContinue |
    Get-NetFirewallPortFilter |
    Select-Object Protocol,LocalPort |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Dal tablet prova prima l'indirizzo HTTP con l'IP Wi-Fi, per esempio:"
$wifiIp = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -First 1 -ExpandProperty IPAddress
if ($wifiIp) {
    Write-Host "http://$wifiIp`:8788"
    Write-Host "https://$wifiIp`:8787"
    Write-Host ""
    Write-Host "Test diagnostico diretto dal telefono:"
    Write-Host "http://$wifiIp`:8788/api/info"
}
