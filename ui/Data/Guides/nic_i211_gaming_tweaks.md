# Intel(R) I211 Gigabit Network Connection — Ajustes para gaming (BF6)

Valores recomendados en **Propiedades del adaptador → Opciones avanzadas**.
Cambia una propiedad a la vez si quieres aislar el efecto de cada una.

| Propiedad | Valor recomendado | Por qué |
| --- | --- | --- |
| Activar al coincidir el patrón (Wake on Pattern Match) | **Deshabilitado** | Función de servidor/red corporativa, sin uso en gaming. Evita que el NIC despierte el sistema innecesariamente. |
| Activar en Magic Packet | **Deshabilitado** | Wake-on-LAN. Si no lo usas para encender el PC remotamente, desactívalo. |
| Activar PME | **Deshabilitado** | Permite que el NIC saque al PC de suspensión. Sin uso en gaming. |
| Búferes de recepción (Receive Buffers) | **Máximo disponible** (normalmente 2048) | Más espacio para encolar paquetes entrantes antes de que la CPU los procese → menos descartes en ráfagas de tráfico (combates grandes). |
| Búferes de transmisión (Transmit Buffers) | **Máximo disponible** (normalmente 2048) | Igual que arriba pero para salida. |
| Configuración de Activar en enlace (Wake on Link) | **Deshabilitado** | Sin uso en gaming. |
| Control de flujo (Flow Control) | **Deshabilitado** | Puede pausar la transmisión completa del NIC en momentos de saturación — justo cuando más te duele el lag. Mejor dejar que TCP maneje la congestión. |
| Descarga de ARP | **Deshabilitado** | Función de ahorro de energía en suspensión, sin efecto en gaming activo. |
| Descarga de NS | **Deshabilitado** | Equivalente IPv6 del anterior. |
| Descarga de suma de comprobación de IPv4 | **Recepcion y transmision habilitadas** | Esta sí ayuda: mueve el cálculo de checksum a hardware del NIC (I211 lo soporta bien), libera CPU. Solo se desactiva si sospechas bug de driver. |
| Descarga de suma de comprobación TCP (IPv4) | **Recepcion y transmision habilitadas** | Mismo caso, offload de hardware confiable en esta tarjeta. |
| Descarga de suma de comprobación TCP (IPv6) | **Deshabilitado** | Igual. |
| Descarga de suma de comprobación UDP (IPv4) | **Recepcion y transmision habilitadas** | BF6 usa mucho UDP — este offload es beneficioso, no lo apagues. |
| Descarga de suma de comprobación UDP (IPv6) | **Deshabilitado** | Igual. |
| Descarga grande de envío V2 (IPv4) — LSO | **Deshabilitado** | LSO agrupa segmentos grandes antes de enviarlos, lo que **añade latencia** — mala combinación para juegos competitivos aunque ayude en transferencias de archivos grandes. |
| Descarga grande de envío V2 (IPv6) — LSO | **Deshabilitado** | Mismo motivo. |
| Dirección administrada localmente | **No presente / en blanco** | Solo se usa para forzar una MAC address custom. No tocar. |
| Esperar al enlace (Wait for Link) | **Deshabilitado** (o "Auto Detect" si no aparece deshabilitado) | Acelera la negociación del enlace al iniciar el PC. |
| Ethernet con uso eficiente de energía (EEE / Green Ethernet) | **Deshabilitado** | El NIC "despierta" el enlace en microsegundos para ahorrar energía, y eso mete jitter/latencia intermitente. El culpable clásico de picos de ping random. |
| Marca de tiempo de hardware PTP | **Deshabilitado** | Precision Time Protocol, uso industrial/broadcast. Sin relación con gaming. |
| Marca de tiempo de software | **Deshabilitado** | Igual que arriba. |
| Moderación de interrupciones (Interrupt Moderation) | **Deshabilitado** | Agrupa interrupciones del NIC para eficiencia de CPU, pero añade latencia al procesar paquetes. En un CPU moderno (tu 5800XT) el costo de más interrupciones es insignificante frente a la ganancia en latencia. |
| Modo maestro esclavo Gigabit | **Auto detectar** (dejar en automático) | No tocar manualmente, riesgo de negociar mal el enlace y perder velocidad. |
| Número máximo de colas de RSS | **Máximo disponible** (usualmente 2 o 4 en I211) | Reparte el procesamiento de paquetes entre varios núcleos de tu Ryzen en vez de saturar uno solo. |
| Paquete jumbo (Jumbo Frame) | **Deshabilitado** | Solo útil en redes locales/NAS con todos los dispositivos configurados igual. En internet normal el MTU estándar (1500) es lo correcto; jumbo frames mal configurados causan fragmentación y pérdida de paquetes. |
| Prioridad de paquetes y VLAN | **Prioridad de  paquetes habilitada** | Permite que el sistema etiquete prioridad de tráfico (802.1p/QoS). Sin costo, déjalo activo. |
| Receive Side Scaling (RSS) | **Habilitado** | Reparte el procesamiento de paquetes recibidos entre varios núcleos — coincide con lo que ya configuramos por `netsh` en el `.bat`. |
| Reducir velocidad al apagar (Reduce Speed On Power Down) | **Deshabilitado** | Ahorro de energía que no aplica mientras el PC está encendido jugando. |
| Registrar sucesos del estado del enlace | **Deshabilitado** | Solo logging para diagnóstico, sin impacto en rendimiento. Déjalo como esté, es indiferente. |
| Velocidad de obstrucción de la interrupción (Interrupt Moderation Rate) | **Desactivado** si el campo lo permite (solo aplica si "Moderación de interrupciones" quedó habilitado) | Como ya la deshabilitaste arriba, este campo puede quedar en gris/sin efecto. |
| Velocidad y dúplex (Speed & Duplex) | **1.0 Gbps Full Duplex** (fijo, no Auto) | Forzarlo evita una renegociación ocasional del enlace que puede causar micro-cortes de 1-2 segundos. Solo usa Auto si notas que el link no sube a 1Gbps al forzarlo. |

## Resumen — lo que realmente mueve la aguja

De toda la lista, estas 4 son las que tienen impacto medible y consistente en estabilidad para gaming:

1. **Moderación de interrupciones → Deshabilitado**
2. **Ethernet con uso eficiente de energía (EEE) → Deshabilitado**
3. **Descarga grande de envío V2 (IPv4/IPv6) → Deshabilitado**
4. **Control de flujo → Deshabilitado**

El resto (checksums, RSS, colas RSS, VLAN priority) es correcto dejarlo en su valor por defecto/habilitado — desactivarlos no ayuda y en algunos casos resta rendimiento.
