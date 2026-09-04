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
#>
function Register-Category {
    param([Parameter(Mandatory)][hashtable]$Definition)

    # Valores por defecto: así una categoría mínima solo necesita
    # Id, Name, Icon, Description e Items.
    # Locked lo rellena el índice; aquí solo se reserva el campo.
    $defaults = @{
        Accent = 'Accent'; AccentSoft = 'AccentSoft'
        Recommended = 0; Default = 0; Custom = 0; Total = 0
        Items = @(); Locked = $false
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
    Crea un ajuste para el array Items de una categoría.

    El tipo de control se deduce solo:
      - con -Options  -> desplegable
      - sin -Options  -> interruptor (el -Value debe ser $true / $false)

    -Registry declara las claves que toca el ajuste. Son las que
    enseña el pie "Detalles técnicos" de la tarjeta (ver
    ui/Components/Cards/TechnicalDetails.ps1). Cada clave es una tabla:

        Path         Ruta completa, con la raíz sin abreviar.
        Name         Nombre del valor dentro de esa ruta.
        Type         Tipo del valor: 'DWord', 'String'...
        Current      Valor que hay ahora.
        Recommended  Valor que propone el programa.
        Default      Valor de fábrica de Windows.

    Los tres valores son texto y hoy son ESTÁTICOS: nadie lee el
    registro todavía. Un ajuste sin -Registry sale con un aviso
    en su lugar, no se rompe.

    Ejemplos:
        New-Setting -Name 'Game Mode' -Description '...' `
                    -Tags 'Recommended','Default' -Value $true

        New-Setting -Name 'Mouse Hover Time' -Description '...' `
                    -Tags 'Custom' -Options '100ms','200ms' `
                    -Value '200ms' -Badge 'NEW' `
                    -Registry @(
                        @{ Path = 'HKEY_CURRENT_USER\Control Panel\Mouse'
                           Name = 'MouseHoverTime'; Type = 'String'
                           Current = '400'; Recommended = '200'; Default = '400' }
                    )
#>
function New-Setting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string[]]$Tags = @(),
        [string[]]$Options,
        [Parameter(Mandatory)]$Value,
        [string]$Badge,
        [hashtable[]]$Registry = @()
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
    }
}
