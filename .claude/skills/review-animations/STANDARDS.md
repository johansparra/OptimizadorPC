# Normas de animación — referencia para WPF

Los valores, curvas y reglas de la revisión. Cítalos en los hallazgos en vez de
aproximar. Destilado de la filosofía de Emil Kowalski y traducido a lo que hay en este
proyecto (`ui/Design/Theme.ps1`: `New-Ease`, `New-Anim`, `Start-EnterTransition`,
`Start-StaggeredEnter`, `Add-HoverLift`).

## De web a WPF

| Web | WPF / este proyecto |
| --- | --- |
| `transition` / `animation` | `$obj.BeginAnimation($Prop, (New-Anim $from $to $ms $delay $ease))` |
| `cubic-bezier(...)` | `New-Ease -Mode EaseOut|EaseInOut|EaseIn -Kind Cubic|Quint|Back`. Si hiciera falta una curva a medida: `KeySpline` en una `SplineDoubleKeyFrame` |
| `transform: translate/scale` | `TranslateTransform` / `ScaleTransform` en `RenderTransform` (**no** en `LayoutTransform`, que recoloca) |
| `transform-origin` | `RenderTransformOrigin = '0.5,0.5'` (relativo) |
| `opacity` | `UIElement.OpacityProperty` |
| `animation-delay` | `BeginTime` (lo pone `New-Anim -Delay`; la propiedad se queda en `From` mientras espera) |
| Transición que retoma (interrumpible) | `BeginAnimation` **sin `From`** o con `From` = valor actual. Por defecto reemplaza con `SnapshotAndReplace`, que parte del valor animado en ese momento… **salvo que fijes `From`** |
| Keyframes que reinician | `New-Anim` con `From` fijo: arranca siempre de ahí |
| `prefers-reduced-motion` | `[System.Windows.SystemParameters]::ClientAreaAnimation` (`$false` = el usuario apagó los efectos de animación) |
| `requestAnimationFrame` | `CompositionTarget.Rendering` o un `DispatcherTimer`. Evítalos si basta una `DoubleAnimation` |
| Limitar fps | `[System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($anim, 20)` |
| `filter: blur()` | `BlurEffect` / `DropShadowEffect.BlurRadius`: **caros**, se recalculan por fotograma |
| `@media (hover: hover)` | No aplica: es un programa de escritorio con ratón |

## ¿Se anima? (frecuencia)

| Frecuencia | Decisión | Aquí |
| --- | --- | --- |
| Cien veces al día, o con teclado | Nunca | Escribir en el buscador, el desplegable de resultados, `Escape`, `Enter` |
| Decenas de veces al día | Quitar o reducir mucho | Hover de tarjetas, cambiar de sección, pulsar interruptores |
| Ocasional | Normal | Cajón del log, plegar el menú, toasts, ejecutar pasos |
| Raro / primera vez | Puede tener gracia | Primer arranque, terminar una tanda de optimizaciones |

Propósitos válidos: continuidad espacial, indicar un estado, explicar, dar respuesta,
evitar un cambio brusco.

## Curvas

Orden de decisión:

- Entra o sale → **`New-Ease`** (`EaseOut` Cubic, el defecto).
- Se mueve por la pantalla de un sitio a otro → **`New-Ease -Mode EaseInOut`**, o
  `-Kind Quint` para más carácter (la marca del menú usa `EaseOut` Quint).
- Color o hover → `EaseOut` suave (`New-Ease`).
- Movimiento constante (fondo vivo, barra indeterminada) → lineal, o `EaseInOut` ida y
  vuelta (`Backdrop.ps1`).
- **Nunca `EaseIn` en la interfaz.**

`CubicEase` `EaseOut` es aceptable; para algo deliberado y vistoso `QuinticEase` frena
más marcado. El equivalente al `cubic-bezier(0.23, 1, 0.32, 1)` que recomienda el
original queda entre los dos; si hiciera falta exacto, `KeySpline "0.23,1 0.32,1"`.

`BackEase` (rebasa y vuelve): solo con recorrido pequeño y `Amplitude` baja (0.2–0.4).
El interruptor es el ejemplo bueno.

## Duraciones

