# ============================================================
# Categoría: Energía (Power)
#
# Sección de COMANDOS, como Internet y Limpieza (pantalla:
# ui/Views/CategoryStepsView.ps1). Sale de
# "maximo rendimiento de enerigia.bat":
#
#   powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
#
# que copia el plan oculto "Máximo rendimiento" (Ultimate
# Performance) para que se pueda usar. El .bat tenía dos pegas, y
# aquí se arreglan las dos:
#
#   1. CADA VEZ CREABA OTRA COPIA. Sin destino, powercfg inventa un
#      GUID nuevo en cada llamada: dos ejecuciones, dos planes
#      "Máximo rendimiento" en Opciones de energía. Aquí la copia va
#      siempre al MISMO GUID ($UltimatePlanGuid) y, si ya existe, el
#      paso se salta (-SkipIf mira su FriendlyName en el registro).
#      No basta con dejar que falle: powercfg devuelve 1 tanto para
#      "ya existe" como para cualquier otro error.
#
#   2. NO LO ACTIVABA. Copiar el plan no cambia el plan en uso; el
#      segundo paso lo pone como activo.
#
# Las copias que ya hubiera dejado el .bat (con GUID al azar) no se
# tocan: se borran a mano en Opciones de energía si sobran.
# ============================================================

# La plantilla oculta de Windows y NUESTRA copia de ella. El segundo
# GUID es fijo e inventado para este programa: no cambiarlo, o la
# próxima ejecución crearía otra copia en vez de reconocer la suya.
$UltimatePlanTemplate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$UltimatePlanGuid     = '5bd7c042-7843-4e69-8004-85491c4f6281'

Register-Category @{
    Id          = 'power'
    Name        = 'Power'
    Icon        = 'Power'
    Accent      = 'Success'
    AccentSoft  = 'SuccessSoft'
    Badge       = 'NEW'
    Description = 'Power plan: add Ultimate Performance and switch to it'

    Steps = @(
        New-CommandStep -Id 'ultimate-plan-add' `
            -Name 'Add the Ultimate Performance plan' `
            -Description 'Copies the hidden Ultimate Performance power plan so it can be used and shows up in Power Options. If this program already added it, the step is skipped.' `
            -SkipIf @{ Path = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$UltimatePlanGuid"; Name = 'FriendlyName' } `
            -Exe 'powercfg.exe' -Arguments '/duplicatescheme', $UltimatePlanTemplate, $UltimatePlanGuid

        New-CommandStep -Id 'ultimate-plan-activate' `
            -Name 'Switch to the Ultimate Performance plan' `
            -Description 'Makes it the plan in use: the processor no longer slows down to save power, so it responds faster but uses more energy and runs warmer.' `
            -Warning 'On a laptop it drains the battery faster.' `
            -Exe 'powercfg.exe' -Arguments '/setactive', $UltimatePlanGuid
    )
}
