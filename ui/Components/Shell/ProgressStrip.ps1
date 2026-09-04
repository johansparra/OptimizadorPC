# ============================================================
# Componente: barra de progreso
#
# La franja del pie de la ventana, para tareas que tardan. Hoy la
# usa la lectura del registro al entrar en una sección; conforme
# haya más claves que consultar, más se notará.
#
# El contenedor está en MainWindow.xaml y arranca colapsado: sin
# alto, así que aparecer y desaparecer no mueve el contenido.
#
# Ojo con Set-ProgressStrip: obliga a WPF a repintar en mitad del
# bucle que lo llama. Ver el comentario de Update-UiNow.
# ============================================================

function Show-ProgressStrip {
    param($Window, [string]$Text)

    $Window.FindName('ProgressText').Text = T $Text
    $Window.FindName('ProgressCount').Text = ''
    Set-ProgressFill $Window 0 1
    $Window.FindName('ProgressStrip').Visibility = 'Visible'
    Update-UiNow $Window
}

# Avance de la barra. $Total = 0 se ignora en vez de dividir por cero.
function Set-ProgressStrip {
    param($Window, [int]$Done, [int]$Total)

    if ($Total -le 0) { return }

    $Window.FindName('ProgressCount').Text = "$Done/$Total"
    Set-ProgressFill $Window $Done $Total
    Update-UiNow $Window
}

function Hide-ProgressStrip {
    param($Window)
    $Window.FindName('ProgressStrip').Visibility = 'Collapsed'
}

# El relleno son dos columnas estrella que se reparten el ancho:
# hecho / lo que falta. Así no hay que medir la ventana.
function Set-ProgressFill {
    param($Window, [double]$Done, [double]$Total)

    $left = $Total - $Done
    if ($left -lt 0) { $left = 0 }

    $Window.FindName('ProgressDone').Width = [System.Windows.GridLength]::new($Done, 'Star')
    $Window.FindName('ProgressLeft').Width = [System.Windows.GridLength]::new($left, 'Star')
}

<#
    Vacía la cola del Dispatcher para que lo pintado hasta ahora
    llegue a la pantalla.

    Hace falta porque la lectura del registro es SÍNCRONA: mientras
    el bucle corre, el hilo de interfaz está ocupado y la barra no
    se redibujaría sola; se vería saltar de 0 a 100 al terminar.

    Es el equivalente del viejo DoEvents, con lo que eso implica:
    durante la pausa WPF puede entregar eventos de ratón. Por eso
    quien la usa deja la ventana bloqueada mientras dura (ver
    Show-CategoryDetailView). Si algún día la lectura se va a un
    hilo aparte, esta función sobra.
#>
function Update-UiNow {
    param($Window)

    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action]{ $frame.Continue = $false }) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}
