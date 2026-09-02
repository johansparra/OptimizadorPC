# ------------------------------------------------------------
# Categoría: Update
# ------------------------------------------------------------

Register-Category @{
    Id          = 'update'
    Name        = 'Update'
    Icon        = 'Sync'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    Badge       = 'NEW 1'
    Description = 'Update Policy, Delivery & Store, Update Behavior'

    Recommended = 5
    Default     = 8
    Custom      = 1
    Total       = 12

    Items = @(
        New-Setting -Name 'Delivery Optimization (P2P)' `
            -Description 'Allow Windows to download/upload updates to and from other PCs on the internet' `
            -Tags 'Recommended', 'Default' `
            -Value $false

        New-Setting -Name 'Auto-Restart With Active Sessions' `
            -Description 'Allow Windows Update to restart the PC automatically while you are logged in' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false
    )
}
