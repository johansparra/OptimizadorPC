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
# el equipo cada vez que se entra en la sección.
#
# La ESCRITURA ya existe. Al pulsar el toggle de un ajuste con
# -Registry, core/Registry/SettingApply.ps1 escribe cada clave:
# ON  -> su Recommended,  OFF -> su Default. Corre elevado y va por
# la lista blanca de rutas de core/Registry/Writer.ps1. Por eso
# Recommended y Default son también el contrato de reversión: OFF
# vuelve al Default declarado, y si el valor estaba personalizado,
# core/Registry/Writer.ps1 guarda copia del anterior en memoria.
# Ver SECURITY.md para el modelo de amenaza completo.
#
# TAMPOCO se declaran -Tags. El estado que sale en la tarjeta
# -Optimizado / Recomendado de fábrica / Personalizado- se calcula
# comparando lo leído contra esos dos valores declarados, así que
# escribirlo a mano solo serviría para mentir. Ver
# core/Registry/SettingStatus.ps1.
#
# De ahí que Recommended y Default sean el dato importante de cada
# clave: si están mal, el estado -y la reversión- salen mal.
#
# Las seis claves de esta sección son el bloque MMCSS del paquete
# "BF6 / Gaming Network Tweaks" (ver ../../../../claves_registro_bf6.md).
# Todas cuelgan de ...\Multimedia\SystemProfile, que ya está en la
# lista blanca de Writer.ps1: no hace falta ampliarla. Ninguna toca
# la postura de seguridad del equipo.
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

    # El menú "Vista" es común a toda la aplicación, pero "Grid view"
    # solo reordena la LISTA de secciones: dentro de una sección no
    # cambia nada. Se oculta aquí para no dejar un interruptor muerto
    # en el detalle de Regedit. La preferencia global no se toca.
    HideViewOptions = @('grid')

    # SIN contadores a mano (Recommended / Default / Custom / Total):
    # esta sección lee el registro, así que las píldoras -tanto la
    # fila del detalle como la tarjeta de la lista- se cuentan por el
    # ESTADO REAL de cada ajuste (Get-CategoryStatusCounts). Ponerlos
    # a mano solo serviría para que no cuadraran.

    Items = @(
        New-Setting -Name 'Network Throttling Mechanism' `
            -Description 'Limits network packet processing (NDIS) to 10 packets' `
            -WhatItDoes 'Caps network traffic while Windows detects active audio or video (MMCSS), so the CPU goes to multimedia instead' `
            -Values '0x0000000A (10, default) - 1 to 70 (adjustable) - 0xFFFFFFFF (disables the limit)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Removes network throttling during matches' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
                   Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0xFFFFFFFF'; Default = '0x0000000A' }
            )

        New-Setting -Name 'System Responsiveness' `
            -Description 'Reserve less CPU for background tasks while MMCSS is active' `
            -WhatItDoes 'Sets the percentage of CPU that Windows holds back for non-multimedia work when a multimedia app (audio, video, games) gets priority through MMCSS. Lower value means more CPU for the foreground app' `
            -Values '0x00000014 (20, default) - lower frees more CPU - 0x00000000 (reserve nothing)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Frees the CPU slice held back for background tasks during matches' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
                   Name = 'SystemResponsiveness'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000014' }
            )

        New-Setting -Name 'GPU Priority for Games' `
            -Description "Give the game's GPU work priority over background tasks" `
            -WhatItDoes 'Sets the GPU scheduling priority MMCSS gives to threads a game registers under the "Games" task. 8 is the ceiling for this task class' `
            -Values '0x00000002 (2) - 0x00000008 (8, maximum). Windows 10/11 usually ships the "Games" task at 8 already' `
            -GamingOptimal 'yes' `
            -GamingNote 'Moves game rendering ahead of background GPU work' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
                   Name = 'GPU Priority'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000008'; Default = '0x00000002' }
            )

        New-Setting -Name 'CPU Priority for Games' `
            -Description 'Raise the CPU thread priority of the "Games" MMCSS task' `
            -WhatItDoes 'Sets the CPU priority Windows gives to threads a game registers with MMCSS. The range is 1 to 8; this raises the "Games" task to 6' `
            -Values '0x00000002 (2, default) - 1 to 8 (higher is more) - 0x00000006 (used here)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Keeps the game scheduled ahead of normal background threads' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
                   Name = 'Priority'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000006'; Default = '0x00000002' }
            )

        New-Setting -Name 'Scheduling Category for Games' `
            -Description 'Put the "Games" MMCSS task in the High scheduling class' `
            -WhatItDoes 'Sets the scheduling category of the MMCSS "Games" task, which controls the kernel priority boost its threads get. Windows ships it at Medium' `
            -Values 'Medium (default) - High - Low' `
            -GamingOptimal 'yes' `
            -GamingNote 'High gives smoother frame pacing under load' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
                   Name = 'Scheduling Category'; Type = 'String'
                   Recommended = 'High'; Default = 'Medium' }
            )

        New-Setting -Name 'Disk I/O Priority for Games' `
            -Description 'Raise the disk I/O priority of the "Games" MMCSS task' `
            -WhatItDoes 'Sets the storage I/O priority Windows gives to threads of the MMCSS "Games" task. Windows ships it at Normal' `
            -Values 'Normal (default) - High - Low' `
            -GamingOptimal 'yes' `
            -GamingNote 'Cuts I/O waits while a match streams assets' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
                   Name = 'SFIO Priority'; Type = 'String'
                   Recommended = 'High'; Default = 'Normal' }
            )
    )
}
