# ============================================================
# Vista: Settings
#
# Se dibuja sola a partir de lo que haya registrado en
# ui/Data/Preferences/: recorre los grupos y, dentro de cada uno,
# sus opciones. Añadir una opción nueva NO requiere tocar este
# archivo.
# ============================================================

function Show-SettingsView {
    param($Window)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Settings') `
        -Subtitle (T 'Preferences for the application itself')

    Add-PageActionLabel $Window (T 'Saved automatically')

    # ---- 2. Cuerpo: un bloque por grupo ----
    $list = New-Object System.Windows.Controls.StackPanel

    foreach ($group in Get-PreferenceGroups) {
        $list.Children.Add((New-SectionHeader $Window (T $group))) | Out-Null

        foreach ($preference in Get-Preferences) {
            if ($preference.Group -ne $group) { continue }
            $list.Children.Add((New-PreferenceCard -Window $Window -Preference $preference)) | Out-Null
        }
    }

    # ---- 3. Pintar con entrada en cascada ----
    $Window.FindName('MainContent').Content = $list
    Start-StaggeredEnter $list
}
