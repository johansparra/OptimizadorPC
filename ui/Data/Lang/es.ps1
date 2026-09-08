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
# añade su línea en ui/Index/LanguageIndex.ps1.
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
    'Activity log'   = 'Registro de actividad'

    # ---- Registro de actividad (ui/Components/Shell/LogPanel.ps1) ----
    # Solo el marco. Las líneas del log no se traducen: son rutas
    # del registro y valores, texto técnico para copiar y pegar.
    'What the app has read from your system in this session' = 'Lo que el programa ha leído de tu sistema en esta sesión'
    'Close the log'   = 'Cerrar el registro'
    'Open the log in its own window' = 'Abrir el registro en su propia ventana'
    'Dock the log back into the main window' = 'Volver a acoplar el registro en la ventana principal'
    'Minimize'        = 'Minimizar'
    'Maximize'        = 'Maximizar'
    'Clear'           = 'Vaciar'
    'Save to file'    = 'Guardar en archivo'
    '{0} entries'     = '{0} entradas'
    'Newest at the bottom' = 'Lo más reciente, abajo'
    'Nothing logged yet'   = 'Todavía no hay nada apuntado'
    'Nothing has been read from your system yet' = 'Todavía no se ha leído nada de tu sistema'
    'Open a section and its registry keys will show up here' = 'Entra en una sección y sus claves del registro saldrán aquí'
    'Showing the last {0} of {1} entries' = 'Se enseñan las {0} últimas de {1} entradas'
    'Only the last {0} entries are kept; {1} older ones were discarded' = 'Solo se guardan las {0} últimas entradas; se han descartado {1} más antiguas'
    'Saved to {0}'    = 'Guardado en {0}'
    'The log file could not be written' = 'No se ha podido escribir el archivo del registro'

    # El diálogo "Guardar como" de Windows. Los rótulos de los
    # filtros se traducen sueltos y luego se juntan: la cadena de
    # filtro lleva su propia sintaxis y no es texto de pantalla.
    'Save the activity log' = 'Guardar el registro de actividad'
    'Log files'       = 'Archivos de registro'
    'All files'       = 'Todos los archivos'
    'Save the log to a file' = 'Guardar el registro en un archivo'
    'Nothing to save yet'    = 'Todavía no hay nada que guardar'

    # Etiquetas de estado de cada línea. Las cuatro primeras son
    # las mismas que usa el detalle técnico de las tarjetas.
    'read'    = 'leído'
    'reading' = 'leyendo'
    'done'    = 'hecho'
    'info'    = 'info'
    'warn'    = 'aviso'
    'error'   = 'fallo'

    # Escritura en el registro (core/Registry/Writer.ps1 / SettingApply.ps1).
    'checked'       = 'evaluado'
    'applying'      = 'aplicando'
    'applied'       = 'aplicado'
    'restored'      = 'restaurado'
    'no change'     = 'sin cambios'
    'snapshot'      = 'copia'
    'write attempt' = 'intento'
    'post write'    = 'verificación'
    'blocked'       = 'bloqueado'
    'disarmed'      = 'desarmado'
    'invalid path'  = 'ruta inválida'
    'type mismatch' = 'tipo distinto'
    'write failed'  = 'no escrito'
    'typefail'      = 'tipo inválido'
    'unsupported'   = 'no soportado'

    # ---- Pantalla principal ----
    'Optimizations' = 'Optimizaciones'
    'Optimize your Windows system performance, privacy and power usage' = 'Ajusta el rendimiento, la privacidad y el consumo de tu sistema'
    'Search optimizations...' = 'Buscar optimizaciones...'
    'Quick Actions' = 'Acciones rápidas'
    'View'          = 'Vista'

    # ---- Menú del botón "Vista" ----
    'Show on screen'    = 'Mostrar en pantalla'
    'Technical details' = 'Detalles técnicos'
    'Show the registry keys each setting touches' = 'Enseñar las claves del registro que toca cada ajuste'
    'Reference'         = 'Referencia'
    'Show values, gaming fit and the reference link for each key' = 'Enseñar los valores, si conviene para gaming y el enlace de referencia de cada clave'
    'New badges'        = 'Insignias de nuevo'
    "Show the red 'NEW' tags on sections and settings" = "Enseñar las etiquetas rojas de 'nuevo' en secciones y ajustes"
    'Grid view'         = 'Cuadrícula'
    'Show the sections as tiles instead of rows' = 'Enseñar las secciones como baldosas en vez de filas'

    # ---- Insignias ----
    'NEW' = 'NUEVO'

    # ---- Detalles técnicos ----
    'Copy the registry path' = 'Copiar la ruta del registro'
    'Copy the value name'    = 'Copiar el nombre del valor'
    'Copied'                 = 'Copiado'
    'Select it or press Ctrl+C to copy it' = 'Selecciónalo o pulsa Ctrl+C para copiarlo'
    'Path:'            = 'Ruta:'
    'Value:'           = 'Valor:'
    'Current:'         = 'Actual:'
    'Recommended:'     = 'Recomendado:'
    'Factory:'         = 'Predeterminado:'
    'Open this key in Registry Editor' = 'Abrir esta clave en el Editor del registro'
    'Reading the registry...' = 'Leyendo el registro...'
    'not set'          = 'sin definir'
    'not read'         = 'sin leer'
    'no access'        = 'sin acceso'
    'unknown root key' = 'raíz desconocida'
    'No registry keys declared for this setting yet.' = 'Este ajuste todavía no declara ninguna clave del registro.'

    # ---- Pantalla de detalle ----
    '{0} settings' = '{0} ajustes'
    'Refresh'      = 'Refrescar'
    'Read the registry keys again' = 'Volver a leer las claves del registro'
    'Expand'   = 'Expandir'
    'Collapse' = 'Contraer'
    'All'      = 'Todo'
    'This section does not read the registry yet' = 'Esta sección todavía no lee el registro'
    'Updated {0}'  = 'Actualizado {0}'
    'Registry values updated' = 'Valores del registro actualizados'
    'Back to the list' = 'Volver a la lista'

    # ---- Etiquetas de clasificación ----
    'Recommended' = 'Recomendado'
    'Default'     = 'De fábrica'
    'Custom'      = 'Personalizado'

    # ---- Estado real de un ajuste (core/Registry/SettingStatus.ps1) ----
    # 'Custom' sale un poco más arriba: es la misma palabra.
    'Optimized'           = 'Optimizado'
    'Factory recommended' = 'Recomendado de fábrica'
    'Unknown'             = 'Desconocido'

    'The registry value is the one this program recommends' = 'El valor del registro es el que recomienda el programa'
    'The registry value is the Windows factory one'         = 'El valor del registro es el de fábrica de Windows'
    'The registry value is neither the recommended nor the factory one' = 'El valor del registro no es ni el recomendado ni el de fábrica'
    'The registry value could not be read'                  = 'No se ha podido leer el valor del registro'

    'Optimized: {0} of {1}'           = 'Optimizados: {0} de {1}'
    'Factory recommended: {0} of {1}' = 'Recomendados de fábrica: {0} de {1}'
    'Unknown: {0} of {1}'             = 'Desconocidos: {0} de {1}'

    # ---- Indicadores ----
    'On'  = 'Sí'
    'Off' = 'No'
    'Recommended value'         = 'Valor recomendado'
    'Windows factory value'     = 'Valor de fábrica de Windows'
    'Recommended: {0} of {1}'   = 'Recomendados: {0} de {1}'
    'Factory defaults: {0} of {1}' = 'De fábrica: {0} de {1}'
    'Customised: {0} of {1}'    = 'Personalizados: {0} de {1}'
    'No recommended settings'   = 'Sin ajustes recomendados'

    # ---- Franja "Referencia": bloques de consulta de la clave ----
    'Values'            = 'Valores'
    'Good for gaming'   = 'Óptimo para gaming'
    'Link'              = 'Enlace'
    'No reference link' = 'Sin enlace'
    'Open the reference in your browser' = 'Abrir el enlace en el navegador'
    'Yes' = 'Sí'
    'No'  = 'No'
    'N/A' = 'N/A'

    # ---- Bloqueo ----
    'Locked section' = 'Sección bloqueada'
    'Its settings are shown for reference only: they cannot be changed. To unlock it, set Locked = $false in ui/Index/CategoryIndex.ps1.' = 'Sus ajustes se muestran solo como consulta: no se pueden modificar. Para desbloquearla, pon Locked = $false en ui/Index/CategoryIndex.ps1.'
    'Locked section: you can look, not change' = 'Sección bloqueada: se puede consultar, no modificar'
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
    'Window material' = 'Material de la ventana'
    'Let the Windows 11 background show through the app. Needs Windows 11 22H2 or newer' = 'Dejar que se vea el fondo de Windows 11 a través del programa. Requiere Windows 11 22H2 o superior'
    'Solid'      = 'Opaco'
    'Mica'       = 'Mica'
    'Acrylic'    = 'Acrílico'
    'Time format' = 'Formato de hora'
    'Clock style for the times shown in the Regedit panel' = 'Estilo de reloj para las horas que se muestran en el panel Regedit'
    '24-hour (18:45:03)'   = '24 horas (18:45:03)'
    '12-hour (6:45:03 PM)' = '12 horas (6:45:03 PM)'

    # ============================================================
    # CONTENIDO: nombres y descripciones de las secciones
    # ============================================================

    'Regedit'               = 'Regedit'
    'Windows registry keys' = 'Claves de registro de Windows'

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

    # ---- Regedit ----
    'Network Throttling Mechanism' = 'Mecanismo de limitación de red'
    'Limits network packet processing (NDIS) to 10 packets' = 'Limita el procesamiento de paquetes de red (NDIS) a 10 paquetes'
    'Caps network traffic while Windows detects active audio or video (MMCSS), so the CPU goes to multimedia instead' = 'Limita el tráfico de red mientras Windows detecta audio o vídeo activo (MMCSS), para que la CPU vaya al multimedia'
    '0x0000000A (10, default) - 1 to 70 (adjustable) - 0xFFFFFFFF (disables the limit)' = '0x0000000A (10, predeterminado) - 1 a 70 (ajustable) - 0xFFFFFFFF (desactiva el límite)'
    'Removes network throttling during matches' = 'Elimina la limitación de red durante las partidas'

    'System Responsiveness' = 'Capacidad de respuesta del sistema'
    'Reserve less CPU for background tasks while MMCSS is active' = 'Reserva menos CPU para tareas en segundo plano mientras MMCSS está activo'
    'Sets the percentage of CPU that Windows holds back for non-multimedia work when a multimedia app (audio, video, games) gets priority through MMCSS. Lower value means more CPU for the foreground app' = 'Fija el porcentaje de CPU que Windows aparta para el trabajo no multimedia cuando una aplicación multimedia (audio, vídeo, juegos) recibe prioridad mediante MMCSS. Un valor más bajo deja más CPU para la aplicación en primer plano'
    '0x00000014 (20, default) - lower frees more CPU - 0x00000000 (reserve nothing)' = '0x00000014 (20, predeterminado) - más bajo libera más CPU - 0x00000000 (no reservar nada)'
    'Frees the CPU slice held back for background tasks during matches' = 'Libera la porción de CPU apartada para tareas en segundo plano durante las partidas'

    'GPU Priority for Games' = 'Prioridad de GPU para juegos'
    "Give the game's GPU work priority over background tasks" = 'Da prioridad al trabajo de GPU del juego frente a las tareas en segundo plano'
    'Sets the GPU scheduling priority MMCSS gives to threads a game registers under the "Games" task. 8 is the ceiling for this task class' = 'Fija la prioridad de planificación de GPU que MMCSS da a los hilos que un juego registra en la tarea "Games". 8 es el máximo de esta clase de tarea'
    '0x00000002 (2) - 0x00000008 (8, maximum). Windows 10/11 usually ships the "Games" task at 8 already' = '0x00000002 (2) - 0x00000008 (8, máximo). Windows 10/11 suele traer la tarea "Games" ya en 8'
    'Moves game rendering ahead of background GPU work' = 'Adelanta el renderizado del juego al trabajo de GPU en segundo plano'

    'CPU Priority for Games' = 'Prioridad de CPU para juegos'
    'Raise the CPU thread priority of the "Games" MMCSS task' = 'Sube la prioridad de CPU de los hilos de la tarea MMCSS "Games"'
    'Sets the CPU priority Windows gives to threads a game registers with MMCSS. The range is 1 to 8; this raises the "Games" task to 6' = 'Fija la prioridad de CPU que Windows da a los hilos que un juego registra con MMCSS. El rango es de 1 a 8; esto sube la tarea "Games" a 6'
    '0x00000002 (2, default) - 1 to 8 (higher is more) - 0x00000006 (used here)' = '0x00000002 (2, predeterminado) - 1 a 8 (más alto es más) - 0x00000006 (el que se usa aquí)'
    'Keeps the game scheduled ahead of normal background threads' = 'Mantiene el juego planificado por delante de los hilos normales en segundo plano'

    'Scheduling Category for Games' = 'Categoría de planificación para juegos'
    'Put the "Games" MMCSS task in the High scheduling class' = 'Pone la tarea MMCSS "Games" en la clase de planificación High'
    'Sets the scheduling category of the MMCSS "Games" task, which controls the kernel priority boost its threads get. Windows ships it at Medium' = 'Fija la categoría de planificación de la tarea MMCSS "Games", que controla el impulso de prioridad del kernel que reciben sus hilos. Windows la trae en Medium'
    'Medium (default) - High - Low' = 'Medium (predeterminado) - High - Low'
    'High gives smoother frame pacing under load' = 'High da un ritmo de fotogramas más estable bajo carga'

    'Disk I/O Priority for Games' = 'Prioridad de E/S de disco para juegos'
    'Raise the disk I/O priority of the "Games" MMCSS task' = 'Sube la prioridad de E/S de disco de la tarea MMCSS "Games"'
    'Sets the storage I/O priority Windows gives to threads of the MMCSS "Games" task. Windows ships it at Normal' = 'Fija la prioridad de E/S de almacenamiento que Windows da a los hilos de la tarea MMCSS "Games". Windows la trae en Normal'
    'Normal (default) - High - Low' = 'Normal (predeterminado) - High - Low'
    'Cuts I/O waits while a match streams assets' = 'Reduce las esperas de E/S mientras una partida carga recursos'

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

    # ---- Búsqueda ----
    'Search' = 'Buscar'
    'Everything in the app, by name, description or registry key' = 'Todo lo que hay en la aplicación: por nombre, descripción o clave del registro'
    'See all {0} results'   = 'Ver los {0} resultados'
    '{0} results for "{1}"' = '{0} resultados de «{1}»'
    '1 result for "{0}"'    = '1 resultado de «{0}»'
    'Nothing matches "{0}"' = 'Nada coincide con «{0}»'
    'Try another word, or part of a registry path' = 'Prueba con otra palabra, o con un trozo de una ruta del registro'
    'Type to search' = 'Escribe para buscar'
    'Sections, settings, registry keys and their values' = 'Secciones, ajustes, claves del registro y sus valores'

    # Por qué ha salido cada resultado. Son las etiquetas, no los
    # datos: la ruta y el valor se enseñan tal cual, que para eso se
    # copian y se pegan.
    'Name'           = 'Nombre'
    'Description'    = 'Descripción'
    'Section'        = 'Sección'
    'Tags'           = 'Etiquetas'
    'Options'        = 'Opciones'
    'Value'          = 'Valor'
    'Registry path'  = 'Ruta del registro'
    'Registry value' = 'Valor del registro'
    'Type'           = 'Tipo'
    'Current value'  = 'Valor actual'
    'Factory'        = 'De fábrica'
    'Status'         = 'Estado'
    # 'Recommended' ya está más arriba, con las etiquetas de
    # clasificación: es la misma palabra.

}
