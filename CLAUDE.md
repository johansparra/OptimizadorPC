# CLAUDE.md

Contexto para trabajar en **Optimizador PC**. Ver `README.md` para la estructura completa y los diagramas.

## Qué es

App de escritorio **WPF construida en PowerShell 5.1**, compilada a un `.exe` portable con **ps2exe**. Muestra categorías de optimizaciones de Windows 11 con toggles y dropdowns.

**Estado actual: solo UI.** Ningún control aplica cambios reales al sistema todavía — los archivos de `ui/Data/Categories/` son datos estáticos y los toggles solo cambian de color.

## Arquitectura (dónde va cada cosa)

De datos a pantalla. **Nunca saltes una capa hacia abajo.**

**Una carpeta por capa.** El nombre de la carpeta dice qué puede haber dentro:

| # | Capa | Carpeta | Regla |
| - | ---- | ------- | ----- |
| 1 | Base | `ui/Design/` | `Theme.ps1` (colores, iconos, animación) y `UiKit.ps1` (piezas genéricas). Están **por debajo de todo**: los usa cualquier capa y ellos no usan a nadie. |
| 2 | Mecanismo | `ui/Engine/` | Registran, traducen, guardan y enrutan. Sin datos ni controles. |
| 3 | Política | `ui/Index/` | **Los archivos principales.** Qué se ve, en qué orden, qué está bloqueado. Nada de contenido. |
| 4 | Sistema | `core/` | Habla con Windows. **No conoce la interfaz**: ni un control de WPF. Devuelve datos y nunca lanza hacia arriba. |
| 5 | Datos | `ui/Data/` | `Categories/`, `Preferences/`, `Lang/`. Un archivo por sección, por opción y por idioma. Solo declaraciones, cero código de UI. |
| 6 | Piezas | `ui/Components/` | Construyen controles concretos. No conocen las vistas. |
| 7 | Pantallas | `ui/Views/` | Solo ensamblan piezas. Sin `New-Object` de controles sueltos. |

`ui/Components/` se divide a su vez por lo que dibuja cada pieza:

| Subcarpeta | Qué contiene |
| ---------- | ------------ |
| `Shell/` | El marco de la ventana: `TitleBar`, `Sidebar`, `ViewMenu`, `LogPanel`, `ProgressStrip`. |
| `Cards/` | Las tarjetas: `CategoryCard`, `SettingCard`, `PreferenceCard`, `TechnicalDetails`. |
| `Layout/` | Piezas de página: `PageHeader`, `Banner`, `CategorySummary`. |

**Cada capa se carga entera, subcarpetas incluidas**, mediante un bloque
`# @@EMBED_DIR:...@@` de `main.ps1`. Un `.ps1` nuevo en cualquiera de ellas entra
solo: no hay que registrarlo en `main.ps1` ni en `build.ps1`.

**Lo único que decide `main.ps1` es el orden de esas siete cargas**, y solo importa
porque los datos se registran al cargarse: `ui/Data/Categories/` llama a
`Register-Category`, que vive en `ui/Engine/`. Dentro de una carpeta el orden es
alfabético y da igual — **el orden que se ve lo decide el índice**, no el nombre del
archivo. Hay una prueba que vigila ese orden entre capas.

**`Locked` no es decorativo.** `New-SettingCard -Locked` pone `IsEnabled = $false` en
el panel de controles, y WPF deja de entregarles el ratón a todo el subárbol. Si
añades un control nuevo a la tarjeta de ajuste, cuélgalo de ese mismo panel para que
herede el bloqueo.

Si una vista empieza a crear controles a mano, esa parte pertenece a `Components/`.
Si un componente empieza a saber de categorías concretas por su `Id`, eso pertenece
al archivo de la categoría.

## Comandos

```powershell
# Ejecutar en modo desarrollo (rápido, sin compilar)
powershell -ExecutionPolicy Bypass -File .\main.ps1

# Compilar el .exe portable
powershell -ExecutionPolicy Bypass -File .\build.ps1

# Pruebas (sin dependencias). Los DOS hosts a la vez -regla 8-, en una sola orden:
pwsh -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1 -BothHosts

# Uno solo, para acotar mientras investigas:
powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1 -File 'Core*'
```

**Hay pruebas y no hay linter.** Viven en `tests/`, no usan Pester (Windows solo trae
la 3.4, incompatible con la sintaxis moderna) y no necesitan instalar nada. Se
reparten en cuatro carpetas:

| Carpeta | Qué prueba |
| ------- | ---------- |
| `tests/Harness/` | El arnés, no la aplicación: `TestKit` (`Describe`/`It`), `AppHost` (carga el programa sin abrir la ventana) y `Fixtures`. |
| `tests/Core/` | `core/` contra el registro de verdad. |
| `tests/Ui/` | La interfaz, construyendo controles de WPF sin enseñar la ventana. |
| `tests/Source/` | Las reglas de este archivo que se ven leyendo el código: BOM, closures, glifos, qué entra en el `.exe`. |

