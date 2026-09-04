# ------------------------------------------------------------
# Categoría: Sound
# Ejemplo de categoría mínima: un solo ajuste y sin distintivo.
# ------------------------------------------------------------

Register-Category @{
    Id          = 'sound'
    Name        = 'Sound'
    Icon        = 'Volume'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Description = 'System Sounds'

    Default     = 7
    Total       = 7

    Items = @(
        New-Setting -Name 'Startup Sound' `
            -Description 'Play the Windows startup sound when signing in' `
            -Tags 'Default' `
            -Value $true
    )
}
