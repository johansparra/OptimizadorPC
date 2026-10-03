# ============================================================
# Pruebas del panel "Acerca de" (ui/Components/Shell/AboutMenu.ps1)
# y de la única fuente de la versión (ui/Data/AppInfo.ps1).
#
# Un Popup con IsOpen = $true solo llega a abrirse con una ventana
# ya mostrada, y ninguna prueba enseña ninguna (ver Search.Tests).
# La señal que sí se puede leer es popup.Child, que Switch-AboutMenu
# rellena antes de tocar IsOpen.
# ============================================================

# Todos los TextBlock de un árbol, para buscar textos.
function Get-AboutTexts {
    param($Root)
    $out = New-Object System.Collections.Generic.List[string]
    $pending = New-Object System.Collections.Generic.Queue[object]
    $pending.Enqueue($Root)
    while ($pending.Count -gt 0) {
        $node = $pending.Dequeue()
        if ($node -is [System.Windows.Controls.TextBlock]) { $out.Add([string]$node.Text) }
        foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($node)) {
            if ($child -is [System.Windows.DependencyObject]) { $pending.Enqueue($child) }
        }
    }
    $out.ToArray()
}

Describe 'ui/Data/AppInfo.ps1 - la versión sale de un solo sitio' {

    It 'la versión es semántica: tres números' {
        Assert-Match '^\d+\.\d+\.\d+$' (Get-AppInfo).Version
    }

    It 'la insignia de la barra de título enseña esa versión' {
        $ventana = New-AppWindow -Language 'en'
        Update-TitleBarTexts $ventana
        Assert-Equal ('v' + (Get-AppInfo).Version) ([string]$ventana.FindName('AppVersionBadge').Text)
    }

    It 'build.ps1 no lleva una versión escrita a mano' {
        # Si alguien vuelve a poner -version '1.0.0.0' en build.ps1, el
        # .exe y la aplicación acabarán diciendo versiones distintas.
        $build = Get-Content -Path (Join-Path (Get-AppRoot) 'build.ps1') -Raw
        Assert-False ($build -match "-version\s+'") 'la versión del .exe tiene que salir de ui/Data/AppInfo.ps1'
        Assert-Match 'ui\\Data\\AppInfo\.ps1' $build
    }

    It 'el repositorio es un enlace que ExternalLink deja abrir' {
        Assert-True (Test-ExternalLinkAllowed (Get-AppInfo).Repository)
    }
}

Describe 'ui/Components/Shell/AboutMenu.ps1 - el panel del botón ?' {

    It 'el botón ? queda enganchado a su panel' {
        $ventana = New-AppWindow -Language 'en'
        Initialize-AboutMenu -Window $ventana

        $popup = $ventana.FindName('AboutPopup')
        Assert-NotNull $popup 'no se ha registrado AboutPopup'
        Assert-True ([object]::ReferenceEquals($popup, $ventana.FindName('BtnHelp').Tag))
    }

    It 'al pulsarlo se arma el panel con nombre, versión y detalles' {
        $ventana = New-AppWindow -Language 'en'
        Initialize-AboutMenu -Window $ventana
        $boton = $ventana.FindName('BtnHelp')

        Assert-NoThrow { Switch-AboutMenu $boton }
        $popup = $ventana.FindName('AboutPopup')
        Assert-NotNull $popup.Child 'el panel no se ha construido'

        $textos = Get-AboutTexts $popup.Child
        $info = Get-AppInfo
        Assert-True ($textos -contains $info.Name) 'falta el nombre'
        Assert-True ($textos -contains ('Version ' + $info.Version)) 'falta la versión'
        Assert-True ($textos -contains $info.Description) 'falta la descripción'
        Assert-True ($textos -contains 'Running as') 'falta la fila de cómo se ejecuta'
        Assert-True ($textos -contains 'View the project on GitHub') 'falta el enlace'
    }

    It 'lo que se copia lleva la versión y cada dato en su línea' {
        $info = Get-AppInfo
        $texto = Get-AboutText $info (Get-AppRuntimeInfo)
        $lineas = $texto -split "`r?`n"

        Assert-Equal ('{0} {1}' -f $info.Name, $info.Version) $lineas[0]
        Assert-Equal 7 $lineas.Count
        Assert-True (@($lineas | Where-Object { $_ -like 'Windows: *' }).Count -eq 1) 'falta la línea de Windows'
    }

    It 'en español sale traducido' {
        $ventana = New-AppWindow -Language 'es'
        $card = New-AboutCard $ventana $null
        $textos = Get-AboutTexts $card
        Set-AppLanguage 'en'

        Assert-True ($textos -contains ('Versión ' + (Get-AppInfo).Version)) 'la versión no sale en español'
        Assert-True ($textos -contains 'Se ejecuta como')
        Assert-True ($textos -contains 'Ver el proyecto en GitHub')
    }
}
