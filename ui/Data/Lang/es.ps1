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
    'Optimize'   = 'Optimizar'
    'Guides'     = 'Guías'
    'Settings'   = 'Ajustes'

    # ---- Barra de título ----
    'Change theme'   = 'Cambiar tema'
    'About this program' = 'Acerca de este programa'

    # ---- Acerca de (botón ?) ----
    'Windows 11 tweaks for performance, gaming and privacy. Every change shows the registry key it touches and can be turned back off.' = 'Ajustes de Windows 11 para rendimiento, juegos y privacidad. Cada cambio enseña la clave del registro que toca y se puede volver a apagar.'
    'Version'                    = 'Versión'
    'Details'                    = 'Detalles'
    'Copy these details'         = 'Copiar estos detalles'
    'Running as'                 = 'Se ejecuta como'
    'Compiled program (.exe)'    = 'Programa compilado (.exe)'
    'Script (development)'       = 'Script (desarrollo)'
    'Permissions'                = 'Permisos'
    'Administrator'              = 'Administrador'
    'Standard user'              = 'Usuario estándar'
    'Architecture'               = 'Arquitectura'
    'Data folder'                = 'Carpeta de datos'
    'View the project on GitHub' = 'Ver el proyecto en GitHub'

    # ---- Filtro por estado (píldoras del resumen) ----
    'Click to show only these settings. Click again to remove the filter.' = 'Pulsa para ver solo estos ajustes. Vuelve a pulsar para quitar el filtro.'
    'Show all' = 'Mostrar todos'
    'Remove the filter' = 'Quitar el filtro'

    # ---- Sección Internet (comandos) ----
    'Internet' = 'Internet'
    'Reset and tune the network: pick the commands and run them in order' = 'Restablece y ajusta la red: elige los comandos y ejecútalos en orden'
    '{0} of {1} commands selected' = '{0} de {1} comandos marcados'
    '{0} of {1} commands selected · they run from top to bottom' = '{0} de {1} comandos marcados · se ejecutan de arriba abajo'
    '{0} of {1} selected' = '{0} de {1} marcados'
    'None' = 'Ninguno'
    'Select the commands that come checked by default' = 'Marca los comandos que vienen marcados de serie'
    'Select every command' = 'Marca todos los comandos'
    'Clear the selection' = 'Desmarca todo'
    'Run order' = 'Orden de ejecución'
    'Needs a restart' = 'Requiere reiniciar'
    'Waits {0} s afterwards' = 'Espera {0} s después'
    'Ready to run' = 'Listo para ejecutar'
    'Run {0}' = 'Ejecutar {0}'
    'Stop' = 'Detener'
    'Running: {0}' = 'Ejecutando: {0}'
    'Waiting {0} s' = 'Esperando {0} s'
    'Next: {0}' = 'Siguiente: {0}'
    'Starting: {0} commands, in order' = 'Empezando: {0} comandos, en orden'
    'Waiting {0} s before the next command' = 'Esperando {0} s antes del siguiente comando'
    'Finished: {0} succeeded, {1} failed' = 'Terminado: {0} correctos, {1} fallidos'
    'Stopped: {0} of {1} commands ran' = 'Detenido: se ejecutaron {0} de {1} comandos'
    'Stopped by the user' = 'Detenido por el usuario'
    'Restart the PC so the network resets take effect.' = 'Reinicia el equipo para que los restablecimientos de red surtan efecto.'
    'Not running as administrator: {0} commands are disabled. Open the program as administrator to use them.' = 'Sin permisos de administrador: {0} comandos están desactivados. Abre el programa como administrador para usarlos.'
    'Requires administrator permissions: open the program as administrator' = 'Requiere permisos de administrador: abre el programa como administrador'
    # Insignia de permisos de la barra de título.
    'Not administrator' = 'Sin administrador'
    'Running with administrator permissions' = 'Se está ejecutando con permisos de administrador'
    'Running without administrator permissions: the actions that need them are disabled. Close the program and open it as administrator.' = 'Se está ejecutando sin permisos de administrador: las acciones que los necesitan están desactivadas. Cierra el programa y ábrelo como administrador.'
    # Estados de un paso (también etiquetas del log).
    'queued'    = 'en cola'
    'running'   = 'en curso'
    'succeeded' = 'correcto'
    'failed'    = 'falló'
    'timed out' = 'tiempo agotado'
    'cancelled' = 'cancelado'
    'skipped'   = 'omitido'
    'waiting'   = 'esperando'
    # Fases.
    'Phase 1 · Clean up and reset the network stack' = 'Fase 1 · Limpiar y restablecer la pila de red'
    'Phase 2 · Tune TCP' = 'Fase 2 · Ajustar TCP'
    'Phase 3 · Adapter, DNS and services' = 'Fase 3 · Adaptador, DNS y servicios'
    # Pasos.
    'Reset Windows Firewall' = 'Restablecer el Firewall de Windows'
    'Restores the firewall to its factory policy.' = 'Devuelve el firewall a su configuración de fábrica.'
    'Deletes every custom rule and exception: apps you had allowed will ask again.' = 'Borra todas las reglas y excepciones propias: las aplicaciones que habías permitido volverán a preguntar.'
    'Reset BranchCache' = 'Restablecer BranchCache'
    'Empties the BranchCache content cache and its settings. Harmless if you do not use it.' = 'Vacía la caché de contenido de BranchCache y su configuración. Inofensivo si no lo usas.'
    'Flush the HTTP log buffer' = 'Vaciar el búfer de registro HTTP'
    'Writes out and empties the HTTP.sys log buffer.' = 'Escribe y vacía el búfer de registro de HTTP.sys.'
    'Reset IPv4' = 'Restablecer IPv4'
    'Rewrites the IPv4 configuration to its defaults.' = 'Reescribe la configuración de IPv4 con sus valores por defecto.'
    'Flush the DNS cache' = 'Vaciar la caché DNS'
    'Forgets the names already resolved, so they are looked up again.' = 'Olvida los nombres ya resueltos, para que se vuelvan a consultar.'
    'Purge the NetBIOS name cache' = 'Purgar la caché de nombres NetBIOS'
    'Empties the NetBIOS name table and reloads it.' = 'Vacía la tabla de nombres NetBIOS y la vuelve a cargar.'
    'Re-register NetBIOS names' = 'Volver a registrar los nombres NetBIOS'
    'Releases and registers this PC''s NetBIOS names again on the network.' = 'Libera y vuelve a registrar en la red los nombres NetBIOS de este equipo.'
    'Clear the ARP cache' = 'Vaciar la caché ARP'
    'Forgets which hardware address belongs to each IP on the local network.' = 'Olvida qué dirección física corresponde a cada IP de la red local.'
    'Reset Winsock' = 'Restablecer Winsock'
    'Restores the Windows sockets catalog: undoes what VPNs or network filters may have hooked in.' = 'Restablece el catálogo de sockets de Windows: deshace lo que hayan enganchado VPN o filtros de red.'
    'Reset TCP/IP' = 'Restablecer TCP/IP'
    'Rewrites the TCP/IP stack settings to their defaults.' = 'Reescribe la configuración de la pila TCP/IP con sus valores por defecto.'
    'Reset the WinHTTP proxy' = 'Restablecer el proxy de WinHTTP'
    'Removes any system proxy for WinHTTP: direct connection.' = 'Quita cualquier proxy del sistema para WinHTTP: conexión directa.'
    'Turn off TCP window heuristics' = 'Desactivar la heurística de ventana TCP'
    'Stops Windows from shrinking the receive window on its own.' = 'Impide que Windows reduzca por su cuenta la ventana de recepción.'
    'Receive window auto-tuning: normal' = 'Ajuste automático de la ventana de recepción: normal'
    'Lets the receive window grow with the connection speed.' = 'Deja que la ventana de recepción crezca con la velocidad de la conexión.'
    'Turn on Receive Side Scaling' = 'Activar Receive Side Scaling'
    'Spreads network processing across several CPU cores.' = 'Reparte el trabajo de red entre varios núcleos del procesador.'
    'Turn off Receive Segment Coalescing' = 'Desactivar Receive Segment Coalescing'
    'Delivers packets as they arrive instead of grouping them: less latency, a bit more CPU.' = 'Entrega los paquetes según llegan en vez de agruparlos: menos latencia, algo más de CPU.'
    'Congestion control: CTCP' = 'Control de congestión: CTCP'
    'Uses Compound TCP for Internet connections. Some Windows 11 builds reject it; then the step fails and nothing changes.' = 'Usa Compound TCP en las conexiones a Internet. Algunas compilaciones de Windows 11 lo rechazan; entonces el paso falla y no cambia nada.'
    'Turn off TCP timestamps' = 'Desactivar las marcas de tiempo TCP'
    'Saves 12 bytes per packet. Windows has them off by default.' = 'Ahorra 12 bytes por paquete. Windows las trae desactivadas.'
    'Turn off ECN' = 'Desactivar ECN'
    'Disables Explicit Congestion Notification, which some routers handle badly.' = 'Desactiva la notificación explícita de congestión, que algunos routers manejan mal.'
    'Initial retransmission timeout: 2000 ms' = 'Tiempo inicial de retransmisión: 2000 ms'
    'How long TCP waits before resending the first packet of a connection.' = 'Cuánto espera TCP antes de reenviar el primer paquete de una conexión.'
    'SYN retransmissions: 2' = 'Retransmisiones SYN: 2'
    'Gives up sooner on connections that do not answer.' = 'Abandona antes las conexiones que no responden.'
    'Turn off Teredo' = 'Desactivar Teredo'
    'Disables the IPv6-over-IPv4 tunnel. Some games and Xbox services use it for multiplayer.' = 'Desactiva el túnel de IPv6 sobre IPv4. Algunos juegos y servicios de Xbox lo usan para el multijugador.'
    'DNS: Google 8.8.8.8 as primary' = 'DNS: Google 8.8.8.8 como principal'
    'Sets a fixed DNS server on the adapter named "Ethernet".' = 'Fija un servidor DNS en el adaptador llamado "Ethernet".'
    'Only works if the adapter is called "Ethernet". Replaces the DNS your router provides.' = 'Solo funciona si el adaptador se llama "Ethernet". Sustituye el DNS que da tu router.'
    'DNS: Google 8.8.4.4 as secondary' = 'DNS: Google 8.8.4.4 como secundario'
    'Adds the second Google DNS server to the adapter named "Ethernet".' = 'Añade el segundo DNS de Google al adaptador llamado "Ethernet".'
    'Run it together with the previous step: on its own it adds a server to whatever DNS is set.' = 'Ejecútalo junto con el paso anterior: solo, añade un servidor a lo que haya configurado.'
    'DNS: back to automatic (DHCP)' = 'DNS: volver a automático (DHCP)'
    'Undoes the two Google steps: the adapter named "Ethernet" goes back to the DNS your router provides.' = 'Deshace los dos pasos de Google: el adaptador llamado "Ethernet" vuelve al DNS que da tu router.'
    'Only to undo the Google DNS. Do not tick it together with them: it runs after them and cancels them.' = 'Solo para deshacer el DNS de Google. No lo marques junto con ellos: corre después y los anula.'
    'Make sure the DHCP Client service is running' = 'Comprobar que el servicio Cliente DHCP está en marcha'
    'Starts it if it is stopped. Without it the PC does not get an IP address.' = 'Lo arranca si está parado. Sin él el equipo no recibe dirección IP.'
    'Make sure the DNS Client service is running' = 'Comprobar que el servicio Cliente DNS está en marcha'
    'Starts it if it is stopped. Without it names are not resolved.' = 'Lo arranca si está parado. Sin él no se resuelven nombres.'
    'Flush the DNS cache again' = 'Vaciar otra vez la caché DNS'
    'One last cleanup with the final configuration in place.' = 'Una última limpieza con la configuración final ya puesta.'
    'List the network adapters' = 'Listar los adaptadores de red'
    'Only reads: shows each adapter and whether it is connected, to check the result in the log.' = 'Solo lee: muestra cada adaptador y si está conectado, para comprobar el resultado en el registro.'
    # ---- Sección Limpieza (comandos) ----
    'Cleanup' = 'Limpieza'
    'Delete temporary files and caches: pick what to clean and run it' = 'Borra temporales y cachés: elige qué limpiar y ejecútalo'
    # Grupos.
    'Temporary files and caches' = 'Temporales y cachés'
    'History and recent items' = 'Historial y elementos recientes'
    'Windows' = 'Windows'
    'Disk' = 'Disco'
    # Pasos.
    'Your temporary files' = 'Tus archivos temporales'
    'Empties your temporary folder: what programs and installers leave behind. Files in use are skipped.' = 'Vacía tu carpeta de temporales: lo que dejan atrás los programas y los instaladores. Los archivos en uso se saltan.'
    'Windows temporary files' = 'Archivos temporales de Windows'
    'Empties the system temporary folder (C:\Windows\Temp): what updates, installers and services leave behind. Files in use are skipped.' = 'Vacía la carpeta temporal del sistema (C:\Windows\Temp): lo que dejan las actualizaciones, los instaladores y los servicios. Los archivos en uso se saltan.'
    'Crash dumps' = 'Volcados de bloqueo'
    'Memory dumps that programs write when they crash. Only useful to send to a developer.' = 'Volcados de memoria que escriben los programas al colgarse. Solo sirven para mandárselos a un desarrollador.'
    'Pending error reports' = 'Informes de errores pendientes'
    'Windows Error Reporting reports still waiting to be sent.' = 'Informes de Windows Error Reporting que aún esperan para enviarse.'
    'Thumbnail and icon cache' = 'Caché de miniaturas e iconos'
    'Deletes the thumbnail and icon databases; Explorer rebuilds them as you browse. The ones in use are skipped.' = 'Borra las bases de datos de miniaturas e iconos; el Explorador las rehace según navegas. Las que están en uso se saltan.'
    'Microsoft Edge cache' = 'Caché de Microsoft Edge'
    'Pages and images cached by the default Edge profile. Close Edge first to clean it completely.' = 'Páginas e imágenes guardadas en caché por el perfil predeterminado de Edge. Cierra Edge antes para limpiarla del todo.'
    'Temporary Internet files' = 'Archivos temporales de Internet'
    'The web cache that Windows and older apps share.' = 'La caché web que comparten Windows y las aplicaciones antiguas.'
    'Internet Explorer history' = 'Historial de Internet Explorer'
    'The legacy browsing history folder. Edge keeps its own history and does not use it.' = 'La carpeta del historial de navegación antiguo. Edge guarda su propio historial y no la usa.'
    'Legacy cookies' = 'Cookies antiguas'
    'Cookies of Internet Explorer and older apps. Modern browsers keep theirs elsewhere.' = 'Cookies de Internet Explorer y de aplicaciones antiguas. Los navegadores actuales guardan las suyas en otro sitio.'
    'Apps that still use them may sign you out.' = 'Las aplicaciones que aún las usan pueden cerrarte la sesión.'
    'WebCache database logs' = 'Registros de la base de datos WebCache'
    'Transaction logs of the database behind the legacy browser history and cache. The ones in use are skipped.' = 'Registros de transacciones de la base de datos del historial y la caché del navegador antiguo. Los que están en uso se saltan.'
    'If that database was not closed cleanly, deleting its logs can damage it; Windows then rebuilds it empty.' = 'Si esa base de datos no se cerró bien, borrar sus registros puede dañarla; entonces Windows la rehace vacía.'
    'Recent files and jump lists' = 'Archivos recientes y listas de accesos'
    'Clears the recent files list, the recent items of Quick access and the taskbar jump lists.' = 'Vacía la lista de archivos recientes, los recientes del Acceso rápido y las listas de accesos de la barra de tareas.'
    'Also removes what you pinned to the jump lists.' = 'También quita lo que anclaste en las listas de accesos.'
    'Empty the Recycle Bin' = 'Vaciar la papelera'
    'Deletes everything in your Recycle Bin, on every drive.' = 'Borra todo lo que hay en tu papelera, en todas las unidades.'
    'Permanent: what is there cannot be recovered afterwards.' = 'Definitivo: lo que haya ahí no se podrá recuperar después.'
    'Disk Cleanup with saved profile 1' = 'Liberador de espacio con el perfil guardado 1'
    'Runs Windows Disk Cleanup with the categories saved in profile 1.' = 'Ejecuta el Liberador de espacio en disco de Windows con las categorías guardadas en el perfil 1.'
    'Does nothing until you choose the categories once with: cleanmgr /sageset:1. Opens its own window.' = 'No hace nada hasta que elijas las categorías una vez con: cleanmgr /sageset:1. Abre su propia ventana.'
    'Clean up the component store (WinSxS)' = 'Limpiar el almacén de componentes (WinSxS)'
    'DISM removes the old copies of system components that updates have replaced.' = 'DISM quita las copias antiguas de componentes del sistema que las actualizaciones han sustituido.'
    'Takes several minutes.' = 'Tarda varios minutos.'
    'Make sure TRIM is on' = 'Comprobar que TRIM está activado'
    'Lets Windows tell SSDs which blocks are free, on NTFS and ReFS. It is on by default; this turns it back on if something disabled it.' = 'Permite que Windows avise a los SSD de qué bloques quedan libres, en NTFS y ReFS. Viene activado; esto lo vuelve a activar si algo lo apagó.'
    'Optimize every drive' = 'Optimizar todas las unidades'
    'The right optimization for each drive: TRIM on SSDs, defragmentation on hard disks.' = 'La optimización adecuada para cada unidad: TRIM en los SSD y desfragmentación en los discos duros.'
    'On hard disks it can take a long time.' = 'En los discos duros puede tardar mucho.'
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
    'Saved to {0}, with details' = 'Guardado en {0}, con el detalle'
    # Detalle desplegable (ui/Components/Cards/DetailList.ps1) y la casilla de guardar con detalle.
    'Show details ({0} lines)' = 'Ver detalle ({0} líneas)'
    'Hide details' = 'Ocultar detalle'
    'With details' = 'Con detalle'
    'Also save the full detail of each entry: the files each cleanup deleted and the full output of each program' = 'Guarda también el detalle completo de cada entrada: los archivos que borró cada limpieza y la salida entera de cada programa'
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
    'deleted'       = 'borrado'
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
    # ---- Sección Guías (ui/Views/GuidesView.ps1) ----
    # El contenido de las guías es del usuario y no se traduce: solo el marco.
    'Your reference notes: open one to read it and copy what you need' = 'Tus notas de referencia: abre una para leerla y copiar lo que necesites'
    '1 section' = '1 sección'
    '{0} sections' = '{0} secciones'
    '{0} min read' = '{0} min de lectura'
    'Copy all' = 'Copiar todo'
    'Contents' = 'Contenido'
    'Find in this guide' = 'Buscar en esta guía'
    'No matches' = 'Sin coincidencias'
    '1 match' = '1 coincidencia'
    '{0} matches' = '{0} coincidencias'
    'Copy the whole guide as plain text' = 'Copia la guía entera como texto normal'
    'Copy the code' = 'Copiar el código'
    'Guide copied to the clipboard' = 'Guía copiada al portapapeles'
    'No guides yet' = 'Todavía no hay guías'
    'Put .md files in ui\Data\Guides and they will show up here' = 'Pon archivos .md en ui\Data\Guides y aparecerán aquí'
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

    'The current value is the one this program recommends' = 'El valor actual es el que recomienda el programa'
    'The current value is the Windows factory one' = 'El valor actual es el de fábrica de Windows'
    'The current value is neither the recommended nor the factory one' = 'El valor actual no es ni el recomendado ni el de fábrica'
    'The current value could not be read' = 'No se ha podido leer el valor actual'

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
    'Power plan: add Ultimate Performance and switch to it' = 'Plan de energía: añade Máximo rendimiento y actívalo'

    'Update' = 'Actualizaciones'
    'Update Policy, Delivery & Store, Update Behavior' = 'Directivas de actualización, distribución y Store, comportamiento'

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

    # Comunes a varios ajustes de Regedit.
    'Privacy; no effect on game performance' = 'Privacidad; no afecta al rendimiento de los juegos'
    'Only affects folders this PC shares on the network' = 'Solo afecta a las carpetas que este equipo comparte en la red'
    '0x00000003 (manual, default) - 0x00000004 (disabled)' = '0x00000003 (manual, predeterminado) - 0x00000004 (deshabilitado)'
    '0x00000001 (on, default) - 0x00000000 (off)' = '0x00000001 (activado, predeterminado) - 0x00000000 (desactivado)'

    'Default TTL' = 'TTL predeterminado'
    'Lower the starting hop limit of outgoing IP packets' = 'Baja el límite inicial de saltos de los paquetes IP salientes'
    'Sets the Time To Live that Windows puts on every packet it sends. It only limits how many routers a packet may cross; it does not change latency or speed' = 'Fija el tiempo de vida (TTL) que Windows pone en cada paquete que envía. Solo limita cuántos routers puede cruzar un paquete; no cambia la latencia ni la velocidad'
    '0x00000080 (128, Windows) - 0x00000040 (64, Linux and consoles) - 1 to 255' = '0x00000080 (128, Windows) - 0x00000040 (64, Linux y consolas) - 1 a 255'
    'No measurable effect on ping; 64 is enough for any route on the internet' = 'Sin efecto medible en el ping; 64 basta para cualquier ruta de internet'

    'TCP Timestamps (RFC 1323)' = 'Marcas de tiempo TCP (RFC 1323)'
    'Turn on TCP timestamps on top of window scaling' = 'Activa las marcas de tiempo TCP además del escalado de ventana'
    'Bit 0 enables TCP window scaling and bit 1 enables timestamps. Windows 10/11 already scales the window and leaves timestamps off (same as 1); 3 adds timestamps, which improve round-trip measurement at the cost of 12 bytes per packet' = 'El bit 0 activa el escalado de ventana TCP y el bit 1 las marcas de tiempo. Windows 10/11 ya escala la ventana y deja las marcas apagadas (equivale a 1); 3 añade las marcas, que miden mejor el tiempo de ida y vuelta a costa de 12 bytes por paquete'
    '0x00000001 (window scaling only, Windows behaviour) - 0x00000003 (scaling + timestamps) - 0x00000000 (both off)' = '0x00000001 (solo escalado, lo que hace Windows) - 0x00000003 (escalado + marcas de tiempo) - 0x00000000 (los dos apagados)'
    'Games mostly use UDP, which TCP options do not touch' = 'Los juegos usan sobre todo UDP, al que las opciones de TCP no afectan'

    'TIME_WAIT Delay' = 'Espera de TIME_WAIT'
    'Release closed TCP connections sooner' = 'Libera antes las conexiones TCP cerradas'
    'Sets how many seconds a closed TCP connection stays in TIME_WAIT before its port can be reused. Shorter frees ports faster when many apps open and close connections' = 'Fija cuántos segundos se queda una conexión TCP cerrada en TIME_WAIT antes de poder reutilizar su puerto. Más corto libera puertos antes cuando muchas aplicaciones abren y cierran conexiones'
    '0x00000078 (120 s, default) - 30 to 300 s - 0x0000001E (30 s, minimum)' = '0x00000078 (120 s, predeterminado) - 30 a 300 s - 0x0000001E (30 s, mínimo)'
    'Helps only when ports run out from many open apps (launchers, browser, chat)' = 'Solo ayuda si se agotan los puertos por tener muchas aplicaciones abiertas (lanzadores, navegador, chat)'

    'Max User Port' = 'Puerto de usuario máximo'
    'Highest port number for outgoing connections (legacy value)' = 'Número de puerto más alto para conexiones salientes (valor heredado)'
    'Sets the top of the ephemeral port range on old versions of Windows. Since Windows Vista this value is ignored: the range is 49152 to 65535 and is changed with netsh' = 'Fija el tope del rango de puertos efímeros en versiones antiguas de Windows. Desde Windows Vista este valor se ignora: el rango es 49152 a 65535 y se cambia con netsh'
    '0x00001388 (5000, legacy default) - up to 0x0000FFFE (65534). Windows 10/11 does not read it' = '0x00001388 (5000, predeterminado antiguo) - hasta 0x0000FFFE (65534). Windows 10/11 no lo lee'
    'No effect on Windows 10/11' = 'Sin efecto en Windows 10/11'

    'SMB Auto Disconnect' = 'Desconexión automática de SMB'
    'Never drop idle file-sharing sessions' = 'No cerrar nunca las sesiones inactivas de archivos compartidos'
    'Sets how many idle minutes the file-sharing server waits before closing a client session. 0xFFFFFFFF turns the timeout off' = 'Fija cuántos minutos de inactividad espera el servidor de archivos compartidos antes de cerrar la sesión de un cliente. 0xFFFFFFFF quita el límite'
    '0x0000000F (15 min, default) - 0xFFFFFFFF (never)' = '0x0000000F (15 min, predeterminado) - 0xFFFFFFFF (nunca)'

    'SMB Server Memory Profile' = 'Perfil de memoria del servidor SMB'
    'Let the file-sharing server use more memory for throughput' = 'Deja que el servidor de archivos compartidos use más memoria para ganar rendimiento'
    'Tells the file-sharing server how much memory to set aside: 1 minimizes memory, 2 balances, 3 maximizes throughput for sharing files' = 'Indica al servidor de archivos compartidos cuánta memoria reservar: 1 la minimiza, 2 equilibra, 3 maximiza el rendimiento al compartir archivos'
    '0x00000001 (minimize memory, restored with OFF) - 0x00000002 (balance) - 0x00000003 (maximize throughput)' = '0x00000001 (minimizar memoria, el que restaura OFF) - 0x00000002 (equilibrado) - 0x00000003 (maximizar rendimiento)'

    'SMB Opportunistic Locks' = 'Bloqueos oportunistas de SMB'
    'Turn off opportunistic locks on shared files' = 'Desactiva los bloqueos oportunistas en los archivos compartidos'
    'Oplocks let a network client cache a shared file locally. Turning them off avoids stale copies with some old programs, but every read goes over the network' = 'Los oplocks dejan que un cliente de la red guarde en caché un archivo compartido. Desactivarlos evita copias desfasadas con algunos programas antiguos, pero cada lectura pasa por la red'
    '0x00000001 (enabled, default) - 0x00000000 (disabled)' = '0x00000001 (activado, predeterminado) - 0x00000000 (desactivado)'
    'Only affects folders this PC shares; usually makes sharing slower' = 'Solo afecta a las carpetas que comparte este equipo; suele hacer más lento el acceso'

    'SMB IRP Stack Size' = 'Tamaño de pila IRP de SMB'
    'Give the file-sharing server more I/O request slots' = 'Da al servidor de archivos compartidos más huecos por petición de E/S'
    'Sets how many stack locations each I/O request packet of the file-sharing server gets. More is needed when antivirus or other filter drivers sit on the disk' = 'Fija cuántas posiciones de pila recibe cada paquete de petición de E/S del servidor de archivos compartidos. Hacen falta más cuando hay antivirus u otros controladores de filtro sobre el disco'
    '0x0000000F (15, default) - 11 to 50 - 0x00000020 (32)' = '0x0000000F (15, predeterminado) - 11 a 50 - 0x00000020 (32)'

    'SMB Sharing Violation Delay' = 'Pausa por infracción de uso compartido en SMB'
    'No pause between retries when a shared file is in use' = 'Sin pausa entre reintentos cuando un archivo compartido está en uso'
    'When a network client opens a shared file that is busy, the server waits this long before each retry. Zero retries without waiting' = 'Cuando un cliente de la red abre un archivo compartido que está ocupado, el servidor espera este tiempo antes de cada reintento. Con cero reintenta sin esperar'
    '0x000000C8 (200 ms, default) - 0x00000000 (no pause)' = '0x000000C8 (200 ms, predeterminado) - 0x00000000 (sin pausa)'

    'SMB Sharing Violation Retries' = 'Reintentos por infracción de uso compartido en SMB'
    'Fail at once when a shared file is in use' = 'Falla al momento cuando un archivo compartido está en uso'
    'When a network client opens a shared file that is busy, the server retries this many times before giving up. Zero returns the error immediately' = 'Cuando un cliente de la red abre un archivo compartido que está ocupado, el servidor reintenta este número de veces antes de rendirse. Con cero devuelve el error al instante'
    '0x00000005 (5, default) - 0x00000000 (no retries)' = '0x00000005 (5, predeterminado) - 0x00000000 (sin reintentos)'

    'QoS Reservable Bandwidth' = 'Ancho de banda reservable de QoS'
    'Set the bandwidth QoS applications may reserve to 0%' = 'Pone al 0% el ancho de banda que pueden reservar las aplicaciones con QoS'
    'Policy "Limit reservable bandwidth". Windows does NOT hold back 20% of your connection: the limit only applies to apps that ask for QoS priority, and unused bandwidth is always available to everything else' = 'Directiva "Limitar el ancho de banda reservable". Windows NO aparta el 20% de tu conexión: el límite solo se aplica a las aplicaciones que piden prioridad QoS, y el ancho de banda sin usar siempre está disponible para todo lo demás'
    'Not set (20%, default) - 0x00000000 (0%)' = 'Sin definir (20%, predeterminado) - 0x00000000 (0%)'
    'Myth: it does not free bandwidth for games' = 'Mito: no libera ancho de banda para los juegos'

    'Prefetcher' = 'Prefetcher'
    'Turn off application and boot prefetching' = 'Desactiva la precarga de aplicaciones y del arranque'
    'The prefetcher records which files programs and boot need and preloads them next time. Turning it off saves that background work, but programs and boot may load slower, mostly on hard disks' = 'El prefetcher apunta qué archivos necesitan los programas y el arranque y los precarga la siguiente vez. Apagarlo ahorra ese trabajo en segundo plano, pero los programas y el arranque pueden cargar más despacio, sobre todo en discos duros'
    '0x00000003 (apps and boot, default) - 0x00000002 (boot only) - 0x00000001 (apps only) - 0x00000000 (off)' = '0x00000003 (aplicaciones y arranque, predeterminado) - 0x00000002 (solo arranque) - 0x00000001 (solo aplicaciones) - 0x00000000 (apagado)'
    'Can make game launch slower on a hard disk' = 'Puede hacer que los juegos tarden más en abrir en un disco duro'

    'Block WPBT Executables' = 'Bloquear ejecutables de WPBT'
    'Stop the firmware from injecting programs into Windows' = 'Impide que el firmware inyecte programas en Windows'
    'The Windows Platform Binary Table lets the BIOS/UEFI hand Windows a program to run at every boot (manufacturer tools, anti-theft). Blocking it stops that program, and closes a known way to plant software from the firmware' = 'La Windows Platform Binary Table permite que la BIOS/UEFI le pase a Windows un programa para ejecutar en cada arranque (utilidades del fabricante, antirrobo). Bloquearla detiene ese programa y cierra una vía conocida para colar software desde el firmware'
    '0x00000000 (allowed, default) - 0x00000001 (blocked)' = '0x00000000 (permitido, predeterminado) - 0x00000001 (bloqueado)'
    'Raises security; may stop manufacturer utilities that came that way' = 'Sube la seguridad; puede detener utilidades del fabricante que llegaban por esa vía'

    'Activity History' = 'Historial de actividad'
    'Turn off the activity feed' = 'Apaga la fuente de actividad'
    'Policy that turns off the activity feed: Windows stops keeping the list of apps, files and pages you have used' = 'Directiva que apaga la fuente de actividad: Windows deja de guardar la lista de aplicaciones, archivos y páginas que has usado'
    'Not set (allowed, default) - 0x00000000 (blocked)' = 'Sin definir (permitido, predeterminado) - 0x00000000 (bloqueado)'

    'Publish User Activities' = 'Publicar actividades del usuario'
    'Stop Windows from recording user activities' = 'Impide que Windows registre las actividades del usuario'
    'Policy that stops apps from publishing what you do to the activity history' = 'Directiva que impide que las aplicaciones publiquen lo que haces en el historial de actividad'

    'Upload User Activities' = 'Subir actividades del usuario'
    'Stop uploading activity history to Microsoft' = 'Deja de subir el historial de actividad a Microsoft'
    'Policy that stops the activity history from being sent to Microsoft and synced to your other devices' = 'Directiva que impide que el historial de actividad se envíe a Microsoft y se sincronice con tus otros dispositivos'

    'Consumer Features' = 'Experiencias de consumidor'
    'Turn off Microsoft consumer experiences' = 'Desactiva las experiencias de consumidor de Microsoft'
    'Policy that stops Windows from installing suggested apps and showing promotional content. Windows only honours it on Enterprise and Education editions; on Home and Pro it is ignored' = 'Directiva que impide que Windows instale aplicaciones sugeridas y muestre contenido promocional. Windows solo la respeta en las ediciones Enterprise y Education; en Home y Pro se ignora'
    'Not set (allowed, default) - 0x00000001 (turned off)' = 'Sin definir (permitido, predeterminado) - 0x00000001 (desactivado)'
    'No effect on Home or Pro editions' = 'Sin efecto en las ediciones Home y Pro'

    'Delivery Optimization' = 'Optimización de distribución'
    'Download updates only from Microsoft, not from other PCs' = 'Descarga las actualizaciones solo de Microsoft, no de otros equipos'
    'Sets the Delivery Optimization download mode to HTTP only: Windows Update and the Store stop sharing pieces of updates with other PCs. Updates still install normally. It is the value behind the switch in Settings' = 'Pone el modo de descarga de Optimización de distribución en solo HTTP: Windows Update y la Tienda dejan de compartir trozos de actualizaciones con otros equipos. Las actualizaciones se siguen instalando con normalidad. Es el valor que hay detrás del interruptor de Configuración'
    '0x00000001 (PCs on the local network, default) - 0x00000000 (HTTP only)' = '0x00000001 (equipos de la red local, predeterminado) - 0x00000000 (solo HTTP)'
    'Stops update uploads to other PCs from using your connection' = 'Evita que subir actualizaciones a otros equipos ocupe tu conexión'

    'Delivery Optimization (Legacy Mode)' = 'Optimización de distribución (modo antiguo)'
    'Old name of the Delivery Optimization download mode' = 'Nombre antiguo del modo de descarga de Optimización de distribución'
    'Same download mode under the name that older Windows 10 builds read. Setting it to HTTP only keeps those builds from sharing pieces of updates with other PCs' = 'El mismo modo de descarga con el nombre que leen las compilaciones antiguas de Windows 10. Ponerlo en solo HTTP evita que esas compilaciones compartan trozos de actualizaciones con otros equipos'

    'Delivery Optimization (Settings Key)' = 'Optimización de distribución (clave Settings)'
    'Download mode stored in the Delivery Optimization settings key' = 'Modo de descarga guardado en la clave Settings de Optimización de distribución'
    'Copy of the download mode that the Settings app keeps in its own key. Setting it to HTTP only keeps it in line with the other Delivery Optimization values' = 'Copia del modo de descarga que la aplicación Configuración guarda en su propia clave. Ponerlo en solo HTTP lo deja alineado con el resto de valores de Optimización de distribución'

    'End Task With Right Click' = 'Finalizar tarea con clic derecho'
    'Add "End task" to the taskbar right-click menu' = 'Añade "Finalizar tarea" al menú contextual de la barra de tareas'
    'Shows an "End task" entry when you right-click an app on the taskbar, to close a frozen program without opening Task Manager' = 'Muestra la opción "Finalizar tarea" al hacer clic derecho sobre una aplicación de la barra de tareas, para cerrar un programa colgado sin abrir el Administrador de tareas'
    '0x00000000 (hidden, default) - 0x00000001 (shown)' = '0x00000000 (oculto, predeterminado) - 0x00000001 (visible)'
    'Quick way to close a frozen game' = 'Forma rápida de cerrar un juego colgado'

    'Geolocation Service' = 'Servicio de geolocalización'
    'Disable the location service (lfsvc)' = 'Deshabilita el servicio de ubicación (lfsvc)'
    'Disables the service that gives apps the position of this PC. Maps, weather and "Find my device" stop knowing where you are. Applies after a restart' = 'Deshabilita el servicio que da a las aplicaciones la posición de este equipo. Mapas, El Tiempo y "Buscar mi dispositivo" dejan de saber dónde estás. Se aplica al reiniciar'

    'Offline Files Service' = 'Servicio de archivos sin conexión'
    'Disable the Offline Files service (CscService)' = 'Deshabilita el servicio de archivos sin conexión (CscService)'
    'Disables the service that keeps local copies of network folders to use them without a connection. Nobody uses it on a home PC. Applies after a restart' = 'Deshabilita el servicio que guarda copias locales de carpetas de red para usarlas sin conexión. En un equipo doméstico no se usa. Se aplica al reiniciar'
    'Unused on a home PC' = 'No se usa en un equipo doméstico'

    'Downloaded Maps Manager' = 'Administrador de mapas descargados'
    'Disable the offline maps service (MapsBroker)' = 'Deshabilita el servicio de mapas sin conexión (MapsBroker)'
    'Disables the service that downloads and updates offline maps for the Maps app. Applies after a restart' = 'Deshabilita el servicio que descarga y actualiza los mapas sin conexión de la aplicación Mapas. Se aplica al reiniciar'
    '0x00000002 (automatic, delayed, default) - 0x00000004 (disabled)' = '0x00000002 (automático retrasado, predeterminado) - 0x00000004 (deshabilitado)'
    'Removes a background service most PCs never use' = 'Quita un servicio en segundo plano que la mayoría de equipos nunca usa'

    'Storage Service' = 'Servicio de almacenamiento'
    'Disable the Storage Service (StorSvc)' = 'Deshabilita el servicio de almacenamiento (StorSvc)'
    'Disables the service behind Storage Sense, the storage settings and installing Store apps on other drives; those stop working. Applies after a restart' = 'Deshabilita el servicio que hay detrás del Sensor de almacenamiento, la configuración de almacenamiento y la instalación de aplicaciones de la Tienda en otras unidades; todo eso deja de funcionar. Se aplica al reiniciar'
    'May break installing Store or Game Pass games on another drive' = 'Puede impedir instalar juegos de la Tienda o de Game Pass en otra unidad'

    'Internet Connection Sharing' = 'Conexión compartida a Internet'
    'Disable Internet Connection Sharing (SharedAccess)' = 'Deshabilita la conexión compartida a Internet (SharedAccess)'
    'Disables the service that shares this PC connection with other devices. Mobile hotspot and the Hyper-V Default Switch stop working. Applies after a restart' = 'Deshabilita el servicio que comparte la conexión de este equipo con otros dispositivos. La zona con cobertura inalámbrica móvil y el conmutador predeterminado de Hyper-V dejan de funcionar. Se aplica al reiniciar'
    'Breaks mobile hotspot; no effect on game performance' = 'Rompe la zona con cobertura inalámbrica móvil; no afecta al rendimiento de los juegos'

    'Hibernation' = 'Hibernación'
    'Turn off hibernation and free hiberfil.sys' = 'Desactiva la hibernación y libera hiberfil.sys'
    'Turns off hibernation. Windows deletes hiberfil.sys (several GB on the system drive) on the next restart, and Fast Startup also stops working because it depends on hibernation' = 'Desactiva la hibernación. Windows borra hiberfil.sys (varios GB en la unidad del sistema) en el siguiente reinicio, y el Inicio rápido también deja de funcionar porque depende de la hibernación'
    'Frees disk space; boot from off may take a little longer' = 'Libera espacio en disco; arrancar desde apagado puede tardar algo más'

    'Location Access' = 'Acceso a la ubicación'
    'Deny location access for the whole device' = 'Deniega el acceso a la ubicación en todo el dispositivo'
    'Same as turning off "Location services" in Settings > Privacy: no app or user on this PC can read its location' = 'Igual que apagar "Servicios de ubicación" en Configuración > Privacidad: ninguna aplicación ni usuario de este equipo puede leer su ubicación'
    'Allow (default) - Deny' = 'Allow (permitir, predeterminado) - Deny (denegar)'

    'Advertising ID' = 'Id. de publicidad'
    'Turn off the advertising ID for apps' = 'Desactiva el id. de publicidad para las aplicaciones'
    'Stops apps from using your advertising ID to show personalized ads. Same as the switch in Settings > Privacy > General' = 'Impide que las aplicaciones usen tu id. de publicidad para mostrar anuncios personalizados. Igual que el interruptor de Configuración > Privacidad > General'

    'Tailored Experiences' = 'Experiencias personalizadas'
    'Stop Microsoft from using diagnostic data for tips and ads' = 'Impide que Microsoft use los datos de diagnóstico para sugerencias y anuncios'
    'Stops Microsoft from using your diagnostic data to offer personalized tips, ads and recommendations' = 'Impide que Microsoft use tus datos de diagnóstico para ofrecerte sugerencias, anuncios y recomendaciones personalizados'

    'Online Speech Recognition' = 'Reconocimiento de voz en línea'
    'Turn off cloud speech recognition' = 'Desactiva el reconocimiento de voz en la nube'
    'Stops sending your voice to Microsoft for online speech recognition. Voice typing and voice access fall back to what works offline' = 'Deja de enviar tu voz a Microsoft para el reconocimiento de voz en línea. El dictado y el acceso por voz se quedan con lo que funciona sin conexión'
    '0x00000001 (accepted, default) - 0x00000000 (off)' = '0x00000001 (aceptado, predeterminado) - 0x00000000 (desactivado)'

    'Improve Inking and Typing' = 'Mejorar la escritura a mano y el tecleo'
    'Stop sending inking and typing data to Microsoft' = 'Deja de enviar a Microsoft datos de escritura a mano y tecleo'
    'Stops sending samples of what you type and write with a pen to help Microsoft improve its recognition' = 'Deja de enviar muestras de lo que tecleas y escribes con el lápiz para ayudar a Microsoft a mejorar su reconocimiento'

    'Inking and Typing Personalization' = 'Personalización de escritura a mano y tecleo'
    'Stop learning from your handwriting' = 'Deja de aprender de tu letra'
    'Part of the "custom inking and typing dictionary": Windows stops collecting what you write with a pen to adapt its handwriting recognition' = 'Parte del "diccionario personalizado de escritura a mano y tecleo": Windows deja de recopilar lo que escribes con el lápiz para adaptar su reconocimiento de escritura'

    'Typing Personalization' = 'Personalización del tecleo'
    'Stop learning from what you type' = 'Deja de aprender de lo que tecleas'
    'Part of the "custom inking and typing dictionary": Windows stops collecting the words you type to build its suggestions' = 'Parte del "diccionario personalizado de escritura a mano y tecleo": Windows deja de recopilar las palabras que tecleas para construir sus sugerencias'

    'Harvest Contacts' = 'Recopilar contactos'
    'Stop learning names from your contacts' = 'Deja de aprender nombres de tus contactos'
    'Part of the "custom inking and typing dictionary": Windows stops reading your contacts to recognise their names when you write or type' = 'Parte del "diccionario personalizado de escritura a mano y tecleo": Windows deja de leer tus contactos para reconocer sus nombres cuando escribes o tecleas'

    'Personalization Privacy Policy' = 'Directiva de privacidad de la personalización'
    'Withdraw consent for the personal dictionary' = 'Retira el consentimiento del diccionario personal'
    'Part of the "custom inking and typing dictionary": withdraws the acceptance of its privacy policy, so the stored data stops being used' = 'Parte del "diccionario personalizado de escritura a mano y tecleo": retira la aceptación de su directiva de privacidad, así que deja de usarse lo que tenía guardado'

    'Diagnostic Data Level' = 'Nivel de datos de diagnóstico'
    'Send Microsoft the least diagnostic data the edition allows' = 'Envía a Microsoft los mínimos datos de diagnóstico que permite la edición'
    'Sets the diagnostic data level. 0 (Security) is only honoured on Enterprise and Education; on Home and Pro Windows treats it as 1 (Required data only)' = 'Fija el nivel de datos de diagnóstico. 0 (Seguridad) solo se respeta en Enterprise y Education; en Home y Pro Windows lo trata como 1 (solo datos obligatorios)'
    '0x00000001 (required only, restored with OFF) - 0x00000003 (optional data, if accepted at setup) - 0x00000000 (security, Enterprise/Education)' = '0x00000001 (solo obligatorios, el que restaura OFF) - 0x00000003 (datos opcionales, si se aceptó en la instalación) - 0x00000000 (seguridad, Enterprise/Education)'

    'Track App Launches' = 'Seguimiento de aplicaciones abiertas'
    'Stop Windows from tracking which apps you open' = 'Impide que Windows registre qué aplicaciones abres'
    'Stops Windows from recording which apps you launch to improve Start and search results. "Most used" in Start stops filling in' = 'Impide que Windows apunte qué aplicaciones abres para mejorar Inicio y los resultados de búsqueda. La lista "Más usadas" de Inicio deja de rellenarse'

    'Feedback Frequency' = 'Frecuencia de comentarios'
    'Stop Windows from asking for your feedback' = 'Impide que Windows te pida tu opinión'
    'Sets how many times Windows may ask for your feedback (the Feedback Hub surveys and pop-ups). 0 means never. You can still send feedback yourself' = 'Fija cuántas veces puede Windows pedirte tu opinión (las encuestas y avisos del Centro de opiniones). 0 es nunca. Puedes seguir enviando comentarios por tu cuenta'
    'Not set (Windows decides, default) - 0x00000000 (never)' = 'Sin definir (decide Windows, predeterminado) - 0x00000000 (nunca)'

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

    # ---- Power (comandos) ----
    'Add the Ultimate Performance plan' = 'Añadir el plan Máximo rendimiento'
    'Copies the hidden Ultimate Performance power plan so it can be used and shows up in Power Options. If this program already added it, the step is skipped.' = 'Copia el plan de energía oculto Máximo rendimiento para que se pueda usar y aparezca en Opciones de energía. Si este programa ya lo añadió, el paso se salta.'
    'Switch to the Ultimate Performance plan' = 'Activar el plan Máximo rendimiento'
    'Makes it the plan in use: the processor no longer slows down to save power, so it responds faster but uses more energy and runs warmer.' = 'Lo pone como plan en uso: el procesador deja de frenarse para ahorrar energía, así que responde antes pero gasta más y se calienta más.'
    'On a laptop it drains the battery faster.' = 'En un portátil gasta antes la batería.'

    # ---- Update ----
    'Delivery Optimization (P2P)' = 'Optimización de distribución (P2P)'
    'Download updates only from Microsoft, never from or to other PCs' = 'Descargar las actualizaciones solo de Microsoft, nunca desde ni hacia otros equipos'
    'Group policy "Download Mode" set to HTTP only: Windows Update and the Store stop sharing pieces of updates with other PCs, on your network or on the internet. Updates still install normally. Turning it off removes the policy and Windows goes back to its own setting' = 'Directiva «Modo de descarga» en solo HTTP: Windows Update y la Tienda dejan de compartir trozos de actualizaciones con otros equipos, de tu red o de internet. Las actualizaciones se siguen instalando con normalidad. Al desactivarlo se quita la directiva y Windows vuelve a su propia configuración'
    'Not set (default; Windows uses 1, PCs on the local network) - 0x00000000 (HTTP only, no other PCs) - 0x00000003 (also PCs on the internet)' = 'Sin definir (predeterminado; Windows usa 1, equipos de la red local) - 0x00000000 (solo HTTP, sin otros equipos) - 0x00000003 (también equipos de internet)'

    'Auto-Restart With Active Sessions' = 'Reinicio automático con sesión iniciada'
    'Stop Windows Update from restarting the PC while you are signed in. Lowers security: fixes that need a restart wait until you restart' = 'Impedir que Windows Update reinicie el equipo con la sesión iniciada. Baja la seguridad: las correcciones que piden reiniciar esperan a que reinicies tú'
    'Policy "No auto-restart with logged on users for scheduled automatic updates installations". While someone is signed in, Windows waits for you to restart instead of doing it on its own, so security fixes that need a restart are not applied until then. Microsoft warns that on a PC nobody signs out of, updates may never restart. Windows only honours it when "Configure Automatic Updates" is set to scheduled install (option 4)' = 'Directiva «No reiniciar automáticamente con usuarios que hayan iniciado sesión para instalaciones de actualizaciones automáticas programadas». Con alguien con la sesión iniciada, Windows espera a que reinicies tú en vez de hacerlo solo, así que las correcciones de seguridad que piden reiniciar no se aplican hasta entonces. Microsoft avisa de que en un equipo en el que nadie cierra sesión puede que las actualizaciones no reinicien nunca. Windows solo la respeta si «Configurar Actualizaciones automáticas» está en instalación programada (opción 4)'
    'Not set (default; Windows may restart on its own outside active hours) - 0x00000001 (no automatic restart while signed in)' = 'Sin definir (predeterminado; Windows puede reiniciar solo fuera del horario activo) - 0x00000001 (sin reinicio automático con la sesión iniciada)'
    'Avoids restarts during a match, but security fixes wait for you' = 'Evita reinicios en mitad de una partida, pero las correcciones de seguridad te esperan'

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
    'Command'        = 'Comando'
    'Warning'        = 'Aviso'
    'File'           = 'Archivo'
    'Guide text'     = 'Texto de la guía'
    'Registry value' = 'Valor del registro'
    'Type'           = 'Tipo'
    'Current value'  = 'Valor actual'
    'Factory'        = 'De fábrica'
    'Status'         = 'Estado'
    # 'Recommended' ya está más arriba, con las etiquetas de
    # clasificación: es la misma palabra.
    'Service'        = 'Servicio'
    'Scheduled task' = 'Tarea programada'

    # ============================================================
    # SERVICIOS Y TAREAS (core/Services/, core/ScheduledTasks/)
    # ============================================================

    # ---- Marco: lectura, refresco, detalles técnicos y log ----
    'Reading services and tasks...' = 'Leyendo servicios y tareas...'
    'Reading the registry, services and tasks...' = 'Leyendo el registro, los servicios y las tareas...'
    'Read the services and tasks again' = 'Volver a leer los servicios y las tareas'
    'Services and tasks updated' = 'Servicios y tareas actualizados'
    'Windows service' = 'Servicio de Windows'
    'Service:'        = 'Servicio:'
    'Folder:'         = 'Carpeta:'
    'Task:'           = 'Tarea:'
    'Copy the service name' = 'Copiar el nombre del servicio'
    'Copy the task folder'  = 'Copiar la carpeta de la tarea'
    'Copy the task name'    = 'Copiar el nombre de la tarea'
    'not found on this PC'  = 'no existe en este equipo'
    'not found'    = 'no existe'
    'unavailable'  = 'no disponible'
    'invalid name' = 'nombre inválido'

    # Tipos de inicio de un servicio y estado de una tarea: los mismos
    # nombres que services.msc y el Programador de tareas.
    'Automatic' = 'Automático'
    'Manual'    = 'Manual'
    'Disabled'  = 'Deshabilitado'
    'Enabled'   = 'Habilitado'
    'Boot'      = 'Arranque'
    'System'    = 'Sistema'

    # ---- La sección ----
    'Services & Tasks' = 'Servicios y tareas'
    'Telemetry services and scheduled tasks' = 'Servicios de telemetría y tareas programadas'

    'Automatic (default) - Manual - Disabled' = 'Automático (predeterminado) - Manual - Deshabilitado'
    'Enabled (default) - Disabled' = 'Habilitado (predeterminado) - Deshabilitado'
    'Avoids an occasional disk scan in the background' = 'Evita un análisis de disco ocasional en segundo plano'

    'Telemetry Service' = 'Servicio de telemetría'
    'Disable Connected User Experiences and Telemetry (DiagTrack)' = 'Deshabilita Experiencias del usuario y telemetría asociadas (DiagTrack)'
    'Sets the service that collects and sends diagnostic data to Microsoft to Disabled. Windows Update and Defender keep working. Applies after a restart' = 'Pone en Deshabilitado el servicio que recopila y envía datos de diagnóstico a Microsoft. Windows Update y Defender siguen funcionando. Se aplica al reiniciar'
    'Privacy; removes a small background load' = 'Privacidad; quita una pequeña carga en segundo plano'

    'WAP Push Message Routing' = 'Enrutamiento de mensajes WAP Push'
    'Disable the WAP Push message routing service (dmwappushservice)' = 'Deshabilita el servicio de enrutamiento de mensajes WAP Push (dmwappushservice)'
    'Sets to Disabled the service that routes device management push messages and feeds the telemetry pipeline. A home PC that no organization manages does not use it. If this PC is enrolled in work or school device management (Intune, MDM), leave it as it is. Applies after a restart' = 'Pone en Deshabilitado el servicio que enruta los mensajes push de la administración de dispositivos y alimenta la telemetría. Un equipo doméstico que no administra ninguna organización no lo usa. Si este equipo está inscrito en la administración de dispositivos del trabajo o de un centro de estudios (Intune, MDM), déjalo como está. Se aplica al reiniciar'
    'Manual (default, starts on demand) - Disabled' = 'Manual (predeterminado, arranca cuando se le pide) - Deshabilitado'

    'SysMain Service' = 'Servicio SysMain'
    'Disable SysMain (formerly Superfetch). Debatable: on an SSD it gains almost nothing' = 'Deshabilita SysMain (antes Superfetch). Discutible: en un SSD casi no gana nada'
    'SysMain preloads into memory the programs you use most. On a hard disk that makes them open faster, so disabling it usually makes the PC slower. On an SSD both the benefit and the cost are small. Only worth disabling if you see it causing constant disk activity. Applies after a restart' = 'SysMain carga por adelantado en memoria los programas que más usas. En un disco duro eso los abre más rápido, así que deshabilitarlo suele volver el equipo más lento. En un SSD tanto la ventaja como el coste son pequeños. Solo merece la pena deshabilitarlo si ves que provoca actividad de disco constante. Se aplica al reiniciar'
    'Not a gaming tweak: on a hard disk, games and apps may load slower' = 'No es un ajuste para juegos: en un disco duro, juegos y aplicaciones pueden cargar más despacio'

    'Compatibility Appraiser' = 'Evaluador de compatibilidad'
    'Disable the program compatibility telemetry task' = 'Deshabilita la tarea de telemetría de compatibilidad de programas'
    'Scheduled task that scans installed programs and sends compatibility data to Microsoft, which uses it for Windows upgrade checks. Some Windows 11 builds renamed or removed it: then it shows as not found and the switch changes nothing' = 'Tarea programada que analiza los programas instalados y envía datos de compatibilidad a Microsoft, que los usa para comprobar las actualizaciones de Windows. Algunas compilaciones de Windows 11 la renombraron o la quitaron: entonces sale como inexistente y el interruptor no cambia nada'

    'Program Data Updater' = 'Actualizador de datos de programas'
    'Disable the program telemetry task of the Customer Experience Improvement Program' = 'Deshabilita la tarea de telemetría de programas del Programa para la mejora de la experiencia del usuario'
    'Scheduled task that collects program telemetry for the Customer Experience Improvement Program. Windows 11 no longer has it on most PCs: if it is not found, there is nothing to change' = 'Tarea programada que recopila telemetría de programas para el Programa para la mejora de la experiencia del usuario. Windows 11 ya no la trae en la mayoría de equipos: si no existe, no hay nada que cambiar'

    'CEIP Consolidator' = 'Consolidador del CEIP'
    'Disable the task that sends usage data to Microsoft' = 'Deshabilita la tarea que envía datos de uso a Microsoft'
    'Scheduled task of the Customer Experience Improvement Program: if you joined it, it collects and sends usage data to Microsoft' = 'Tarea programada del Programa para la mejora de la experiencia del usuario: si participas, recopila y envía datos de uso a Microsoft'

    'USB CEIP' = 'CEIP de USB'
    'Disable the USB telemetry task' = 'Deshabilita la tarea de telemetría de USB'
    'Scheduled task that collects USB statistics and information about this PC and sends them to Microsoft, for Customer Experience Improvement Program participants. USB devices keep working the same' = 'Tarea programada que recopila estadísticas de USB e información sobre este equipo y las envía a Microsoft, para quienes participan en el Programa para la mejora de la experiencia del usuario. Los dispositivos USB siguen funcionando igual'

    'Autochk Telemetry' = 'Telemetría de Autochk'
    'Disable the task that uploads boot disk check data' = 'Deshabilita la tarea que sube los datos de la comprobación de disco al arrancar'
    'Scheduled task that collects and uploads data from autochk (the disk check at boot) for the Customer Experience Improvement Program. The disk check itself keeps working: only the upload stops' = 'Tarea programada que recopila y sube los datos de autochk (la comprobación de disco al arrancar) para el Programa para la mejora de la experiencia del usuario. La comprobación de disco sigue funcionando: solo deja de subirse'

    'Disk Diagnostic Data Collector' = 'Recopilador de datos de diagnóstico de disco'
    'Disable the task that sends disk information to Microsoft' = 'Deshabilita la tarea que envía información de los discos a Microsoft'
    'Scheduled task that sends general information about your disks and system to Microsoft, for Customer Experience Improvement Program participants. It is not the disk check (chkdsk), which is not affected' = 'Tarea programada que envía información general sobre tus discos y el sistema a Microsoft, para quienes participan en el Programa para la mejora de la experiencia del usuario. No es la comprobación de disco (chkdsk), que no se ve afectada'

}
