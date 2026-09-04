---
name: windows-desktop-architect
description: Arquitecto de la aplicación de escritorio WPF sobre PowerShell. Úsalo al añadir o mover funcionalidad de interfaz - una sección nueva, un componente, una vista, una opción del menú Vista, un icono, un color, traducciones, animaciones o cualquier duda de "dónde va esto". Cubre la disciplina de capas y las trampas propias de WPF (pinceles congelados, DynamicResource, hit-testing, Dispatcher, XAML embebido). Trigger words - WPF, XAML, ventana, vista, componente, categoría, sección, tema, icono, glifo, animación, traducción, sidebar, "dónde pongo".
---

# Arquitecto de escritorio — WPF sobre PowerShell 5.1

## 1. Las capas, de datos a pantalla

**Nunca saltes una capa hacia abajo.**

**Una carpeta por capa**, y el número es el orden en que `main.ps1` las carga:

| # | Capa | Carpeta | Regla |
| - | --- | --- | --- |
| 1 | Base | `ui/Design/` | `Theme.ps1` (colores, iconos, animación) y `UiKit.ps1` (piezas genéricas). **Por debajo de todo**: los usa cualquiera y ellos no usan a nadie. |
| 2 | Mecanismo | `ui/Engine/` | `CategoryRegistry`, `PreferenceRegistry`, `Translation`, `AppSettings`, `Router`. Sin datos ni controles. |
| 3 | Política | `ui/Index/` | Qué se ve, en qué orden, qué está bloqueado. **Cero contenido.** |
| 4 | Sistema | `core/` | Habla con Windows. **Ni un control de WPF.** Devuelve datos, nunca lanza. Dividido en `Registry/` y `Diagnostics/`. |
| 5 | Datos | `ui/Data/` | `Categories/`, `Preferences/`, `Lang/`. Un archivo por sección/opción/idioma. Solo declaraciones. |
| 6 | Piezas | `ui/Components/` | Construyen controles. **No conocen las vistas.** Dividido en `Shell/`, `Cards/` y `Layout/`. |
| 7 | Pantallas | `ui/Views/` | Solo ensamblan piezas. Sin `New-Object` de controles sueltos. |

Dentro de `ui/Components/`: **`Shell/`** es el marco de la ventana (TitleBar, Sidebar,
ViewMenu, LogPanel, ProgressStrip), **`Cards/`** las tarjetas (CategoryCard,
SettingCard, PreferenceCard, TechnicalDetails) y **`Layout/`** las piezas de página
(PageHeader, Banner, CategorySummary). Una pieza nueva va donde encaje por lo que
dibuja, no por quién la llama.

**Dos olores que delatan una capa mal puesta:**
- Una vista creando controles a mano → eso pertenece a `Components/`.
- Un componente mirando el `Id` de categorías concretas → eso pertenece al archivo de
  la categoría, o a un campo nuevo en su declaración.

## 2. Recetas — dónde va cada cosa

| Quiero… | Hago… |
| --- | --- |
| Añadir una sección | Un `.ps1` nuevo en `ui/Data/Categories/` + su línea en `CategoryIndex.ps1`. Entra sola al `.exe`. |
| Quitar una sección | Borrar su archivo. Nada más. |
| Añadir un ajuste | `New-Setting` en el archivo de su categoría. Nunca en la vista. |
| Añadir una opción de Settings | Un `.ps1` en `ui/Data/Preferences/` con `Register-Preference`. |
| Añadir una casilla al menú Vista | Una línea en `ui/Index/ViewOptionsIndex.ps1`; se consulta con `Get-ViewOption 'id'`. |
| Añadir una pantalla | `.ps1` en `ui/Views/` + entrada en `NavigationIndex.ps1`. Se muestra con `Show-View`. |
| Añadir un control reutilizable | `ui/Components/`, o `UiKit.ps1` si es genérico y no sabe de nada. |
| Leer algo del sistema | `core/`. Siempre. |

**Las siete carpetas de capa se cargan enteras, subcarpetas incluidas** (bloques
`# @@EMBED_DIR:...@@` de `main.ps1`). Un archivo nuevo dentro de cualquiera entra
solo, tanto en desarrollo como en el `.exe`. **El orden que se ve lo decide el
índice**, no el nombre del archivo.

Lo que **no** se puede es dejar un `.ps1` fuera de esas carpetas: `build.ps1` no tiene
forma de incluirlo y el programa funcionaría en desarrollo pero fallaría compilado.
Una familia nueva de piezas o de mecanismos de sistema es una **subcarpeta** dentro de
la capa que le toque.

## 3. Trampas de WPF que ya nos han mordido

### Pinceles congelados

WPF congela al cargar el XAML los `SolidColorBrush` que considera compartibles, y un
`Freezable` congelado **no se puede mutar**. `Set-AppTheme` intenta primero
`$brush.Color = ...` y solo si está congelado lo sustituye. Al sustituir usa
`Resources.Add()`, **nunca** el indexador:

```powershell
$Window.Resources[$k] = $brush     # mal: guarda el PSObject que envuelve al pincel
$Window.Resources.Add($k, $brush)  # bien
```

El indexador provoca *"'#FF59616F' no es un valor válido para la propiedad
'Foreground'"* al resolver el `DynamicResource`. El mensaje engaña: el `ToString()` de
un `SolidColorBrush` es su color.

### Colores: siempre por recurso de tema