Ver `tests/README.md`, que además explica por qué Playwright no sirve para esto y qué
haría falta para llegar a pruebas de extremo a extremo.

`tests/Harness/AppHost.ps1` **no repite la lista de archivos**: lee `main.ps1` con el
mismo marcador y el mismo orden que `build.ps1`. Si tocas eso, las pruebas se enteran
antes que el `.exe`.

**Toca las pruebas al mismo tiempo que el código.** Si añades una sección, una
opción o un componente, lo normal es que no haya que escribir nada: casi todo se
recorre solo a partir de los índices.

## Cómo se trabaja rápido aquí

Por orden de lo que más tiempo ahorra:

1. **Las llamadas independientes van en el mismo turno.** Leer seis archivos para
   entender una zona son seis llamadas a la vez, no seis turnos. Solo se espera
   cuando el resultado de una decide cuál es la siguiente.
2. **Las pruebas, con `-BothHosts`.** Los dos intérpretes en paralelo, una sola orden
   y una sola aprobación. Pueden correr a la vez porque ya no comparten nada: la rama
   del registro de `tests/Harness/Fixtures.ps1` y el script combinado de
   `tests/Source/Rules.Tests.ps1` llevan el PID en el nombre.
3. **La codificación se arregla sola.** El hook `PostToolUse` de
   `.claude/hooks/Normalize-PsEncoding.ps1` deja cada `.ps1` y `.xaml` en UTF-8 con
   BOM y CRLF en cuanto se escribe (regla 3). Ya no hay que normalizar a mano;
   verificar con `file` sigue siendo gratis.
4. **Las skills se cargan al empezar, no cuando alguien las nombra.** Son
   instrucciones que entran en el turno: no arrancan en frío ni gastan contexto de
   más, así que no hay nada que amortizar. La que toque según la tarea
   (`windows-desktop-architect` para interfaz, `powershell-engineer` para cualquier
   `.ps1`, `exploracion` para leer y buscar, `versionado` para confirmar), y se dice
   en una línea.

**El freno de verdad son los permisos.** Un comando que no esté en la lista de
`.claude/settings.local.json` detiene la sesión hasta que alguien lo apruebe. Si algo
se repite y es de solo lectura, su sitio es esa lista y no cada turno.

**Delegar en agentes SÍ cuesta contexto.** Un agente arranca en frío y tiene que
redescubrir el proyecto: para un cambio de uno o dos archivos sale más caro que
hacerlo. Se delega cuando hay **dos o más frentes que no se tocan entre sí** —una
sección nueva y una auditoría de pruebas, por ejemplo— y entonces se lanzan **a la
vez**, no en fila. **Esa decisión la toma Claude solo**, sin preguntar. Ver
`.claude/agents/README.md`.

### El grafo de graphify: para qué sirve y para qué no

Hay un grafo del proyecto en `graphify-out/` (ver su `README.md`). **No sustituye a
este archivo**, y conviene saber por qué antes de perder tiempo con él. Medido sobre
la primera pasada, 673 nodos y 1.355 aristas:

| Sirve | No sirve |
| ----- | -------- |
| `graphify path A B` y `graphify explain X` sobre **símbolos de código**: se quedan en la capa del árbol sintáctico, que es exacta y trae número de línea. | `graphify query "<pregunta en lenguaje natural>"`. |
| El `graph.html` para ver el mapa de un vistazo. | Preguntas de "¿cómo funciona esto?": para eso, leer el código. |
| Los *god nodes* del informe: `T()` con 61 aristas describe este proyecto de una. | Encontrar dónde va algo: para eso está este archivo. |

**Por qué falla la consulta en lenguaje natural: `0` de 1.355 aristas conectan el
código con la documentación.** No es un grafo, son dos grafos desconectados en el
mismo archivo — el AST no sabe qué dice `CLAUDE.md` y la documentación no sabe qué
función implementa cada regla. Preguntando *"cómo se guarda el registro en un
archivo"* devolvió 36 nodos de documentación y **ninguna** de las ocho funciones que
lo hacen, más una comunidad entera de ruido enganchada por la palabra "archivos".

**La descripción de la skill dice que, existiendo `graphify-out/`, cualquier pregunta
sobre el código se trate primero como consulta al grafo. Aquí NO.** Con la calidad
medida eso empeora las respuestas: se empieza por nodos de documentación y se pierde
el código. El orden bueno sigue siendo este archivo, luego búsqueda directa, y el
grafo solo para lo de la columna izquierda.

**El grafo envejece en silencio.** Se construyó del árbol de trabajo, no del commit;
tras tocar código hay que pasar `/graphify . --update` o dejará de cuadrar. Si algún
día se quieren de verdad los puentes documentación↔código, hay que pedirlos en la
extracción (`--mode deep`, o que los nodos de documentación citen los símbolos).

## Reglas del proyecto

