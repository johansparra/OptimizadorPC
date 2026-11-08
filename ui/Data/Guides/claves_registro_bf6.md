# Claves de registro — BF6 / Gaming Network Tweaks

## 1) Multimedia System Profile
`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`

### NetworkThrottlingIndex
**Qué hace:** Limita a 10 paquetes/ms el tráfico de red mientras Windows detecta audio/video activo (MMCSS), para priorizar CPU al multimedia.
**Valores:** `0x0000000A` (10, predeterminado) · `1`–`70` (ajustable) · `0xFFFFFFFF` (desactiva el límite)
**¿Óptimo para gaming?** Sí — elimina el throttling de red durante partidas.
**Link oficial:** https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service *(documenta MMCSS; este valor puntual es tweak derivado, sin doc oficial exacta)*

### SystemResponsiveness
**Qué hace:** % de CPU reservado para tareas de baja prioridad mientras corre MMCSS. A menor valor, más CPU disponible para la app en primer plano.
**Valores:** `20` (0x14, predeterminado) · `0`–`100` (se redondea al múltiplo de 10 más cercano) · `0` (nada reservado) · `100` (desactiva MMCSS)
**¿Óptimo para gaming?** Sí — en 0 le da toda la CPU disponible al juego.
**Link oficial:** https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service

---

## 2) MMCSS — Prioridad para juegos
`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`

### GPU Priority
**Qué hace:** Prioridad relativa de GPU asignada a la tarea "Games" dentro de MMCSS.
**Valores:** `2` (predeterminado) · `8` (máxima prioridad)
**¿Óptimo para gaming?** Sí.
**Link oficial:** https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service *(tabla de valores de Tasks, sin recomendación oficial de "óptimo")*

### Priority
**Qué hace:** Prioridad de CPU del hilo asociado a la tarea "Games".
**Valores:** `2` (predeterminado) · `1`–`8` (mayor = más prioridad) · `6` (usado en este tweak)
**¿Óptimo para gaming?** Sí, dentro de rango razonable.
**Link oficial:** mismo de arriba.

### Scheduling Category
**Qué hace:** Categoría de scheduling del hilo (afecta boost de prioridad del kernel).
**Valores:** `Medium` (predeterminado) · `High` / `Low` / `Exhausted`
**¿Óptimo para gaming?** Sí, `High` da mejor respuesta.
**Link oficial:** mismo de arriba.

### SFIO Priority
**Qué hace:** Prioridad de I/O (disco) asignada al hilo.
**Valores:** `Normal` (predeterminado) · `Low` / `High`
**¿Óptimo para gaming?** Sí, reduce esperas de I/O durante carga de assets.
**Link oficial:** mismo de arriba.

---

## 2b) Game Bar / Game Mode
`HKCU\Software\Microsoft\GameBar`

### AllowAutoGameMode / AutoGameModeEnabled
**Qué hace:** Activa el "Modo Juego" de Windows automáticamente al detectar un juego (pausa notificaciones, prioriza el proceso).
**Valores:** `0` (desactivado) · `1` (activado, predeterminado en Windows 11)
**¿Óptimo para gaming?** Sí, mantenerlo en `1`.
**Link oficial:** No hay documentación técnica oficial de esta clave puntual (es configuración interna de Xbox Game Bar); referencia general: https://support.microsoft.com/windows/game-mode-in-windows-e2129f36-a3d1-6207-8c25-f30c76f52338

---

## 3) TCP/IP Parameters (global)
`HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters`

Esta rama sí tiene documentación oficial extensa (originalmente TechNet, ahora "previous-versions" en Learn):
**Link base oficial:** https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/cc957549(v=technet.10)

### DefaultTTL
**Qué hace:** Time-to-live por defecto de paquetes IP salientes.
**Valores:** `128` (0x80, predeterminado) · `1`–`255` · `64` (0x40, usado aquí)
**¿Óptimo para gaming?** Neutro — no afecta rendimiento, solo dificulta el fingerprinting del ISP.
**Link oficial:** https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/cc957549(v=technet.10)

### Tcp1323Opts
**Qué hace:** Activa Window Scaling y Timestamps (RFC 1323) para ventanas TCP dinámicas.
**Valores:** `0` (desactivado) · `1` (solo scaling) · `2` (solo timestamps) · `3` (ambos, predeterminado en Windows moderno)
**¿Óptimo para gaming?** Neutro/positivo — ya suele venir en 3 por defecto en Win10/11.
**Link oficial:** mismo de arriba.

### TcpWindowSize / GlobalMaxTcpWindowSize
**Qué hace:** Tamaño de la ventana de recepción TCP.
**Valores:** `0xFFFF` (65535, valor usado aquí) · autoajustable de forma nativa en Win10/11 (auto-tuning)
**¿Óptimo para gaming?** Cuestionable — Windows 10/11 ya autoajusta la ventana dinámicamente; fijarla puede limitar throughput en enlaces rápidos.
**Link oficial:** mismo de arriba.

### MaxUserPort
**Qué hace:** Rango máximo de puertos efímeros disponibles para conexiones salientes.
**Valores:** `5000` (predeterminado, decimal) · `0xFFFE` (65534, usado aquí)
**¿Óptimo para gaming?** Sí, útil con muchas apps de red abiertas a la vez.
**Link oficial:** mismo de arriba.

### TcpTimedWaitDelay
**Qué hace:** Segundos que una conexión permanece en estado TIME_WAIT antes de liberar el puerto.
**Valores:** `240` (predeterminado) · `30`–`300` · `30` (0x1E, usado aquí)
**¿Óptimo para gaming?** Sí, libera puertos más rápido.
**Link oficial:** mismo de arriba.

