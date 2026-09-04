# ------------------------------------------------------------
# Categoría: Power
# ------------------------------------------------------------

Register-Category @{
    Id          = 'power'
    Name        = 'Power'
    Icon        = 'Power'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Badge       = $null
    Description = 'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...'

    Recommended = 18
    Default     = 23
    Custom      = 2
    Total       = 34

    Items = @(
        New-Setting -Name 'High Performance Power Plan' `
            -Description 'Switch to the High Performance / Ultimate Performance power scheme' `
            -Tags 'Recommended', 'Default' `
            -Value $true

        New-Setting -Name 'USB Selective Suspend' `
            -Description 'Allow Windows to power down idle USB devices to save energy' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'Hibernation' `
            -Description 'Enable or disable hibernate mode and the hiberfil.sys reserved space' `
            -Tags 'Default' `
            -Value $true
    )
}