1. **Editar siempre los archivos fuente**, nunca `build/_combined.ps1` — es generado y se sobrescribe en cada build.
2. **`build.ps1` parsea `main.ps1` y solo entiende dos marcadores.** No se deben romper:
   - Las carpetas completas, entre `# @@EMBED_DIR:ui/Carpeta@@` y `# @@ENDEMBED@@` (**recursivo**: incluye las subcarpetas).
   - El XAML, entre `# @@EMBED_XAML:...@@` y `# @@ENDEMBED@@`.

   **No hay forma de incluir un archivo suelto.** Todo `.ps1` va DENTRO de una de las siete carpetas que se incrustan, y entonces entra solo. Cualquier otra manera de cargarlo (un `. (Join-Path ...)` a mano) se copia tal cual al script combinado y el `.exe` intentará abrir algo que no tiene al lado: funciona en desarrollo y falla compilado. Hay una prueba que lo impide.

   Los tres sitios que recorren esas carpetas — `main.ps1`, `build.ps1` y `tests/Harness/AppHost.ps1` — usan **el mismo orden**: `-Recurse` y `Sort-Object FullName`. Si cambias uno, cambia los tres.
3. **Todos los `.ps1` y el `.xaml` deben guardarse en UTF-8 CON BOM.** Windows PowerShell 5.1 lee un script sin BOM como ANSI (Windows-1252): los caracteres acentuados de los comentarios y cualquier símbolo no ASCII se vuelven mojibake y el parser falla con *"Token inesperado"* / *"Falta la cadena en el terminador"*. `powershell` (5.1) y `pwsh` (7) difieren aquí, así que un archivo puede parsear bien en 7 y romperse en 5.1 — verifica siempre con 5.1. Nunca escribas estos archivos con `Set-Content -Encoding UTF8` desde pwsh 7 (no pone BOM); usa `[System.IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding($true)))`.
4. **NO uses `.GetNewClosure()` en los handlers de eventos.** Un scriptblock con closure queda ligado a un módulo dinámico y desde ahí **no se ven las funciones del script**: al hacer clic falla con *"The term 'Show-CategoryDetailView' is not recognized"*. En el `.exe` no se nota, porque ps2exe deja las funciones en ámbito global — el bug solo aparece ejecutando `main.ps1`. El patrón correcto es pasar el dato por el `Tag` del control y sacar la ventana del emisor:
   ```powershell
   $card.Tag = $cat
   $card.Add_MouseLeftButtonUp({
       param($s, $e)
       Show-CategoryDetailView -Window ([System.Windows.Window]::GetWindow($s)) -Category $s.Tag
   })
   ```
   Tampoco captures una variable de bucle (`$cat`, `$item`) directamente sin `Tag`: al dispararse apuntaría al último elemento.
5. **XAML como aquí-string literal**: `build.ps1` lo envuelve en un aquí-string de comillas simples. No metas un cierre de aquí-string a inicio de línea dentro del XAML.
6. **El `.exe` se compila con `-requireAdmin` y `-noConsole`.** Cualquier tweak real correrá elevado — hay que ser conservador.
7. **Sin ventana de consola en el `.exe`**: `Write-Host` no se ve. Para depurar, ejecuta `main.ps1` directamente.
8. **Prueba siempre en ambos hosts.** El `.exe` (ámbito global, 5.1) y `main.ps1` (ámbito de script, tu pwsh 7) se comportan distinto: hay bugs que solo se ven en uno de los dos.
9. **Colores: siempre por recurso de tema, nunca literales.** En XAML `{DynamicResource Accent}`, en código `Set-TextFg` / `Set-BoxBg` / `Set-BoxLine` (envuelven `SetResourceReference`). Un `#RRGGBB` a pelo no cambia al alternar claro/oscuro.

    **Hay TRES propiedades de fondo distintas y no son intercambiables**: la de un
    `Border` (`Set-BoxBg`), la de un `Panel` —`Grid`, `StackPanel`— (`Set-PanelBg`), la
    de un `Control` o una ventana (`Set-WinBg`), y el relleno de una figura
    (`Set-ShapeFill`). Poner la de `Border` a un `Grid` no da error: no pasa nada, que
    es peor.
10. **Pinceles congelados.** WPF congela al cargar el XAML los `SolidColorBrush` que considera compartibles, y un `Freezable` congelado no se puede mutar. Por eso `Set-AppTheme` intenta primero `$brush.Color = ...` y solo si está congelado lo sustituye. Al sustituir usa `Resources.Add()`, **no** el indexador `Resources[$k] = ...`: el indexador guarda el `PSObject` que envuelve al pincel y WPF lo rechaza al resolver el `DynamicResource` con *"'#FF59616F' no es un valor válido para la propiedad 'Foreground'"* (el mensaje engaña: el `ToString()` de un `SolidColorBrush` es su color).
11. **Nunca declares un `Freezable` dentro de un `Setter` de estilo si vas a animarlo.** `RenderTransform` y `Effect` puestos en un `Setter` se comparten entre todos los controles del estilo y WPF no permite animar una instancia compartida. Créalos por control en código (ver `Add-HoverLift`).
12. **Iconos: `Glyph 'Nombre'` del catálogo de `Theme.ps1`** (fuente *Segoe Fluent Icons*, nativa de Windows 11), nunca emoji. Antes de usar un codepoint nuevo, comprueba que existe con `GlyphTypeface.CharacterToGlyphMap` y míralo renderizado: varios glifos parecidos tienen significados distintos (p. ej. `E7ED` es una campana **tachada**, la campana normal es `EA8F`).

