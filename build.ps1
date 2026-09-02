<#
    build.ps1
    ---------
    1) Empaqueta main.ps1 + ui/*.ps1 + ui/MainWindow.xaml en un solo
       script (_combined.ps1), porque ps2exe solo admite un archivo
       de entrada y el .exe final debe ser portable (un solo archivo,
       sin depender de la carpeta ui/ al lado).
    2) Compila ese script combinado a OptimizadorPC.exe con ps2exe.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\build.ps1
#>

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

    if ($line -match '^\s*\. \(Join-Path \$ScriptRoot ''ui\\(.+)''\)\s*$') {
        $relPath = 'ui/' + ($Matches[1] -replace '\\', '/')
        $output.Add("# ---- inicio incluido: $relPath ----")
        $output.Add((Get-IncludedContent $relPath))
        $output.Add("# ---- fin incluido: $relPath ----")
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

$combinedPath = Join-Path $buildDir '_combined.ps1'
# UTF-8 CON BOM obligatorio: Windows PowerShell 5.1 lee los scripts sin BOM
# como ANSI y destroza los emoji/simbolos (el parser revienta).
# Set-Content -Encoding UTF8 escribe BOM en 5.1 pero NO en PowerShell 7,
# asi que se fuerza el BOM explicitamente.
[System.IO.File]::WriteAllLines($combinedPath, $output, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "Script combinado generado en: $combinedPath" -ForegroundColor Cyan

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
