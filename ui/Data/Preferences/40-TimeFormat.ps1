# ------------------------------------------------------------
# Opción: formato de hora
#
# Controla el estilo de reloj de las horas de la interfaz -hoy, la
# etiqueta "Actualizado {hora}" de la cabecera del panel Regedit-.
# La lógica de formateo está centralizada en ui/Engine/TimeFormat.ps1
# (Format-AppTime); aquí solo se declara la opción y se persiste
# con Set-AppSetting, igual que el resto de preferencias.
#
# El registro de actividad NO se rige por esto: su hora es técnica,
# para copiar y pegar, y va siempre en 24h.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 40
    Id          = 'timeformat'
    Group       = 'Appearance'
    Label       = 'Time format'
    Description = 'Clock style for the times shown in the Regedit panel'
    Type        = 'Choice'

    Options = @(
        @{ Value = '24'; Label = '24-hour (18:45:03)' }
        @{ Value = '12'; Label = '12-hour (6:45:03 PM)' }
    )

    Get = { Get-AppTimeFormat }

    Set = {
        param($Value)
        Set-AppTimeFormat $Value
    }
}