13. **El menú lateral se construye por código, no en el XAML.** `MainWindow.xaml` solo aporta el `Border` llamado `Sidebar` con dos `StackPanel` vacíos (`NavTop` y `NavBottom`) y la marca de selección (`NavIndicator`, ver la regla 25); los botones los crea `Build-Sidebar` a partir de `ui/Index/NavigationIndex.ps1`. Cada botón se registra con `$Window.RegisterName('Nav<Id>', ...)`, así que `FindName('NavSettings')` sigue funcionando — si añades uno nuevo, respeta ese nombrado.

    **Una entrada sin `View` no navega, y es a propósito.** Hoy tienen pantalla Search, Optimize y Settings; las otras cuatro siguen en el menú para conservar la estructura, se ven igual que las demás (ni en gris ni con candado) y `Set-NavSelection` sale antes de tocar nada: ni cambia de vista, ni repinta, ni mueve la marca del menú. **No las mandes a una vista de relleno** — el menú marcaría una cosa y la pantalla enseñaría otra. Activar una es escribir el nombre de su función de vista en `View`.

    **Quién está marcado lo decide `Sync-NavSelection`, y lo llama `Show-View`.** No el botón al pulsarse: a una pantalla se puede llegar sin tocar el menú —a la de búsqueda se entra con Enter desde la caja de la cabecera—, y con la marca puesta en el clic el menú acabaría señalando otra cosa. Si la vista actual no es la de ninguna entrada (el detalle de una sección), no se toca nada: sigue marcada aquella desde la que entraste.
14. **Al plegar el menú se anima el ancho del `Border`, nunca la columna del `Grid`.** La columna es `Auto` y sigue al `Border` sola; animar un `GridLength` exigiría escribir una animación propia porque WPF no trae ninguna. El borde derecho de 1px se pone a 0 al plegar, o el ancho nunca llegaría a cero.

15. **Todo texto visible pasa por `T`.** El inglés es el idioma fuente y se traduce por texto original, no por clave (ver `ui/Engine/Translation.ps1`). Un literal sin `T` sale siempre en inglés y no aparece en `Get-MissingTranslations`, así que es un fallo silencioso. El XAML no puede llamar a `T`: sus textos se fijan en `ui/Components/Shell/TitleBar.ps1`.
16. **Al cambiar de idioma hay que repintar.** Los colores se actualizan solos por `DynamicResource`, el texto no. `Update-UiLanguage` reconstruye el menú y vuelve a dibujar la pantalla actual a través de `ui/Engine/Router.ps1`. Se aplaza al `Dispatcher` porque suele dispararse desde un control que está dentro de la vista que se va a destruir.
17. **Las vistas se muestran con `Show-View`, no llamándolas directamente**, o el enrutador pierde el hilo de dónde estás y el cambio de idioma repinta la pantalla equivocada.
18. **Toda preferencia que deba recordarse pasa por `Set-AppSetting`.** Se guarda en `%APPDATA%\OptimizadorPC\settings.json`, nunca junto al `.exe`: el ejecutable es portable y puede acabar en una carpeta sin permisos de escritura. Un JSON corrupto se ignora y se arranca con los valores por defecto.

19. **`@()` sobre una `List[object]` creada con `New-Object` revienta.** Falla con *"los tipos de argumentos no coinciden"* en 5.1 **y** en 7 (`New-Object` devuelve el objeto envuelto en un `PSObject`). Con `List[string]`, con `ArrayList` o construyéndola con `::new()` funciona, así que el fallo aparece solo en algunos sitios y despista mucho. Usa `.ToArray()`:
    ```powershell
    $lista = New-Object System.Collections.Generic.List[object]
    $copia = @($lista)            # ✗ excepción
    $copia = $lista.ToArray()     # ✓
    ```
    Recorrerla con `foreach`, mandarla por la tubería o devolverla desde una función sí funciona — que es por lo que el resto del proyecto no se ha tropezado nunca con esto.

20. **Dentro de los paréntesis de un método, la coma separa ARGUMENTOS.** Un `-f` ahí se queda solo con el primer valor y el resto se convierte en argumentos extra del método:
    ```powershell
    $lista.Add('{0} de {1}' -f $hechas, $total)     # ✗ {1} se sale de la lista
    $texto = '{0} de {1}' -f $hechas, $total
    $lista.Add($texto)                              # ✓
    ```
    Al llamar a un **comando** (`Write-Host (...)`, `-Detail (...)`) no pasa: ahí los paréntesis envuelven una expresión y la coma es suya.

