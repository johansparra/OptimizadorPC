# ============================================================
# CategoryRegistry.ps1
# Registro de categorías.
#
# NO contiene datos ni decide qué se ve: solo el mecanismo.
#
#   ui/Categories/<Nombre>.ps1  ->  QUÉ tiene cada sección
#   ui/CategoryIndex.ps1        ->  CUÁLES se ven, en qué orden
#                                   y cuáles están bloqueadas
#
#   -> Añadir una sección  = crear su archivo en ui/Categories/
#                            (aparece al final) y, si quieres
#                            colocarla, añadir su línea al índice
#   -> Ocultar una sección = Visible = $false en el índice
#   -> Bloquear una sección= Locked  = $true  en el índice
#   -> Reordenar           = mover su línea en el índice
# ============================================================

# Lista donde se van acumulando las categorías al cargarse.
$CategoryList = New-Object System.Collections.Generic.List[object]

<#
    Da de alta una categoría. Campos de la definición:

    Id           (string) Identificador corto y único: 'privacy', 'power'...
                          Es la clave con la que ui/CategoryIndex.ps1 la coloca.
    Name         (string) Título visible.
    Icon         (string) Nombre de glifo del catálogo de Theme.ps1 ('Shield', 'Power'...).
    Accent       (string) Clave de color del tema para el icono ('Accent', 'Success', 'Warn').
    AccentSoft   (string) Clave de color del tema para el fondo del icono.
    Badge        (string) Distintivo rojo opcional: 'NEW 45'. $null para ocultarlo.
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
        Badge = $null; Accent = 'Accent'; AccentSoft = 'AccentSoft'
        Recommended = 0; Default = 0; Custom = 0; Total = 0
        Items = @(); Locked = $false
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Definition.ContainsKey($key)) { $Definition[$key] = $defaults[$key] }
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
    ordenadas y filtradas según ui/CategoryIndex.ps1:

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
    Crea un ajuste para el array Items de una categoría.

    El tipo de control se deduce solo:
      - con -Options  -> desplegable
      - sin -Options  -> interruptor (el -Value debe ser $true / $false)

    Ejemplos:
        New-Setting -Name 'Game Mode' -Description '...' `
                    -Tags 'Recommended','Default' -Value $true

        New-Setting -Name 'Mouse Hover Time' -Description '...' `
                    -Tags 'Preference' -Options '100ms','200ms' `
                    -Value '200ms' -Badge 'NEW'
#>
function New-Setting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [string[]]$Tags = @(),
        [string[]]$Options,
        [Parameter(Mandatory)]$Value,
        [string]$Badge
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
    }
}
