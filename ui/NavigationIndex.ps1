# ============================================================
# NavigationIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DEL MENÚ LATERAL ***
#
# Mismo planteamiento que ui/CategoryIndex.ps1, pero para los
# botones de la barra de la izquierda. Antes estaban escritos a
# mano dentro de MainWindow.xaml; ahora son datos y los dibuja
# ui/Components/Sidebar.ps1.
#
#   ORDEN      El de esta lista, dentro de cada grupo.
#              Mover un botón = mover su línea.
#
#   Group      'Top'    -> arriba del todo
#              'Bottom' -> pegado abajo, tras la línea separadora
#
#   Visible    $true  -> se muestra
#              $false -> se oculta (no se pierde nada)
#
#   Locked     $false -> normal
#              $true  -> se muestra en gris con candado y no
#                        responde al clic
#
#   Default    $true en el botón que sale marcado al arrancar.
#
#   Icon       Nombre de glifo del catálogo de ui/Theme.ps1.
# ============================================================

$NavigationIndex = @(

    #  Id             Icono        Etiqueta       Grupo      Visible  Bloqueado
    @{ Id = 'software';  Icon = 'Apps';    Label = 'Software';  Group = 'Top';    Visible = $true; Locked = $false }
    @{ Id = 'optimize';  Icon = 'Gauge';   Label = 'Optimize';  Group = 'Top';    Visible = $true; Locked = $false; Default = $true }
    @{ Id = 'customize'; Icon = 'Palette'; Label = 'Customize'; Group = 'Top';    Visible = $true; Locked = $false }

    @{ Id = 'advanced';  Icon = 'Wrench';  Label = 'Advanced';  Group = 'Bottom'; Visible = $true; Locked = $false }
    @{ Id = 'settings';  Icon = 'Gear';    Label = 'Settings';  Group = 'Bottom'; Visible = $true; Locked = $false }
    @{ Id = 'more';      Icon = 'More';    Label = 'More';      Group = 'Bottom'; Visible = $true; Locked = $false }

)

# Devuelve los botones visibles, opcionalmente los de un grupo.
function Get-NavigationItems {
    param([string]$Group)

    $items = $NavigationIndex | Where-Object {
        -not ($_.ContainsKey('Visible')) -or $_.Visible
    }
    if ($Group) { $items = $items | Where-Object { $_.Group -eq $Group } }
    $items
}

# Nombre con el que se registra cada botón en la ventana, para
# que $Window.FindName('NavSettings') siga funcionando.
function Get-NavElementName {
    param([string]$Id)
    'Nav' + $Id.Substring(0, 1).ToUpper() + $Id.Substring(1)
}
