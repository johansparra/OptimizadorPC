# ============================================================
# core/Registry/CategoryState.ps1
# Vuelca en los ajustes lo que hay de verdad en el equipo.
#
# Es el puente entre core/Registry/Reader.ps1 (lee el sistema) y los
# datos de ui/Data/Categories/: recorre las claves declaradas en el
# campo -Registry de cada ajuste y rellena su Current.
#
# Sigue sin saber de interfaz. Para poder enseñar una barra de
# progreso acepta un scriptblock -OnProgress al que va avisando;
# quién lo pinte es asunto de quien llame.
#
# SOLO LECTURA: aquí no se escribe nada en el registro.
# ============================================================

<#
    Lee del equipo todas las claves de una categoría y actualiza
    en el sitio los campos de cada una:

        Current   texto ya formateado, o $null si no se pudo leer
        State     'read' | 'missing' | 'denied' | 'badpath'

    El Current que venga escrito en ui/Data/Categories/ se ignora: el
    valor bueno es el del equipo.

    Una categoría cuyos ajustes no declaren claves -hoy, todas
    menos Regedit- sale por la puerta de atrás sin hacer nada, así
    que se puede llamar siempre sin preguntar de cuál se trata.

        Update-CategoryRegistryState -Category $cat -OnProgress {
            param($Done, $Total) Set-ProgressStrip ...
        }

    Devuelve cuántas claves ha leído.
#>
function Update-CategoryRegistryState {
    param(
        [Parameter(Mandatory)]$Category,
        [scriptblock]$OnProgress
    )

    $keys = New-Object System.Collections.Generic.List[object]
    foreach ($setting in @($Category.Items)) {
        foreach ($key in @($setting.Registry)) { $keys.Add($key) }
    }

    $total = $keys.Count
    if ($total -eq 0) { return 0 }

    # Cabecera del bloque en el registro de actividad: sin ella,
    # las lecturas de una sección y las de la siguiente saldrían
    # seguidas y no se sabría dónde empieza cada visita.
    Write-AppLog -Source 'registry' -Level 'info' -Status 'reading' `
        -Message $Category.Name -Detail "$total keys"

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $states = @{}

    $done = 0
    if ($OnProgress) { & $OnProgress $done $total }

    foreach ($key in $keys) {
        $result = Read-RegistryValue $key.Path $key.Name

        # Las claves de -Registry son hashtables, así que se
        # rellenan en el sitio y la tarjeta las lee tal cual.
        $key['State'] = $result.State
        if ($result.State -eq 'read') {
            $key['Current'] = Format-RegistryValue $result.Value $result.Kind $key.Display
        }
        else {
            $key['Current'] = $null
        }

        $states[$result.State] = 1 + [int]$states[$result.State]

        $done++
        if ($OnProgress) { & $OnProgress $done $total }
    }

    $watch.Stop()

    # Resumen: cuántas de cada clase y cuánto ha costado. Es lo
    # que dice de un vistazo si una sección va lenta o si hay
    # claves que no se están pudiendo leer.
    $summary = ($states.Keys | Sort-Object | ForEach-Object { "$($states[$_]) $_" }) -join ' - '
    Write-AppLog -Source 'registry' -Level 'info' -Status 'done' `
        -Message $Category.Name `
        -Detail ('{0} - {1:N1} ms' -f $summary, $watch.Elapsed.TotalMilliseconds)

    $total
}

# Cuántas claves declara una categoría. La vista lo usa para saber
# si merece la pena enseñar la barra antes de ponerse a leer.
function Get-CategoryRegistryKeyCount {
    param([Parameter(Mandatory)]$Category)

    $n = 0
    foreach ($setting in @($Category.Items)) { $n += @($setting.Registry).Count }
    $n
}
