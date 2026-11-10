<#
    tools/CodeSigning.ps1
    ---------------------
    Firma Authenticode del .exe: elegir el certificado, firmar con SHA-256
    y sello de tiempo RFC 3161, y comprobar el resultado. Lo carga build.ps1
    con un punto, y SOLO cuando se le pide firmar.

    Qué NO es: parte de la aplicación. tools/ no es una carpeta de capa, así
    que nada de aquí entra en el .exe (regla 2 de CLAUDE.md), y no debe
    entrar: el programa no firma nada, lo firma quien lo compila.

    Por qué no se firma con Set-AuthenticodeSignature (comprobado el
    2026-11-09, en 5.1 y en 7):
      - Su -TimestampServer pide un sello Authenticode LEGADO (contrafirma
        PKCS #9, OID 1.2.840.113549.1.9.6), no RFC 3161.
      - Añadir después el sello RFC 3161 con SignerTimeStampEx2 sí lo pone,
        pero reescribe el .exe ya firmado, y en la máquina de desarrollo
        el proceso que sellaba murió sin decir nada y el .exe desapareció
        (el antivirus, Bitdefender, lo tenía abierto en ese momento).
        Firmar y sellar en una sola llamada no lo provocó ni una vez.
    Así que se hace como signtool (`sign /fd sha256 /tr <url> /td sha256`):
    UNA llamada a SignerSignEx2 de mssign32.dll, que firma y sella a la vez
    y escribe el archivo una sola vez. Si el sello falla, no firma: el .exe
    se queda como estaba, sin firma a medias. mssign32.dll viene con
    Windows; no hace falta el SDK. La verificación sí es la de siempre,
    Get-AuthenticodeSignature.

    Funciones:
        Resolve-CodeSigningCertificate  busca el certificado y dice por qué no vale
        Invoke-CodeSigning              firma (+ sello) y verifica; devuelve un
                                        objeto con lo que pasó
#>

# EKU "Firma de código". Un certificado sin ella no se acepta aunque
# técnicamente sirviera para todo: quien firma tiene que haberlo pedido
# para esto.
$CodeSigningEkuOid = '1.3.6.1.5.5.7.3.3'

# Dónde se buscan. Solo los almacenes personales: los de CA o raíz no
# guardan certificados con clave privada para firmar.
$CodeSigningStores = @('Cert:\CurrentUser\My', 'Cert:\LocalMachine\My')

<#
    Huella normalizada: solo los 40 dígitos hexadecimales, en mayúsculas.
    Al copiarla del diálogo de certificados de Windows suelen venir espacios
    y un carácter invisible (U+200E) delante; se quitan aquí para que no
    haya que explicarlo. Devuelve $null si no queda una huella SHA-1 válida.
#>
function ConvertTo-CertificateThumbprint {
    param([string]$Thumbprint)
    $limpia = ($Thumbprint -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    if ($limpia.Length -ne 40) { return $null }
    $limpia
}

function Test-CodeSigningEku {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    foreach ($ext in $Certificate.Extensions) {
        if ($ext -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
            foreach ($oid in $ext.EnhancedKeyUsages) {
                if ($oid.Value -eq $CodeSigningEkuOid) { return $true }
            }
        }
    }
    $false
}

<#
    Busca en Cert:\CurrentUser\My y Cert:\LocalMachine\My el certificado de
    esa huella y comprueba que sirve para firmar: EKU de firma de código,
    clave privada y dentro de sus fechas. Nunca lanza.

    Devuelve un objeto:
        Certificate  el certificado, o $null si no vale
        Store        en qué almacén estaba
        Problem      por qué no vale (texto), o $null
        Usable       lista de los que SÍ valdrían, para enseñarlos en el error
#>
function Resolve-CodeSigningCertificate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Thumbprint)

    $usable = New-Object System.Collections.Generic.List[object]
    $found = $null
    $foundStore = $null
    $huella = ConvertTo-CertificateThumbprint $Thumbprint
    $now = Get-Date

    foreach ($store in $CodeSigningStores) {
        $certs = @()
        try { $certs = @(Get-ChildItem -Path $store -ErrorAction Stop) }
        catch { continue }   # almacén ilegible: se mira el siguiente
        foreach ($cert in $certs) {
            $ok = $cert.HasPrivateKey -and (Test-CodeSigningEku $cert) -and
                  $now -ge $cert.NotBefore -and $now -le $cert.NotAfter
            if ($ok) { $usable.Add([PSCustomObject]@{ Store = $store; Thumbprint = $cert.Thumbprint; Subject = $cert.Subject; NotAfter = $cert.NotAfter }) }
            if ($huella -and $cert.Thumbprint -eq $huella -and -not $found) { $found = $cert; $foundStore = $store }
        }
    }

    $problem = $null
    if (-not $huella) {
        $problem = "'$Thumbprint' no es una huella SHA-1 (40 dígitos hexadecimales)"
    }
    elseif (-not $found) {
        $problem = "no hay ningún certificado con la huella $huella en $($CodeSigningStores -join ' ni en ')"
    }
    elseif (-not (Test-CodeSigningEku $found)) {
        $problem = "el certificado $huella no tiene el uso 'Firma de código' (EKU $CodeSigningEkuOid)"
    }
    elseif (-not $found.HasPrivateKey) {
        $problem = "el certificado $huella está en $foundStore pero sin su clave privada"
    }
    elseif ($now -lt $found.NotBefore -or $now -gt $found.NotAfter) {
        $problem = 'el certificado {0} no está en vigor (válido del {1:yyyy-MM-dd} al {2:yyyy-MM-dd})' -f $huella, $found.NotBefore, $found.NotAfter
    }

    [PSCustomObject]@{
        Certificate = $(if ($problem) { $null } else { $found })
        Store       = $foundStore
        Problem     = $problem
        Usable      = $usable.ToArray()
    }
}

