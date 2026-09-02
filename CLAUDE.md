# CLAUDE.md

Contexto para trabajar en **Optimizador PC**. Ver `README.md` para la estructura completa y los diagramas.

## Qué es

App de escritorio **WPF construida en PowerShell 5.1**, compilada a un `.exe` portable con **ps2exe**. Muestra categorías de optimizaciones de Windows 11 con toggles y dropdowns.

**Estado actual: solo UI.** Ningún control aplica cambios reales al sistema todavía — `ui/CategoryData.ps1` son datos estáticos y los toggles solo cambian de color.

## Comandos

```powershell
# Ejecutar en modo desarrollo (rápido, sin compilar)
powershell -ExecutionPolicy Bypass -File .\main.ps1

# Compilar el .exe portable
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

No hay tests ni linter.

## Reglas del proyecto

1. **Editar siempre los archivos fuente**, nunca `build/_combined.ps1` — es generado y se sobrescribe en cada build.
2. **`build.ps1` parsea `main.ps1` con regex.** Dos patrones son frágiles y no se deben romper:
   - Los dot-source deben quedar exactamente como `. (Join-Path $ScriptRoot 'ui\Archivo.ps1')` (una línea, comillas simples, backslash).
   - El XAML va entre los marcadores `@@EMBED_XAML@@` y `@@ENDEMBED@@`.
   Si agregas un archivo nuevo en `ui/`, dot-sourcéalo con ese formato o no entrará al `.exe`.
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

## Al implementar tweaks reales (aún no hecho)

- La lógica de sistema debe vivir en módulos nuevos separados de `ui/` (p.ej. `core/`), no dentro de las vistas.
- Cada tweak necesita leer su estado real del sistema, no asumir el `Value` estático de `CategoryData.ps1`.
- Todo cambio de registro/servicio debe ser reversible y tener su valor de restauración documentado.
