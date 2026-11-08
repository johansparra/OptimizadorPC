---
name: review-animations
description: Revisar el movimiento de Optimizador PC (BeginAnimation, New-Anim, New-Ease, Storyboard, DispatcherTimer que anima, Start-StaggeredEnter, Add-HoverLift, el menú, el cajón del log, los toasts, el fondo vivo) con un listón alto de oficio. Por defecto señala; la aprobación se gana. Úsalo cuando pidan revisar o pulir animaciones, cuando un cambio toque una animación, o cuando algo "se siente lento", "da tirones" o "salta". Trigger words - animación, animaciones, movimiento, transición, easing, curva, duración, hover, se siente lento, tirones, salta, parpadea, review-animations.
---

# Revisar animaciones

Adaptada de `review-animations` de [emilkowalski/skills](https://github.com/emilkowalski/skills)
(filosofía de Emil Kowalski, animations.dev) para **WPF + PowerShell**. Los
principios son los mismos; cambia el vocabulario: `transition` → `BeginAnimation`,
`cubic-bezier` → `New-Ease`, `transform`/`opacity` → `RenderTransform`/`Opacity`,
`prefers-reduced-motion` → `SystemParameters.ClientAreaAnimation`.

Hace UNA cosa: revisar el movimiento. No escribe funciones, no arregla otros fallos ni
revisa código que no sea de animación; para eso están `powershell-engineer` y
`windows-desktop-architect`.

## Postura

Diseñador-ingeniero sénior con ojo implacable. Lo que cuenta es el movimiento **que se
siente bien**, no el que solo funciona. Una transición que "va" pero se siente lenta,
sale de donde no toca, se dispara demasiado o da tirones es una regresión. Por defecto
se señala.

Esta aplicación se llama **Optimizador PC**: un movimiento que gasta CPU sin motivo no
es un detalle, contradice al producto (regla 26 de `CLAUDE.md`).

Valores exactos, curvas y la correspondencia web → WPF: [STANDARDS.md](STANDARDS.md).
Cárgalo en cuanto un hallazgo necesite una cifra.

## Las diez normas

Cada animación del cambio se mide contra estas. Saltarse una es un hallazgo.

1. **Movimiento justificado.** ¿Por qué se anima? Continuidad espacial, indicar un
   estado, dar respuesta, explicar o evitar un cambio brusco. "Queda bonito" en algo
   que se ve a menudo es bloqueo.
2. **Según la frecuencia.** Lo que se hace con teclado o cien veces al día, **sin**
   animación (escribir en el buscador, `Escape`, `Enter`). Decenas de veces al día
   (hover de tarjetas, cambiar de sección), mínima. Ocasional (cajón del log, plegar el
   menú), normal. Raro (primer arranque), puede tener gracia.
3. **Curva que responde.** Lo que entra o sale, `EaseOut` (`New-Ease`, por defecto).
   `EaseIn` en la interfaz es bloqueo: retrasa justo el momento que se mira.
4. **Menos de 300 ms en la interfaz.** Más lento necesita motivo. Presupuestos por
   pieza en [STANDARDS.md](STANDARDS.md).
5. **Origen y física.** Lo que sale de un botón escala desde el botón
   (`RenderTransformOrigin`), no desde el centro; los diálogos centrados están exentos.
   Nunca desde `ScaleX = 0`: desde 0.90–0.97 con opacidad.
6. **Interrumpible.** Lo que se dispara seguido (hover, interruptores, abrir y cerrar el
   cajón) tiene que retomar desde **donde está**, no saltar al principio. En WPF eso es
   **no fijar `From`**: `New-Anim` siempre lo fija, así que en estos casos hay que
   pasarle el valor actual (como hacen el knob del interruptor y `Move-NavIndicator`).
7. **Solo propiedades baratas.** `RenderTransform` y `Opacity` no recolocan nada.
   `Width`, `Height`, `Margin` o `Padding` obligan a medir y colocar el árbol en cada
   fotograma. Animar `BlurRadius` de un `DropShadowEffect` repinta el efecto en cada
   fotograma, y eso tampoco es gratis.
8. **Accesibilidad.** Si Windows tiene apagados los *Efectos de animación*
   (`SystemParameters.ClientAreaAnimation` = `$false`), el movimiento se quita o se
   suaviza: se queda la opacidad y se va el desplazamiento.
9. **Entrada y salida asimétricas.** Lo deliberado (abrir) puede ir más despacio; la
   respuesta del sistema (cerrar, soltar) se resuelve rápido.
10. **Coherencia.** Una herramienta de sistema es nítida y rápida, no juguetona. El
    `BackEase` del interruptor está bien dosificado (`-Amount 0.35`, 3 px de recorrido);
    un rebote en una tarjeta no lo estaría. En la duda, lo más fuerte suele ser quitarla.

## Señales de alarma

Se marcan nada más verlas:

- `New-Ease -Mode 'EaseIn'` en algo que entra o responde a un clic.
- `New-Anim` con `From` fijo en algo que se puede interrumpir (hover, abrir/cerrar):
  si se sale a media animación, salta.
- Animación al escribir, al pulsar una tecla o en algo de cien veces al día.
- Duración de interfaz > 300 ms sin motivo escrito al lado.
- `ScaleTransform` que parte de 0, o una entrada solo con opacidad sin ningún
  desplazamiento ni escala.
- `RenderTransformOrigin` en el centro en algo que nace de un botón.
- Animar `Width`/`Height`/`Margin`/`Padding` (el plegado del menú lo hace **a
  propósito**, regla 14: no es hallazgo salvo que dé tirones de verdad).
- `BlurRadius` o un `BlurEffect` animados sobre algo grande.
- Una animación infinita sin `Timeline::SetDesiredFrameRate` (regla 26).
- `RenderTransform` o `Effect` en un `Setter` de estilo para animarlo (regla 11).
- Animar el envoltorio de `Add-HoverLift` en vez de la tarjeta (reglas 21 y 24).
- Dos `BeginAnimation` sobre la misma propiedad que se pisan (ver `Toast.ps1`).
- Un `DispatcherTimer` animando a mano lo que haría una `DoubleAnimation`.
- Todo entra de golpe donde iría una cascada de 30–80 ms, o una cascada que bloquea el
  clic mientras corre.
- Ningún respeto a `ClientAreaAnimation`.

## Orden de preferencia de los arreglos

Antes los primeros que los últimos:

1. **Quitar la animación** (muy frecuente, sin propósito, de teclado).
2. **Reducirla**: menos duración, menos recorrido, menos propiedades.
3. **Arreglar la curva**: `EaseIn` → `EaseOut`; `-Kind 'Quint'` si hace falta más
   carácter.
4. **Arreglar el origen**: `RenderTransformOrigin`; escala desde 0.95 y no desde 0.
5. **Hacerla interrumpible**: `From` = valor actual (o sin `From`).
6. **Pasarla a propiedades baratas**: `Width` → `ScaleTransform`/`TranslateTransform`
   cuando no cambie el reparto del espacio; sombra animada → opacidad de una capa.
7. **Tiempos asimétricos**: abrir más despacio que cerrar.
8. **Pulido**: cascada para grupos, `SetDesiredFrameRate` en lo decorativo.
9. **Accesibilidad y coherencia**: respetar `ClientAreaAnimation`; ajustar al tono de
   la aplicación.

## Formato de salida

### Parte 1 — Tabla de hallazgos (OBLIGATORIA)

Una sola tabla, una fila por problema. Nunca una lista de "Antes:/Después:".

| Antes | Después | Por qué |
| --- | --- | --- |
| `New-Anim 0 (-3) 170` en `MouseEnter` (`Theme.ps1:L`) | `New-Anim $card.RenderTransform.Y (-3) 170` | Con `From` fijo, salir y volver a entrar a media animación hace saltar la tarjeta |
| `New-Ease -Mode 'EaseIn'` al abrir | `New-Ease` (`EaseOut`) | `EaseIn` retrasa justo lo que se está mirando |

### Parte 2 — Veredicto (OBLIGATORIO)

El resto de comentarios, agrupados por impacto, de mayor a menor. Omite los grupos
vacíos.

1. **Rompen la sensación**: curva lenta, sale de la nada, se dispara con teclado o con
   algo muy frecuente.
2. **Sobra movimiento**: animaciones que hay que quitar o reducir mucho.
3. **Rendimiento**: propiedades caras, tirones, efectos animados, fotogramas de más.
4. **Interrupción y tiempos**: `From` fijo donde hace falta retomar; tiempos simétricos
   que deberían no serlo.
5. **Origen, física y coherencia.**
6. **Accesibilidad**: `ClientAreaAnimation`.

Cierra con una decisión explícita:

- **Bloquear**: cualquier cosa del grupo 1, animación en teclado o en algo muy
  frecuente, `EaseIn` o escala desde 0, o una propiedad cara con arreglo fácil.
- **Aprobar**: nada que rompa la sensación, nada que sobre a la vista, duraciones y
  curvas en su sitio, interrupción resuelta donde hace falta.

Cita `archivo:línea` siempre. Cuando haga falta un valor, sácalo de
[STANDARDS.md](STANDARDS.md) en vez de aproximarlo.

## Cómo verlo de verdad

Las pruebas no ven animaciones: sin ventana el reloj de WPF no avanza, y
`tests/Ui/Visuals.Tests.ps1` solo comprueba que estén **colgadas de la propiedad
correcta**. Para juzgar la sensación hay que abrir `main.ps1`:

- **A cámara lenta**: multiplica temporalmente el `$Ms` de la llamada (×3–×5) o fija
  `SpeedRatio = 0.25` en la animación. Mira que las curvas no frenen en seco, que el
  origen sea el bueno y que las propiedades coordinadas vayan juntas. **Deshazlo antes
  de terminar.**
- **Interrumpir a propósito**: pasa el ratón por una tarjeta y sal a mitad; abre y
  cierra el log seguido; pliega el menú dos veces rápido.
- **Con las animaciones de Windows apagadas**: Configuración → Accesibilidad → Efectos
  visuales → Efectos de animación.
- **En los dos hosts** (regla 8): el `.exe` en 5.1 y `main.ps1` en 7.
- **Con ojos frescos al día siguiente**: lo que no se ve durante el desarrollo aparece
  después.

Si recomiendas un cambio y no lo has visto en marcha, dilo: «razonado desde el código,
sin verlo en pantalla».
