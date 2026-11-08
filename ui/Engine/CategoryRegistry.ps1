# ============================================================
# CategoryRegistry.ps1
# Registro de categorías.
#
# NO contiene datos ni decide qué se ve: solo el mecanismo.
#
#   ui/Data/Categories/<Nombre>.ps1  ->  QUÉ tiene cada sección
#   ui/Index/CategoryIndex.ps1        ->  CUÁLES se ven, en qué orden
#                                   y cuáles están bloqueadas
#
#   -> Añadir una sección  = crear su archivo en ui/Data/Categories/
#                            (aparece al final) y, si quieres
#                            colocarla, añadir su línea al índice
#   -> Ocultar una sección = Visible = $false en el índice
#   -> Bloquear una sección= Locked  = $true  en el índice
#   -> Reordenar           = mover su línea en el índice
# ============================================================

# Lista donde se van acumulando las categorías al cargarse.
$CategoryList = New-Object System.Collections.Generic.List[object]

<#
    Cuenta los ajustes marcados como nuevos y devuelve el texto del
    distintivo de la categoría: 'NEW 3', o $null si no hay ninguno
    (así la tarjeta no pinta un distintivo vacío).

    Nuevo = el ajuste lleva su propio Badge, sea cual sea su texto.
#>
function Get-NewBadgeText {
    param($Items)

    $count = @($Items | Where-Object { $_.Badge }).Count
    if ($count -eq 0) { return $null }
    "NEW $count"
}

<#
    Da de alta una categoría. Campos de la definición:

    Id           (string) Identificador corto y único: 'regedit', 'power'...
                          Es la clave con la que ui/Index/CategoryIndex.ps1 la coloca.
    Name         (string) Título visible.
    Icon         (string) Nombre de glifo del catálogo de Theme.ps1 ('Shield', 'Power'...).
    Accent       (string) Clave de color del tema para el icono ('Accent', 'Success', 'Warn').
    AccentSoft   (string) Clave de color del tema para el fondo del icono.
    Badge        (string) Distintivo rojo. Si NO se declara, se calcula solo:
                          cuenta los Items que llevan su propio -Badge y sale
                          'NEW <n>', o nada si no hay ninguno. Declararlo lo
                          fija a mano ('NEW 45'); ponerlo a '' lo apaga.
    Description  (string) Línea gris bajo el título.
    Recommended / Default / Custom / Total  (int)  Contadores de las píldoras.
    Items        (array)  Ajustes, creados con New-Setting.
    Steps        (array)  Pasos que se EJECUTAN, creados con New-CommandStep.
                          Una sección con Steps no enseña ajustes sino una
                          lista para marcar y un botón para correrla (ver
                          ui/Views/CategoryStepsView.ps1). Hoy: Internet
                          y Limpieza. Cada paso queda apuntado con el Id
                          de su sección (Source): es el apartado del log
                          en el que caen sus líneas.
#>
function Register-Category {
    param([Parameter(Mandatory)][hashtable]$Definition)

    # Valores por defecto: así una categoría mínima solo necesita
    # Id, Name, Icon, Description e Items.
    # Locked lo rellena el índice; aquí solo se reserva el campo.
    $defaults = @{
        Accent = 'Accent'; AccentSoft = 'AccentSoft'
        Recommended = 0; Default = 0; Custom = 0; Total = 0
        Items = @(); Steps = @(); Locked = $false
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Definition.ContainsKey($key)) { $Definition[$key] = $defaults[$key] }
    }

    # El distintivo se cuenta a partir de los ajustes marcados como
    # nuevos, para que el número no se quede desfasado al añadir o
    # quitar uno. Declarar Badge en la categoría lo fija a mano.
    if (-not $Definition.ContainsKey('Badge')) {
        $Definition['Badge'] = Get-NewBadgeText $Definition['Items']
    }

    foreach ($required in @('Id', 'Name', 'Icon', 'Description')) {
        if (-not $Definition[$required]) {
            throw "Register-Category: falta el campo obligatorio '$required'."
        }
    }

    foreach ($step in @($Definition['Steps'] | Where-Object { $_ })) {
        if (-not $step.Source) { $step.Source = $Definition['Id'] }
    }

    $CategoryList.Add([PSCustomObject]$Definition)
}

