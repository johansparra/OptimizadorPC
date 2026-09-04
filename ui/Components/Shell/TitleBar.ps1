# ============================================================
# Componente: barra de título
#
# El XAML deja los textos en inglés porque no puede llamar a T;
# aquí se traducen al arrancar y cada vez que cambia el idioma.
# ============================================================

function Update-TitleBarTexts {
    param($Window)

    $Window.FindName('BtnModeNormal').Content  = T 'Normal'
    $Window.FindName('BtnModeBuilder').Content = T 'Builder'
    $Window.FindName('BtnModeConfig').Content  = T 'Config Review'

    $Window.FindName('BtnLog').ToolTip   = T 'Activity log'
    $Window.FindName('BtnTheme').ToolTip = T 'Change theme'
    $Window.FindName('BtnHelp').ToolTip  = T 'Help'

    $menu = $Window.FindName('BtnMenu')
    if (Get-SidebarExpanded) { $menu.ToolTip = T 'Hide the menu' } else { $menu.ToolTip = T 'Show the menu' }
}

# El glifo del botón de tema refleja a qué tema se cambiaría:
# con tema claro se ve una luna, con tema oscuro un sol.
function Sync-ThemeButton {
    $window = Get-AppWindow
    if (-not $window) { return }

    $button = $window.FindName('BtnTheme')
    if ((Get-AppTheme) -eq 'Dark') { $button.Content = Glyph 'Sun' } else { $button.Content = Glyph 'Moon' }
}
