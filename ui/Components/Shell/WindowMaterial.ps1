# ============================================================
# Componente: material de la ventana (Mica / Acrílico)
#
# El fondo translúcido de verdad de Windows 11: en vez de pintar
# nosotros el fondo, se lo pedimos al sistema y la ventana deja
# ver -borroso y teñido- el escritorio que tiene detrás.
#
# La llamada a Windows la hace core/Interop/SystemBackdrop.ps1;
# aquí solo está lo que sabe de la ventana.
#
# POR QUÉ VIENE APAGADO DE FÁBRICA
#
# Mica y el degradado propio son EXCLUYENTES: el material del
# sistema solo se ve si nuestra ventana es translúcida, y una
# ventana translúcida ya no puede tener su propio fondo. Así que
# esto no "añade" nada, cambia una cosa por otra:
#
#     Solid    -> BgGradient  (el degradado de la casa, opaco)
#     Mica     -> BgGlassGradient sobre el material del sistema
#     Acrylic  -> lo mismo, con el desenfoque más marcado
#
# Y solo funciona en Windows 11 22H2 o superior. Por eso es una
# preferencia (ui/Data/Preferences/30-Material.ps1) y no una
# decisión tomada por el programa: en un equipo antiguo o con un
# escritorio muy cargado, el fondo propio se ve mejor.
#
# NO SE APLICA HASTA SourceInitialized. Antes de eso la ventana no
# tiene descriptor, y sin descriptor no hay a qué ponerle nada;
# main.ps1 lo engancha ahí.
# ============================================================

$WindowMaterials = @('None', 'Mica', 'Acrylic')

# Qué superficies se vuelven de cristal al encender el material.
# Con el fondo translúcido, una barra de título opaca cortaría el
# efecto por la mitad.
function Get-WindowMaterial {
    $value = [string](Get-AppSetting 'Material' -Default 'None')
    if ($WindowMaterials -notcontains $value) { return 'None' }
    $value
}

# Guarda la elección y la aplica. Es lo que llama la opción de
# Settings; el arranque pasa por Sync-WindowMaterial directamente.
function Set-WindowMaterialChoice {
    param([string]$Value)

    if ($WindowMaterials -notcontains $Value) { $Value = 'None' }
    Set-AppSetting 'Material' $Value
    Sync-WindowMaterial -Window (Get-AppWindow)
}

<#
    Pone la ventana como diga la preferencia.

    Si Windows no acepta el material -equipo antiguo, o la llamada
    falla- se cae de pie: las superficies se quedan opacas, que es
    exactamente el aspecto de antes. Nunca se deja una ventana
    translúcida sin material detrás, que es como se ve mal de
    verdad.
#>
function Sync-WindowMaterial {
    param($Window)

    if (-not $Window) { return }

    $wanted = Get-WindowMaterial
    $applied = 'None'

    if ($wanted -ne 'None') {
        $handle = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle

        if ($handle -ne [IntPtr]::Zero) {
            $dark = ((Get-AppTheme) -eq 'Dark')

            if (Set-WindowBackdrop -Handle $handle -Kind $wanted -Dark $dark) {
                # WPF pinta un fondo opaco por debajo de todo aunque
                # los controles sean transparentes. Hay que decirle al
                # destino de composición que no lo haga, o el material
                # quedaría tapado por un negro perfecto.
                $source = [System.Windows.Interop.HwndSource]::FromHwnd($handle)
                if ($source -and $source.CompositionTarget) {
                    $source.CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
                }
                $applied = $wanted
            }
        }
    }

    Set-MaterialSurfaces -Window $Window -Applied $applied
}

# Las tres superficies grandes de la ventana, opacas o de cristal.
# Cada una tiene su propia DependencyProperty de fondo: el raíz es
# un Border, la barra de título un Grid y el menú lateral otro
# Border. No son la misma propiedad (ver Set-PanelBg).
function Set-MaterialSurfaces {
    param($Window, [string]$Applied)

    $root    = $Window.FindName('WindowRoot')
    $title   = $Window.FindName('TitleBar')
    $sidebar = $Window.FindName('Sidebar')

    if ($Applied -eq 'None') {
        if ($root)    { Set-BoxBg   $root    'BgGradient' }
        if ($title)   { Set-PanelBg $title   'Bg1' }
        if ($sidebar) { Set-BoxBg   $sidebar 'Bg1' }
        return
    }

    if ($root)    { Set-BoxBg   $root    'BgGlassGradient' }
    if ($title)   { Set-PanelBg $title   'SurfaceGlass' }
    if ($sidebar) { Set-BoxBg   $sidebar 'SurfaceGlass' }
}
