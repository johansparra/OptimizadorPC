# ============================================================
# Pruebas de los menus "Expandir" / "Contraer" de la cabecera del
# detalle (ui/Views/CategoryDetailView.ps1) y de la maquinaria que
# reutilizan:
#
#   - Close-DisclosureSection: el reverso sin animacion de Open-
#     (ui/Components/Cards/Disclosure.ps1).
#   - el Kind estable en el Tag de cada franja, que es como se
#     apunta a "solo Referencia" / "solo Detalles tecnicos" sin
#     mirar la etiqueta traducida.
#   - Set-CategoryDisclosures -Open [-Kind]: recorre las tarjetas ya
#     pintadas y abre/cierra los cuerpos, sin recrear el contenido.
#   - New-ChipMenu (ui/Components/Shell/ChipMenu.ps1): el chip con
#     Popup de acciones que usan los dos menus.
#
# Nada abre el Popup de verdad (IsOpen = $true crea una ventana de
# Windows y ninguna prueba muestra ninguna): se dispara el
# MouseLeftButtonUp de la fila, que es lo que corre al pulsarla.
#
# 'reference' se enciende y se apaga en cada prueba que lo necesita,
# sobre el settings.json redirigido del arnes, nunca el del usuario.
# ============================================================

$BulkWindow = New-AppWindow -Language 'en'

function New-BulkSetting {
    New-Setting -Name 'Ajuste de prueba' -Description 'x' -Value $true -Registry @(
        @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; Name = 'V'; Type = 'DWord'
           Recommended = '1'; Default = '0' }
    )
}

# Franjas plegables de un arbol (Border con Body en el Tag),
# opcionalmente filtradas por Kind ('reference' / 'technical').
# Devuelve siempre un array (posiblemente vacio).
function Get-Headers {
    param($Root, [string]$Kind)
    $all = Find-Visuals $Root {
        param($el)
        $el -is [System.Windows.Controls.Border] -and
        $el.Tag -and $el.Tag.PSObject.Properties['Body']
    }
    $sel = if ($Kind) { $all | Where-Object { [string]$_.Tag.Kind -eq $Kind } } else { $all }
    , @($sel)
}

function Assert-BodiesAre {
    param($Headers, [string]$Expected, [string]$Msg)
    foreach ($h in $Headers) {
        Assert-Equal $Expected ([string]$h.Tag.Body.Visibility) $Msg
    }
}

# El chip-menu (Grid con boton + Popup) cuyo boton dice $Label.
function Get-ChipMenuShell {
    param($Window, [string]$Label)
    $btn = (Find-Visuals ($Window.FindName('HeaderActionsArea')) {
        param($el)
        $el -is [System.Windows.Controls.Button] -and
        (Get-VisualText $el) -match [regex]::Escape($Label)
    })[0]
    if ($btn) { $btn.Parent } else { $null }
}

# La fila del menu $Shell cuya etiqueta contiene $Label. Solo las
# filas de accion llevan OnClick en el Tag.
function Get-MenuRow {
    param($Shell, [string]$Label)
    (Find-Visuals $Shell {
        param($el)
        $el -is [System.Windows.Controls.Border] -and
        $el.Tag -and $el.Tag.PSObject.Properties['OnClick'] -and
        (Get-VisualText $el) -match [regex]::Escape($Label)
    })[0]
}

function Invoke-MenuRow {
    param($Shell, [string]$Label)
    $row = Get-MenuRow $Shell $Label
    Assert-NotNull $row "no se ha encontrado la fila '$Label'"
    $clic = New-Object System.Windows.Input.MouseButtonEventArgs `
        ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
    $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
    $row.RaiseEvent($clic)
}

function Invoke-RowClick {
    param($Header)
    $clic = New-Object System.Windows.Input.MouseButtonEventArgs `
        ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
    $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
    $Header.RaiseEvent($clic)
}

# Pinta el detalle de Regedit y devuelve la ventana. No toca
# opciones de vista: eso lo hace cada prueba con su try/finally.
function Show-RegeditDetail {
    $ventana = New-AppWindow -Language 'en'
    Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
    $ventana
}

