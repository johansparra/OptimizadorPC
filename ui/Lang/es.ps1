# ------------------------------------------------------------
# Español
#
# Diccionario "texto en inglés" -> "texto en español".
# La clave es el texto tal cual aparece en el código fuente; si
# falta una entrada, se muestra el inglés en vez de fallar.
#
# Para saber qué queda por traducir, navega por la aplicación y
# después ejecuta:  Get-MissingTranslations 'es'
#
# Para crear otro idioma, copia este archivo con otro código y
# añade su línea en ui/LanguageIndex.ps1.
# ------------------------------------------------------------

Register-Language 'es' @{

    # ---- Menú lateral ----
    'Software'   = 'Programas'
    'Optimize'   = 'Optimizar'
    'Customize'  = 'Personalizar'
    'Advanced'   = 'Avanzado'
    'Settings'   = 'Ajustes'
    'More'       = 'Más'

    # ---- Barra de título ----
    'Normal'         = 'Normal'
    'Builder'        = 'Constructor'
    'Config Review'  = 'Revisar configuración'
    'Change theme'   = 'Cambiar tema'
    'Help'           = 'Ayuda'
    'Hide the menu'  = 'Ocultar el menú'
    'Show the menu'  = 'Mostrar el menú'

    # ---- Pantalla principal ----
    'Optimizations' = 'Optimizaciones'
    'Optimize your Windows system performance, privacy and power usage' = 'Ajusta el rendimiento, la privacidad y el consumo de tu sistema'
    'Search optimizations...' = 'Buscar optimizaciones...'
    'Quick Actions' = 'Acciones rápidas'
    'View'          = 'Vista'

    # ---- Pantalla de detalle ----
    '{0} settings' = '{0} ajustes'
    'Reset'        = 'Restablecer'
    'Back to the list' = 'Volver a la lista'

    # ---- Etiquetas de clasificación ----
    'Preference'  = 'Preferencia'
    'Recommended' = 'Recomendado'
    'Default'     = 'De fábrica'
    'Custom'      = 'Personalizado'

    # ---- Indicadores ----
    'On'  = 'Sí'
    'Off' = 'No'
    'Recommended value'         = 'Valor recomendado'
    'Windows factory value'     = 'Valor de fábrica de Windows'
    'Recommended: {0} of {1}'   = 'Recomendados: {0} de {1}'
    'Factory defaults: {0} of {1}' = 'De fábrica: {0} de {1}'
    'Customised: {0} of {1}'    = 'Personalizados: {0} de {1}'
    'No recommended settings'   = 'Sin ajustes recomendados'

    # ---- Bloqueo ----
    'Locked section' = 'Sección bloqueada'
    'Its settings are shown for reference only: they cannot be changed. To unlock it, set Locked = $false in ui/CategoryIndex.ps1.' = 'Sus ajustes se muestran solo como consulta: no se pueden modificar. Para desbloquearla, pon Locked = $false en ui/CategoryIndex.ps1.'
    'Locked section: you can look, not change' = 'Sección bloqueada: se puede consultar, no modificar'
    'Not available: the section is locked'     = 'No disponible: la sección está bloqueada'
    '{0}: locked' = '{0}: bloqueado'

    # ---- Pantalla de Settings ----
    'Preferences for the application itself' = 'Preferencias del propio programa'
    'Saved automatically' = 'Se guarda solo'
    'General'    = 'General'
    'Appearance' = 'Apariencia'
    'Language'   = 'Idioma'
    'Language used across the whole interface' = 'Idioma de toda la interfaz'
    'Theme'      = 'Tema'
    'Light or dark colour scheme' = 'Combinación de colores clara u oscura'
    'Light'      = 'Claro'
    'Dark'       = 'Oscuro'

    # ============================================================
    # CONTENIDO: nombres y descripciones de las secciones
    # ============================================================

    'Privacy & Security'   = 'Privacidad y seguridad'
    'Security, Content Delivery & Advertising, Lock Screen, General, ...' = 'Seguridad, contenido y publicidad, pantalla de bloqueo, general, ...'

    'Power' = 'Energía'
    'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...' = 'Pantalla, disco duro, Internet Explorer, fondo de escritorio, ...'

    'Gaming & Performance' = 'Juegos y rendimiento'
    'Processor, Graphics, Network, Security, ...' = 'Procesador, gráficos, red, seguridad, ...'

    'Update' = 'Actualizaciones'
    'Update Policy, Delivery & Store, Update Behavior' = 'Directivas de actualización, distribución y Store, comportamiento'

    'Notifications' = 'Notificaciones'
    'Additional Settings, System Notifications, Privacy Notifications, Security Notifications' = 'Ajustes adicionales, notificaciones del sistema, de privacidad y de seguridad'

    'Sound' = 'Sonido'
    'System Sounds' = 'Sonidos del sistema'

    # ============================================================
    # CONTENIDO: ajustes
    # ============================================================

    # ---- Privacy & Security ----
    'User Account Control Level' = 'Nivel del Control de cuentas de usuario'
    'Controls UAC notification level and secure desktop behavior' = 'Controla el nivel de aviso del UAC y el comportamiento del escritorio seguro'
    'Always notify' = 'Notificar siempre'
    'Notify when apps try to make changes' = 'Notificar cuando una aplicación intente hacer cambios'
    'Notify me only (no dim)' = 'Notificar sin atenuar el escritorio'
    'Never notify' = 'No notificar nunca'

    'Workplace Join Message Prompts' = 'Avisos de unión al trabajo'
    "Show 'Allow my organization to manage my device' prompts throughout Windows" = "Mostrar los avisos de 'Permitir que mi organización administre mi dispositivo' por todo Windows"

    'BitLocker Auto Encryption' = 'Cifrado automático de BitLocker'
    'Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device' = 'Controla si Windows puede cifrar unidades automáticamente con BitLocker. No tiene efecto si el cifrado ya está activo en tu equipo'

    'WiFi-Sense' = 'Sensor WiFi'
    'Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots' = 'Permitir compartir contraseñas WiFi con tus contactos y conectarse solo a las redes abiertas sugeridas'

    'Automatic Maintenance' = 'Mantenimiento automático'
    'Choose if Windows should run automatic system maintenance tasks during idle time' = 'Elige si Windows debe ejecutar tareas de mantenimiento cuando el equipo está inactivo'

    'Windows Error Reporting' = 'Informe de errores de Windows'
    'Choose if Windows should collect and send crash reports and error information to Microsoft' = 'Elige si Windows debe recopilar y enviar a Microsoft los informes de fallos y errores'

    # ---- Power ----
    'High Performance Power Plan' = 'Plan de energía de alto rendimiento'
    'Switch to the High Performance / Ultimate Performance power scheme' = 'Cambiar al plan de energía de alto rendimiento o rendimiento máximo'

    'USB Selective Suspend' = 'Suspensión selectiva de USB'
    'Allow Windows to power down idle USB devices to save energy' = 'Permitir que Windows apague los dispositivos USB inactivos para ahorrar energía'

    'Hibernation' = 'Hibernación'
    'Enable or disable hibernate mode and the hiberfil.sys reserved space' = 'Activar o desactivar la hibernación y el espacio reservado de hiberfil.sys'

    # ---- Gaming & Performance ----
    'Game Mode' = 'Modo de juego'
    'Optimize your PC for play by turning things off in the background' = 'Optimizar el equipo para jugar desactivando procesos en segundo plano'

    'Enhance Pointer Precision' = 'Mejorar la precisión del puntero'
    'Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games' = 'Ajusta la velocidad del cursor según la del movimiento (aceleración del ratón). La mayoría de jugadores competitivos lo desactivan para apuntar de forma constante en los FPS'

    'Mouse Hover Time' = 'Tiempo de reposo del ratón'
    'Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms' = 'Controla cuánto hay que mantener el ratón encima de un elemento antes de que reaccione (en milisegundos). Valores más bajos hacen que los mensajes emergentes y los menús aparezcan antes. El valor de fábrica es 400 ms'
    '100ms' = '100 ms'
    '200ms' = '200 ms'
    '400ms (Default)' = '400 ms (de fábrica)'
    '600ms' = '600 ms'

    'Startup Delay for Apps' = 'Retraso de los programas de inicio'
    'Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load' = 'Retrasa 10 segundos los programas de inicio para que el sistema responda antes. Windows se puede usar más rápido, pero tus programas tardan más en cargar'

    'Background App Permissions' = 'Permisos de aplicaciones en segundo plano'
    'Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp' = 'Controla mediante directivas de grupo si las aplicaciones pueden ejecutarse en segundo plano. "Denegar siempre" quita esa opción por aplicación de la Configuración de Windows. Usa "Decide el usuario" si necesitas Teams, Zoom o WhatsApp'
    'User in Control' = 'Decide el usuario'
    'Force Allow' = 'Permitir siempre'
    'Force Deny' = 'Denegar siempre'

    # ---- Update ----
    'Delivery Optimization (P2P)' = 'Optimización de distribución (P2P)'
    'Allow Windows to download/upload updates to and from other PCs on the internet' = 'Permitir que Windows descargue y envíe actualizaciones desde y hacia otros equipos de internet'

    'Auto-Restart With Active Sessions' = 'Reinicio automático con sesión iniciada'
    'Allow Windows Update to restart the PC automatically while you are logged in' = 'Permitir que Windows Update reinicie el equipo automáticamente con la sesión iniciada'

    # ---- Notifications ----
    'Windows Tips & Suggestions' = 'Consejos y sugerencias de Windows'
    'Show occasional tips, tricks, and suggestions as you use Windows' = 'Mostrar de vez en cuando consejos, trucos y sugerencias mientras usas Windows'

    'Lock Screen Suggestions' = 'Sugerencias en la pantalla de bloqueo'
    'Show fun facts, tips, and other suggestions on the lock screen' = 'Mostrar curiosidades, consejos y otras sugerencias en la pantalla de bloqueo'

    # ---- Sound ----
    'Startup Sound' = 'Sonido de inicio'
    'Play the Windows startup sound when signing in' = 'Reproducir el sonido de inicio de Windows al iniciar sesión'

}
