# ------------------------------------------------------------
# Categoría: Update
#
# Dos directivas de Windows Update, UNA POR CLAVE, con el mismo
# formato que ui/Data/Categories/Regedit.ps1 (ver su cabecera):
# -Registry con Recommended, sin -Tags y sin contadores a mano. El
# estado de cada tarjeta y las píldoras de la sección salen de leer
# el equipo (core/Registry/SettingStatus.ps1).
#
# Las dos claves cuelgan de HKLM\SOFTWARE\Policies\Microsoft, que ya
# es una rama de la lista blanca de core/Registry/Writer.ps1. No se
# ha abierto nada nuevo.
#
# De fábrica NINGUNA de las dos existe: la directiva está "sin
# configurar" y Windows usa su comportamiento propio. Por eso no
# declaran Default sino DefaultAbsent = $true: OFF BORRA el valor
# (solo el valor, la clave se queda) en vez de dejar una directiva
# puesta con otro número. Ver SECURITY.md §3.2.
#
# 'Auto-Restart With Active Sessions' escribe
# NoAutoRebootWithLoggedOnUsers, que está en la lista de valores que
# bajan la seguridad (SECURITY.md §3.4): lleva -AllowsSecurityTradeoff
# y su descripción dice lo que se pierde.
#
# 'Delivery Optimization (P2P)' toca el MISMO valor que el ajuste
# 'Delivery Optimization (Policy)' de Regedit. Es a propósito: es la
# directiva de esta sección. Los dos proponen el mismo valor (0).
# ------------------------------------------------------------

Register-Category @{
    Id          = 'update'
    Name        = 'Update'
    Icon        = 'Sync'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    Badge       = 'NEW 1'
    Description = 'Update Policy, Delivery & Store, Update Behavior'

    # SIN contadores a mano (Recommended / Default / Custom / Total):
    # las píldoras se cuentan por el estado real de cada ajuste
    # (Get-CategoryStatusCounts), igual que en Regedit.

    Items = @(
        New-Setting -Name 'Delivery Optimization (P2P)' `
            -Description 'Download updates only from Microsoft, never from or to other PCs' `
            -WhatItDoes 'Group policy "Download Mode" set to HTTP only: Windows Update and the Store stop sharing pieces of updates with other PCs, on your network or on the internet. Updates still install normally. Turning it off removes the policy and Windows goes back to its own setting' `
            -Values 'Not set (default; Windows uses 1, PCs on the local network) - 0x00000000 (HTTP only, no other PCs) - 0x00000003 (also PCs on the internet)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Stops update uploads to other PCs from using your connection' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
                   Name = 'DODownloadMode'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; DefaultAbsent = $true }
            )

        New-Setting -Name 'Auto-Restart With Active Sessions' `
            -Description 'Stop Windows Update from restarting the PC while you are signed in. Lowers security: fixes that need a restart wait until you restart' `
            -WhatItDoes 'Policy "No auto-restart with logged on users for scheduled automatic updates installations". While someone is signed in, Windows waits for you to restart instead of doing it on its own, so security fixes that need a restart are not applied until then. Microsoft warns that on a PC nobody signs out of, updates may never restart. Windows only honours it when "Configure Automatic Updates" is set to scheduled install (option 4)' `
            -Values 'Not set (default; Windows may restart on its own outside active hours) - 0x00000001 (no automatic restart while signed in)' `
            -GamingOptimal 'na' `
            -GamingNote 'Avoids restarts during a match, but security fixes wait for you' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/update/waas-restart' `
            -AllowsSecurityTradeoff `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                   Name = 'NoAutoRebootWithLoggedOnUsers'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; DefaultAbsent = $true }
            )
    )
}
