# ============================================================
# AppSettings.ps1
# Preferencias guardadas entre sesiones.
#
# Se escriben en un JSON dentro del perfil del usuario:
#     %APPDATA%\OptimizadorPC\settings.json
#
# Ahí y no junto al .exe a propósito: el ejecutable es portable
# y puede acabar en una carpeta sin permisos de escritura.
#
# Guardar una preferencia nueva no requiere tocar este archivo:
#     Set-AppSetting 'MiOpcion' $valor
#     Get-AppSetting 'MiOpcion' -Default 'algo'
# ============================================================

$AppSettingsPath = Join-Path $env:APPDATA 'OptimizadorPC\settings.json'
$AppSettings = @{}

# Lee el archivo si existe. Un JSON corrupto no debe impedir que
# el programa arranque: se ignora y se usan los valores por defecto.
function Import-AppSettings {
    if (-not (Test-Path $AppSettingsPath)) { return }
    try {
        $json = Get-Content -Path $AppSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($property in $json.PSObject.Properties) {
            $script:AppSettings[$property.Name] = $property.Value
        }
    }
    catch {
        $script:AppSettings = @{}
    }
}

function Save-AppSettings {
    try {
        $folder = Split-Path -Parent $AppSettingsPath
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        }
        $AppSettings | ConvertTo-Json | Set-Content -Path $AppSettingsPath -Encoding UTF8
        $true
    }
    catch {
        # Sin permisos o disco lleno: la sesión sigue funcionando,
        # simplemente no se recordará la preferencia.
        $false
    }
}

function Get-AppSetting {
    param([Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($AppSettings.ContainsKey($Name)) { $AppSettings[$Name] } else { $Default }
}

function Set-AppSetting {
    param([Parameter(Mandatory)][string]$Name, $Value)
    $script:AppSettings[$Name] = $Value
    Save-AppSettings | Out-Null
}

function Get-AppSettingsPath { $AppSettingsPath }
