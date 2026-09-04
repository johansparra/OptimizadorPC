# ------------------------------------------------------------
# Categoría: Regedit
# Todo lo de esta sección vive aquí. Para quitarla del programa,
# borra este archivo. Ver ui/Engine/CategoryRegistry.ps1 para el formato.
#
# Cada ajuste declara en -Registry las claves que toca:
#
#   Path / Name / Type   dónde está el valor
#   Recommended          lo que propone el programa
#   Default              el valor de fábrica de Windows
#   Display = 'hex'      enseñarlo como 0xFFFFFFFF y no en decimal
#
# NO se declara Current: lo rellena core/Registry/CategoryState.ps1 leyendo
# el equipo cada vez que se entra en la sección. Escribir en el
# registro sigue sin estar implementado.
# ------------------------------------------------------------

Register-Category @{
    Id          = 'regedit'
    Name        = 'Regedit'
    Icon        = 'Shield'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    # Sin Badge: lo cuenta Register-Category a partir de los Items
    # que llevan -Badge 'NEW'. Marcar uno más sube el número solo.
    Description = 'Windows registry keys'

    Recommended = 29
    Default     = 59
    Custom      = 0
    Total       = 88

    Items = @(
        New-Setting -Name 'Network Throttling Mechanism' `
            -Description 'Limits network packet processing (NDIS) to 10 packets' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
                   Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0xFFFFFFFF'; Default = '0x00000000' }
            )
        New-Setting -Name 'User Account Control Level' `
            -Description 'Controls UAC notification level and secure desktop behavior' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Options 'Always notify', 'Notify when apps try to make changes', 'Notify me only (no dim)', 'Never notify' `
            -Value 'Notify when apps try to make changes' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
                   Name = 'ConsentPromptBehaviorAdmin'; Type = 'DWord'
                   Recommended = '0'; Default = '5' }
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
                   Name = 'PromptOnSecureDesktop'; Type = 'DWord'
                   Recommended = '0'; Default = '1' }
            )

        New-Setting -Name 'Workplace Join Message Prompts' `
            -Description "Show 'Allow my organization to manage my device' prompts throughout Windows" `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
                   Name = 'BlockAADWorkplaceJoin'; Type = 'DWord'
                   Recommended = '1'; Default = '0' }
            )

        New-Setting -Name 'BitLocker Auto Encryption' `
            -Description 'Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\BitLocker'
                   Name = 'PreventDeviceEncryption'; Type = 'DWord'
                   Recommended = '1'; Default = '0' }
            )

        New-Setting -Name 'WiFi-Sense' `
            -Description 'Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots' `
            -Tags 'Recommended', 'Custom' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting'
                   Name = 'Value'; Type = 'DWord'
                   Recommended = '0'; Default = '1' }
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots'
                   Name = 'Value'; Type = 'DWord'
                   Recommended = '0'; Default = '1' }
            )

        New-Setting -Name 'Automatic Maintenance' `
            -Description 'Choose if Windows should run automatic system maintenance tasks during idle time' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'
                   Name = 'MaintenanceDisabled'; Type = 'DWord'
                   Recommended = '0'; Default = '0' }
            )

        New-Setting -Name 'Windows Error Reporting' `
            -Description 'Choose if Windows should collect and send crash reports and error information to Microsoft' `
            -Tags 'Recommended', 'Default', 'Custom' `
            -Value $false `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
                   Name = 'Disabled'; Type = 'DWord'
                   Recommended = '1'; Default = '0' }
            )
    )
}
