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
#
# TAMPOCO se declaran -Tags. El estado que sale en la tarjeta
# -Optimizado / Recomendado de fábrica / Personalizado- se calcula
# comparando lo leído contra esos dos valores declarados, así que
# escribirlo a mano solo serviría para mentir. Ver
# core/Registry/SettingStatus.ps1.
#
# De ahí que Recommended y Default sean el dato importante de cada
# clave: si están mal, el estado sale mal.
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

    Recommended = 29
    Default     = 59
    Custom      = 0
    Total       = 88

    Items = @(
        New-Setting -Name 'Network Throttling Mechanism' `
            -Description 'Limits network packet processing (NDIS) to 10 packets' `
            -Badge 'NEW' `
            -Value $true `
            -Registry @(
                @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
                   Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Display = 'hex'
                   Recommended = '0xFFFFFFFF'; Default = '0x00000000' }
            )
       
    )
}
