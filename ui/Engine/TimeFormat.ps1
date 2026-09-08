# ============================================================
# TimeFormat.ps1
# El único sitio donde se decide cómo se enseña una hora en la
# interfaz: 24h ("18:45:03") o 12h ("6:45:03 PM"). Ambos con segundos.
#
# Lo gobierna la preferencia "Formato de hora" de la pantalla
# Settings (ui/Data/Preferences/40-TimeFormat.ps1), que se guarda
# como cualquier otra con Set-AppSetting.
#
# Hoy solo lo usa la etiqueta "Actualizado {hora}" de la cabecera
# del panel Regedit (ui/Views/CategoryDetailView.ps1). Cualquier
# campo de hora nuevo de la interfaz debe pasar por Format-AppTime
# en vez de llamar a .ToString(...) por su cuenta.
#
# El registro de actividad NO se rige por esto: su hora es texto
# técnico para copiar y pegar, y va siempre en 24h (ver
# core/Diagnostics/Log.ps1 y la regla del log en CLAUDE.md).
# ============================================================

# Clave en settings.json y valor de partida. '24' conserva el
# comportamiento que había antes de existir la opción.
$TimeFormatKey     = 'TimeFormat'
$TimeFormatDefault = '24'

# Patrón .NET por estilo. Los dos llevan segundos. Se formatea con
# cultura invariante para que "PM" sea "PM" -y no "p. m."- en un
# Windows en español, y para que el ejemplo de la opción salga igual
# en cualquier equipo.
$TimeFormatPatterns = @{
    '24' = 'HH:mm:ss'     # 18:45:03
    '12' = 'h:mm:ss tt'   # 6:45:03 PM
}

# El estilo elegido ('24' / '12'). Un valor desconocido -settings.json
# editado a mano- cae al de partida en vez de reventar el formateo.
function Get-AppTimeFormat {
    $value = [string](Get-AppSetting $TimeFormatKey -Default $TimeFormatDefault)
    if ($TimeFormatPatterns.ContainsKey($value)) { $value } else { $TimeFormatDefault }
}

<#
    Guarda el estilo y repinta la pantalla actual para que las horas
    ya dibujadas cambien en el sitio.

    El repintado se aplaza al Dispatcher por el mismo motivo que en
    Update-UiLanguage: esto se dispara desde el desplegable de
    Settings, que vive en la vista que Show-CurrentView va a
    reconstruir. Sin ventana (pruebas) solo guarda.
#>
function Set-AppTimeFormat {
    param([Parameter(Mandatory)][string]$Value)

    Set-AppSetting $TimeFormatKey $Value

    $window = Get-AppWindow
    if (-not $window) { return }
    $window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{ Show-CurrentView }) | Out-Null
}

<#
    Da formato a una hora/fecha según la preferencia "Formato de
    hora". Es la función que deben usar todos los textos de hora de
    la interfaz.

        Format-AppTime (Get-Date)            -> '18:45:03' o '6:45:03 PM'
        Format-AppTime $stamp -Format '12'   -> fuerza un estilo

    -Format se acepta para las pruebas y para casos puntuales; lo
    normal es no pasarlo y que use el de Settings.
#>
function Format-AppTime {
    param(
        [Parameter(Mandatory)][datetime]$Time,
        [string]$Format
    )

    if (-not $Format) { $Format = Get-AppTimeFormat }

    $pattern = $TimeFormatPatterns[$Format]
    if (-not $pattern) { $pattern = $TimeFormatPatterns[$TimeFormatDefault] }

    $Time.ToString($pattern, [System.Globalization.CultureInfo]::InvariantCulture)
}