21. **Un `RenderTransform` mueve también la zona sensible al ratón.** Elevar una tarjeta al pasar por encima la aparta del cursor: con el puntero parado sobre sus últimos píxeles, subirla dispara `MouseLeave`, bajarla `MouseEnter`, y el efecto se queda en bucle para siempre. **El que escucha al ratón no puede ser el control que se mueve**, sino un envoltorio quieto —con `Background = Transparent`, o no oye nada— que ocupa su hueco entero; el margen se muda a ese envoltorio para que el hueco entre tarjetas siga sin responder. `Add-HoverLift` devuelve ese envoltorio, y ahí van también el cursor y el clic. Un efecto que solo *agranda* (una escala) no tiene el problema; uno que desplaza, sí.

22. **Un `TextBlock` no se puede seleccionar ni copiar.** WPF no trae selección en `TextBlock`: para que el usuario pueda seleccionar con el ratón y copiar con Ctrl+C hace falta un `TextBox` con `IsReadOnly = $true`, `IsReadOnlyCaretVisible = $false`, `BorderThickness = 0`, `Background = Transparent` y `Padding = 0` — así se ve igual que el texto de al lado, pero se selecciona, trae su menú contextual y responde a Ctrl+C y Ctrl+A. De solo lectura **no** es lo mismo que editable. Su color se pone con `Set-TextFg` como en cualquier otro sitio: `TextBlock.ForegroundProperty` y `Control.ForegroundProperty` son la **misma** `DependencyProperty` (a diferencia de `Background`, que sí son dos distintas — por eso existe `Set-WinBg`). Lo hace `New-MonoField` en `ui/Components/Cards/TechnicalDetails.ps1` con la ruta y el valor del registro. Al copiar, el aviso lo enseña **un solo botón a la vez**: un `DispatcherTimer` no tiene `Tag` donde dejar a quién apagar, así que el manejador llama a una función y es ella la que mira el estado del módulo.

23. **El tema tiene DOS familias de color y se declaran por separado.** `Get-Palette`
    lleva los colores planos; `$GradientTokens` lleva los degradados, y **cada uno se
    compone a partir de dos claves de la paleta**, nunca de colores propios. Así no hay
    ni un color escrito dos veces y `Set-AppTheme` los repinta a los dos por el mismo
    camino. Un degradado se muta **parada a parada** (`GradientStops[i].Color`), con la
    misma trampa del pincel congelado que los planos (regla 10). Las dos son claves
    válidas para `Set-BoxBg` y compañía: la lista completa es `Get-ThemeKeys`, y es
    contra ella —no contra la paleta— contra la que comprueba la prueba de la regla 9.

    Para pedir "la versión en degradado de esta clave" está `Get-GradientKey`, que
    devuelve la plana tal cual si no tiene: por eso `New-IconTile` pinta el acento de
    cualquier sección sin saber qué secciones hay.

24. **La entrada en cascada NO mueve el envoltorio de la tarjeta.** `Start-StaggeredEnter`
    anima cada hijo con un retardo creciente, pero quien se desplaza lo decide
    `Get-EnterTarget`: si el hijo es el envoltorio quieto de `Add-HoverLift` —marcado con
    `Uid = 'lift'`— se mueve la tarjeta de dentro. Mover el envoltorio movería su zona
    sensible al ratón y la elevación entraría en el bucle de la regla 21. Hay una prueba
    que lo vigila.

25. **Los indicadores que se deslizan no se colocan si no hay medidas.** El del menú
    lateral (`Move-NavIndicator`) y la pastilla del selector de modo
    (`Move-ModeIndicator`) calculan su sitio con `TranslatePoint`, que necesita que WPF
    ya haya medido: al arrancar, `main.ps1` pinta la primera pantalla antes de que la
    ventana exista de verdad y ahí todo vale cero. En ese caso **se esconden** y vuelven
    por el `SizeChanged`, que se engancha **una sola vez** (marcado en el `Tag` del
    `Border` o en el `Uid` del `Grid`, porque esas funciones se repiten al cambiar de
    idioma). Que nunca haya nada sin marcar es cosa del fondo del botón, no del
    indicador. Y se anima solo al navegar: durante el plegado del menú el `SizeChanged`
    se dispara decenas de veces y una animación por cada una se pelearía consigo misma.

26. **El fondo vivo va a 20 fps y sin `BlurEffect`.** Las manchas de
    `ui/Components/Shell/Backdrop.ps1` se difuminan porque su relleno es un degradado
    **radial** que acaba en transparente; un desenfoque grande sobre media pantalla es lo
    caro de verdad. Y se limitan con `Timeline::SetDesiredFrameRate`: el recorrido dura
    medio minuto, nadie distingue 20 de 60, y la alternativa es tener la máquina
    repintando la ventana entera sin parar. En un programa que se llama Optimizador PC
    eso no es un detalle.

