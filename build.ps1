<#
    build.ps1
    ---------
    1) Empaqueta main.ps1 + todo ui/ + todo core/ + ui/MainWindow.xaml
       en un solo script (_combined.ps1), porque ps2exe solo admite un
       archivo de entrada y el .exe final debe ser portable (un solo
       archivo, sin depender de las carpetas al lado).
    2) Compila ese script combinado a OptimizadorPC.exe con ps2exe.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\build.ps1

    Solo entiende DOS marcadores de main.ps1:

        # @@EMBED_DIR:carpeta@@ ... # @@ENDEMBED@@   una carpeta entera
        # @@EMBED_XAML:ruta@@   ... # @@ENDEMBED@@   el XAML

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
#>

param([switch]$CombineOnly, [string]$OutFile)

$root = $PSScriptRoot
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
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host 'Instalando módulo ps2exe (solo usuario actual, sin admin)...' -ForegroundColor Cyan
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe

$outPath = Join-Path $root 'OptimizadorPC.exe'

Invoke-ps2exe `
    -inputFile $combinedPath `
    -outputFile $outPath `
    -noConsole `
    -requireAdmin `
    -title 'Optimizador PC' `
    -description 'Optimizador de Windows 11 Pro' `
    -company 'Personal' `
    -version '1.0.0.0' `
    -product 'Optimizador PC'

Write-Host "Listo: $outPath" -ForegroundColor Green
Write-Host 'Ese .exe es portable: cópialo donde quieras, no necesita instalación ni la carpeta ui/.' -ForegroundColor Green