<#
    El puente a mssign32.dll. Literal fijo y revisado, como los Add-Type de
    core/Interop (SECURITY.md §11 nº 6): no se construye con nada de fuera.
    Se compila una vez por sesión.

    Las estructuras son las de mssign32 (SIGNER_*), en el orden en que las
    declara la API; LayoutKind.Sequential pone el relleno de 64 bits.
#>
function Initialize-CodeSigningInterop {
    if ('OptimizadorPCBuild.AuthenticodeSigner' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace OptimizadorPCBuild {
    public static class AuthenticodeSigner {
        [StructLayout(LayoutKind.Sequential)]
        struct SIGNER_FILE_INFO { public uint cbSize; public IntPtr pwszFileName; public IntPtr hFile; }

        [StructLayout(LayoutKind.Sequential)]
        struct SIGNER_SUBJECT_INFO { public uint cbSize; public IntPtr pdwIndex; public uint dwSubjectChoice; public IntPtr pSignerFileInfo; }

        [StructLayout(LayoutKind.Sequential)]
        struct SIGNER_CERT_STORE_INFO { public uint cbSize; public IntPtr pSigningCert; public uint dwCertPolicy; public IntPtr hCertStore; }

        [StructLayout(LayoutKind.Sequential)]
        struct SIGNER_CERT { public uint cbSize; public uint dwCertChoice; public IntPtr pCertStoreInfo; public IntPtr hwnd; }

        [StructLayout(LayoutKind.Sequential)]
        struct SIGNER_SIGNATURE_INFO { public uint cbSize; public uint algidHash; public uint dwAttrChoice; public IntPtr pAttrAuthcode; public IntPtr psAuthenticated; public IntPtr psUnauthenticated; }

        // pszTimestampAlgorithmOid es una cadena ANSI con el OID del hash del
        // sello (no un ALG_ID): pasar un número hace que el proceso muera con
        // 0xC0000005.
        [DllImport("mssign32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        static extern int SignerSignEx2(uint dwFlags, IntPtr pSubjectInfo, IntPtr pSignerCert, IntPtr pSignatureInfo,
                                        IntPtr pProviderInfo, uint dwTimestampFlags,
                                        [MarshalAs(UnmanagedType.LPStr)] string pszTimestampAlgorithmOid,
                                        string pwszHttpTimeStamp, IntPtr psRequest, IntPtr pSipData,
                                        out IntPtr ppSignerContext, IntPtr pCryptoPolicy, IntPtr pReserved);

        [DllImport("mssign32.dll", ExactSpelling = true)]
        static extern int SignerFreeSignerContext(IntPtr pSignerContext);

        const uint SIGNER_SUBJECT_FILE = 1;
        const uint SIGNER_CERT_STORE = 2;
        const uint SIGNER_CERT_POLICY_CHAIN_NO_ROOT = 8;   // la cadena, sin la raíz
        const uint SIGNER_NO_ATTR = 0;
        const uint CALG_SHA_256 = 0x0000800c;
        const uint SIGNER_TIMESTAMP_RFC3161 = 2;
        const string SZOID_NIST_SHA256 = "2.16.840.1.101.3.4.2.1";

        static IntPtr Put(object value) {
            IntPtr p = Marshal.AllocHGlobal(Marshal.SizeOf(value));
            Marshal.StructureToPtr(value, p, false);
            return p;
        }

        // Firma el archivo en el sitio con SHA-256 y, si hay URL, sello
        // RFC 3161 SHA-256. certContext = X509Certificate2.Handle
        // (PCCERT_CONTEXT). Devuelve el HRESULT (0 = bien).
        public static int Sign(string path, IntPtr certContext, string timestampUrl) {
            IntPtr name = IntPtr.Zero, index = IntPtr.Zero, file = IntPtr.Zero, subject = IntPtr.Zero;
            IntPtr store = IntPtr.Zero, cert = IntPtr.Zero, signature = IntPtr.Zero, context = IntPtr.Zero;
            try {
                name = Marshal.StringToHGlobalUni(path);
                index = Marshal.AllocHGlobal(4);
                Marshal.WriteInt32(index, 0);

                SIGNER_FILE_INFO fi = new SIGNER_FILE_INFO();
                fi.cbSize = (uint)Marshal.SizeOf(typeof(SIGNER_FILE_INFO));
                fi.pwszFileName = name;
                file = Put(fi);

                SIGNER_SUBJECT_INFO si = new SIGNER_SUBJECT_INFO();
                si.cbSize = (uint)Marshal.SizeOf(typeof(SIGNER_SUBJECT_INFO));
                si.pdwIndex = index;
                si.dwSubjectChoice = SIGNER_SUBJECT_FILE;
                si.pSignerFileInfo = file;
                subject = Put(si);

                SIGNER_CERT_STORE_INFO csi = new SIGNER_CERT_STORE_INFO();
                csi.cbSize = (uint)Marshal.SizeOf(typeof(SIGNER_CERT_STORE_INFO));
                csi.pSigningCert = certContext;
                csi.dwCertPolicy = SIGNER_CERT_POLICY_CHAIN_NO_ROOT;
                store = Put(csi);

                SIGNER_CERT sc = new SIGNER_CERT();
                sc.cbSize = (uint)Marshal.SizeOf(typeof(SIGNER_CERT));
                sc.dwCertChoice = SIGNER_CERT_STORE;
                sc.pCertStoreInfo = store;
                cert = Put(sc);

                SIGNER_SIGNATURE_INFO ssi = new SIGNER_SIGNATURE_INFO();
                ssi.cbSize = (uint)Marshal.SizeOf(typeof(SIGNER_SIGNATURE_INFO));
                ssi.algidHash = CALG_SHA_256;
                ssi.dwAttrChoice = SIGNER_NO_ATTR;
                signature = Put(ssi);

                bool stamp = !string.IsNullOrEmpty(timestampUrl);
                return SignerSignEx2(0, subject, cert, signature, IntPtr.Zero,
                                     stamp ? SIGNER_TIMESTAMP_RFC3161 : 0u,
                                     stamp ? SZOID_NIST_SHA256 : null,
                                     stamp ? timestampUrl : null,
                                     IntPtr.Zero, IntPtr.Zero, out context, IntPtr.Zero, IntPtr.Zero);
            }
            finally {
                if (context != IntPtr.Zero) SignerFreeSignerContext(context);
                foreach (IntPtr p in new IntPtr[] { signature, cert, store, subject, file, index, name }) {
                    if (p != IntPtr.Zero) Marshal.FreeHGlobal(p);
                }
            }
        }
    }
}
'@
}

<#
    Qué quiere decir un HRESULT de SignerSignEx2, en una frase. Los de red
    llegan como 0x80072xxx (WinINet/WinHTTP).
#>
function Get-SigningErrorHint {
    param([string]$HResult)
    switch ($HResult) {
        '0x80072EE7' { 'no se resuelve el nombre del servidor de sellado (¿hay red? ¿DNS?)' }
        '0x80072EFD' { 'no se puede conectar con el servidor de sellado (¿hay red? ¿cortafuegos o proxy?)' }
        '0x80072EE2' { 'el servidor de sellado no contesta a tiempo' }
        '0x80070020' { 'el .exe está en uso por otro proceso (¿el antivirus?)' }
        '0x80070005' { 'acceso denegado al .exe (¿el antivirus lo tiene abierto?)' }
        '0x80090016' { 'no se puede abrir la clave privada (¿permisos? en LocalMachine hace falta ser administrador)' }
        '0x8009000D' { 'no se puede abrir la clave privada' }
        '0x80092004' { 'el sello de tiempo no se pudo añadir (respuesta del servidor no válida)' }
        default {
            if ($HResult -like '0x8010*') { 'fallo de la tarjeta o el token USB del certificado (¿está conectado? ¿PIN?)' }
            else { 'Windows rechazó la firma' }
        }
    }
}

<#
    Espera a que nadie más tenga abierto el archivo. Un .exe recién escrito
    -por ps2exe o por la firma- lo abre el antivirus para analizarlo, y
    mientras tanto firmarlo o leer su firma falla con "acceso denegado" o
    "en uso por otro proceso" (visto el 2026-11-09 con Bitdefender: más de
    medio minuto). Devuelve $true si quedó libre a tiempo.
#>
function Wait-FileUnlocked {
    param([Parameter(Mandatory)][string]$Path, [int]$TimeoutSeconds = 90)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
        try {
            $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
            $fs.Close()
            return $true
        }
        catch {
            # En uso o acceso denegado mientras lo analizan: se espera.
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) { return $false }
            Start-Sleep -Milliseconds 500
        }
    }
}

