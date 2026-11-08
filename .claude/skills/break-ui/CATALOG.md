# Catálogo del peor caso — Optimizador PC

Valores realistas que rompen la interfaz, agrupados por lo que pinta la pieza. Usa las
filas que encajen con tu tabla de la fase 1. Cada valor puede salir de verdad: de la
traducción, del registro de Windows o de lo que el usuario hace con el programa.

Adaptado del catálogo genérico de `break-ui` (emilkowalski/skills): fuera emails,
avatares, monedas y RTL, que aquí no existen; dentro el registro, el idioma y los
estados del programa.

---

## Nombres y descripciones de ajustes

El texto se declara en inglés y se pinta traducido. **El español es lo que se rompe.**

| Valor | Rompe |
| --- | --- |
| `Desactivar la optimización de pantalla completa para aplicaciones heredadas` | Nombre largo en español; una línea a 830 px no llega |
| `Prioridad de programación de GPU acelerada por hardware (HAGS)` | Paréntesis y siglas al final: recortar al final esconde lo que lo distingue |
| `J` / `Sí` | Una o dos letras: columna medio vacía, zona de clic diminuta si el nombre es el enlace |
| Nombre igual que otro con distinto final (`SystemResponsiveness` / `SystemResponsivenessOverride`) | Listas donde el nombre es lo único que distingue |
| Descripción de 3 frases (~300 caracteres) | Alto fijo de la descripción en cuadrícula (`New-CategoryTile`), tarjeta que crece |
| Descripción vacía `''` | Hueco o línea en blanco donde iba |
| Texto sin traducción en `es.ps1` | Sale en inglés en mitad de la pantalla en español; `Get-MissingTranslations 'es'` |
| `{0} ajustes` con 1 | `"1 ajustes"` |
| Insignia larga traducida (`Recomendado por el fabricante`) | Insignia que se parte o empuja el nombre |
| `Line one` + salto de línea + `Line two` en un `-Description` | Dobla el alto de la fila o se pierde en silencio |
| `&amp;`, `<b>`, `**negrita**` | Debe salir tal cual: WPF no interpreta, pero comprueba que nadie lo pase por XAML |

## Registro

| Valor | Rompe |
| --- | --- |
| `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters` | Ruta larga real; sin espacios útiles, empuja el botón de copiar |
| `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games` | Dos rutas con el mismo principio largo: recortar al final las deja iguales |
| Nombre de valor de 40+ caracteres (`GlobalTimerResolutionRequests…`) | Columna del nombre en detalles técnicos |
| DWord `0xFFFFFFFF` | Se lee como `-1`; tiene que salir igual que lo declarado (`Format-RegistryValue`) |
| DWord `0x0000000A` frente a `10` frente a `0XA` | Misma cifra escrita de tres formas: comparación por valor, no por texto |
| QWord `18446744073709551615` | Número muy ancho en una columna estrecha |
| String de 260 caracteres (una ruta de archivo como valor) | Campo de valor (`New-MonoField`) que no parte |
| String vacío `''` frente a valor ausente | `factory` frente a `custom`: no pueden pintarse igual |
| MultiString con 12 líneas | Altura de la fila de valor |
| Binary de 64 bytes | Volcado hex ilegible en una línea |
| Clave `missing` / `denied` / `badpath` | Cada estado de lectura con su texto y su color |
| Ajuste con 9 claves en `-Registry` | Detalles técnicos muy altos (aunque hoy es una por ajuste: compruébalo igual) |

## Recuentos y números

| Valor | Rompe |
| --- | --- |
| `0` | Píldoras a cero, `"0 ajustes"`, porcentajes que dividen por cero |
| `1` | Plurales: `"1 ajustes"`, `"1 resultados"` |
| `1284` | Separador de miles según idioma (`1.284` en español, `1,284` en inglés) |
| Recuento que sube en vivo (`Start-CountUp` de 9 a 10) | La cifra cambia de ancho y mueve lo de al lado |
| `-1` en un `Total` o `Default` de `Register-Category` | Píldoras negativas, barras fuera de rango |

## Colecciones

| Valor | Rompe |
| --- | --- |
| Sección con 0 ajustes | ¿Hay estado vacío o solo un hueco? |
| Sección con 1 ajuste | La cuadrícula con una sola baldosa parece rota |
| Sección con 40 ajustes | `Start-StaggeredEnter` (se corta en `-MaxSteps`), tiempo de construcción |
| Todos los estados a la vez (`optimized`, `factory`, `custom`, `unknown`) | Píldoras de anchos distintos, filtro combinado |
| Filtro de píldoras que deja 0 tarjetas | Lista vacía sin "Mostrar todos" visible |
| Búsqueda sin resultados / con 1 / con 200 | Desplegable (`$SearchPopupMax`), página de resultados, recuento |
| Log vacío / lleno (`$AppLogCapacity`) | Botón de guardar apagado; tope de `$LogPanelMaxRows` |
| Sección de comandos con todos los pasos sin permisos | Lista entera apagada, botón de ejecutar sin nada que hacer |

## Salida de comandos (secciones de `Steps`)

| Valor | Rompe |
| --- | --- |
| Línea de `netsh` de 200 caracteres | Marco de estado (`StepRunPanel`, caja de 118 px de alto) |
| Salida en OEM 850 con `ñ`/`á` | Mojibake si se decodifica con la página equivocada |
| 500 líneas de salida | Desplazamiento y memoria del panel |
| Paso que falla con código distinto de 0 y sin texto | ¿Se ve que falló? |
| Paso que tarda 30 s | La ventana sigue respondiendo; el temporizador y el texto de espera |

## Estados del programa

| Estado | Rompe |
| --- | --- |
| Sin permisos de administrador | Insignia, pasos apagados, toggles de `HKLM` que no pueden escribir |
| Sección `Locked` | Controles apagados pero la fila mide lo mismo |
| Opciones de vista apagadas (`badges`, `reference`, `technical`) | Pie de la tarjeta sin franjas: ¿redondea bien? |
| Lectura del registro a medias (`Update-UiNow`) | Contenido que salta cuando llegan los `Current` |

## Entorno

No son datos, pero se comprueban igual: pinta el peor caso y cambia esto.

| Condición | Rompe |
| --- | --- |
| Ventana en su mínimo (`-Width 830`) | Todos los desbordamientos de arriba a la vez |
| Menú plegado (`-Width 920`) | Lo pensado para un ancho que ahora sobra |
| Maximizada en 2560 px (`-Width 1900`) | Líneas larguísimas, tarjetas sueltas a un lado |
| Escala de Windows 150 % (`-Scale 1.5`) | Altos fijos que recortan texto más grande |
| Tema oscuro | Colores literales, bordes invisibles |
| Mica activada | Texto sobre superficie translúcida: contraste |
