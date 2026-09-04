# ============================================================
# Componente: el registro de actividad, en su propia ventana
#
# El mismo contenido que el cajón de LogPanel.ps1, pero sacado a
# una ventana aparte que se puede mover, redimensionar, minimizar,
# maximizar y cerrar, y volver a acoplar cuando estorbe menos
# dentro. Sirve para dejar el log a la vista en otro monitor
# mientras se navega por las secciones.
#
#   cajón  --[sacar]-->  ventana  --[acoplar]-->  cajón
#
# Lo que hay que saber de esta ventana:
#
# - Se construye POR CÓDIGO, no en XAML. build.ps1 solo sabe
#   incrustar UN xaml (el de la ventana principal): un segundo
#   archivo .xaml funcionaría en desarrollo y faltaría en el .exe.
#   Es el mismo motivo por el que el menú lateral se arma a mano.
#
# - Es HIJA de la principal (Owner). Eso le da dos cosas gratis:
#   se cierra sola cuando se cierra el programa -si no, quedaría
#   una ventana viva impidiendo salir- y sigue siendo usable
#   aunque la principal se muestre con ShowDialog, que si no
#   dejaría inservible cualquier otra ventana.
#
# - COMPARTE LOS RECURSOS del tema por MergedDictionaries, así que
#   alternar claro/oscuro la repinta a la vez que a la principal
#   sin que haya que enterarse aquí.
#
# - NO TIENE CROMO de Windows (WindowStyle None + WindowChrome),
#   igual que la ventana principal: los bordes de redimensión son
#   los nativos y la barra de título es la propia cabecera del
#   registro, que ya trae los botones.
# ============================================================

# La ventana, mientras exista. $null cuando el log está acoplado
# o cerrado.
$LogWindow = $null

# Dónde se abre el log al pulsar el botón de la barra de título.
# Se recuerda dentro de la sesión: si lo sacaste y lo cerraste, la
# próxima vez vuelve a salir fuera. No se guarda en settings.json a
# propósito, para que arrancar el programa empiece siempre con el
# log recogido.
$LogFloating = $false

function Get-LogWindow   { $script:LogWindow }
function Get-LogFloating { $script:LogFloating }
function Get-LogDetached { $null -ne $script:LogWindow }

# Quién aloja ahora mismo las filas del registro. Lo usa
# Update-LogList para encontrar su ScrollViewer sin que le importe
# dónde está pintado.
function Get-LogHostWindow {
    if ($script:LogWindow) { $script:LogWindow } else { Get-AppWindow }
}

# ---- Sacar, acoplar, cerrar ---------------------------------

<#
    Saca el registro a su propia ventana.

    Si ya está fuera no crea otra: la trae al frente, que es lo
    que espera quien vuelve a pulsar el botón.
#>
function Open-LogWindow {
    if ($script:LogWindow) { Show-LogWindowFront; return }

    $main = Get-AppWindow
    if (-not $main) { return }

    # El cajón se retira sin esperar a su animación: Close-LogOverlay
    # colapsa ya, porque Hide-LogPanel deja el panel marcado como
    # cerrado antes de animar nada.
    Hide-LogPanel $main
    Close-LogOverlay $main

    $script:LogFloating = $true
    $script:LogWindow = New-LogWindow $main

    # Después de guardar la ventana, no antes: Update-LogList
    # pregunta por Get-LogHostWindow para dejar el scroll al final.
    Update-LogList $script:LogWindow

    $script:LogWindow.Show()
    $script:LogWindow.Activate() | Out-Null
}

# Devuelve el registro al cajón de la ventana principal.
function Join-LogPanel {
    $win = $script:LogWindow
    $script:LogFloating = $false

    # Al cerrarse, su manejador Closed deja $LogWindow en $null, de
    # modo que el cajón ya cuenta como alojamiento actual.
    if ($win) { $win.Close() }

    Show-LogPanel (Get-AppWindow)
}

# Cierra la ventana sin acoplar: el log queda escondido, y el botón
# de la barra de título lo volverá a sacar fuera.
function Close-LogWindow {
    if ($script:LogWindow) { $script:LogWindow.Close() }
}

# La trae al frente, restaurándola si estaba minimizada.
function Show-LogWindowFront {
    $win = $script:LogWindow
    if (-not $win) { return }
    if ($win.WindowState -eq 'Minimized') { $win.WindowState = 'Normal' }
    $win.Activate() | Out-Null
}

function Switch-LogWindowState {
    param($Window)
    if ($Window.WindowState -eq 'Maximized') { $Window.WindowState = 'Normal' }
    else                                     { $Window.WindowState = 'Maximized' }
}

