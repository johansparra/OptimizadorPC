# ============================================================
# Categoría: Limpieza (Cleanup)
#
# Como Internet, NO es una sección de ajustes: es una lista de
# COMANDOS que se ejecutan (pantalla: ui/Views/CategoryStepsView.ps1).
# Sale de EliminarTemporales.v1.cmd, una línea del .cmd por paso.
#
#   -Clean '%TEMP%'               vacía la carpeta entera, también las
#                                 subcarpetas: el ":DelMode ... 2"
#   -Clean '%...%\carpeta\*.db'   borra solo esos archivos: el modo 1
#   -EmptyRecycleBin              vacía la papelera
#   -Exe                          DISM, cleanmgr, fsutil y defrag
#
# AÑADIR UNA CARPETA = un New-CommandStep aquí + la misma ruta en
# $CleanupAllowedFolders (core/Commands/FolderCleanup.ps1). Lo segundo
# es una decisión de seguridad (SECURITY.md §12): se borra sin pasar
# por la papelera y desde un programa elevado. Un ejecutable nuevo va
# a $CommandAllowedExecutables, como en Internet.
#
# EL ORDEN ES EL DE EJECUCIÓN, y es distinto del .cmd a propósito:
# primero se borra y al final se optimiza el disco, que así no
# recoloca archivos que estaban a punto de desaparecer.
#
# Lo que borra algo que se puede echar de menos -la papelera, los
# recientes, las cookies- viene DESMARCADO y con aviso. Lo que tarda
# minutos (DISM, optimizar unidades) también.
# ============================================================

$CleanupGroup1 = 'Temporary files and caches'
$CleanupGroup2 = 'History and recent items'
$CleanupGroup3 = 'Windows'
$CleanupGroup4 = 'Disk'

