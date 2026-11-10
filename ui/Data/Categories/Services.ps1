# ------------------------------------------------------------
# Categoría: Services & Tasks (Servicios y tareas)
#
# Tipo de inicio de tres servicios y seis tareas programadas de
# telemetría. UN AJUSTE = UN SERVICIO O UNA TAREA, igual que "una
# clave por ajuste" en Regedit. Mismo formato que Regedit.ps1 y
# Update.ps1: sin -Tags ni contadores a mano; el estado de cada tarjeta
# sale de leer el equipo (core/Registry/SettingStatus.ps1).
#
#   -Service        @{ Name; Recommended; Default }
#                   'Automatic' | 'Manual' | 'Disabled'
#                   core/Services/ServiceStartup.ps1
#   -ScheduledTask  @{ Path; Name; Recommended; Default }
#                   'Enabled' | 'Disabled'
#                   core/ScheduledTasks/ScheduledTaskState.ps1
#
# ON escribe el Recommended, OFF el Default (el de fábrica). Nada se
# borra ni se crea, no se para ni se arranca ningún servicio (el
# cambio vale desde el siguiente reinicio) y cada nombre tiene que
# estar en la lista blanca de su mecanismo: lo comprueba
# tests/Source/Security.Tests.ps1. Ver SECURITY.md §14.
#
# DE FÁBRICA en Windows 11 (lo que escribe OFF):
#   DiagTrack          Automatic
#   dmwappushservice   Manual (arranca por desencadenador)
#   SysMain            Automatic
#   las seis tareas    Enabled
# Son los valores de una instalación limpia de Windows 11. NO se han
# podido comprobar en el equipo de desarrollo: ya los tenía todos
# deshabilitados (los tres servicios en Disabled, y Consolidator,
# UsbCeip y DiskDiagnosticDataCollector deshabilitadas). Si algún día
# se comprueban en un equipo limpio y no cuadran, se cambian aquí.
#
# Dos tareas pueden no existir: 'Microsoft Compatibility Appraiser' y
# 'ProgramDataUpdater' faltan en compilaciones recientes de Windows 11
# (en la 26300 la primera se llama 'Microsoft Compatibility Appraiser
# Exp' y la segunda ya no está). Una tarea que no existe sale 'missing'
# -como un valor del registro ausente: cuenta como de fábrica- y su
# interruptor no hace nada. La variante 'Exp' NO está en la lista
# blanca: añadirla es una decisión del propietario.
#
# Nada de esto baja la seguridad del equipo: son telemetría y el
# precargador de memoria. Windows Update, Defender, el firewall y sus
# servicios y tareas están en las listas de PROTEGIDOS de los dos
# mecanismos, y no se pueden tocar desde aquí aunque alguien los
# añadiera a la blanca (SECURITY.md §3.4 y §14).
#
# DiagTrack y SysMain vivían en Regedit como el valor Start de su clave
# del registro. Se mudaron aquí para no tener dos interruptores sobre
# lo mismo (como DODownloadMode, que vive solo en Actualizaciones).
# ------------------------------------------------------------

Register-Category @{
    Id          = 'services'
    Name        = 'Services & Tasks'
    Icon        = 'Wrench'
    Accent      = 'Accent2'
    AccentSoft  = 'Accent2Soft'
    Description = 'Telemetry services and scheduled tasks'

    # En el detalle la cuadrícula no hace nada: es la misma razón que
    # en Regedit.
    HideViewOptions = @('grid')

    Items = @(
        # ---- Servicios ----------------------------------------------

        New-Setting -Name 'Telemetry Service' `
            -Description 'Disable Connected User Experiences and Telemetry (DiagTrack)' `
            -WhatItDoes 'Sets the service that collects and sends diagnostic data to Microsoft to Disabled. Windows Update and Defender keep working. Applies after a restart' `
            -Values 'Automatic (default) - Manual - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; removes a small background load' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization' `
            -Badge 'NEW' `
            -Service @(
                @{ Name = 'DiagTrack'; Recommended = 'Disabled'; Default = 'Automatic' }
            )

        New-Setting -Name 'WAP Push Message Routing' `
            -Description 'Disable the WAP Push message routing service (dmwappushservice)' `
            -WhatItDoes 'Sets to Disabled the service that routes device management push messages and feeds the telemetry pipeline. A home PC that no organization manages does not use it. If this PC is enrolled in work or school device management (Intune, MDM), leave it as it is. Applies after a restart' `
            -Values 'Manual (default, starts on demand) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Link 'https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization' `
            -Badge 'NEW' `
            -Service @(
                @{ Name = 'dmwappushservice'; Recommended = 'Disabled'; Default = 'Manual' }
            )

        New-Setting -Name 'SysMain Service' `
            -Description 'Disable SysMain (formerly Superfetch). Debatable: on an SSD it gains almost nothing' `
            -WhatItDoes 'SysMain preloads into memory the programs you use most. On a hard disk that makes them open faster, so disabling it usually makes the PC slower. On an SSD both the benefit and the cost are small. Only worth disabling if you see it causing constant disk activity. Applies after a restart' `
            -Values 'Automatic (default) - Manual - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Not a gaming tweak: on a hard disk, games and apps may load slower' `
            -Badge 'NEW' `
            -Service @(
                @{ Name = 'SysMain'; Recommended = 'Disabled'; Default = 'Automatic' }
            )

        # ---- Tareas programadas de telemetría -----------------------

        New-Setting -Name 'Compatibility Appraiser' `
            -Description 'Disable the program compatibility telemetry task' `
            -WhatItDoes 'Scheduled task that scans installed programs and sends compatibility data to Microsoft, which uses it for Windows upgrade checks. Some Windows 11 builds renamed or removed it: then it shows as not found and the switch changes nothing' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Avoids an occasional disk scan in the background' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )

        New-Setting -Name 'Program Data Updater' `
            -Description 'Disable the program telemetry task of the Customer Experience Improvement Program' `
            -WhatItDoes 'Scheduled task that collects program telemetry for the Customer Experience Improvement Program. Windows 11 no longer has it on most PCs: if it is not found, there is nothing to change' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Avoids an occasional disk scan in the background' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )

        New-Setting -Name 'CEIP Consolidator' `
            -Description 'Disable the task that sends usage data to Microsoft' `
            -WhatItDoes 'Scheduled task of the Customer Experience Improvement Program: if you joined it, it collects and sends usage data to Microsoft' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )

        New-Setting -Name 'USB CEIP' `
            -Description 'Disable the USB telemetry task' `
            -WhatItDoes 'Scheduled task that collects USB statistics and information about this PC and sends them to Microsoft, for Customer Experience Improvement Program participants. USB devices keep working the same' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )

        New-Setting -Name 'Autochk Telemetry' `
            -Description 'Disable the task that uploads boot disk check data' `
            -WhatItDoes 'Scheduled task that collects and uploads data from autochk (the disk check at boot) for the Customer Experience Improvement Program. The disk check itself keeps working: only the upload stops' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Privacy; no effect on game performance' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )

        New-Setting -Name 'Disk Diagnostic Data Collector' `
            -Description 'Disable the task that sends disk information to Microsoft' `
            -WhatItDoes 'Scheduled task that sends general information about your disks and system to Microsoft, for Customer Experience Improvement Program participants. It is not the disk check (chkdsk), which is not affected' `
            -Values 'Enabled (default) - Disabled' `
            -GamingOptimal 'na' `
            -GamingNote 'Avoids an occasional disk scan in the background' `
            -Badge 'NEW' `
            -ScheduledTask @(
                @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector'
                   Recommended = 'Disabled'; Default = 'Enabled' }
            )
    )
}
