# ------------------------------------------------------------
# Categoría: Privacy & Security
# Todo lo de esta sección vive aquí. Para quitarla del programa,
# borra este archivo. Ver ui/CategoryRegistry.ps1 para el formato.
# ------------------------------------------------------------

Register-Category @{
    Id          = 'privacy'
    Name        = 'Privacy & Security'
    Icon        = 'Shield'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    Badge       = 'NEW 45'
    Description = 'Security, Content Delivery & Advertising, Lock Screen, General, ...'

    Recommended = 29
    Default     = 59
    Custom      = 0
    Total       = 88

    Items = @(
        New-Setting -Name 'User Account Control Level' `
            -Description 'Controls UAC notification level and secure desktop behavior' `
            -Tags 'Preference', 'Recommended', 'Default', 'Custom' `
            -Options 'Always notify', 'Notify when apps try to make changes', 'Notify me only (no dim)', 'Never notify' `
            -Value 'Notify when apps try to make changes'

        New-Setting -Name 'Workplace Join Message Prompts' `
            -Description "Show 'Allow my organization to manage my device' prompts throughout Windows" `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $true

        New-Setting -Name 'BitLocker Auto Encryption' `
            -Description 'Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device' `
            -Tags 'Preference', 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'WiFi-Sense' `
            -Description 'Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots' `
            -Tags 'Recommended', 'Custom' `
            -Value $true

        New-Setting -Name 'Automatic Maintenance' `
            -Description 'Choose if Windows should run automatic system maintenance tasks during idle time' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'Windows Error Reporting' `
            -Description 'Choose if Windows should collect and send crash reports and error information to Microsoft' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false
    )
}