# Arrastrar la ventana desde su cabecera, y doble clic para
# maximizar. Igual que la barra de título de la principal.
#
# Los botones de la cabecera no se ven afectados: un Button marca
# como tratado el MouseLeftButtonDown, así que no llega hasta aquí.
function Add-LogWindowDrag {
    param($Element)

    $Element.Add_MouseLeftButtonDown({
        param($s, $e)
        $win = [System.Windows.Window]::GetWindow($s)
        if (-not $win) { return }

        if ($e.ClickCount -eq 2) { Switch-LogWindowState $win; return }
        # DragMove lanza si el botón ya no está pulsado.
        if ($e.ButtonState -eq 'Pressed') { $win.DragMove() }
    })
}

# ---- La ventana ---------------------------------------------

<#
    Construye la ventana. No la enseña ni toca el estado: eso es de
    Open-LogWindow, para que las pruebas puedan armar el árbol sin
    que aparezca nada en pantalla.
#>
function New-LogWindow {
    param($Main)

    $win = New-Object System.Windows.Window
    $win.Title = T 'Activity log'
    $win.Width = 760
    $win.Height = 640
    $win.MinWidth = 460
    $win.MinHeight = 320
    $win.WindowStyle = 'None'
    $win.ResizeMode = 'CanResize'
    $win.ShowInTaskbar = $true
    $win.FontFamily = $Main.FontFamily
    $win.SnapsToDevicePixels = $true
    $win.UseLayoutRounding = $true

    # Una ventana creada por código no trae NameScope -el de la
    # principal lo monta el cargador de XAML-, y sin él RegisterName
    # lanza con "No se encontró ningún NameScope". Tiene que estar
    # puesto ANTES de construir nada que se registre.
    [System.Windows.NameScope]::SetNameScope($win, (New-Object System.Windows.NameScope))

    # Mismo diccionario que la principal: un cambio de tema muta
    # esos pinceles y los DynamicResource de aquí se enteran solos.
    $win.Resources.MergedDictionaries.Add($Main.Resources)
    Set-WinBg $win 'Bg1'

    # Owner solo admite una ventana que ya se haya mostrado. En las
    # pruebas no se muestra ninguna, así que ahí se queda huérfana
    # -y entonces centrarla sobre la principal tampoco tendría
    # sentido-.
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $Main
    if ($helper.Handle -ne [IntPtr]::Zero) {
        $win.Owner = $Main
        $win.WindowStartupLocation = 'CenterOwner'
    }
    else {
        $win.WindowStartupLocation = 'CenterScreen'
    }

    # Bordes de redimensión nativos sin barra de título de Windows,
    # igual que MainWindow.xaml.
    $chrome = New-Object System.Windows.Shell.WindowChrome
    $chrome.CaptionHeight = 0
    $chrome.ResizeBorderThickness = New-Object System.Windows.Thickness 6
    $chrome.GlassFrameThickness = New-Object System.Windows.Thickness 0
    $chrome.CornerRadius = New-Object System.Windows.CornerRadius 0
    $chrome.UseAeroCaptionButtons = $false
    [System.Windows.Shell.WindowChrome]::SetWindowChrome($win, $chrome)

    $root = New-Object System.Windows.Controls.Border
    $root.BorderThickness = New-Object System.Windows.Thickness 1
    Set-BoxBg   $root 'Bg1'
    Set-BoxLine $root 'Stroke'
    $root.Child = New-LogContent $win -Floating
    $win.Content = $root

    # El glifo de maximizar alterna con el de restaurar, como en la
    # ventana principal.
    $win.Add_StateChanged({
        param($s, $e)
        $btn = $s.FindName('LogBtnMaximize')
        if (-not $btn) { return }
        if ($s.WindowState -eq 'Maximized') { $btn.Content = Glyph 'Restore' }
        else                                { $btn.Content = Glyph 'Maximize' }
    })

    # Se cierre como se cierre -su botón, Alt+F4, o al salir del
    # programa por ser hija- el estado tiene que quedar limpio, o el
    # botón de la barra de título intentaría enfocar una ventana
    # muerta.
    $win.Add_Closed({
        param($s, $e)
        Clear-LogWindowState
    })

    $win
}

function Clear-LogWindowState { $script:LogWindow = $null }

# Rehace el contenido de la ventana. Lo llama el cambio de idioma,
# igual que Update-LogPanel rehace el cajón.
function Update-LogWindow {
    $win = $script:LogWindow
    if (-not $win) { return }

    $win.Title = T 'Activity log'
    $win.Content.Child = New-LogContent $win -Floating
    Update-LogList $win
}