27. **Mica y el degradado propio son EXCLUYENTES.** El material del sistema solo se ve si
    la ventana es translúcida, y una ventana translúcida ya no puede tener fondo propio:
    `ui/Components/Shell/WindowMaterial.ps1` cambia una cosa por la otra, no las suma.
    Por eso es una preferencia y viene apagada. La llamada a `dwmapi` vive en
    `core/Interop/` y **nunca lanza**: si Windows no lo admite devuelve `$false` y las
    superficies se quedan opacas — jamás se deja una ventana translúcida sin material
    detrás. Se aplica en `SourceInitialized`, que es cuando hay descriptor.

28. **Las pruebas NO escriben en tus ajustes.** `tests/Harness/AppHost.ps1` redirige
    `$AppSettingsPath` a un temporal con el PID en el nombre. Sin eso, cualquier prueba
    que toque una preferencia reescribiría `%APPDATA%\OptimizadorPC\settings.json`
    entero, porque el arnés no llama a `Import-AppSettings` y la tabla arranca vacía:
    guardar dejaría solo la clave que acaba de tocar la prueba.

    **La sonda de `Ui/Wiring.Tests.ps1` va aparte**, porque no pasa por el arnés: es una
    copia de `main.ps1` en otro proceso, y ahí la redirección se le cuela justo antes de
    su `Import-AppSettings`. Sin eso, pulsar el botón de tema en la sonda le cambiaba el
    tema al usuario en cada pasada de las pruebas.

## La capa visual (fondo, degradados y movimiento)

Dónde vive cada cosa del aspecto, para no buscarla:

| Qué se ve | Dónde se toca |
| --------- | ------------- |
| Colores planos | `Get-Palette` en `ui/Design/Theme.ps1` |
| Degradados | `$GradientTokens`, en el mismo archivo. **Se componen de dos claves de la paleta** |
| Las manchas del fondo | `ui/Components/Shell/Backdrop.ps1` (posición, tamaño y vaivén) |
| Entrada en cascada | `Start-StaggeredEnter`, y quién se mueve lo dice `Get-EnterTarget` |
| Halo de la tarjeta | `Add-HoverLift -Glow <clave>`; el color se resuelve al pasar el ratón |
| Marca del menú y pastilla de modo | `Move-NavIndicator` / `Move-ModeIndicator` |
| Lista o cuadrícula | opción `grid` de `ui/Index/ViewOptionsIndex.ps1`; el panel lo elige `New-CategoryPanel` |
| Mica / Acrílico | `ui/Components/Shell/WindowMaterial.ps1` + `core/Interop/SystemBackdrop.ps1` |

**La cuadrícula no es una vista aparte.** `ui/Views/OptimizationsListView.ps1` pregunta
por la opción y elige panel (`StackPanel` o `WrapPanel`) y pieza (`New-CategoryCard` o
`New-CategoryTile`). Las dos piezas comparten las píldoras (`New-CategoryStats`), así
que no pueden acabar contando cosas distintas según cómo se mire la pantalla. En
cuadrícula la descripción lleva **alto fijo**: con alto máximo, la baldosa de
descripción corta sube y deja la fila dentada.

**Un número que sube pasa por `Start-CountUp`**, y sin ventana viva escribe el valor
final y se acaba. Sin bucle de mensajes el temporizador no late nunca y la cifra se
quedaría clavada en cero — que es lo que verían las pruebas.

## Al implementar tweaks reales

Ya hay lógica real: `core/` **lee** el registro. Escribir sigue sin hacerse.

- La lógica de sistema vive en `core/`, nunca dentro de las vistas ni de los componentes.
- **`core/` está dividido por lo que toca de Windows**, no por tamaño: `core/Registry/` (leer y, algún día, escribir el registro), `core/Interop/` (llamadas a la API de Windows: hoy solo Mica y Acrílico) y `core/Diagnostics/` (el registro de actividad). Un mecanismo nuevo — red, servicios, energía — es una subcarpeta nueva ahí dentro, y entra al `.exe` sola.
- **Nada de `core/` lanza hacia arriba.** Una clave inexistente o sin permisos es una respuesta, no un error: se devuelve un estado (`read` / `missing` / `denied` / `badpath`) y la interfaz lo pinta. Una excepción escapando de aquí tumbaría la ventana.
- **Un DWord llega como `Int32` con signo.** `0xFFFFFFFF` se lee como `-1`. Hay que reinterpretarlo sin signo (`Format-RegistryValue`) o los valores altos salen negativos y no cuadran con lo declarado.
- **Se abre siempre `RegistryView::Registry64`.** Si el `.exe` se compilara a 32 bits, `HKLM\SOFTWARE` se redirigiría a `Wow6432Node` en silencio.
- El estado real se lee al entrar en la sección y se vuelca en las claves de `-Registry`; el `Current` **no se declara** en `ui/Data/Categories/`.
- **La etiqueta de un ajuste que lee el registro se calcula, no se declara.** `core/Registry/SettingStatus.ps1` compara lo leído con el `Recommended` y el `Default` de cada clave y deja un `Status`: `optimized`, `factory`, `custom` o `unknown`. Un ajuste con `-Registry` **no lleva `-Tags`** — serían la versión inventada de lo mismo. Se compara por valor y no por escritura (`0x0000000A` = `10` = `0XA`, y `-1` = `0xFFFFFFFF`), un valor ausente es `factory` (Windows usa el suyo), y sin nada declarado con lo que comparar es `unknown`, nunca `custom`.
- **El estado se calcula donde se lee, no donde se pinta.** Cuelga de `Update-CategoryRegistryState`, así que entrar en la sección y pulsar *Refrescar* lo dejan al día por el mismo camino. La interfaz solo lee `$Setting.Status` y `$Key.Status`; los colores y los nombres salen todos de `Get-StatusStyle` (`ui/Design/UiKit.ps1`), que es el único sitio donde se escriben.
- Todo cambio de registro/servicio debe ser reversible y tener su valor de restauración documentado.

