<#
    .claude/hooks/Normalize-PsEncoding.ps1

    Deja todo .ps1 y .xaml que se escriba en UTF-8 CON BOM y con
    saltos CRLF. Es la regla 3 de CLAUDE.md aplicada sola.

    Por qué existe: Windows PowerShell 5.1 -el intérprete del .exe-
    lee un script sin BOM como ANSI, y los acentos de los
    comentarios se vuelven mojibake hasta que el parser muere con
    "Token inesperado". pwsh 7 no se entera, así que el archivo
    parsea en 7 y revienta en 5.1. Las herramientas de edición y
    los heredoc de Bash escriben sin BOM y con LF, de modo que
    hasta ahora había que arreglarlo a mano en cada archivo nuevo.

    Se engancha como hook PostToolUse de Write|Edit en
    .claude/settings.local.json. Recibe por la entrada estándar el
    JSON de la llamada y saca la ruta de tool_input.file_path.

    NO toca nada más: si el archivo ya tiene BOM y CRLF, sale sin
    escribir, para no marcarlo como modificado sin motivo.
#>

$ErrorActionPreference = 'Stop'

try {
    $json = [Console]::In.ReadToEnd()
    if (-not $json) { exit 0 }

    $payload = $json | ConvertFrom-Json
    $ruta = $payload.tool_input.file_path
    if (-not $ruta) { $ruta = $payload.tool_response.filePath }
    if (-not $ruta) { exit 0 }

    if ($ruta -notmatch '\.(ps1|xaml)$') { exit 0 }
    # Generado por build.ps1 y sobrescrito entero en cada build.
    if ($ruta -match '[\/]build[\/]_combined\.ps1$') { exit 0 }
    if (-not (Test-Path -LiteralPath $ruta)) { exit 0 }

    $bytes = [System.IO.File]::ReadAllBytes($ruta)
    $tieneBom = $bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

    # ReadAllText sin encoding detecta el BOM y asume UTF-8 si no lo hay,
    # que es justo lo que escriben las herramientas de edición.
    $texto = [System.IO.File]::ReadAllText($ruta)
    $normal = $texto -replace "`r`n", "`n" -replace "`n", "`r`n"

    if ($tieneBom -and $normal -eq $texto) { exit 0 }

    [System.IO.File]::WriteAllText($ruta, $normal, (New-Object System.Text.UTF8Encoding($true)))

    $arreglos = @()
    if (-not $tieneBom)        { $arreglos += 'BOM' }
    if ($normal -ne $texto)    { $arreglos += 'CRLF' }
    $aviso = @{
        systemMessage = ('{0}: normalizado a UTF-8 con {1}' -f (Split-Path $ruta -Leaf), ($arreglos -join ' + '))
    }
    $aviso | ConvertTo-Json -Compress
}
catch {
    # Un hook que falla no puede tumbar la edición: si algo sale
    # mal, las pruebas de tests/Source/Rules.Tests.ps1 siguen
    # cazando el BOM que falte.
    exit 0
}

exit 0
