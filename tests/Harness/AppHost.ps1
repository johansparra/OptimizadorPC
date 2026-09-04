# ============================================================
# tests/Harness/AppHost.ps1
# Carga la aplicación entera sin abrir la ventana.
#
# No repite la lista de archivos: LEE main.ps1 y la deduce, con
# el MISMO marcador y el MISMO orden que usa build.ps1 (ver la
# regla 2 de CLAUDE.md). Dos motivos:
#
#   1. Las pruebas cargan exactamente lo que carga el programa,
#      en el mismo orden. Un archivo que main.ps1 no vea tampoco
#      lo verán ellas, y hay una prueba que lo comprueba
#      (tests/Source/Rules.Tests.ps1).
#
#   2. De paso, ejecutar las pruebas ya valida el contrato de
#      build.ps1: si alguien saca un archivo de las carpetas que
#      se incrustan, aqui se nota antes de compilar el .exe.
#
# Se para en el marcador del XAML: a partir de ahí main.ps1 crea
# la ventana, conecta botones y llama a ShowDialog, que es justo
# lo que no queremos. La ventana la fabrica New-AppWindow cuando
# una prueba la pide.
#
# ESTE ARCHIVO SE CARGA CON PUNTO desde Run-Tests.ps1, para que
# las funciones de la aplicación queden en el ámbito de las
# pruebas. Ejecutarlo suelto no sirve de nada.
# ============================================================

$AppRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# Qué se ha cargado, en orden. Lo consulta Source/Rules.Tests.ps1
# para comprobar que no se ha quedado ningún archivo fuera.
$AppLoadedFiles = New-Object System.Collections.Generic.List[string]

# Nombres largos y feos a propósito: estas variables viven en el
# mismo ámbito que todo lo que se va a cargar, y una $file o una
# $line se pisarían con las de cualquier archivo de la aplicación.
foreach ($hostLine in (Get-Content -Path (Join-Path $AppRoot 'main.ps1'))) {

    if ($hostLine -match '^\s*# @@EMBED_XAML:') { break }

    if ($hostLine -match '^\s*# @@EMBED_DIR:(.+)@@\s*$') {
        $hostDir  = $Matches[1]
        $hostBase = Join-Path $AppRoot ($hostDir -replace '/', '\')
        foreach ($hostFile in (Get-ChildItem -Path $hostBase -Recurse -Filter '*.ps1' | Sort-Object FullName)) {
            $hostDentro = $hostFile.FullName.Substring($hostBase.Length).TrimStart('\') -replace '\\', '/'
            $AppLoadedFiles.Add("$hostDir/$hostDentro")
            . $hostFile.FullName
        }
    }
}

<#
    Una ventana de verdad, con su XAML cargado y su tema puesto,
    pero SIN enseñar: no hace falta pintar nada para comprobar
    que el árbol de controles es el que debe ser.

        $window = New-AppWindow
        $window = New-AppWindow -Theme 'Dark' -Language 'es'

    Se registra con Set-AppWindow, así que Get-AppWindow la
    devuelve y funcionan los manejadores que la buscan por ahí.
#>
function New-AppWindow {
    param([string]$Theme = 'Light', [string]$Language = 'en')

    [xml]$xaml = Get-Content -Path (Join-Path $AppRoot 'ui\MainWindow.xaml') -Raw
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    Set-AppWindow $window
    Set-AppTheme -Window $window -Name $Theme
    Set-AppLanguage $Language

    $window
}

# Ruta de la aplicación para las pruebas que miran el código
# fuente en vez de ejecutarlo.
function Get-AppRoot { $AppRoot }

<#
    Vacía la cola del Dispatcher.

    Varias cosas de la interfaz se aplazan a propósito -repintar
    tras cambiar de idioma, bajar el log hasta el final- y sin
    bucle de mensajes nunca llegarían a ejecutarse. Esto las
    fuerza, que es lo que haría la ventana estando abierta.

    Es lo mismo que hace Update-UiNow (ver ProgressStrip.ps1),
    pero sin depender de que haya una ventana viva.
#>
function Sync-Dispatcher {
    param([string]$Priority = 'Loaded')

    $frame = New-Object System.Windows.Threading.DispatcherFrame
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]$Priority,
        [action]{ $frame.Continue = $false }) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

<#
    Recorre un árbol de controles y devuelve los que cumplan algo.

        Find-Visuals $panel { param($el) $el -is [System.Windows.Controls.TextBlock] }

    Va por el árbol LÓGICO (Children / Child / Content), no por el
    visual: sin ventana abierta WPF no ha construido plantillas y
    el árbol visual está a medias.
#>
function Find-Visuals {
    param(
        [Parameter(Mandatory)]$Root,
        [Parameter(Mandatory)][scriptblock]$Where
    )

    $found = New-Object System.Collections.Generic.List[object]
    $pending = New-Object System.Collections.Generic.Stack[object]
    $pending.Push($Root)

    while ($pending.Count -gt 0) {
        $node = $pending.Pop()
        if ($null -eq $node) { continue }

        if (& $Where $node) { $found.Add($node) }

        if ($node.PSObject.Properties['Children'] -and $node.Children) {
            foreach ($child in $node.Children) { $pending.Push($child) }
        }
        if ($node.PSObject.Properties['Child'] -and $node.Child) {
            $pending.Push($node.Child)
        }
        if ($node.PSObject.Properties['Content'] -and $node.Content -is [System.Windows.DependencyObject]) {
            $pending.Push($node.Content)
        }
        if ($node.PSObject.Properties['Inlines'] -and $node.Inlines) {
            foreach ($inline in $node.Inlines) { $pending.Push($inline) }
        }
    }

    , $found.ToArray()
}

<#
    Todo el texto de un árbol de controles, junto. Sirve para
    preguntar "¿sale esto en pantalla?" sin saber en qué control
    concreto ha acabado.

    Se recogen los Run y no los TextBlock, porque varios sitios
    del proyecto arman la línea por trozos con Inlines.Add() -las
    rutas del registro, por ejemplo- y en ese caso TextBlock.Text
    viene VACÍO: WPF llena Inlines desde Text, pero no al revés.
    Un TextBlock con su Text puesto sí tiene su Run implícito, así
    que mirando solo los Run se ven los dos casos.
#>
function Get-VisualText {
    param([Parameter(Mandatory)]$Root)

    $partes = Find-Visuals $Root {
        param($el)
        $el -is [System.Windows.Documents.Run] -or
        ($el -is [System.Windows.Controls.TextBlock] -and $el.Inlines.Count -eq 0)
    }
    (($partes | ForEach-Object { $_.Text }) -join "`n")
}