| Pieza | Duración |
| --- | --- |
| Respuesta al pulsar | 100–160 ms |
| Tooltips, popups pequeños | 125–200 ms |
| Desplegables | 150–250 ms |
| Cajones, diálogos, plegar el menú | 200–300 ms (hasta 500 si es grande y raro) |
| Entrada de vista | 200–300 ms |
| Cascada | 30–80 ms entre elementos, con tope (`-MaxSteps`) |
| Hover | 120–200 ms |

**Interfaz por debajo de 300 ms.** Los valores de hoy, para comparar (`grep -rn
"New-Anim" ui`): hover 170, interruptor 260, menú 220, cajón 240/200, marca del menú
300, entrada de vista 260, cascada 300 + 45 por paso (máx. 9), toast 220 de entrada y
300 de salida.

## Física

- **Nunca escala 0.** Desde 0.90–0.97 + opacidad 0. Los estilos de botón de
  `MainWindow.xaml` usan 0.90/0.93/0.96 al pulsar: bien.
- **Origen**: lo que nace de un botón escala desde él. Los diálogos centrados se
  quedan en el centro.
- **Respuesta al pulsar**: escala 0.95–0.98, 100–160 ms, `EaseOut`.

## Interrupción

`New-Anim` **siempre fija `From`**. Para algo que se dispara seguido y puede cambiar de
sentido a medias (hover, abrir/cerrar), eso hace que salte al valor de partida. Dos
formas buenas, ya presentes en el proyecto:

```powershell
# Desde donde esté ahora (Move-NavIndicator, el knob del interruptor):
New-Anim $indicator.RenderTransform.Y $y 300 0 (New-Ease -Kind 'Quint')

# Desde el valor real medido (el plegado del menú):
New-Anim $sidebar.ActualWidth $to $Ms
```

Ojo: leer `.Y` mientras una animación corre devuelve el valor **animado** en ese
instante, que es justo lo que se quiere.

Una animación con `Completed` que hace algo (colapsar el cajón) tiene que soportar que
la reemplace otra antes de acabar: el `Completed` de la reemplazada **no** se dispara.

## Asimetría

Se va despacio donde el usuario decide y rápido donde responde el sistema. El cajón del
log ya lo hace (abre en 240, cierra en 200).

## Rendimiento

- **Baratas**: `RenderTransform` (`TranslateTransform`, `ScaleTransform`) y `Opacity`.
  No disparan `Measure`/`Arrange`.
- **Caras**: `Width`, `Height`, `Margin`, `Padding`, y `LayoutTransform`, porque recolocan
  el árbol en cada fotograma. Excepción documentada: el ancho del menú (regla 14),
  porque el contenido de al lado tiene que ocupar el hueco.
- **Efectos**: animar `DropShadowEffect.BlurRadius` u `Opacity` del efecto obliga a
  recalcularlo; en una tarjeta pequeña se nota poco, sobre media pantalla mucho. Un
  `BlurEffect` grande es lo más caro que hay (regla 26: el fondo vivo lo evita con
  degradados radiales).
- **Infinitas**: siempre con `SetDesiredFrameRate` (el fondo, a 20).
- **Temporizadores**: un `DispatcherTimer` que anima a mano (`Start-CountUp`, cada
  `$CountUpTickMs`) compite con el hilo de la interfaz; se justifica solo cuando no
  existe la animación equivalente (animar el texto de un número).
- **Durante una lectura síncrona** (`Update-UiNow`) el hilo está ocupado: cualquier
  animación da tirones. No se arranca nada vistoso mientras se lee el registro.

## Cascada

30–80 ms entre elementos; más largo se siente lento. Decorativa: **nunca** bloquea el
clic mientras corre. `Start-StaggeredEnter` usa 45 ms con tope de 9 pasos. Quién se
mueve lo decide `Get-EnterTarget` (regla 24).

## Accesibilidad

```powershell
if (-not [System.Windows.SystemParameters]::ClientAreaAnimation) {
    # Sin desplazamiento: se queda la opacidad (o ni eso) y duración corta.
}
```

Menos movimiento no es cero: se quedan los fundidos que ayudan a entender un cambio y
se va lo que desplaza. El sitio natural para decidirlo es `New-Anim` /
`Start-EnterTransition` / `Start-StaggeredEnter`, no cada llamada.

## Coherencia

Una herramienta de sistema se siente nítida y rápida. Si dos piezas parecidas se animan
distinto (el cajón del log y la ventana aparte, dos desplegables), es un hallazgo: la
duración y la curva deberían salir del mismo sitio.