<#
    Devuelve las categorías que debe pintar la interfaz, ya
    ordenadas y filtradas según ui/Index/CategoryIndex.ps1:

      1. Recorre el índice en orden. De cada entrada:
           - si no existe el archivo de esa Id, la salta
           - si Visible = $false, la salta
           - copia Locked a la categoría
      2. Añade al final las categorías registradas que todavía
         no aparecen en el índice (visibles y desbloqueadas),
         para que crear un archivo nuevo funcione sin tocar nada.
#>
function Get-OptimizationCategories {
    $result = New-Object System.Collections.Generic.List[object]
    $placed = @{}

    foreach ($entry in $CategoryIndex) {
        $category = $CategoryList | Where-Object { $_.Id -eq $entry.Id } | Select-Object -First 1
        if (-not $category) { continue }

        $placed[$entry.Id] = $true

        # Visible por defecto: solo se oculta si se pide explícitamente.
        if ($entry.ContainsKey('Visible') -and -not $entry.Visible) { continue }

        $category.Locked = [bool]$entry.Locked
        $result.Add($category)
    }

    foreach ($category in $CategoryList) {
        if (-not $placed.ContainsKey($category.Id)) {
            $category.Locked = $false
            $result.Add($category)
        }
    }

    $result
}

# Categorías que existen en disco pero nadie ha colocado en el
# índice. Útil para depurar por qué algo aparece al final.
function Get-UnlistedCategories {
    $listed = @{}
    foreach ($entry in $CategoryIndex) { $listed[$entry.Id] = $true }
    $CategoryList | Where-Object { -not $listed.ContainsKey($_.Id) }
}

<#
    ¿Es una sección de COMANDOS (declara Steps)?

    No vale @($Category.Steps).Count: si la categoría no tiene el campo
    -una de mentira en las pruebas, o una que no pasó por
    Register-Category-, Steps es $null y @($null) es un array con UN
    elemento.
#>
function Test-CategoryHasSteps {
    param($Category)
    if (-not $Category) { return $false }
    $steps = @($Category.Steps | Where-Object { $_ })
    $steps.Count -gt 0
}

<#
    ¿Se puede correr este paso AHORA? No, si pide administrador y el
    programa no lo tiene.

    Y ¿cuenta como marcado? Solo si el usuario lo marcó Y se puede
    correr. Es la selección EFECTIVA: la que pinta la casilla, la que
    cuentan las píldoras y la que entra en la cola. Selected guarda lo
    que eligió el usuario; esto, lo que de verdad va a pasar.
#>
function Test-StepAvailable {
    param($Step)
    if (-not $Step) { return $false }
    -not ($Step.RequiresAdmin -and -not (Test-AppElevated))
}

function Test-StepSelected {
    param($Step)
    [bool]$Step.Selected -and (Test-StepAvailable $Step)
}

