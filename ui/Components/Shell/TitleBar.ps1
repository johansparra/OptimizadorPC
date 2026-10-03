# ============================================================
# Componente: barra de título
#
# El XAML deja los textos en inglés porque no puede llamar a T;
# aquí se traducen al arrancar y cada vez que cambia el idioma.
# ============================================================

function Update-TitleBarTexts {
    param($Window)

    $Window.FindName('BtnLog').ToolTip   = T 'Activity log'
    $Window.FindName('BtnTheme').ToolTip = T 'Change theme'
    $Window.FindName('BtnHelp').ToolTip  = T 'About this program'

    # La versión sale de ui/Data/AppInfo.ps1, la misma que lleva el .exe.
    $Window.FindName('AppVersionBadge').Text = 'v' + (Get-AppInfo).Version

    Sync-AdminBadge $Window
}

<#
    La insignia de permisos, junto a la versión.

    El programa está pensado para correr SIEMPRE como administrador (el
    .exe lo pide al abrirse). Si no -main.ps1 lanzado a mano, o alguien
    rechazó el aviso de UAC-, la insignia se pone en ámbar y lo dice, y
    las acciones que necesitan permisos salen apagadas en su sección.
#>
function Sync-AdminBadge {
    param($Window)

    $badge = $Window.FindName('AdminBadge')
    if (-not $badge) { return }
    $icon = $Window.FindName('AdminBadgeIcon')
    $text = $Window.FindName('AdminBadgeText')

    if (Test-AppElevated) {
        $icon.Text = Glyph 'Shield'
        $text.Text = T 'Administrator'
        $badge.ToolTip = T 'Running with administrator permissions'
        Set-BoxBg $badge 'SuccessSoft'
        Set-TextFg $icon 'Success'
        Set-TextFg $text 'Success'
    }
    else {
        $icon.Text = Glyph 'Warning'
        $text.Text = T 'Not administrator'
        $badge.ToolTip = T 'Running without administrator permissions: the actions that need them are disabled. Close the program and open it as administrator.'
        Set-BoxBg $badge 'WarnSoft'
        Set-TextFg $icon 'Warn'
        Set-TextFg $text 'Warn'
    }

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
