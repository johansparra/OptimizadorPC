<#
.SYNOPSIS
    Crea un certificado de firma de código AUTOFIRMADO, solo para probar que
    build.ps1 firma. NO SIRVE PARA DISTRIBUIR.

.DESCRIPTION
    Deja en Cert:\CurrentUser\My un certificado con el uso "Firma de código"
    (EKU 1.3.6.1.5.5.7.3.3), clave RSA de 3072 bits no exportable y una
    vigencia corta (7 días por defecto). Con él se puede recorrer el flujo
    entero de build.ps1 -CertificateThumbprint: firmar, sellar la hora y
    verificar.

    Por qué no sirve para distribuir: nadie más confía en él. En cualquier
    otro equipo -y en este también- Get-AuthenticodeSignature dirá que la
    cadena acaba en una raíz no reconocida, y SmartScreen seguirá avisando
    igual que sin firma. Para entregar el .exe hace falta un certificado de
    firma de código de una CA (OV o EV) o Azure Trusted Signing; ver
    SECURITY.md §11 nº 3.

    Qué NO hace, a propósito: no lo copia a "Entidades de certificación raíz
    de confianza" ni a "Editores de confianza". Un certificado propio en la
    raíz de confianza convertiría la clave de este equipo en algo que Windows
    acepta para TODO (TLS incluido): un agujero que dura más que la prueba.

    No necesita permisos de administrador: solo toca el almacén del usuario.

.PARAMETER ValidDays
    Días de vigencia (1 a 30). Corto a propósito: es para una prueba.

.EXAMPLE
    $c = .\tools\New-DevSigningCert.ps1
    powershell -ExecutionPolicy Bypass -File .\build.ps1 -CertificateThumbprint $c.Thumbprint
    Remove-Item "Cert:\CurrentUser\My\$($c.Thumbprint)" -DeleteKey   # al terminar, BÓRRALO

.OUTPUTS
    El certificado creado (X509Certificate2).
#>
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateRange(1, 30)][int]$ValidDays = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$subject = 'CN=OptimizadorPC - firma de PRUEBA (no distribuir)'
$store = 'Cert:\CurrentUser\My'

if (-not $PSCmdlet.ShouldProcess($store, "crear el certificado autofirmado '$subject'")) { return }

$params = @{
    Type              = 'CodeSigningCert'
    Subject           = $subject
    FriendlyName      = 'OptimizadorPC: firma de PRUEBA, no distribuir'
    CertStoreLocation = $store
    KeyAlgorithm      = 'RSA'
    KeyLength         = 3072
    HashAlgorithm     = 'SHA256'
    KeyExportPolicy   = 'NonExportable'
    NotAfter          = (Get-Date).AddDays($ValidDays)
}
$cert = New-SelfSignedCertificate @params

Write-Warning 'Certificado AUTOFIRMADO de prueba: sirve para probar build.ps1, NO para distribuir el .exe.'
Write-Host ''
Write-Host "  Huella:  $($cert.Thumbprint)"
Write-Host "  Caduca:  $($cert.NotAfter.ToString('yyyy-MM-dd HH:mm'))"
Write-Host ''
Write-Host '  Compilar firmando con él:'
Write-Host "    powershell -ExecutionPolicy Bypass -File .\build.ps1 -CertificateThumbprint $($cert.Thumbprint)"
Write-Host ''
Write-Host '  Borrarlo al terminar (certificado y clave privada):'
Write-Host "    Remove-Item 'Cert:\CurrentUser\My\$($cert.Thumbprint)' -DeleteKey"
Write-Host ''

$cert