# Busca una categoría concreta por su Id (esté visible o no).
function Get-CategoryById {
    param([string]$Id)
    $CategoryList | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

<#
    Cuenta los ajustes de una categoría por etiqueta. Es lo que
    resume la fila centrada bajo el título del detalle (ver
    ui/Components/Layout/CategorySummary.ps1).

    Se cuenta SIEMPRE sobre los Items de verdad, no sobre los
    campos Recommended/Default/Custom de la categoría: esos son
    números fijos escritos a mano para las píldoras de la lista y
    no cuadran con el contenido real del archivo.

    Al recontar se vuelve a leer el array, así que en cuanto la
    lógica real cambie las etiquetas de un ajuste el resumen se
    actualiza sin tocar nada aquí.
#>
function Get-CategoryCounts {
    param($Category)

    $items = @($Category.Items)
    $counts = [ordered]@{}
    foreach ($tag in @('Recommended', 'Default', 'Custom')) {
        $counts[$tag] = @($items | Where-Object { $_.Tags -contains $tag }).Count
    }
    $counts['Total'] = $items.Count
    [PSCustomObject]$counts
}

<#
    Lo mismo, pero por ESTADO REAL: el que core/Registry/SettingStatus.ps1
    deja en cada ajuste al leer el equipo.

        optimized / factory / custom / unknown / Total

    Devuelve $null cuando NINGÚN ajuste de la sección tiene estado,
    que es tanto como decir que ninguno declara claves del registro.
    Entonces la que vale sigue siendo Get-CategoryCounts, con las
    etiquetas escritas a mano en ui/Data/Categories/.

    Solo cuentan los ajustes que sí tienen estado: mezclar en el
    total los que no leen nada haría que los números no cuadraran
    con lo que se ve en las tarjetas.
#>
function Get-CategoryStatusCounts {
    param($Category)

    $items = @(@($Category.Items) | Where-Object { $_.Status })
    if ($items.Count -eq 0) { return $null }

    $counts = [ordered]@{}
    foreach ($status in Get-SettingStatusNames) {
        $counts[$status] = @($items | Where-Object { $_.Status -eq $status }).Count
    }
    $counts['Total'] = $items.Count
    [PSCustomObject]$counts
}

<#
    Crea un ajuste para el array Items de una categoría.

    El tipo de control se deduce solo:
      - con -Options  -> desplegable
      - sin -Options  -> interruptor (el -Value debe ser $true / $false)

    -Value es la posición de partida del control, escrita a mano. Un
    INTERRUPTOR con -Registry no la lleva: su posición sale del estado
    leído del equipo (ON solo si está 'optimized', ver New-SettingControl
    en ui/Components/Cards/SettingCard.ps1), igual que no lleva -Tags.
    Declararla sería la versión inventada de lo mismo.

    La "Descripción" de la tarjeta se pinta en cuatro bloques SOLO
    cuando el ajuste declara -Registry (ver New-SettingFactSheet en
    ui/Components/Cards/SettingCard.ps1). Los cuatro campos son
    opcionales y cada uno tiene su plan B:

        -WhatItDoes     Bloque "Qué hace". Si falta, se usa -Description.
        -Values         Bloque "Valores" (rango, recomendado...). Si
                        falta, el bloque no sale.
        -GamingOptimal  'yes' | 'no' | 'na'. Sale como una etiqueta
                        Sí / No / N/A con los colores de New-Tag.
                        Por defecto 'na'.
        -GamingNote     Una línea breve junto a esa etiqueta. Opcional.
        -Link           URL de referencia. Se abre en el navegador
                        (core/Shell/ExternalLink.ps1). Si falta, el
                        bloque dice "Sin enlace".

    Un ajuste SIN -Registry ignora estos campos y enseña -Description
    en una línea, como siempre.

    -Registry declara las claves que toca el ajuste. Son las que
    enseña el pie "Detalles técnicos" de la tarjeta (ver
    ui/Components/Cards/TechnicalDetails.ps1). Cada clave es una tabla:

        Path         Ruta completa, con la raíz sin abreviar.
        Name         Nombre del valor dentro de esa ruta.
        Type         Tipo del valor: 'DWord', 'String'...
        Display      'hex' para enseñarlo como 0xFFFFFFFF.
        Recommended  Valor que propone el programa.
        Default      Valor de fábrica de Windows.

    Current y Status NO se declaran: los rellena core/ al leer el
    equipo (ver core/Registry/CategoryState.ps1). Recommended y Default sí
    son texto escrito a mano, y son contra lo que se compara lo
    leído para saber en qué estado está el ajuste.

    Un ajuste sin -Registry sale con un aviso en su lugar, no se
    rompe: se queda sin Status y la tarjeta enseña sus -Tags.

    Ejemplos:
        New-Setting -Name 'Game Mode' -Description '...' `
                    -Tags 'Recommended','Default' -Value $true

        New-Setting -Name 'Mouse Hover Time' -Description '...' `
                    -Tags 'Custom' -Options '100ms','200ms' `
                    -Value '200ms' -Badge 'NEW' `
                    -Registry @(
                        @{ Path = 'HKEY_CURRENT_USER\Control Panel\Mouse'
                           Name = 'MouseHoverTime'; Type = 'String'
                           Recommended = '200'; Default = '400' }
                    )
#>
function New-Setting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string[]]$Tags = @(),
        [string[]]$Options,
        $Value,
        [string]$Badge,
        [hashtable[]]$Registry = @(),

        # Bloques de la "Descripción" ampliada (solo si hay -Registry).
        [string]$WhatItDoes,
        [string]$Values,
        [ValidateSet('yes', 'no', 'na')][string]$GamingOptimal = 'na',
        [string]$GamingNote,
        [string]$Link
    )

    if ($Options) { $type = 'Dropdown' } else { $type = 'Toggle' }

    [PSCustomObject]@{
        Name        = $Name
        Description = $Description
        Tags        = $Tags
        Type        = $type
        Options     = $Options
        Value       = $Value
        Badge       = $Badge
        Registry    = $Registry

        # Bloques de la "Descripción" ampliada. Opcionales; los pinta
        # New-SettingFactSheet cuando el ajuste tiene claves.
        WhatItDoes    = $WhatItDoes
        Values        = $Values
        GamingOptimal = $GamingOptimal
        GamingNote    = $GamingNote
        Link          = $Link

        # NO se declara: lo rellena core/Registry/SettingStatus.ps1 al leer
        # el equipo, igual que el Current de cada clave. Se reserva
        # aquí el campo para poder asignarlo después.
        Status      = $null
    }
}

