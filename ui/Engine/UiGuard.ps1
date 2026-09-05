# ============================================================
# UiGuard.ps1
# Que un fallo en un manejador no se lleve la ventana por delante.
#
# En WPF, una excepción que escapa de un manejador de evento sube
# al Dispatcher, y desde ahí a quien arrancó el bucle de mensajes:
# en este programa, el ShowDialog() de main.ps1. El síntoma que ve
# quien usa la aplicación no es un mensaje de error, es que la
# ventana deja de responder y hay que cerrarla a mano; el error
# aparece en la consola, que en el .exe ni siquiera existe
# (regla 7).
#
# Este guardián engancha Dispatcher.UnhandledException:
#
#   1. Apunta el fallo en el registro de actividad -con su
#      mensaje y de dónde venía-, que es donde ya se mira todo lo
#      demás y se puede volcar a un archivo.
#   2. Lo marca como tratado, así que el bucle de mensajes sigue
#      vivo y la ventana responde.
#
# NO es una excusa para no arreglar los fallos: es la red por
# debajo. Todo lo que caiga aquí sale en el cajón del log en rojo,
# que es justamente donde hay que ir a buscarlo.
# ============================================================

# Cuántos fallos se han tragado en esta sesión. Sirve para no
# repetir el mismo aviso mil veces si algo falla en cada repintado.
$UiGuardCaught = 0

# A qué dispatchers ya se enganchó. Se guardan AQUÍ y no como marca
# en el propio objeto: Dispatcher no tiene Tag -ni ninguna propiedad
# libre-, y asignársela lanza "La propiedad 'Tag' no se encuentra en
# este objeto", en 5.1 y en 7. La ventana del log tiene su propio
# dispatcher, así que la lista puede tener más de uno.
$UiGuardHooked = New-Object System.Collections.Generic.List[object]

function Get-UiGuardCount { $script:UiGuardCaught }

function Reset-UiGuardCount { $script:UiGuardCaught = 0 }

<#
    Engancha el guardián a la ventana.

        Register-UiErrorGuard -Window $Window

    Se engancha UNA sola vez por dispatcher: main.ps1 lo llama al
    arrancar y las pruebas pueden llamarlo sin miedo a duplicar el
    manejador -dos manejadores apuntarían el mismo fallo dos veces-.
#>
function Register-UiErrorGuard {
    param($Window)

    if (-not $Window) { return $false }

    $dispatcher = $Window.Dispatcher
    if (-not $dispatcher) { return $false }

    # Una sola vez por dispatcher: dos manejadores apuntarían el
    # mismo fallo dos veces. Se compara por referencia, que es lo que
    # hace -contains con objetos.
    if ($script:UiGuardHooked -contains $dispatcher) { return $false }
    $script:UiGuardHooked.Add($dispatcher)

    # Sin closure (regla 4): el manejador solo llama a funciones del
    # script y saca del evento lo que necesita.
    $dispatcher.Add_UnhandledException({
        param($s, $e)
        Write-UiGuardLog $e.Exception
        $e.Handled = $true
    })

    $true
}

<#
    Apunta el fallo en el registro de actividad.

    Aparte del manejador para poder probarlo: fabricar un
    DispatcherUnhandledExceptionEventArgs a mano no se puede, pero
    esto sí se llama con una excepción cualquiera.

    El mensaje NO se traduce, igual que el resto de líneas del log:
    es texto técnico para copiar y pegar en un informe (ver la
    cabecera de LogPanel.ps1).
#>
function Write-UiGuardLog {
    param($Exception)

    $script:UiGuardCaught++

    $mensaje = 'unhandled'
    if ($Exception -and $Exception.Message) { $mensaje = [string]$Exception.Message }

    # De dónde venía: el primer marco del stack ya dice el archivo y
    # la línea, y es lo único que cabe en una línea de log.
    $detalle = ''
    if ($Exception -and $Exception.StackTrace) {
        $detalle = (([string]$Exception.StackTrace) -split "`r?`n" | Where-Object { $_ })[0]
    }
    if (-not $detalle -and $Exception) { $detalle = $Exception.GetType().FullName }

    Write-AppLog -Source 'app' -Level 'error' -Status 'error' `
                 -Message $mensaje -Detail ([string]$detalle).Trim()
}