<#
    Get-AuthenticodeSignature tras esperar a que el archivo esté libre. Si lo
    pilla a medias, escribe un error y devuelve un objeto incompleto (sin el
    certificado del sello): por eso -ErrorAction Stop y se reintenta.
    Devuelve $null si no hubo forma de leerlo.
#>
function Read-AuthenticodeSignature {
    param([Parameter(Mandatory)][string]$Path, [int]$Attempts = 5)
    for ($i = 1; $i -le $Attempts; $i++) {
        $null = Wait-FileUnlocked -Path $Path
        try { return (Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop) }
        catch { Start-Sleep -Seconds 2 }
    }
    $null
}

<#
    Firma el archivo y lo verifica:
      1. SignerSignEx2: SHA-256, cadena sin la raíz y, si hay
         -TimestampServer, sello RFC 3161 SHA-256 en la misma llamada.
         Reintenta un par de veces si falla la red (los servidores públicos
         de sellado fallan a ratos); los demás errores no se reintentan.
      2. Get-AuthenticodeSignature: que la firma esté, sea de este
         certificado, lleve sello si se pidió, y qué dice Windows de ella.

    Devuelve un objeto con el resultado; quien llama decide qué es fallo.
    Outcome:
        trusted               firmado (y sellado si se pidió) y Windows lo da por Valid
        untrusted-selfsigned  firmado con un certificado autofirmado que este
                              equipo no reconoce: la firma está, pero no vale
                              para distribuir
        untrusted             firmado, pero Windows no lo da por bueno
                              (cadena, revocación...)
        failed                no se ha firmado (el .exe se queda sin firma)
    Nunca lanza.
