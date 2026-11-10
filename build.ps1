<#
    build.ps1
    ---------
    1) Empaqueta main.ps1 + todo ui/ + todo core/ + ui/MainWindow.xaml
       en un solo script (build/_combined.ps1), porque ps2exe solo
       admite un archivo de entrada y el .exe final debe ser portable
       (un solo archivo, sin depender de las carpetas al lado).
    2) Compila ese script combinado a build/OptimizadorPC.exe con ps2exe.

    Todo lo que build.ps1 produce vive en build/: el script combinado
    intermedio (generado, NO se versiona) y el .exe (ese sí). El .exe
    sigue siendo portable: cópialo fuera de build/ y funciona igual.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\build.ps1

    Solo entiende TRES marcadores de main.ps1:

        # @@EMBED_DIR:carpeta@@    ... # @@ENDEMBED@@   una carpeta entera de .ps1
        # @@EMBED_GUIDES:carpeta@@ ... # @@ENDEMBED@@   los .md de las guías
        # @@EMBED_XAML:ruta@@      ... # @@ENDEMBED@@   el XAML

    Todo lo demas se copia tal cual. No hay forma de incluir un
    archivo suelto: si necesitas uno nuevo, va dentro de una de las
    carpetas que ya se incrustan.

    -CombineOnly hace el paso 1 y para. Sirve para comprobar que
    todo sigue entrando en el paquete sin esperar a ps2exe, que es
    lo lento; lo usa tests/Source/Rules.Tests.ps1 para verificar
    que el script combinado parsea antes de compilar nada.

    -OutFile cambia donde se deja el script combinado. Las pruebas
    lo mandan a un archivo por proceso, para que las dos suites
    puedan correr a la vez sin pisarse el mismo archivo.

    3) FIRMA (opcional). Con un certificado de firma de código,
       firma el .exe con Authenticode (SHA-256), le pone un sello
       de tiempo RFC 3161 y lo verifica:

        powershell -ExecutionPolicy Bypass -File .\build.ps1 -CertificateThumbprint <huella>

       La huella también puede venir en la variable de entorno
       OPTIMIZADORPC_SIGN_THUMBPRINT (para la CI). El certificado
       se busca en Cert:\CurrentUser\My y Cert:\LocalMachine\My, y
       solo vale uno con el uso "Firma de código", clave privada y
       en vigor. -TimestampServer (o OPTIMIZADORPC_TIMESTAMP_URL)
       cambia el servidor de sellado; por defecto DigiCert. El
       sello necesita red. -NoTimestamp firma sin sello (la firma
       deja de valer cuando caduque el certificado: no lo
       distribuyas así).

       Sin certificado compila sin firmar, como siempre, y lo dice
       en una línea. Si se pidió firmar y algo falla -certificado
       que no vale, firma que no se pone, sello que no llega-,
       termina con código 1 y dice qué ha quedado en el .exe (si
       el sello no llega, NO se firma: firma y sello van en la
       misma llamada). Un certificado autofirmado firma, pero
       avisa de que no sirve para distribuir.
       El trabajo de firmar vive en tools/CodeSigning.ps1, fuera
       de las capas: no entra en el .exe. Firma como signtool
       (SignerSignEx2), no con Set-AuthenticodeSignature: ese
       solo sabe poner el sello legado, no el RFC 3161 (el porqué,
       en la cabecera de tools/CodeSigning.ps1).

       Para probar el flujo sin comprar nada:
       tools/New-DevSigningCert.ps1 (autofirmado, NO distribuible).
#>

param(
    [switch]$CombineOnly,
    [string]$OutFile,
    [string]$CertificateThumbprint,
    [string]$TimestampServer,
    [switch]$NoTimestamp
)

$root = $PSScriptRoot