Register-Category @{
    Id          = 'cleanup'
    Name        = 'Cleanup'
    Icon        = 'Broom'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Description = 'Delete temporary files and caches: pick what to clean and run it'
    Badge       = 'NEW'

    Steps = @(
        # ---- Temporales y cachés ---------------------------------
        New-CommandStep -Id 'temp-user' -Group $CleanupGroup1 `
            -Name 'Your temporary files' `
            -Description 'Empties your temporary folder: what programs and installers leave behind. Files in use are skipped.' `
            -Clean '%TEMP%'

        New-CommandStep -Id 'windows-temp' -Group $CleanupGroup1 `
            -Name 'Windows temporary files' `
            -Description 'Empties the system temporary folder (C:\Windows\Temp): what updates, installers and services leave behind. Files in use are skipped.' `
            -RequiresAdmin $true `
            -Clean '%WINDIR%\Temp'

        New-CommandStep -Id 'crash-dumps' -Group $CleanupGroup1 `
            -Name 'Crash dumps' `
            -Description 'Memory dumps that programs write when they crash. Only useful to send to a developer.' `
            -Clean '%LOCALAPPDATA%\CrashDumps'

        New-CommandStep -Id 'wer-queue' -Group $CleanupGroup1 `
            -Name 'Pending error reports' `
            -Description 'Windows Error Reporting reports still waiting to be sent.' `
            -Clean '%LOCALAPPDATA%\Microsoft\Windows\WER\ReportQueue'

        New-CommandStep -Id 'thumbnail-cache' -Group $CleanupGroup1 `
            -Name 'Thumbnail and icon cache' `
            -Description 'Deletes the thumbnail and icon databases; Explorer rebuilds them as you browse. The ones in use are skipped.' `
            -Clean '%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db'

        New-CommandStep -Id 'edge-cache' -Group $CleanupGroup1 `
            -Name 'Microsoft Edge cache' `
            -Description 'Pages and images cached by the default Edge profile. Close Edge first to clean it completely.' `
            -Clean '%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache'

        New-CommandStep -Id 'inet-cache' -Group $CleanupGroup1 `
            -Name 'Temporary Internet files' `
            -Description 'The web cache that Windows and older apps share.' `
            -Clean '%LOCALAPPDATA%\Microsoft\Windows\InetCache'

        # ---- Historial y recientes -------------------------------
        New-CommandStep -Id 'ie-history' -Group $CleanupGroup2 `
            -Name 'Internet Explorer history' `
            -Description 'The legacy browsing history folder. Edge keeps its own history and does not use it.' `
            -Clean '%LOCALAPPDATA%\Microsoft\Windows\History'

        New-CommandStep -Id 'legacy-cookies' -Group $CleanupGroup2 `
            -Name 'Legacy cookies' `
            -Description 'Cookies of Internet Explorer and older apps. Modern browsers keep theirs elsewhere.' `
            -Warning 'Apps that still use them may sign you out.' `
            -Checked $false `
            -Clean '%APPDATA%\Microsoft\Windows\Cookies'

        New-CommandStep -Id 'webcache-logs' -Group $CleanupGroup2 `
            -Name 'WebCache database logs' `
            -Description 'Transaction logs of the database behind the legacy browser history and cache. The ones in use are skipped.' `
            -Warning 'If that database was not closed cleanly, deleting its logs can damage it; Windows then rebuilds it empty.' `
            -Checked $false `
            -Clean '%LOCALAPPDATA%\Microsoft\Windows\WebCache\*.log'

        New-CommandStep -Id 'recent-items' -Group $CleanupGroup2 `
            -Name 'Recent files and jump lists' `
            -Description 'Clears the recent files list, the recent items of Quick access and the taskbar jump lists.' `
            -Warning 'Also removes what you pinned to the jump lists.' `
            -Checked $false `
            -Clean '%APPDATA%\Microsoft\Windows\Recent'

        # ---- Windows ---------------------------------------------
        New-CommandStep -Id 'recycle-bin' -Group $CleanupGroup3 `
            -Name 'Empty the Recycle Bin' `
            -Description 'Deletes everything in your Recycle Bin, on every drive.' `
            -Warning 'Permanent: what is there cannot be recovered afterwards.' `
            -Checked $false `
            -EmptyRecycleBin

        New-CommandStep -Id 'disk-cleanup' -Group $CleanupGroup3 `
            -Name 'Disk Cleanup with saved profile 1' `
            -Description 'Runs Windows Disk Cleanup with the categories saved in profile 1.' `
            -Warning 'Does nothing until you choose the categories once with: cleanmgr /sageset:1. Opens its own window.' `
            -Checked $false -TimeoutSeconds 1800 `
            -Exe 'cleanmgr.exe' -Arguments '/sagerun:1'

        New-CommandStep -Id 'component-store' -Group $CleanupGroup3 `
            -Name 'Clean up the component store (WinSxS)' `
            -Description 'DISM removes the old copies of system components that updates have replaced.' `
            -Warning 'Takes several minutes.' `
            -Checked $false -TimeoutSeconds 3600 `
            -Exe 'Dism.exe' -Arguments '/online', '/Cleanup-Image', '/StartComponentCleanup'

        # ---- Disco -----------------------------------------------
        New-CommandStep -Id 'trim-on' -Group $CleanupGroup4 `
            -Name 'Make sure TRIM is on' `
            -Description 'Lets Windows tell SSDs which blocks are free, on NTFS and ReFS. It is on by default; this turns it back on if something disabled it.' `
            -Exe 'fsutil.exe' -Arguments 'behavior', 'set', 'DisableDeleteNotify', '0'

        New-CommandStep -Id 'optimize-drives' -Group $CleanupGroup4 `
            -Name 'Optimize every drive' `
            -Description 'The right optimization for each drive: TRIM on SSDs, defragmentation on hard disks.' `
            -Warning 'On hard disks it can take a long time.' `
            -Checked $false -TimeoutSeconds 3600 `
            -Exe 'defrag.exe' -Arguments '/C', '/O'
    )
}