## El registro de actividad (el botón "log")

Cada lectura del registro deja una línea en `core/Diagnostics/Log.ps1`, y el botón de la barra de
título abre el cajón que las enseña (`ui/Components/Shell/LogPanel.ps1`).

- **`core/Diagnostics/Log.ps1` guarda hechos, no frases.** El campo `Status` lleva una palabra en
  inglés (`read`, `not set`, `no access`, `reading`, `done`) que la interfaz pasa por
  `T` al pintar la etiqueta de color. Así `core/` sigue sin saber que existe un idioma.
- **Las líneas del log NO se traducen, y es a propósito.** Son rutas del registro y
  valores: texto técnico para copiar y pegar. Lo que sí se traduce es el marco.
  Es la excepción consciente a la regla 15, y está explicada en la cabecera de
  `LogPanel.ps1`.
- **El cajón no es una vista.** Se pone encima de la pantalla actual y no pasa por
  `ui/Engine/Router.ps1`, así que al cerrarlo sigues donde estabas. Por eso `Update-UiLanguage`
  lo rehace aparte: `Show-CurrentView` no lo toca.
- **Colapsar el velo al cerrar está en `Close-LogOverlay`, no dentro del manejador de
  la animación.** Mientras el velo esté visible se come los clics de lo que hay
  debajo, y las animaciones de WPF no avanzan sin una ventana pintándose: separarlo
  permite probar el cierre.
- **El buffer es circular** (`$AppLogCapacity`, mil entradas) y **se pintan como mucho
  `$LogPanelMaxRows`**. Si algún día se apunta mucho más, esos dos números son los que
  hay que mirar.
- **Guardar abre el "Guardar como" de Windows**, y lo que se escribe es el buffer
  entero, no las filas pintadas. El diálogo está partido en tres —`New-LogSaveDialog`
  lo arma, `Read-LogSaveResult` traduce su respuesta (cancelar es `$null`: ni archivo
  ni aviso) y `Save-AppLogTo` escribe— porque **un modal no se puede probar**: la suite
  se quedaría esperando a que alguien pulse. Así lo único sin cubrir es la línea del
  `ShowDialog`. El nombre sugerido lo pone `Get-AppLogFileName` en `core/`
  (`opt-<fecha>.log`, **sin dos puntos**: Windows no los admite en un nombre).
- **La carpeta de guardado se recuerda en `settings.json`** (`LogSaveFolder`, vía
  `Set-AppSetting` como cualquier preferencia). La primera vez, y **siempre que la
  guardada ya no exista**, se cae al Escritorio —preguntado a Windows, no compuesto a
  mano: con OneDrive el Escritorio de verdad está dentro de OneDrive—.
- **Con el registro vacío no se guarda.** `Update-LogSaveButton` apaga el botón desde
  `Update-LogList` (por donde pasan todos los cambios de las filas) y `Export-AppLog`
  se niega igualmente: la garantía de que no salga un archivo con solo la cabecera
  está en `core/`, no en el botón.
- **El volcado usa `[fecha] [NIVEL] [FUENTE]`,** con el estado como cuarto corchete y
  el detalle tras una barra. Cada campo se delimita solo, así que una línea se parte
  con una expresión regular aunque el mensaje lleve espacios. Solo afecta al archivo:
  el panel pinta los campos uno a uno y no pasa por `Format-AppLogLine`.
- `Read-RegistryValue` solo cronometra y apunta; la lectura pelada es
  `Read-RegistryValueRaw`.

**El log puede vivir en dos sitios**: el cajón de siempre y una ventana aparte
(`ui/Components/Shell/LogWindow.ps1`), con un botón para sacarlo y otro para volver a
acoplarlo. Lo que hay que saber:

- **El contenido lo arma una sola función**, `New-LogContent`. Lo único que cambia es
  la esquina de botones de la cabecera; en la ventana suelta esa misma cabecera hace
  además de barra de título (arrastra, y el doble clic maximiza). Si algún día se
  duplica esa construcción, las dos vistas acabarán desparejadas.