# ---- 0. Firma: se resuelve ANTES de compilar ----
# Un certificado mal puesto tiene que fallar al empezar, no tras
# esperar a ps2exe. Sin huella no se carga nada de esto.
$signCert = $null
$timestampUrl = $null
if (-not $CombineOnly) {
    $thumb = if ($CertificateThumbprint) { $CertificateThumbprint } else { $env:OPTIMIZADORPC_SIGN_THUMBPRINT }
    if ($thumb) {
        . (Join-Path $root 'tools\CodeSigning.ps1')
        $resuelto = Resolve-CodeSigningCertificate -Thumbprint $thumb
        if ($resuelto.Problem) {
            Write-Host "FIRMA: $($resuelto.Problem)." -ForegroundColor Red
            if ($resuelto.Usable.Count -gt 0) {
                Write-Host '  Certificados de firma de código que sí valdrían:' -ForegroundColor Red
                foreach ($u in $resuelto.Usable) {
                    Write-Host ('    {0}  {1}  (caduca {2:yyyy-MM-dd}, {3})' -f $u.Thumbprint, $u.Subject, $u.NotAfter, $u.Store) -ForegroundColor Red
                }
            }
            else {
                Write-Host '  No hay ningún certificado de firma de código utilizable en este equipo.' -ForegroundColor Red
            }
            Write-Host 'No se ha compilado nada.' -ForegroundColor Red
            exit 1
        }
        $signCert = $resuelto.Certificate

        if (-not $NoTimestamp) {
            $timestampUrl = if ($TimestampServer) { $TimestampServer }
                            elseif ($env:OPTIMIZADORPC_TIMESTAMP_URL) { $env:OPTIMIZADORPC_TIMESTAMP_URL }
                            else { 'http://timestamp.digicert.com' }
            $uri = $null
            if (-not [System.Uri]::TryCreate($timestampUrl, [System.UriKind]::Absolute, [ref]$uri) -or
                $uri.Scheme -notin @('http', 'https')) {
                Write-Host "FIRMA: '$timestampUrl' no es una URL http/https de servidor de sellado. No se ha compilado nada." -ForegroundColor Red
                exit 1
            }
        }
        Write-Host ('Se firmará con: {0} ({1}, {2})' -f $signCert.Subject, $signCert.Thumbprint, $resuelto.Store) -ForegroundColor Cyan
    }
}
$buildDir = Join-Path $root 'build'
New-Item -Path $buildDir -ItemType Directory -Force | Out-Null

function Get-IncludedContent {
    param([string]$RelativePath)
    Get-Content -Path (Join-Path $root $RelativePath) -Raw
}

# ---- 1. Leer main.ps1 línea por línea y resolver marcadores ----
$mainLines = Get-Content -Path (Join-Path $root 'main.ps1')
$output = New-Object System.Collections.Generic.List[string]