### TcpMaxDataRetransmissions
**Qué hace:** Número de reintentos antes de dar un segmento por perdido.
**Valores:** `5` (predeterminado, igual al usado aquí)
**¿Óptimo para gaming?** Neutro — ya está en su valor por defecto.
**Link oficial:** mismo de arriba.

### TcpMaxDupAcks
**Qué hace:** Número de ACKs duplicados antes de disparar retransmisión rápida.
**Valores:** `2` (predeterminado, igual al usado aquí)
**¿Óptimo para gaming?** Neutro — valor estándar, no aporta cambio real.
**Link oficial:** mismo de arriba.

### SackOpts
**Qué hace:** Activa Selective Acknowledgment (retransmite solo el segmento perdido, no toda la ventana).
**Valores:** `1` (activado, predeterminado en Windows moderno)
**¿Óptimo para gaming?** Neutro/positivo — ya suele venir activado.
**Link oficial:** mismo de arriba.

### EnablePMTUDiscovery
**Qué hace:** Detecta el MTU óptimo de la ruta hacia el servidor destino.
**Valores:** `1` (activado, predeterminado)
**¿Óptimo para gaming?** Neutro — ya está en su valor por defecto.
**Link oficial:** mismo de arriba.

### EnablePMTUBHDetect
**Qué hace:** Detecta "black holes" de MTU (routers que descartan ICMP necesarios para el discovery).
**Valores:** `0` (desactivado, predeterminado) · `1` (activado)
**¿Óptimo para gaming?** Neutro — se deja en su valor por defecto (0).
**Link oficial:** mismo de arriba.

---

## 3b) Winsock
`HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Winsock`

### MaxSockAddrLength / MinSockAddrLength
**Qué hace:** Longitud de estructura de direcciones de socket usada por Winsock.
**Valores:** `16` (0x10) — valor estándar de por sí, rara vez se toca
**¿Óptimo para gaming?** Sin impacto — no es un tweak de rendimiento.
**Link oficial:** No documentado como tweak; referencia de API: https://learn.microsoft.com/en-us/windows/win32/winsock/sockaddr-2

---

## 3c) LanmanServer / SysMain / Ndu
No relacionados con red de juego, sino con compartición de archivos (SMB) y telemetría de uso de red:

### autodisconnect, Size, EnableOplocks, IRPStackSize, SharingViolation*
**Qué hace:** Configuración del servidor SMB (compartición de archivos/impresoras). No afecta tráfico de juego.
**¿Óptimo para gaming?** No aplica — irrelevante para latencia/rendimiento en juegos online.
**Link oficial:** https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-server-tuning

### SysMain (Start=4, deshabilitado)
**Qué hace:** Servicio que precarga apps de uso frecuente en RAM (antes "Superfetch").
**Valores:** `2` (automático, predeterminado) · `4` (deshabilitado)
**¿Óptimo para gaming?** Discutible — en SSD/NVMe con suficiente RAM se suele deshabilitar sin pérdida notable, pero no es un tweak de red.
**Link oficial:** No hay doc oficial de "valor óptimo"; referencia general de servicios: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config

### Ndu (Start=2)
**Qué hace:** Network Data Usage Monitor — recolecta estadísticas de uso de red por proceso (Task Manager/Configuración las usa).
**Valores:** `2` (automático) · `4` (deshabilitado, tweak común aunque aquí quedó en 2)
**¿Óptimo para gaming?** Marginal — deshabilitarlo reduce overhead mínimo; no cambia latencia real.
**Link oficial:** No documentado oficialmente como tweak de gaming.

---

## 4) QoS Packet Scheduler
`HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched`

### NonBestEffortLimit
**Qué hace:** % de ancho de banda que Windows reserva para tráfico QoS (equivalente al ajuste de `gpedit.msc`).
**Valores:** `20` (predeterminado) · `0` (libera el 100% del ancho de banda)
**¿Óptimo para gaming?** Sí — mito parcial (Windows no reserva ancho de banda salvo que una app lo pida activamente), pero no hace daño.
**Link oficial:** https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-r2-and-2008/cc731316(v=ws.10)

---

## 5) Prefetcher
`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters`

### EnablePrefetcher
**Qué hace:** Controla si Windows precarga en RAM archivos usados frecuentemente al iniciar apps.
**Valores:** `3` (ambos, predeterminado) · `0` (desactivado) · `1` (solo apps) · `2` (solo boot)
**¿Óptimo para gaming?** Discutible en SSD/NVMe — reduce actividad de disco en segundo plano, pero no es un tweak de red/latencia.
**Link oficial:** No documentado oficialmente por Microsoft como ajuste de rendimiento.

---

## 6–13) Privacidad, telemetría y servicios en segundo plano
(Activity History, ConsumerFeatures, Delivery Optimization, ubicación, DiagTrack, telemetría, etc.)

**Qué hacen (en conjunto):** Deshabilitan servicios de telemetría, actualizaciones P2P, seguimiento de actividad/ubicación y sugerencias del sistema.
**¿Óptimo para gaming?** No — son tweaks de **privacidad y limpieza**, no de rendimiento en juego. Su efecto en FPS/latencia es nulo o marginal (liberan algo de CPU/red en segundo plano, no lo que se nota en partida).
**Link oficial:** Las políticas de privacidad sí están documentadas oficialmente (son GPO estándar):
https://learn.microsoft.com/en-us/windows/privacy/manage-windows-1809-endpoints

---

## Nota — Nagle's Algorithm (no incluida en el .reg)
Va en `HKLM\...\Tcpip\Parameters\Interfaces\{GUID}` (por adaptador, no global). Ya la tienes aplicada según lo trabajado antes (`TcpAckFrequency=1`, `TCPNoDelay=1`).
**Link oficial:** https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/nagles-algorithm
