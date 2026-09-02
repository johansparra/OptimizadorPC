# ------------------------------------------------------------
# Categoría: Gaming & Performance
# ------------------------------------------------------------

Register-Category @{
    Id          = 'gaming'
    Name        = 'Gaming & Performance'
    Icon        = 'Game'
    Accent      = 'Warn'
    AccentSoft  = 'WarnSoft'
    Badge       = 'NEW 16'
    Description = 'Processor, Graphics, Network, Security, ...'

    Recommended = 65
    Default     = 47
    Custom      = 2
    Total       = 112

    Items = @(
        New-Setting -Name 'Game Mode' `
            -Description 'Optimize your PC for play by turning things off in the background' `
            -Tags 'Recommended', 'Default' `
            -Value $true

        New-Setting -Name 'Enhance Pointer Precision' `
            -Description 'Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games' `
            -Tags 'Preference', 'Recommended' `
            -Value $false

        New-Setting -Name 'Mouse Hover Time' `
            -Description 'Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms' `
            -Tags 'Preference', 'Recommended', 'Default', 'Custom' `
            -Options '100ms', '200ms', '400ms (Default)', '600ms' `
            -Value '400ms (Default)' `
            -Badge 'NEW'

        New-Setting -Name 'Startup Delay for Apps' `
            -Description 'Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load' `
            -Tags 'Preference', 'Recommended', 'Default', 'Custom' `
            -Value $false

        New-Setting -Name 'Background App Permissions' `
            -Description 'Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp' `
            -Tags 'Preference', 'Recommended', 'Default', 'Custom' `
            -Options 'User in Control', 'Force Allow', 'Force Deny' `
            -Value 'Force Deny' `
            -Badge 'NEW'
    )
}
