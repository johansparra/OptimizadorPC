# ============================================================
# core/Registry/CategoryState.ps1
# Vuelca en los ajustes lo que hay de verdad en el equipo.
#
# Es el puente entre core/Registry/Reader.ps1 (lee el sistema) y los
# datos de ui/Data/Categories/: recorre las claves declaradas en el
# campo -Registry de cada ajuste y rellena su Current. Igual con los
# servicios (-Service, core/Services/) y las tareas programadas
# (-ScheduledTask, core/ScheduledTasks/): ver Update-SettingTargetState.
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
        Status    'optimized' | 'factory' | 'custom' | 'unknown'

    Y, con sus claves ya leídas, deja también el Status de cada
    ajuste: en qué estado ha quedado comparando lo leído con lo
    declarado (ver core/Registry/SettingStatus.ps1).

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

    $total = Get-CategoryRegistryKeyCount $Category
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

    # Se recorre ajuste por ajuste -y no una lista plana de claves-
    # porque en cuanto están leídas las suyas hay que decidir en qué
    # estado ha quedado ese ajuste.
    foreach ($setting in @($Category.Items)) {
        foreach ($target in @(Get-SettingTargets $setting)) {
            $state = Update-SettingTargetState $target
            $states[$state] = 1 + [int]$states[$state]

            $done++
            if ($OnProgress) { & $OnProgress $done $total }
        }

        # Recomendado / de fábrica / a medida, comparando lo leído con
        # lo declarado (core/Registry/SettingStatus.ps1). Va aquí y no en la
        # interfaz para que se recalcule SIEMPRE que se lee: entrar en
        # la sección y refrescar pasan los dos por este mismo sitio.
        Update-SettingStatus $setting | Out-Null

        # Y la línea de evaluación en el log: tipo, leído, recomendado,
        # de fábrica y estado. Justo después de decidirlo.
        Write-SettingEvalLog $setting
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

<#
    Lee UN objetivo de un ajuste (Get-SettingTargets) por su mecanismo
    y deja State y Current en su entrada. Devuelve el State.

        registry  Read-RegistryValue          (core/Registry/Reader.ps1)
        service   Update-ServiceEntryState    (core/Services/)
        task      Update-ScheduledTaskEntryState (core/ScheduledTasks/)

    Cada lectura deja su línea en el log. La usan este archivo al
    entrar en la sección y core/Registry/SettingApply.ps1 al releer
    tras un cambio: un solo camino para las dos cosas.
#>
function Update-SettingTargetState {
    param($Target)

    if (-not $Target -or -not $Target.Entry) { return 'unknown' }
    $key = $Target.Entry

    switch ($Target.Kind) {
        'service' { return (Update-ServiceEntryState $key) }
        'task'    { return (Update-ScheduledTaskEntryState $key) }
    }

    $result = Read-RegistryValue $key.Path $key.Name

    # Las claves de -Registry son hashtables, así que se rellenan en
    # el sitio y la tarjeta las lee tal cual.
    $key['State'] = $result.State
    if ($result.State -eq 'read') {
        $key['Current'] = Format-RegistryValue $result.Value $result.Kind $key.Display
    }
    else {
        $key['Current'] = $null
    }
    $result.State
}

# Cuántos objetivos declara una categoría: claves del registro,
# servicios y tareas programadas (el nombre es de cuando solo había
# claves). La vista lo usa para saber si hay algo que leer y si
# merece la pena enseñar la barra antes de ponerse a ello.
function Get-CategoryRegistryKeyCount {
    param([Parameter(Mandatory)]$Category)

    $n = 0
    foreach ($setting in @($Category.Items)) { $n += @(Get-SettingTargets $setting).Count }
    $n
}

<#
    ¿Qué clases de objetivo hay en una categoría? 'registry', 'service',
    'task', sin repetir. La interfaz lo usa para decir "leyendo el
    registro" o "leyendo servicios y tareas" sin conocer la sección.
#>
function Get-CategoryTargetKinds {
    param($Category)

    if (-not $Category) { return @() }
    $kinds = @{}
    foreach ($setting in @($Category.Items)) {
        foreach ($t in @(Get-SettingTargets $setting)) { $kinds[$t.Kind] = $true }
    }
    @($kinds.Keys | Sort-Object)
}