$i = 0
while ($i -lt $mainLines.Count) {
    $line = $mainLines[$i]

    # Carpeta completa: se insertan todos los .ps1 que contenga,
    # SUBCARPETAS INCLUIDAS, por orden de ruta. Es lo que permite que
    # anadir una seccion, un componente o una vista no obligue a tocar
    # main.ps1 ni este script.
    #
    # El orden tiene que ser el mismo que usan main.ps1 y
    # tests/Harness/AppHost.ps1: los tres ordenan por ruta completa.
    if ($line -match '^\s*# @@EMBED_DIR:(.+)@@\s*$') {
        $dirRel = $Matches[1]
        $dirPath = Join-Path $root ($dirRel -replace '/', '\')
        if (-not (Test-Path $dirPath)) { throw "build.ps1: no existe la carpeta '$dirRel' referenciada en main.ps1" }

        $files = Get-ChildItem -Path $dirPath -Recurse -Filter '*.ps1' | Sort-Object FullName
        if ($files.Count -eq 0) { Write-Host "  aviso: la carpeta $dirRel no tiene ningun .ps1" -ForegroundColor Yellow }

        foreach ($file in $files) {
            # Ruta relativa a la carpeta incrustada, con barras normales,
            # para que el marcador diga 'ui/Components/Cards/SettingCard.ps1'
            # y no solo el nombre del archivo.
            $dentro = $file.FullName.Substring($dirPath.Length).TrimStart('\') -replace '\\', '/'
            $rel = "$dirRel/$dentro"
            $output.Add("# ---- inicio incluido: $rel ----")
            $output.Add((Get-Content -Path $file.FullName -Raw))
            $output.Add("# ---- fin incluido: $rel ----")
        }
        Write-Host ("  {0,-18} {1} archivo(s)" -f $dirRel, $files.Count) -ForegroundColor DarkGray

        # saltar el foreach original que recorria la carpeta en desarrollo
        while ($i -lt $mainLines.Count -and $mainLines[$i] -notmatch '^\s*# @@ENDEMBED@@\s*$') { $i++ }
        $i++
        continue
    }

    # Las guías: cada .md de la carpeta (sin subcarpetas, por nombre,
    # igual que Import-GuideFolder) se convierte en una llamada a
    # Register-Guide con el texto en Base64. Base64 y no un aquí-string
    # porque el .md es texto libre: un '@ a principio de línea cerraría
    # el aquí-string y el .exe no arrancaría.
    if ($line -match '^\s*# @@EMBED_GUIDES:(.+)@@\s*$') {
        $dirRel = $Matches[1]
        $dirPath = Join-Path $root ($dirRel -replace '/', '\')
        $guides = @()
        if (Test-Path $dirPath) { $guides = @(Get-ChildItem -Path $dirPath -Filter '*.md' -File | Sort-Object FullName) }

        foreach ($guide in $guides) {
            $b64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($guide.FullName))
            $name = $guide.Name -replace "'", "''"
            $output.Add("# ---- guía incluida: $dirRel/$($guide.Name) ----")
            $output.Add("Register-Guide -FileName '$name' -Markdown (ConvertFrom-GuideBase64 '$b64')")
        }
        Write-Host ("  {0,-18} {1} guía(s)" -f $dirRel, $guides.Count) -ForegroundColor DarkGray

        while ($i -lt $mainLines.Count -and $mainLines[$i] -notmatch '^\s*# @@ENDEMBED@@\s*$') { $i++ }
        $i++
        continue
    }

    if ($line -match '^\s*# @@EMBED_XAML:(.+)@@\s*$') {
        $xamlRel = $Matches[1]
        $xamlContent = Get-IncludedContent $xamlRel
        $output.Add('$xamlString = @''')
        $output.Add($xamlContent)
        $output.Add('''@')
        $output.Add('[xml]$xamlXml = $xamlString')
        # saltar hasta @@ENDEMBED@@ (líneas originales que leían el archivo)
        while ($i -lt $mainLines.Count -and $mainLines[$i] -notmatch '^\s*# @@ENDEMBED@@\s*$') { $i++ }
        $i++
        continue
    }

    $output.Add($line)
    $i++
}

$combinedPath = if ($OutFile) { $OutFile } else { Join-Path $buildDir '_combined.ps1' }
# UTF-8 CON BOM obligatorio: Windows PowerShell 5.1 lee los scripts sin BOM
# como ANSI y destroza los emoji/simbolos (el parser revienta).
# Set-Content -Encoding UTF8 escribe BOM en 5.1 pero NO en PowerShell 7,
# asi que se fuerza el BOM explicitamente.
[System.IO.File]::WriteAllLines($combinedPath, $output, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "Script combinado generado en: $combinedPath" -ForegroundColor Cyan

if ($CombineOnly) { return }

# ---- 2. Compilar con ps2exe ----
# Versión FIJADA a propósito. Sin -RequiredVersion, cada compilación
# podría traer una versión distinta del compilador; sin -Repository,
# si el equipo tiene otro repositorio de PowerShell registrado con
# prioridad, podría ganar el suyo. Las dos cosas son cadena de
# suministro: el .exe que se entrega lleva dentro el stub de ps2exe.
# Para subir de versión: cambia el número aquí, recompila y prueba.
$Ps2ExeVersion = '1.0.18'
if (-not (Get-Module -ListAvailable -Name ps2exe | Where-Object { $_.Version -eq [version]$Ps2ExeVersion })) {
    Write-Host "Instalando módulo ps2exe $Ps2ExeVersion (solo usuario actual, sin admin)..." -ForegroundColor Cyan
    Install-Module -Name ps2exe -RequiredVersion $Ps2ExeVersion -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -RequiredVersion $Ps2ExeVersion

# El .exe se deja en build/, junto al combinado que lo origina.
$outPath = Join-Path $buildDir 'OptimizadorPC.exe'

# Nombre y versión, de la MISMA fuente que enseña la aplicación
# (ui/Data/AppInfo.ps1). Windows pide cuatro números en la versión de
# un ejecutable; la del proyecto tiene tres, así que se añade el .0.
. (Join-Path $root 'ui\Data\AppInfo.ps1')
$exeVersion = '{0}.0' -f $AppInfo.Version

# Para saber si ps2exe ha dejado un .exe NUEVO: build/OptimizadorPC.exe
# está versionado, y si la compilación fallara sin lanzar se firmaría
# (o se probaría) el de antes sin que nadie lo notase.
$compileStart = Get-Date

Invoke-ps2exe `
    -inputFile $combinedPath `
    -outputFile $outPath `
    -noConsole `
    -requireAdmin `
    -title $AppInfo.Name `
    -description 'Optimizador de Windows 11 Pro' `
    -company 'Personal' `
    -version $exeVersion `
    -product $AppInfo.Name

$exeItem = Get-Item -LiteralPath $outPath -ErrorAction SilentlyContinue
if ($null -eq $exeItem -or $exeItem.LastWriteTime -lt $compileStart.AddSeconds(-2)) {
    Write-Host "ps2exe no ha dejado un .exe nuevo en $outPath." -ForegroundColor Red
    exit 1
}

Write-Host "Listo: $outPath" -ForegroundColor Green
Write-Host 'Ese .exe es portable: cópialo donde quieras, no necesita instalación ni la carpeta ui/.' -ForegroundColor Green

# ---- 3. Firmar (solo si se pidió) ----
if (-not $signCert) {
    Write-Host 'Sin firmar: no se ha indicado certificado (-CertificateThumbprint u OPTIMIZADORPC_SIGN_THUMBPRINT).' -ForegroundColor Yellow
    exit 0
}

$firma = Invoke-CodeSigning -Path $outPath -Certificate $signCert -TimestampServer $timestampUrl
$sha256 = (Get-FileHash -LiteralPath $outPath -Algorithm SHA256).Hash

if ($firma.Outcome -eq 'failed') {
    Write-Host "FIRMA: $($firma.Error)." -ForegroundColor Red
    $ahora = Get-AuthenticodeSignature -FilePath $outPath -ErrorAction SilentlyContinue
    $estado = if ($null -eq $ahora) { 'no se puede leer' } elseif ($ahora.Status -eq 'NotSigned') { 'SIN firma' } else { "firmado a medias ($($ahora.Status))" }
    Write-Host "  El .exe compilado se ha quedado $estado. No lo distribuyas." -ForegroundColor Red
    if ($timestampUrl) {
        Write-Host "  Sello pedido a $timestampUrl. Si es la red, repite; prueba otro con -TimestampServer, o -NoTimestamp si es a propósito." -ForegroundColor Red
    }
    exit 1
}

switch ($firma.Outcome) {
    'trusted' {
        Write-Host "Firmado: $($signCert.Subject). Windows lo da por válido (Valid)." -ForegroundColor Green
    }
    'untrusted-selfsigned' {
        Write-Host "Firmado con un certificado AUTOFIRMADO ($($signCert.Subject))." -ForegroundColor Yellow
        Write-Host "  La firma está, pero este equipo no confía en él ($($firma.Status): $($firma.StatusMessage))" -ForegroundColor Yellow
        Write-Host '  Sirve para probar el flujo; NO para distribuir: SmartScreen avisará igual que sin firma.' -ForegroundColor Yellow
    }
    'untrusted' {
        Write-Host "FIRMA: la firma está, pero Windows no la da por válida: $($firma.Status) - $($firma.StatusMessage)" -ForegroundColor Red
        Write-Host '  Con un certificado comprado esto no debería pasar (¿cadena incompleta? ¿revocado?). No lo distribuyas.' -ForegroundColor Red
        exit 1
    }
}

if ($firma.Timestamped) {
    Write-Host "  Sello de tiempo RFC 3161: $($firma.TimestampAuthority)" -ForegroundColor Green
}
else {
    Write-Host '  Sin sello de tiempo (-NoTimestamp): la firma dejará de valer cuando caduque el certificado. No lo distribuyas así.' -ForegroundColor Yellow
}
Write-Host "  SHA-256: $sha256" -ForegroundColor Green
exit 0