<#
    Crea un paso para el array Steps de una categoría: algo que se
    EJECUTA, no un ajuste que se lee y se cambia.

    Cuatro tipos, y se deduce solo de qué parámetro lleva:

      -Exe + -Arguments  ejecuta un programa de Windows, sin shell.
                         Solo los de la lista blanca de
                         core/Commands/CommandRunner.ps1, siempre desde
                         la carpeta de sistema. Los argumentos, uno por
                         elemento y literales: 'int','ipv4','reset'.
      -Service           arranca ese servicio si está parado (y si ya
                         corre, no hace nada). Lista blanca también.
      -Clean             vacía una carpeta, escrita como en un .cmd:
                         '%TEMP%' (todo, también subcarpetas) o
                         '%LOCALAPPDATA%\...\Explorer\*.db' (solo esos
                         archivos). Tiene que estar TAL CUAL en la lista
                         blanca de core/Commands/FolderCleanup.ps1.
      -EmptyRecycleBin   vacía la papelera del usuario.

    El ORDEN de ejecución es el de declaración en el archivo, marque
    el usuario lo que marque: un reset de Winsock antes de limpiar la
    pila no es lo mismo que después. Por eso el orden lo decide el
    archivo de la sección, no el clic.

        -Id              Único dentro de la sección. Estable: no se traduce.
        -Name            Título del paso (texto fuente en inglés, pasa por T).
        -Description     Qué hace, en una o dos frases.
        -Group           Fase a la que pertenece. Los pasos seguidos con el
                         mismo Group salen bajo la misma cabecera.
        -Checked         Si viene marcado. Por defecto $true. Lo que tenga
                         efectos que el usuario debe decidir (borrar reglas
                         del firewall, fijar DNS) va en $false.
        -Warning         Aviso que sale en ámbar en la fila.
        -RequiresRestart Al terminar, la sección pide reiniciar el equipo.
        -RequiresAdmin   Por defecto $true en -Exe y -Service: casi todo lo
                         que cambia la red necesita administrador. Sin
                         permisos, el paso sale desmarcado, apagado y
                         avisando, y no entra en la cola. Solo los que de
                         verdad funcionan sin permisos (comprobado, no
                         supuesto: nbtstat -R falla y aun así devuelve 0)
                         llevan $false. En -Clean y -EmptyRecycleBin es
                         $false: borran en TU carpeta de usuario, y eso no
                         necesita permisos.
        -PauseAfter      Segundos de espera tras el paso (el "timeout /t 5"
                         del .cmd original). La espera NO bloquea la ventana.
        -TimeoutSeconds  Tope antes de darlo por colgado. Por defecto, el de
                         CommandRunner (60 s; 600 s en -Clean).
        -SkipIf          @{ Path = 'HKEY_...\Clave'; Name = 'Valor' }. Si ese
                         valor del registro EXISTE, el paso no se ejecuta y
                         termina 'succeeded' diciendo que ya estaba. Solo se
                         LEE. Sirve para comandos que no se pueden repetir
                         (crear algo que ya existe) cuando el programa no
                         distingue "ya estaba" de un fallo por su código de
                         salida, como powercfg.

    Status y Selected NO se declaran: son estado de la sesión. Selected
    arranca en -Checked y lo cambia el usuario; Status lo va poniendo la
    ejecución (pending / running / succeeded / failed / ...).

    Ejemplo:
        New-CommandStep -Id 'winsock-reset' -Name 'Reset Winsock' `
            -Description 'Restores the Windows sockets catalog' `
            -Group 'Phase 1' -Exe 'netsh.exe' -Arguments 'winsock', 'reset' `
            -RequiresRestart
#>
function New-CommandStep {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string]$Group,
        [string]$Exe,
        [string[]]$Arguments = @(),
        [string]$Service,
        [string]$Clean,
        [switch]$EmptyRecycleBin,
        [bool]$Checked = $true,
        [string]$Warning,
        [switch]$RequiresRestart,
        [bool]$RequiresAdmin = $true,
        [int]$PauseAfter = 0,
        [int]$TimeoutSeconds = 0,
        [hashtable]$SkipIf
    )

    if ($SkipIf -and (-not $SkipIf.Path -or -not $SkipIf.Name)) {
        throw "New-CommandStep '$Id': -SkipIf necesita Path y Name."
    }

    if ($Service) { $kind = 'service' }
    elseif ($Exe) { $kind = 'exe' }
    elseif ($Clean) { $kind = 'clean' }
    elseif ($EmptyRecycleBin) { $kind = 'recyclebin' }
    else { throw "New-CommandStep '$Id': falta -Exe, -Service, -Clean o -EmptyRecycleBin." }

    # Borrar en la carpeta del usuario no pide permisos.
    if ($kind -in @('clean', 'recyclebin') -and -not $PSBoundParameters.ContainsKey('RequiresAdmin')) {
        $RequiresAdmin = $false
    }

    [PSCustomObject]@{
        Id              = $Id
        Name            = $Name
        Description     = $Description
        Group           = $Group
        Kind            = $kind
        Exe             = $Exe
        Arguments       = @($Arguments)
        Service         = $Service
        Clean           = $Clean
        Checked         = $Checked
        Warning         = $Warning
        RequiresRestart = [bool]$RequiresRestart
        RequiresAdmin   = $RequiresAdmin
        PauseAfter      = $PauseAfter
        TimeoutSeconds  = $TimeoutSeconds
        SkipIf          = $SkipIf

        # Lo pone Register-Category: el Id de la sección.
        Source          = $null

        # Estado de la sesión: no se declaran.
        Selected        = $Checked
        Status          = $null
        Items           = $null     # el detalle de la última ejecución
    }
}

<#
    LO QUE EL USUARIO MARCÓ EN UNA SECCIÓN DE COMANDOS, ENTRE SESIONES.

    Se guarda en settings.json (Set-AppSetting, regla 18) bajo
    'StepChoices.<sección>', y no como la lista de marcados sino como
    los pasos que el usuario CAMBIÓ respecto a lo de serie (-Checked).
    Así un paso nuevo que se añada después a la sección sale como venga
    declarado, en vez de quedarse desmarcado porque no estaba en la lista.
#>
function Save-StepChoices {
    param($Category)

    if (-not $Category -or -not (Test-CategoryHasSteps $Category)) { return }
    $changed = @(@($Category.Steps | Where-Object { $_ }) |
                 Where-Object { [bool]$_.Selected -ne [bool]$_.Checked } |
                 ForEach-Object { [string]$_.Id })
    Set-AppSetting ('StepChoices.' + $Category.Id) $changed
}

# Lo contrario, al arrancar: deja cada paso como lo dejó el usuario.
function Restore-StepChoices {
    foreach ($category in $CategoryList) {
        if (-not (Test-CategoryHasSteps $category)) { continue }
        $saved = Get-AppSetting ('StepChoices.' + $category.Id)
        if ($null -eq $saved) { continue }
        $changed = @(@($saved) | ForEach-Object { [string]$_ })
        foreach ($step in @($category.Steps | Where-Object { $_ })) {
            $step.Selected = if ($changed -contains [string]$step.Id) { -not $step.Checked } else { [bool]$step.Checked }
        }
    }
}
