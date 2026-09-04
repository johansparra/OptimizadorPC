# ------------------------------------------------------------
# Categoría: Notifications
# ------------------------------------------------------------

Register-Category @{
    Id          = 'notifications'
    Name        = 'Notifications'
    Icon        = 'Bell'
    Accent      = 'Warn'
    AccentSoft  = 'WarnSoft'
    Badge       = $null
    Description = 'Additional Settings, System Notifications, Privacy Notifications, Security Notifications'

    Recommended = 7
    Default     = 9
    Custom      = 0
    Total       = 15

    Items = @(
        New-Setting -Name 'Windows Tips & Suggestions' `
            -Description 'Show occasional tips, tricks, and suggestions as you use Windows' `
            -Tags 'Recommended', 'Default' `
            -Value $false

        New-Setting -Name 'Lock Screen Suggestions' `
            -Description 'Show fun facts, tips, and other suggestions on the lock screen' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false
    )
}