- **La ventana se construye por código, no en XAML.** `build.ps1` solo sabe incrustar
  UN xaml: un segundo `.xaml` funcionaría con `main.ps1` y faltaría en el `.exe`. Es
  el mismo motivo que el del menú lateral (regla 13).
- **Es hija de la principal (`Owner`).** Eso le da dos cosas: se cierra sola al salir
  del programa —si no, quedaría una ventana viva impidiendo terminar— y sigue siendo
  usable pese a que la principal se muestre con `ShowDialog`, que de otro modo
  inutiliza cualquier otra ventana de la aplicación. `Owner` solo admite una ventana
  ya mostrada, así que en las pruebas se queda sin dueño a propósito.
- **Hereda el tema por `MergedDictionaries`**, de modo que alternar claro/oscuro la
  repinta a la vez que a la principal sin que haya que enterarse allí.
- **Una ventana creada por código no trae `NameScope`** —el de la principal lo monta
  el cargador de XAML— y sin él `RegisterName` lanza. Hay que ponérselo antes de
  construir nada que se registre.
- **Las líneas nuevas NO se pintan solas: hay que llamar a `Sync-LogView`.**
  `Write-AppLog` apunta en `core/` y ahí se acaba; nadie avisa a la interfaz. El cajón
  lo disimula porque `Show-LogPanel` lo rehace entero cada vez que se abre, pero la
  ventana suelta se queda delante mientras se navega y se lee el registro, y sin el
  aviso enseña para siempre lo que había al sacarla. Quien lea el sistema es quien
  avisa —hoy `Show-CategoryDetailView`, junto a `Reset-SearchIndex`—, porque `core/` no
  sabe que existe ni un cajón ni una ventana.

**`Update-UiNow` (ProgressStrip) es un `DoEvents`.** Cede el hilo para que la barra de progreso se pinte durante una lectura síncrona, y en esa pausa WPF entrega eventos de ratón. Quien la use debe dejar la ventana sorda mientras dura (`$Window.Content.IsHitTestVisible = $false`), o un clic a mitad de carga navega a otro sitio dejando la lectura a medias. Si algún día la lectura se va a un hilo aparte, esa función sobra.

## El buscador global (la caja de la cabecera)

`ui/Engine/Search.ps1` arma **un índice plano** con una entrada por sección y otra por
ajuste, cada una con su `Haystack` en minúsculas. Buscar es mirar si están dentro
todos los términos, así que la coincidencia es parcial y sin distinguir mayúsculas:
medio nombre de valor encuentra la clave entera.

- **No sabe qué secciones hay**: se las pregunta a `Get-OptimizationCategories`. Una
  sección nueva entra en el buscador sola, sin tocar ese archivo.
- **El índice se guarda y se reutiliza.** Se tira con `Reset-SearchIndex`, y hoy eso
  pasa en dos sitios: al leer el registro de una sección (aparecen `Current` y
  `Status`, que se indexan) y al cambiar de idioma. Si algún día se indexa algo más
  que cambie en caliente, ahí es donde hay que avisar.
- **Se indexa el texto traducido Y el original.** Quien usa la aplicación en español
  busca en español, pero `telemetry` tiene que seguir encontrando lo mismo. Lo
  técnico —rutas, nombres de valor, números— no se traduce nunca.
- **Lo que se junta se traduce ANTES de juntarse.** Las etiquetas y las opciones de un
  desplegable pasan por `New-SearchListField`, que traduce uno a uno; juntarlas antes
  y pasar la frase por `T` no traduce nada y ensucia `Get-MissingTranslations`.

Dos trampas que ya han mordido una vez:

- **El `Tag` de la caja es del desplegable, no del marcador.** `New-SearchBox`
  (`ui/Design/UiKit.ps1`) esconde su "Buscar optimizaciones..." buscando entre los
  hermanos justamente para dejar el `Tag` libre, porque ahí mete su `Popup`
  `New-SearchBar`. Dos dueños para el mismo hueco y una de las dos cosas deja de
  funcionar.
- **Al escribir se repinta el cuerpo, nunca la cabecera.** Rehacer la cabecera
  destruye la caja de texto en la que se está escribiendo, y con ella el foco y el
  cursor. Por eso hay dos caminos —`Show-SearchResultsView` entra y pinta las dos
  cosas, `Update-SearchResults` solo el cuerpo— y por eso el recuento
  ("12 resultados") va en el cuerpo y no en el subtítulo.

Escribir abre un desplegable con las primeras filas (`$SearchPopupMax`), `Enter` lleva
a la página con todas y `Escape` lo cierra —pero solo se queda la tecla si había algo
abierto, o dejaría de cerrarse el cajón del log. Hay antirrebote
(`$SearchDebounceMs`): diez pulsaciones son una búsqueda, no diez.

Pulsar un resultado abre su sección con **el ajuste marcado** (`New-SettingCard
-Highlight`, borde de acento) y lo trae a la vista. El desplazamiento va aplazado al
`Dispatcher` a propósito: `Show-View` manda el scroll arriba DESPUÉS de que la vista
termine, así que hacerlo en el sitio no serviría de nada.
