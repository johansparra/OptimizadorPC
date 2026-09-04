# ============================================================
# Componente: aviso efímero
#
# La pastilla que aparece un momento en la cabecera para decir
# que algo acaba de terminar -hoy, que se han vuelto a leer las
# claves del registro-.
#
# No es lo mismo que Banner.ps1: aquel se queda mientras dure la
# condición que avisa (una sección bloqueada lo está siempre),
# este cuenta un hecho que ya pasó y se va solo.
#
# Se descuelga con un DispatcherTimer y no desde el Completed de
# la animación: ese evento trae el reloj como emisor, no el
# control, y llegar hasta el control obligaría a capturarlo en el
# scriptblock (regla 4). El temporizador sí tiene Tag.
# ============================================================

<#
    Enseña la pastilla al principio de la zona de acciones y deja
    programada su marcha de una vez: se desvanece a los $Ms
    -animación aplazada con BeginTime- y se descuelga 320 ms más
    tarde, cuando ya no se ve.

        Show-PageToast -Window $w -Text 'Registry values updated'

    Sin ventana pintándose ni bucle de mensajes -las pruebas- ni
    la animación avanza ni el temporizador dispara: la pastilla se
    queda puesta, que es exactamente lo que hay que poder mirar.
#>
function Show-PageToast {
    param(
        $Window,
        [string]$Text,
        [string]$Icon = 'Check',
        [int]$Ms = 2400
    )

    $pill = New-Pill -Icon $Icon -Text (T $Text) -Fg 'Success' -Bg 'SuccessSoft'
    $pill.Margin = New-Object System.Windows.Thickness 0, 0, 8, 0
    Add-PageActionFirst $Window $pill

    # Entra deslizando desde la derecha. Se anima el
    # desplazamiento y no la opacidad porque la opacidad la tiene
    # reservada la salida: dos BeginAnimation sobre la misma
    # propiedad y el segundo se lleva por delante al primero.
    $slide = New-Object System.Windows.Media.TranslateTransform
    $pill.RenderTransform = $slide
    $slide.BeginAnimation(
        [System.Windows.Media.TranslateTransform]::XProperty, (New-Anim 12 0 220))

    $fade = New-Anim 1 0 300
    $fade.BeginTime = [TimeSpan]::FromMilliseconds($Ms)
    $pill.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($Ms + 320)
    $timer.Tag = $pill
    $timer.Add_Tick({
        param($s, $e)
        $s.Stop()
        $gone = $s.Tag
        # Puede que ya no cuelgue de nadie: repintar la pantalla
        # vacía la cabecera y se lleva la pastilla con ella.
        if ($gone -and $gone.Parent) { $gone.Parent.Children.Remove($gone) }
    })
    $timer.Start()

    $pill
}