En XAML `{DynamicResource Accent}`; en código `Set-TextFg` / `Set-BoxBg` /
`Set-BoxLine` (envuelven `SetResourceReference`). Un `#RRGGBB` a pelo **no cambia** al
alternar claro/oscuro.

### Nunca un Freezable dentro de un Setter que vayas a animar

`RenderTransform` y `Effect` puestos en un `Setter` se **comparten** entre todos los
controles del estilo, y WPF no permite animar una instancia compartida. Créalos por
control en código (ver `Add-HoverLift` en `Theme.ps1`).

### IsEnabled = $false bloquea todo el subárbol

`New-SettingCard -Locked` lo pone en el panel de controles y WPF deja de entregar el
ratón a **todo lo que cuelgue de ahí**. Si añades un control a la tarjeta, cuélgalo de
ese mismo panel para que herede el bloqueo. `Locked` no es decorativo.

### Un Popup tiene que colgar del árbol lógico

Si lo creas suelto queda fuera y los `SetResourceReference` del tema **no resuelven**.
Mételo como hijo del `Grid` del control que lo abre (ver `ViewMenu.ps1`).

### Update-UiNow es un DoEvents

Cede el hilo para que la barra de progreso se pinte durante una lectura síncrona, y en
esa pausa **WPF entrega eventos de ratón**. Quien la use debe dejar la ventana sorda
mientras dura:

```powershell
$Window.Content.IsHitTestVisible = $false
```

o un clic a mitad de carga navega a otro sitio dejando la lectura a medias. Si algún
día la lectura se va a un hilo aparte, esa función sobra.

### Las animaciones no avanzan sin una ventana pintándose

Por eso colapsar el velo al cerrar el log está en `Close-LogOverlay` y **no** dentro
del manejador de la animación: así se puede probar el cierre sin ventana. Mientras el
velo esté visible se come los clics de lo que hay debajo.

### El menú lateral se construye por código

`MainWindow.xaml` solo aporta el `Border` llamado `Sidebar` con `NavTop` y `NavBottom`
vacíos; los botones los crea `Build-Sidebar` desde `NavigationIndex.ps1`. Cada uno se
registra con `$Window.RegisterName('Nav<Id>', ...)` para que `FindName('NavSettings')`
siga funcionando: respeta ese nombrado.

### Al plegar el menú se anima el ancho del Border, nunca la columna

La columna es `Auto` y sigue al `Border` sola. Animar un `GridLength` exigiría escribir
una animación propia (WPF no trae ninguna). El borde derecho de 1px se pone a 0 al
plegar, o el ancho nunca llegaría a cero.

### El XAML va como aquí-string literal

`build.ps1` lo envuelve en un aquí-string de comillas simples. **No metas un cierre de
aquí-string a inicio de línea dentro del XAML.** El XAML tampoco puede llamar a `T`:
sus textos se fijan desde `ui/Components/Shell/TitleBar.ps1`.

## 4. Idioma

- **Todo texto visible pasa por `T`.** El inglés es el idioma fuente y se traduce por
  texto original, no por clave. Un literal sin `T` sale siempre en inglés y **no**
  aparece en `Get-MissingTranslations`: fallo silencioso.
- **Al cambiar de idioma hay que repintar.** Los colores se actualizan solos por
  `DynamicResource`, el texto no. `Update-UiLanguage` reconstruye el menú y redibuja
  la pantalla actual vía `Router.ps1`, aplazado al `Dispatcher` porque suele
  dispararse desde un control que está dentro de la vista que se va a destruir.
- **Excepción consciente:** las líneas del log **no** se traducen (son rutas y valores
  para copiar y pegar). Lo que se traduce es el marco y el `Status`.
- `Ui/Language.Tests.ps1` recorre la interfaz buscando texto sin traducir.

## 5. Navegación y estado

- **Las vistas se muestran con `Show-View`**, nunca llamándolas directamente, o el
  enrutador pierde el hilo y el cambio de idioma repinta la pantalla equivocada.
- **El cajón del log no es una vista**: se pone encima y no pasa por el enrutador, así
  que al cerrarlo sigues donde estabas. Por eso `Update-UiLanguage` lo rehace aparte.
- **Toda preferencia que deba recordarse pasa por `Set-AppSetting`** →
  `%APPDATA%\OptimizadorPC\settings.json`. Nunca junto al `.exe`: es portable y puede
  acabar en una carpeta sin permisos de escritura. Un JSON corrupto se ignora y se
  arranca con los valores por defecto.

## 6. Iconos

`Glyph 'Nombre'` del catálogo de `Theme.ps1` (fuente *Segoe Fluent Icons*, nativa de
Windows 11). **Nunca emoji.** Antes de usar un codepoint nuevo comprueba que existe
con `GlyphTypeface.CharacterToGlyphMap` y **míralo renderizado**: varios glifos
parecidos significan cosas distintas (`E7ED` es una campana **tachada**; la normal es
`EA8F`).

## 7. Antes de dar la interfaz por terminada

1. Pruebas verdes en 5.1 **y** en 7 (`tests/Run-Tests.ps1`).
2. **Abre la aplicación y míralo.** Las pruebas no ven el aspecto: ni un color
   ilegible en oscuro, ni una tarjeta torcida, ni un glifo equivocado.
3. Alterna claro/oscuro y cambia de idioma con la pantalla nueva delante.
4. ¿Algún literal sin `T`? ¿Algún `#RRGGBB`?
5. ¿El archivo nuevo entra al `.exe`?
