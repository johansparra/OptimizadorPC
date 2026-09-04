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

# Pruebas (sin dependencias). Pásalas en LOS DOS hosts: ver la regla 8.
powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
pwsh       -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
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
10. **Pinceles congelados.** WPF congela al cargar el XAML los `SolidColorBrush` que considera compartibles, y un `Freezable` congelado no se puede mutar. Por eso `Set-AppTheme` intenta primero `$brush.Color = ...` y solo si está congelado lo sustituye. Al sustituir usa `Resources.Add()`, **no** el indexador `Resources[$k] = ...`: el indexador guarda el `PSObject` que envuelve al pincel y WPF lo rechaza al resolver el `DynamicResource` con *"'#FF59616F' no es un valor válido para la propiedad 'Foreground'"* (el mensaje engaña: el `ToString()` de un `SolidColorBrush` es su color).
11. **Nunca declares un `Freezable` dentro de un `Setter` de estilo si vas a animarlo.** `RenderTransform` y `Effect` puestos en un `Setter` se comparten entre todos los controles del estilo y WPF no permite animar una instancia compartida. Créalos por control en código (ver `Add-HoverLift`).
12. **Iconos: `Glyph 'Nombre'` del catálogo de `Theme.ps1`** (fuente *Segoe Fluent Icons*, nativa de Windows 11), nunca emoji. Antes de usar un codepoint nuevo, comprueba que existe con `GlyphTypeface.CharacterToGlyphMap` y míralo renderizado: varios glifos parecidos tienen significados distintos (p. ej. `E7ED` es una campana **tachada**, la campana normal es `EA8F`).

13. **El menú lateral se construye por código, no en el XAML.** `MainWindow.xaml` solo aporta el `Border` llamado `Sidebar` con dos `StackPanel` vacíos (`NavTop` y `NavBottom`); los botones los crea `Build-Sidebar` a partir de `ui/Index/NavigationIndex.ps1`. Cada botón se registra con `$Window.RegisterName('Nav<Id>', ...)`, así que `FindName('NavSettings')` sigue funcionando — si añades uno nuevo, respeta ese nombrado.
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

## Al implementar tweaks reales

Ya hay lógica real: `core/` **lee** el registro. Escribir sigue sin hacerse.

- La lógica de sistema vive en `core/`, nunca dentro de las vistas ni de los componentes.
- **`core/` está dividido por lo que toca de Windows**, no por tamaño: `core/Registry/` (leer y, algún día, escribir el registro) y `core/Diagnostics/` (el registro de actividad). Un mecanismo nuevo — red, servicios, energía — es una subcarpeta nueva ahí dentro, y entra al `.exe` sola.
- **Nada de `core/` lanza hacia arriba.** Una clave inexistente o sin permisos es una respuesta, no un error: se devuelve un estado (`read` / `missing` / `denied` / `badpath`) y la interfaz lo pinta. Una excepción escapando de aquí tumbaría la ventana.
- **Un DWord llega como `Int32` con signo.** `0xFFFFFFFF` se lee como `-1`. Hay que reinterpretarlo sin signo (`Format-RegistryValue`) o los valores altos salen negativos y no cuadran con lo declarado.
- **Se abre siempre `RegistryView::Registry64`.** Si el `.exe` se compilara a 32 bits, `HKLM\SOFTWARE` se redirigiría a `Wow6432Node` en silencio.
- El estado real se lee al entrar en la sección y se vuelca en las claves de `-Registry`; el `Current` **no se declara** en `ui/Data/Categories/`.
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
- `Read-RegistryValue` solo cronometra y apunta; la lectura pelada es
  `Read-RegistryValueRaw`.

**`Update-UiNow` (ProgressStrip) es un `DoEvents`.** Cede el hilo para que la barra de progreso se pinte durante una lectura síncrona, y en esa pausa WPF entrega eventos de ratón. Quien la use debe dejar la ventana sorda mientras dura (`$Window.Content.IsHitTestVisible = $false`), o un clic a mitad de carga navega a otro sitio dejando la lectura a medias. Si algún día la lectura se va a un hilo aparte, esa función sobra.