Describe 'ui/Components/Cards/Disclosure.ps1 - Kind identifica cada franja' {

    function Get-OneHeader { param($Pie) (Get-Headers $Pie)[0] }

    It '"Detalles tecnicos" se marca como technical' {
        $header = Get-OneHeader (New-TechnicalDetails $BulkWindow (New-BulkSetting))
        Assert-Equal 'technical' ([string]$header.Tag.Kind)
    }

    It '"Referencia" se marca como reference' {
        $header = Get-OneHeader (New-SettingReference $BulkWindow (New-BulkSetting))
        Assert-Equal 'reference' ([string]$header.Tag.Kind)
    }

    It 'una franja sin Kind sigue construyendose sin romperse' {
        $pie = New-DisclosureSection -Window $BulkWindow -Icon 'Info' -Label 'Technical details' `
            -Body (New-Object System.Windows.Controls.StackPanel)
        $header = Get-OneHeader $pie
        Assert-NotNull $header
        Assert-Equal '' ([string]$header.Tag.Kind)
    }
}

Describe 'ui/Components/Cards/Disclosure.ps1 - Close-DisclosureSection' {

    function Get-OneHeader { param($Pie) (Get-Headers $Pie)[0] }

    It 'cierra una franja abierta y le devuelve chevron y redondeo' {
        $header = Get-OneHeader (New-TechnicalDetails $BulkWindow (New-BulkSetting))

        Open-DisclosureSection $header
        Assert-Equal 'Visible' ([string]$header.Tag.Body.Visibility)

        Close-DisclosureSection $header
        Assert-Equal 'Collapsed' ([string]$header.Tag.Body.Visibility)
        Assert-Equal 'Collapsed' ([string]$header.Tag.Split.Visibility)
        Assert-Equal (Glyph 'ChevronDown') ([string]$header.Tag.Chevron.Text)
        Assert-Equal 15 $header.CornerRadius.BottomLeft
        Assert-Equal 15 $header.CornerRadius.BottomRight
    }

    It 'cerrar una franja ya cerrada no hace nada' {
        $header = Get-OneHeader (New-TechnicalDetails $BulkWindow (New-BulkSetting))
        Assert-NoThrow { Close-DisclosureSection $header }
        Assert-Equal 'Collapsed' ([string]$header.Tag.Body.Visibility)
    }

    It 'open y luego close deja el mismo estado que al construir' {
        $header = Get-OneHeader (New-TechnicalDetails $BulkWindow (New-BulkSetting))
        $chevron0 = [string]$header.Tag.Chevron.Text
        $radio0   = $header.CornerRadius.BottomLeft

        Open-DisclosureSection  $header
        Close-DisclosureSection $header

        Assert-Equal 'Collapsed' ([string]$header.Tag.Body.Visibility)
        Assert-Equal $chevron0 ([string]$header.Tag.Chevron.Text)
        Assert-Equal $radio0 $header.CornerRadius.BottomLeft
    }
}

Describe 'ui/Views/CategoryDetailView.ps1 - Set-CategoryDisclosures filtra por Kind' {

    It '-Kind reference solo abre las franjas Referencia' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content
            Assert-True ((Get-Headers $c 'reference').Count -gt 0) 'deberia haber franjas Referencia'

            Set-CategoryDisclosures -Open $true -Kind 'reference'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Visible'   'las Referencia deberian abrirse'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Collapsed' 'las Detalles tecnicos no debian tocarse'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It '-Kind technical solo abre las franjas Detalles tecnicos' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Set-CategoryDisclosures -Open $true -Kind 'technical'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Visible'   'las Detalles tecnicos deberian abrirse'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Collapsed' 'las Referencia no debian tocarse'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'sin -Kind abre las dos secciones' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Set-CategoryDisclosures -Open $true
            Assert-BodiesAre (Get-Headers $c) 'Visible' 'todas las franjas deberian abrirse'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'cerrar por Kind respeta la otra seccion' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Set-CategoryDisclosures -Open $true
            Set-CategoryDisclosures -Open $false -Kind 'technical'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Collapsed' 'las Detalles tecnicos deberian cerrarse'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Visible'   'las Referencia debian seguir abiertas'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'no recrea MainContent.Content' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Set-CategoryDisclosures -Open $true
            Set-CategoryDisclosures -Open $false
            Assert-Equal $c $ventana.FindName('MainContent').Content 'la seccion se ha repintado'
        }
        finally { Set-ViewOption 'reference' $false }
    }
}

Describe 'ui/Views/CategoryDetailView.ps1 - los menus Expandir / Contraer' {

    It 'la cabecera de Regedit trae los dos menus con sus tres opciones' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

            $expand   = Get-ChipMenuShell $ventana 'Expand'
            $collapse = Get-ChipMenuShell $ventana 'Collapse'
            Assert-NotNull $expand   'falta el menu Expandir'
            Assert-NotNull $collapse 'falta el menu Contraer'

            foreach ($shell in @($expand, $collapse)) {
                $t = Get-VisualText $shell
                Assert-Match 'Reference'         $t
                Assert-Match 'Technical details' $t
                Assert-Match 'All'               $t
            }
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It '"Expandir -> Referencia" solo abre Referencia y no repinta' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'Reference'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Visible'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Collapsed'
            Assert-Equal $c $ventana.FindName('MainContent').Content
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It '"Expandir -> Detalles tecnicos" solo abre Detalles tecnicos' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'Technical details'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Visible'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Collapsed'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It '"Expandir -> Todo" abre las dos y "Contraer -> Todo" las cierra' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'All'
            Assert-BodiesAre (Get-Headers $c) 'Visible' 'Todo deberia abrir ambas'

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Collapse') 'All'
            Assert-BodiesAre (Get-Headers $c) 'Collapsed' 'Todo deberia cerrar ambas'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It '"Contraer -> Detalles tecnicos" no toca Referencia' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand')   'All'
            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Collapse') 'Technical details'
            Assert-BodiesAre (Get-Headers $c 'technical') 'Collapsed'
            Assert-BodiesAre (Get-Headers $c 'reference') 'Visible'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'acciones consecutivas dejan el estado consistente' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content
            $expand   = Get-ChipMenuShell $ventana 'Expand'
            $collapse = Get-ChipMenuShell $ventana 'Collapse'

            Invoke-MenuRow $expand   'All'
            Invoke-MenuRow $collapse 'Reference'
            Invoke-MenuRow $expand   'Reference'
            Invoke-MenuRow $collapse 'Technical details'
            Invoke-MenuRow $expand   'Technical details'
            Invoke-MenuRow $collapse 'All'

            Assert-BodiesAre (Get-Headers $c) 'Collapsed' 'la ultima orden fue "Contraer Todo"'
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'tras un menu, la fila individual de una franja se sigue plegando a mano' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'reference' $true
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            $c = $ventana.FindName('MainContent').Content

            Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'All'
            $headers = Get-Headers $c
            Assert-True ($headers.Count -ge 2) 'hace falta mas de una franja'

            Invoke-RowClick $headers[0]
            Assert-Equal 'Collapsed' ([string]$headers[0].Tag.Body.Visibility) 'la fila pulsada deberia cerrarse'
            for ($i = 1; $i -lt $headers.Count; $i++) {
                Assert-Equal 'Visible' ([string]$headers[$i].Tag.Body.Visibility) "la franja $i no debia moverse"
            }
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'por defecto (solo Detalles tecnicos) los menus salen igual y "Todo" abre esas franjas' {
        $ventana = Show-RegeditDetail   # 'reference' viene apagada
        $c = $ventana.FindName('MainContent').Content

        Assert-NotNull (Get-ChipMenuShell $ventana 'Expand') 'el menu Expandir deberia salir igual'
        Assert-Equal 0 (Get-Headers $c 'reference').Count 'sin la opcion no hay franjas Referencia'

        Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'All'
        Assert-BodiesAre (Get-Headers $c 'technical') 'Visible'

        # La fila "Referencia" es un no-op limpio: no hay nada que abrir.
        Assert-NoThrow { Invoke-MenuRow (Get-ChipMenuShell $ventana 'Expand') 'Reference' }
    }

    It 'una seccion que no lee el registro no trae los menus' {
        $ventana = New-AppWindow -Language 'en'
        $cat = Get-OptimizationCategories | Where-Object { (Get-CategoryRegistryKeyCount $_) -eq 0 } | Select-Object -First 1
        if (-not $cat) { Skip-Test 'todas las secciones leen ya el registro' }

        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        Assert-Null (Get-ChipMenuShell $ventana 'Expand')   'no deberia haber menu Expandir'
        Assert-Null (Get-ChipMenuShell $ventana 'Collapse') 'no deberia haber menu Contraer'
    }

    It 'sin ninguna franja activada en Vista, Regedit tampoco los trae' {
        $ventana = New-AppWindow -Language 'en'
        Set-ViewOption 'technical' $false   # 'reference' ya viene apagada
        try {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }
            Assert-Null (Get-ChipMenuShell $ventana 'Expand') 'sin franjas no hay nada que plegar'
        }
        finally { Set-ViewOption 'technical' $true }
    }
}
