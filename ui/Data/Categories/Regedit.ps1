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
# la lista blanca de core/Registry/Writer.ps1. Por eso
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
# Las claves son el paquete "BF6 / Gaming Network Tweaks"
# (../../../../bf6_network_tweaks.reg), en el mismo orden. Las seis
# primeras (MMCSS) cuelgan de ...\Multimedia\SystemProfile, que es una
# rama de la lista blanca; el resto entra valor a valor por
# $RegistryWriteAllowedValues de Writer.ps1, o por la rama de
# SOFTWARE\Policies\Microsoft.
#
# Del .reg se quedan FUERA a propósito:
#   - Lo que Windows 11 ya trae así de fábrica (Modo de juego, Ndu=2,
#     SackOpts, TcpMaxDupAcks, TcpMaxDataRetransmissions, PMTU, Winsock
#     Min/MaxSockAddrLength, ShowHibernateOption): Recommended = Default,
#     la tarjeta diría siempre "de fábrica" y el toggle no haría nada.
#   - TcpWindowSize / GlobalMaxTcpWindowSize: Windows 10/11 no los lee
#     (los sustituye el autoajuste de ventana) y no hay de fábrica que
#     escribir.
#   - NumberOfSIUFInPeriod: de fábrica el valor NO existe y Writer.ps1
#     todavía no sabe borrar.
#   - La capa de compatibilidad de bf6.exe: lleva una ruta de este
#     equipo concreto (D:\juegos\...).
#
# Ninguno toca la postura de seguridad del equipo (SECURITY.md §3.4).
# DisableWpbtExecution la SUBE.
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
        # ---- 1-2) MMCSS ---------------------------------------------

        New-Setting -Name 'Network Throttling Mechanism' `
            -Description 'Limits network packet processing (NDIS) to 10 packets' `
            -WhatItDoes 'Caps network traffic while Windows detects active audio or video (MMCSS), so the CPU goes to multimedia instead' `
            -Values '0x0000000A (10, default) - 1 to 70 (adjustable) - 0xFFFFFFFF (disables the limit)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Removes network throttling during matches' `
            -Link 'https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service' `
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
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
                   Name = 'SFIO Priority'; Type = 'String'
                   Recommended = 'High'; Default = 'Normal' }
            )

        # ---- 3) TCP/IP global ---------------------------------------
        # Valores sueltos de ...\Tcpip\Parameters: Windows usa su valor
        # interno mientras no existen. Ninguno toca ...\Interfaces.

        New-Setting -Name 'Default TTL' `
            -Description 'Lower the starting hop limit of outgoing IP packets' `
            -WhatItDoes 'Sets the Time To Live that Windows puts on every packet it sends. It only limits how many routers a packet may cross; it does not change latency or speed' `
            -Values '0x00000080 (128, Windows) - 0x00000040 (64, Linux and consoles) - 1 to 255' `
            -GamingOptimal 'na' `
            -GamingNote 'No measurable effect on ping; 64 is enough for any route on the internet' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                   Name = 'DefaultTTL'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000040'; Default = '0x00000080' }
            )

        New-Setting -Name 'TCP Timestamps (RFC 1323)' `
            -Description 'Turn on TCP timestamps on top of window scaling' `
            -WhatItDoes 'Bit 0 enables TCP window scaling and bit 1 enables timestamps. Windows 10/11 already scales the window and leaves timestamps off (same as 1); 3 adds timestamps, which improve round-trip measurement at the cost of 12 bytes per packet' `
            -Values '0x00000001 (window scaling only, Windows behaviour) - 0x00000003 (scaling + timestamps) - 0x00000000 (both off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Games mostly use UDP, which TCP options do not touch' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                   Name = 'Tcp1323Opts'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000003'; Default = '0x00000001' }
            )

        New-Setting -Name 'TIME_WAIT Delay' `
            -Description 'Release closed TCP connections sooner' `
            -WhatItDoes 'Sets how many seconds a closed TCP connection stays in TIME_WAIT before its port can be reused. Shorter frees ports faster when many apps open and close connections' `
            -Values '0x00000078 (120 s, default) - 30 to 300 s - 0x0000001E (30 s, minimum)' `
            -GamingOptimal 'na' `
            -GamingNote 'Helps only when ports run out from many open apps (launchers, browser, chat)' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                   Name = 'TcpTimedWaitDelay'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x0000001E'; Default = '0x00000078' }
            )

        New-Setting -Name 'Max User Port' `
            -Description 'Highest port number for outgoing connections (legacy value)' `
            -WhatItDoes 'Sets the top of the ephemeral port range on old versions of Windows. Since Windows Vista this value is ignored: the range is 49152 to 65535 and is changed with netsh' `
            -Values '0x00001388 (5000, legacy default) - up to 0x0000FFFE (65534). Windows 10/11 does not read it' `
            -GamingOptimal 'na' `
            -GamingNote 'No effect on Windows 10/11' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                   Name = 'MaxUserPort'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x0000FFFE'; Default = '0x00001388' }
            )

        # ---- 3b) Servidor SMB (LanmanServer) ------------------------
        # Solo afectan a las carpetas que ESTE equipo comparte en la red.

        New-Setting -Name 'SMB Auto Disconnect' `
            -Description 'Never drop idle file-sharing sessions' `
            -WhatItDoes 'Sets how many idle minutes the file-sharing server waits before closing a client session. 0xFFFFFFFF turns the timeout off' `
            -Values '0x0000000F (15 min, default) - 0xFFFFFFFF (never)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares on the network' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'autodisconnect'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0xFFFFFFFF'; Default = '0x0000000F' }
            )

        New-Setting -Name 'SMB Server Memory Profile' `
            -Description 'Let the file-sharing server use more memory for throughput' `
            -WhatItDoes 'Tells the file-sharing server how much memory to set aside: 1 minimizes memory, 2 balances, 3 maximizes throughput for sharing files' `
            -Values '0x00000001 (minimize memory, restored with OFF) - 0x00000002 (balance) - 0x00000003 (maximize throughput)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares on the network' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'Size'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000003'; Default = '0x00000001' }
            )

        New-Setting -Name 'SMB Opportunistic Locks' `
            -Description 'Turn off opportunistic locks on shared files' `
            -WhatItDoes 'Oplocks let a network client cache a shared file locally. Turning them off avoids stale copies with some old programs, but every read goes over the network' `
            -Values '0x00000001 (enabled, default) - 0x00000000 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares; usually makes sharing slower' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'EnableOplocks'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'SMB IRP Stack Size' `
            -Description 'Give the file-sharing server more I/O request slots' `
            -WhatItDoes 'Sets how many stack locations each I/O request packet of the file-sharing server gets. More is needed when antivirus or other filter drivers sit on the disk' `
            -Values '0x0000000F (15, default) - 11 to 50 - 0x00000020 (32)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares on the network' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'IRPStackSize'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000020'; Default = '0x0000000F' }
            )

        New-Setting -Name 'SMB Sharing Violation Delay' `
            -Description 'No pause between retries when a shared file is in use' `
            -WhatItDoes 'When a network client opens a shared file that is busy, the server waits this long before each retry. Zero retries without waiting' `
            -Values '0x000000C8 (200 ms, default) - 0x00000000 (no pause)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares on the network' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'SharingViolationDelay'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x000000C8' }
            )

        New-Setting -Name 'SMB Sharing Violation Retries' `
            -Description 'Fail at once when a shared file is in use' `
            -WhatItDoes 'When a network client opens a shared file that is busy, the server retries this many times before giving up. Zero returns the error immediately' `
            -Values '0x00000005 (5, default) - 0x00000000 (no retries)' `
            -GamingOptimal 'na' `
            -GamingNote 'Only affects folders this PC shares on the network' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                   Name = 'SharingViolationRetries'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000005' }
            )

        # ---- 3c) Servicios --------------------------------------------
        # Start: 2 automático, 3 manual, 4 deshabilitado. Se aplica al
        # reiniciar; el servicio que ya corre no se para.

        New-Setting -Name 'SysMain Service' `
            -Description 'Disable SysMain (formerly Superfetch)' `
            -WhatItDoes 'SysMain preloads into memory the programs you use most and manages the prefetcher. Disabling it stops that background disk and memory work; apps may open a little slower. Applies after a restart' `
            -Values '0x00000002 (automatic, default) - 0x00000003 (manual) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Avoids background disk activity; on an SSD the difference is small' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SysMain'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000002' }
            )

        # ---- 4) QoS -------------------------------------------------

        New-Setting -Name 'QoS Reservable Bandwidth' `
            -Description 'Set the bandwidth QoS applications may reserve to 0%' `
            -WhatItDoes 'Policy "Limit reservable bandwidth". Windows does NOT hold back 20% of your connection: the limit only applies to apps that ask for QoS priority, and unused bandwidth is always available to everything else' `
            -Values 'Not set (20%, default; restored as 0x00000014) - 0x00000000 (0%)' `
            -GamingOptimal 'na' `
            -GamingNote 'Myth: it does not free bandwidth for games' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Psched'
                   Name = 'NonBestEffortLimit'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000014' }
            )

        # ---- 5) Prefetcher y WPBT -----------------------------------

        New-Setting -Name 'Prefetcher' `
            -Description 'Turn off application and boot prefetching' `
            -WhatItDoes 'The prefetcher records which files programs and boot need and preloads them next time. Turning it off saves that background work, but programs and boot may load slower, mostly on hard disks' `
            -Values '0x00000003 (apps and boot, default) - 0x00000002 (boot only) - 0x00000001 (apps only) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Can make game launch slower on a hard disk' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
                   Name = 'EnablePrefetcher'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000003' }
            )

        New-Setting -Name 'Block WPBT Executables' `
            -Description 'Stop the firmware from injecting programs into Windows' `
            -WhatItDoes 'The Windows Platform Binary Table lets the BIOS/UEFI hand Windows a program to run at every boot (manufacturer tools, anti-theft). Blocking it stops that program, and closes a known way to plant software from the firmware' `
            -Values '0x00000000 (allowed, default) - 0x00000001 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Raises security; may stop manufacturer utilities that came that way' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager'
                   Name = 'DisableWpbtExecution'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; Default = '0x00000000' }
            )

        # ---- 6-8) Directivas ----------------------------------------

        # Historial de actividad: tres directivas, un ajuste por clave.

        New-Setting -Name 'Activity History' `
            -Description 'Turn off the activity feed' `
            -WhatItDoes 'Policy that turns off the activity feed: Windows stops keeping the list of apps, files and pages you have used' `
            -Values '0x00000001 (allowed, default) - 0x00000000 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System'
                   Name = 'EnableActivityFeed'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Publish User Activities' `
            -Description 'Stop Windows from recording user activities' `
            -WhatItDoes 'Policy that stops apps from publishing what you do to the activity history' `
            -Values '0x00000001 (allowed, default) - 0x00000000 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System'
                   Name = 'PublishUserActivities'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Upload User Activities' `
            -Description 'Stop uploading activity history to Microsoft' `
            -WhatItDoes 'Policy that stops the activity history from being sent to Microsoft and synced to your other devices' `
            -Values '0x00000001 (allowed, default) - 0x00000000 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System'
                   Name = 'UploadUserActivities'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Consumer Features' `
            -Description 'Turn off Microsoft consumer experiences' `
            -WhatItDoes 'Policy that stops Windows from installing suggested apps and showing promotional content. Windows only honours it on Enterprise and Education editions; on Home and Pro it is ignored' `
            -Values '0x00000000 (allowed, default) - 0x00000001 (turned off)' `
            -GamingOptimal 'na' `
            -GamingNote 'No effect on Home or Pro editions' `
            -Link 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
                   Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; Default = '0x00000000' }
            )

        # Optimización de distribución: cuatro claves, un ajuste por clave.

        New-Setting -Name 'Delivery Optimization' `
            -Description 'Download updates only from Microsoft, not from other PCs' `
            -WhatItDoes 'Sets the Delivery Optimization download mode to HTTP only: Windows Update and the Store stop sharing pieces of updates with other PCs. Updates still install normally. It is the value behind the switch in Settings' `
            -Values '0x00000001 (PCs on the local network, default) - 0x00000000 (HTTP only)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Stops update uploads to other PCs from using your connection' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
                   Name = 'DODownloadMode'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Delivery Optimization (Legacy Mode)' `
            -Description 'Old name of the Delivery Optimization download mode' `
            -WhatItDoes 'Same download mode under the name that older Windows 10 builds read. Setting it to HTTP only keeps those builds from sharing pieces of updates with other PCs' `
            -Values '0x00000001 (PCs on the local network, default) - 0x00000000 (HTTP only)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Stops update uploads to other PCs from using your connection' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
                   Name = 'DownloadMode'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Delivery Optimization (Policy)' `
            -Description 'Force HTTP-only update downloads by policy' `
            -WhatItDoes 'Group policy for the Delivery Optimization download mode. It wins over the switch in Settings, which then shows as managed by your organization' `
            -Values '0x00000001 (PCs on the local network, default) - 0x00000000 (HTTP only)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Stops update uploads to other PCs from using your connection' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
                   Name = 'DODownloadMode'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Delivery Optimization (Settings Key)' `
            -Description 'Download mode stored in the Delivery Optimization settings key' `
            -WhatItDoes 'Copy of the download mode that the Settings app keeps in its own key. Setting it to HTTP only keeps it in line with the other Delivery Optimization values' `
            -Values '0x00000001 (PCs on the local network, default) - 0x00000000 (HTTP only)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Stops update uploads to other PCs from using your connection' `
            -Link 'https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'
                   Name = 'DownloadMode'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        # ---- 9) Barra de tareas -------------------------------------

        New-Setting -Name 'End Task With Right Click' `
            -Description 'Add "End task" to the taskbar right-click menu' `
            -WhatItDoes 'Shows an "End task" entry when you right-click an app on the taskbar, to close a frozen program without opening Task Manager' `
            -Values '0x00000000 (hidden, default) - 0x00000001 (shown)' `
            -GamingOptimal 'yes' `
            -GamingNote 'Quick way to close a frozen game' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
                   Name = 'TaskbarEndTask'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; Default = '0x00000000' }
            )

        # ---- 10) Servicios --------------------------------------------

        New-Setting -Name 'Geolocation Service' `
            -Description 'Disable the location service (lfsvc)' `
            -WhatItDoes 'Disables the service that gives apps the position of this PC. Maps, weather and "Find my device" stop knowing where you are. Applies after a restart' `
            -Values '0x00000003 (manual, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\lfsvc'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000003' }
            )

        New-Setting -Name 'Offline Files Service' `
            -Description 'Disable the Offline Files service (CscService)' `
            -WhatItDoes 'Disables the service that keeps local copies of network folders to use them without a connection. Nobody uses it on a home PC. Applies after a restart' `
            -Values '0x00000003 (manual, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Unused on a home PC' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CscService'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000003' }
            )

        New-Setting -Name 'Telemetry Service' `
            -Description 'Disable Connected User Experiences and Telemetry (DiagTrack)' `
            -WhatItDoes 'Disables the service that collects and sends diagnostic data to Microsoft. Windows Update and Defender keep working. Applies after a restart' `
            -Values '0x00000002 (automatic, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; removes a small background load' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DiagTrack'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000002' }
            )

        New-Setting -Name 'Downloaded Maps Manager' `
            -Description 'Disable the offline maps service (MapsBroker)' `
            -WhatItDoes 'Disables the service that downloads and updates offline maps for the Maps app. Applies after a restart' `
            -Values '0x00000002 (automatic, delayed, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Removes a background service most PCs never use' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MapsBroker'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000002' }
            )

        New-Setting -Name 'Storage Service' `
            -Description 'Disable the Storage Service (StorSvc)' `
            -WhatItDoes 'Disables the service behind Storage Sense, the storage settings and installing Store apps on other drives; those stop working. Applies after a restart' `
            -Values '0x00000003 (manual, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'no' `
            -GamingNote 'May break installing Store or Game Pass games on another drive' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\StorSvc'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000003' }
            )

        New-Setting -Name 'Internet Connection Sharing' `
            -Description 'Disable Internet Connection Sharing (SharedAccess)' `
            -WhatItDoes 'Disables the service that shares this PC connection with other devices. Mobile hotspot and the Hyper-V Default Switch stop working. Applies after a restart' `
            -Values '0x00000003 (manual, default) - 0x00000004 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Breaks mobile hotspot; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess'
                   Name = 'Start'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000004'; Default = '0x00000003' }
            )

        # ---- 11) Hibernación ----------------------------------------

        New-Setting -Name 'Hibernation' `
            -Description 'Turn off hibernation and free hiberfil.sys' `
            -WhatItDoes 'Turns off hibernation. Windows deletes hiberfil.sys (several GB on the system drive) on the next restart, and Fast Startup also stops working because it depends on hibernation' `
            -Values '0x00000001 (enabled, default) - 0x00000000 (disabled)' `
            -GamingOptimal 'na' `
            -GamingNote 'Frees disk space; boot from off may take a little longer' `
            -Link 'https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
                   Name = 'HibernateEnabled'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        # ---- 12) Ubicación ------------------------------------------

        New-Setting -Name 'Location Access' `
            -Description 'Deny location access for the whole device' `
            -WhatItDoes 'Same as turning off "Location services" in Settings > Privacy: no app or user on this PC can read its location' `
            -Values 'Allow (default) - Deny' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
                   Name = 'Value'; Type = 'String'
                   Recommended = 'Deny'; Default = 'Allow' }
            )

        # ---- 13) Privacidad y telemetría ----------------------------

        New-Setting -Name 'Advertising ID' `
            -Description 'Turn off the advertising ID for apps' `
            -WhatItDoes 'Stops apps from using your advertising ID to show personalized ads. Same as the switch in Settings > Privacy > General' `
            -Values '0x00000001 (on, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
                   Name = 'Enabled'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Tailored Experiences' `
            -Description 'Stop Microsoft from using diagnostic data for tips and ads' `
            -WhatItDoes 'Stops Microsoft from using your diagnostic data to offer personalized tips, ads and recommendations' `
            -Values '0x00000001 (on, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy'
                   Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Online Speech Recognition' `
            -Description 'Turn off cloud speech recognition' `
            -WhatItDoes 'Stops sending your voice to Microsoft for online speech recognition. Voice typing and voice access fall back to what works offline' `
            -Values '0x00000001 (accepted, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
                   Name = 'HasAccepted'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Improve Inking and Typing' `
            -Description 'Stop sending inking and typing data to Microsoft' `
            -WhatItDoes 'Stops sending samples of what you type and write with a pen to help Microsoft improve its recognition' `
            -Values '0x00000001 (on, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Input\TIPC'
                   Name = 'Enabled'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        # Diccionario personalizado de escritura a mano y tecleo: cuatro
        # valores, un ajuste por clave.

        New-Setting -Name 'Inking and Typing Personalization' `
            -Description 'Stop learning from your handwriting' `
            -WhatItDoes 'Part of the "custom inking and typing dictionary": Windows stops collecting what you write with a pen to adapt its handwriting recognition' `
            -Values '0x00000000 (allowed, default) - 0x00000001 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization'
                   Name = 'RestrictImplicitInkCollection'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; Default = '0x00000000' }
            )

        New-Setting -Name 'Typing Personalization' `
            -Description 'Stop learning from what you type' `
            -WhatItDoes 'Part of the "custom inking and typing dictionary": Windows stops collecting the words you type to build its suggestions' `
            -Values '0x00000000 (allowed, default) - 0x00000001 (blocked)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization'
                   Name = 'RestrictImplicitTextCollection'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000001'; Default = '0x00000000' }
            )

        New-Setting -Name 'Harvest Contacts' `
            -Description 'Stop learning names from your contacts' `
            -WhatItDoes 'Part of the "custom inking and typing dictionary": Windows stops reading your contacts to recognise their names when you write or type' `
            -Values '0x00000001 (on, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization\TrainedDataStore'
                   Name = 'HarvestContacts'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Personalization Privacy Policy' `
            -Description 'Withdraw consent for the personal dictionary' `
            -WhatItDoes 'Part of the "custom inking and typing dictionary": withdraws the acceptance of its privacy policy, so the stored data stops being used' `
            -Values '0x00000001 (accepted, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Personalization\Settings'
                   Name = 'AcceptedPrivacyPolicy'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )

        New-Setting -Name 'Diagnostic Data Level' `
            -Description 'Send Microsoft the least diagnostic data the edition allows' `
            -WhatItDoes 'Sets the diagnostic data level. 0 (Security) is only honoured on Enterprise and Education; on Home and Pro Windows treats it as 1 (Required data only)' `
            -Values '0x00000003 (optional data, default if accepted at setup) - 0x00000001 (required only) - 0x00000000 (security, Enterprise/Education)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
                   Name = 'AllowTelemetry'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000003' }
            )

        New-Setting -Name 'Track App Launches' `
            -Description 'Stop Windows from tracking which apps you open' `
            -WhatItDoes 'Stops Windows from recording which apps you launch to improve Start and search results. "Most used" in Start stops filling in' `
            -Values '0x00000001 (on, default) - 0x00000000 (off)' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -Registry @(
                @{ Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                   Name = 'Start_TrackProgs'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0x00000000'; Default = '0x00000001' }
            )
    )
}
