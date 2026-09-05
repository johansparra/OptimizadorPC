# ============================================================
# NavigationIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DEL MENÚ LATERAL ***
#
# Mismo planteamiento que ui/Index/CategoryIndex.ps1, pero para los
# botones de la barra de la izquierda. Antes estaban escritos a
# mano dentro de MainWindow.xaml; ahora son datos y los dibuja
# ui/Components/Shell/Sidebar.ps1.
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
#   View       Nombre de la función de vista a la que lleva.
#
#              $null -> la sección todavía NO tiene pantalla. El
#                       botón se ve y se pulsa como los demás -ni
#                       gris ni con candado-, pero el clic no hace
#                       nada: ni navega, ni cambia el contenido, ni
#                       mueve la selección. Te quedas donde estabas.
#
#              Crear una pantalla es añadir su archivo a ui/Views/ y
#              escribir aquí el nombre de su función; el botón
#              empieza a funcionar solo, sin tocar nada más.
#
#   Icon       Nombre de glifo del catálogo de ui/Design/Theme.ps1.
# ============================================================

# Hoy solo hay pantalla para dos entradas -Optimize y Settings-. Las
# otras cuatro siguen aquí a propósito: mantienen la estructura del
# menú a la vista, y activarlas será rellenar su View.
$NavigationIndex = @(

    #  Id             Icono        Etiqueta       Grupo      Visible  Bloqueado   Vista
    @{ Id = 'software';  Icon = 'Apps';    Label = 'Software';  Group = 'Top';    Visible = $true; Locked = $false; View = $null }
    @{ Id = 'optimize';  Icon = 'Gauge';   Label = 'Optimize';  Group = 'Top';    Visible = $true; Locked = $false; View = 'Show-OptimizationsListView'; Default = $true }
    @{ Id = 'customize'; Icon = 'Palette'; Label = 'Customize'; Group = 'Top';    Visible = $true; Locked = $false; View = $null }

    @{ Id = 'advanced';  Icon = 'Wrench';  Label = 'Advanced';  Group = 'Bottom'; Visible = $true; Locked = $false; View = $null }
    @{ Id = 'settings';  Icon = 'Gear';    Label = 'Settings';  Group = 'Bottom'; Visible = $true; Locked = $false; View = 'Show-SettingsView' }
    @{ Id = 'more';      Icon = 'More';    Label = 'More';      Group = 'Bottom'; Visible = $true; Locked = $false; View = $null }

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

function Get-NavigationItem {
    param([string]$Id)
    $NavigationIndex | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}
