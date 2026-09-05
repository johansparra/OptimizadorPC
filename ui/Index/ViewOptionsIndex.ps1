# ============================================================
# ViewOptionsIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DEL BOTÓN "VISTA" ***
#
# Mismo planteamiento que ui/Index/CategoryIndex.ps1 y que
# ui/Index/NavigationIndex.ps1, pero para las casillas que salen al
# pulsar el botón "Vista" de la cabecera. Las dibuja
# ui/Components/Shell/ViewMenu.ps1.
#
# Son opciones de VISTA: deciden qué se enseña en pantalla, no
# tocan nada del sistema ni del contenido de las categorías.
#
#   ORDEN      El de esta lista, de arriba abajo.
#
#   Id         Clave corta. Se guarda en settings.json como
#              'View.<Id>', así que cambiarla olvida lo elegido.
#
#   Label      Texto de la fila (en inglés: es el idioma fuente).
#   Hint       Línea gris debajo del texto.
#   Icon       Nombre de glifo del catálogo de ui/Design/Theme.ps1.
#   Default    Valor con el que arranca la primera vez.
#   Visible    $false -> se oculta la fila (no se pierde nada)
#
# Añadir una opción es añadir su línea aquí y consultarla con
# Get-ViewOption '<Id>' donde toque. El menú se dibuja solo.
# ============================================================

$ViewOptionsIndex = @(

    #  Id             Icono     Etiqueta              Por defecto  Visible
    @{ Id = 'technical'; Icon = 'Info'; Label = 'Technical details'
       Hint = 'Show the registry keys each setting touches'
       Default = $true;  Visible = $true }

    @{ Id = 'badges';    Icon = 'Bulb'; Label = 'New badges'
       Hint = "Show the red 'NEW' tags on sections and settings"
       Default = $true;  Visible = $true }

    @{ Id = 'grid';      Icon = 'Grid'; Label = 'Grid view'
       Hint = 'Show the sections as tiles instead of rows'
       Default = $false; Visible = $true }

)

# Clave con la que se guarda cada opción en settings.json.
function Get-ViewOptionKey {
    param([Parameter(Mandatory)][string]$Id)
    "View.$Id"
}

# Devuelve las filas visibles del menú, en el orden del índice.
function Get-ViewOptions {
    $ViewOptionsIndex | Where-Object {
        -not ($_.ContainsKey('Visible')) -or $_.Visible
    }
}

function Get-ViewOptionDefinition {
    param([Parameter(Mandatory)][string]$Id)
    $ViewOptionsIndex | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

<#
    Estado actual de una opción de vista.

        if (Get-ViewOption 'badges') { ... }

    Una Id desconocida devuelve $false en lugar de fallar: así un
    componente que pregunte por una opción ya retirada del índice
    simplemente deja de enseñar esa parte.
#>
function Get-ViewOption {
    param([Parameter(Mandatory)][string]$Id)

    $definition = Get-ViewOptionDefinition $Id
    if (-not $definition) { return $false }

    [bool](Get-AppSetting (Get-ViewOptionKey $Id) -Default $definition.Default)
}

# Guarda el nuevo estado en %APPDATA%\OptimizadorPC\settings.json.
function Set-ViewOption {
    param([Parameter(Mandatory)][string]$Id, [bool]$Value)
    Set-AppSetting (Get-ViewOptionKey $Id) $Value
}
