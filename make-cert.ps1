$ErrorActionPreference = "Stop"

$certDir = Join-Path $PSScriptRoot "certs"
$certPath = Join-Path $certDir "emuk-cert.pem"
$keyPath = Join-Path $certDir "emuk-key.pem"
$configPath = Join-Path $certDir "openssl.cnf"

if (!(Test-Path $certDir)) {
    New-Item -ItemType Directory -Path $certDir | Out-Null
}

if ((Test-Path $certPath) -and (Test-Path $keyPath)) {
    Write-Host "Certificato HTTPS gia presente."
    exit 0
}

$openssl = $null
$candidates = @(
    "openssl.exe",
    "C:\Program Files\Git\usr\bin\openssl.exe",
    "C:\Program Files\Git\mingw64\bin\openssl.exe"
)

foreach ($candidate in $candidates) {
    try {
        $openssl = (Get-Command $candidate -ErrorAction Stop).Source
        break
    } catch {
    }
}

if (!$openssl) {
    throw "OpenSSL non trovato. Installa Git for Windows oppure crea certs\emuk-cert.pem e certs\emuk-key.pem."
}

$ipAddresses = @("127.0.0.1")
try {
    $localIps = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Select-Object -ExpandProperty IPAddress -Unique
    $ipAddresses += $localIps
} catch {
}
$ipAddresses = $ipAddresses | Select-Object -Unique

$dnsNames = @("localhost", $env:COMPUTERNAME) |
    Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique

$altLines = @()
$index = 1
foreach ($name in $dnsNames) {
    $altLines += "DNS.$index = $name"
    $index += 1
}
$index = 1
foreach ($ip in $ipAddresses) {
    $altLines += "IP.$index = $ip"
    $index += 1
}

$config = @"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = emuK local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
$($altLines -join "`n")
"@

[System.IO.File]::WriteAllText($configPath, $config)

$opensslArgs = @(
    "req",
    "-x509",
    "-nodes",
    "-days",
    "730",
    "-newkey",
    "rsa:2048",
    "-keyout",
    $keyPath,
    "-out",
    $certPath,
    "-config",
    $configPath
)
$process = Start-Process -FilePath $openssl -ArgumentList $opensslArgs -NoNewWindow -Wait -PassThru -RedirectStandardError "$certDir\openssl.err"

if ($process.ExitCode -ne 0) {
    throw "OpenSSL non e riuscito a creare il certificato."
}

Write-Host "Certificato HTTPS creato in $certDir"
