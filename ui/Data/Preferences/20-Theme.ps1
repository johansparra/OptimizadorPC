# ------------------------------------------------------------
# Opción: tema claro / oscuro
#
# El botón de la barra de título hace lo mismo; los dos pasan por
# Set-AppTheme y por Set-AppSetting, así que el tema se recuerda
# se cambie desde donde se cambie.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 20
    Id          = 'theme'
    Group       = 'Appearance'
    Label       = 'Theme'
    Description = 'Light or dark colour scheme'
    Type        = 'Choice'

    Options = @(
        @{ Value = 'Light'; Label = 'Light' }
        @{ Value = 'Dark';  Label = 'Dark' }
    )

    Get = { Get-AppTheme }

    Set = {
        param($Value)
        Set-AppTheme -Window (Get-AppWindow) -Name $Value
        Set-AppSetting 'Theme' $Value
        Sync-ThemeButton

        # Con Mica o Acrílico puestos, el material y el borde de la
        # ventana los tiñe DWM y hay que volver a decirle si el
        # contenido es claro u oscuro. Sin material no hace nada.
        Sync-WindowMaterial -Window (Get-AppWindow)
    }
}