#>
function Invoke-CodeSigning {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$TimestampServer,
        [ValidateRange(1, 10)][int]$Attempts = 3
    )

    $result = [PSCustomObject]@{
        Outcome            = 'failed'
        Status             = $null
        StatusMessage      = $null
        SelfSigned         = ($Certificate.Subject -eq $Certificate.Issuer)
        Timestamped        = $false
        TimestampAuthority = $null
        HResult            = $null
        Error              = $null
    }

    if (-not $PSCmdlet.ShouldProcess($Path, "firmar con $($Certificate.Subject)")) {
        $result.Error = 'simulado (-WhatIf)'
        return $result
    }

    try { Initialize-CodeSigningInterop }
    catch {
        $result.Error = "no se pudo preparar la llamada a mssign32.dll: $($_.Exception.Message)"
        return $result
    }

    # 1. Firmar (y sellar).
    $hr = 0
    for ($i = 1; $i -le $Attempts; $i++) {
        if (-not (Wait-FileUnlocked -Path $Path)) {
            $result.Error = "no se puede abrir $Path para firmarlo (¿no existe, o lo tiene bloqueado otro proceso, p. ej. el antivirus?)"
            return $result
        }
        $hr = [OptimizadorPCBuild.AuthenticodeSigner]::Sign($Path, $Certificate.Handle, $TimestampServer)
        if ($hr -eq 0) { break }
        $hex = '0x{0:X8}' -f $hr
        $deRed = $hex -like '0x80072*'
        if (-not $deRed -or $i -eq $Attempts) {
            $result.HResult = $hex
            $result.Error = '{0} ({1})' -f (Get-SigningErrorHint $hex), $hex
            return $result
        }
        Start-Sleep -Seconds (2 * $i)
    }

    # 2. Verificar. SignerSignEx2 puede decir que bien y aun así lo que
    # cuenta es lo que se relee del archivo.
    $sig = Read-AuthenticodeSignature -Path $Path
    if ($null -eq $sig) {
        $result.Error = "no se puede releer la firma de $Path (¿lo ha bloqueado o retirado el antivirus?)"
        return $result
    }
    $result.Status = [string]$sig.Status
    $result.StatusMessage = $sig.StatusMessage
    if ($null -ne $sig.TimeStamperCertificate) {
        $result.Timestamped = $true
        $result.TimestampAuthority = $sig.TimeStamperCertificate.Subject
    }

    if ($null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -ne $Certificate.Thumbprint) {
        $result.Error = 'tras firmar, el archivo no lleva la firma de este certificado'
    }
    elseif ($sig.Status -eq 'HashMismatch') {
        $result.Error = 'la firma no corresponde al contenido del archivo (HashMismatch)'
    }
    elseif ($TimestampServer -and -not $result.Timestamped) {
        $result.Error = 'la firma está pero sin el sello de tiempo que se pidió'
    }
    elseif ($sig.Status -eq 'Valid') {
        $result.Outcome = 'trusted'
    }
    elseif ($result.SelfSigned) {
        $result.Outcome = 'untrusted-selfsigned'
    }
    else {
        $result.Outcome = 'untrusted'
    }
    $result
}
