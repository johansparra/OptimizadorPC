---
name: refactoring-agent
description: Refactorizador seguro para este repositorio. Úsalo al reorganizar código sin cambiar comportamiento - mover algo de capa, renombrar, extraer un componente, borrar una sección o una etiqueta de todo el proyecto, limpiar duplicación. Cubre el ciclo de trabajo (dos hosts, 130 pruebas, sin linter), qué se rompe al mover archivos y el barrido completo para eliminar un concepto sin dejar restos. Trigger words - refactor, refactorizar, reorganizar, mover, renombrar, extraer, limpiar, eliminar, quitar, deduplicar, "de todo el proyecto".
---

# Refactorizar aquí sin romper nada

Refactorizar es **cambiar la forma sin cambiar el comportamiento**. Si el
comportamiento cambia, ya no es un refactor: dilo explícitamente antes de hacerlo.

## 0. Las dos reglas que no se negocian

1. **Edita siempre los archivos fuente, NUNCA `build/_combined.ps1`.** Es generado y
   `build.ps1` lo sobrescribe entero en cada compilación. Cualquier búsqueda debe
   excluirlo o te devolverá coincidencias fantasma:
   ```bash
   grep -rn "loQueSea" --include=*.ps1 . | grep -v build/
   ```
2. **Las pruebas se pasan en los dos hosts, antes y después.** Un refactor que solo
   verificas en uno no está verificado.

## 1. El ciclo

```bash
# 1. Punto de partida verde  (si ya está roja, arregla eso primero o para y avisa)
powershell -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1
pwsh       -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1

# 2. Un cambio pequeño y completo

# 3. Verificar codificación de lo tocado
file ui/Archivo.ps1        # UTF-8 (with BOM)

# 4. Las dos suites otra vez.  Rojo -> deshaz ese paso, no acumules
```

Pasos pequeños. Si un refactor necesita treinta archivos, hazlo en tandas que dejen
las pruebas verdes entre medias.

**Herramientas:** `sed -i` y `perl -i` **conservan el BOM** (operan sobre bytes), así
que son seguros. `Set-Content -Encoding UTF8` desde pwsh 7 **no pone BOM** y rompe el
5.1: no lo uses nunca para estos archivos.

## 2. Los olores propios de este proyecto

| Olor | Dónde va | Cómo cazarlo |
| --- | --- | --- |
| Una vista haciendo `New-Object` de controles | `ui/Components/` | `grep -n "New-Object System.Windows.Controls" ui/Views/` |
| Un componente mirando `Id` de categorías concretas | al archivo de la categoría | `grep -n "\.Id -eq '" ui/Components/` |
| Un texto visible sin `T` | envolverlo en `T` + `ui/Data/Lang/es.ps1` | `Ui/Language.Tests.ps1` |
| Un color literal `#RRGGBB` | `Set-TextFg` / `Set-BoxBg` / `DynamicResource` | `grep -rn "#[0-9A-Fa-f]\{6\}" ui/ --include=*.ps1` |
| `.GetNewClosure()` o variable de bucle capturada | patrón `Tag` | `grep -rn "GetNewClosure" .` |
| Lógica de sistema dentro de `ui/` | `core/` | `grep -rn "Microsoft.Win32\|Get-Service" ui/` |
| Un control de WPF dentro de `core/` | `ui/` | `grep -rn "System.Windows" core/` |
| `@()` sobre una `List[object]` | `.ToArray()` | `grep -rn "@(\$" --include=*.ps1 .` |
| Emoji en vez de `Glyph` | catálogo de `Theme.ps1` | `Source/Rules.Tests.ps1` |

`tests/Source/Rules.Tests.ps1` ya comprueba varias de estas leyendo el código. Si
añades una regla nueva al proyecto, ese es su sitio natural.

## 3. Mover código entre capas

**Vista → componente.** Corta el bloque que crea controles, envuélvelo en
`New-LoQueSea { param($Window, $Datos) ... }` dentro de un archivo nuevo de
`ui/Components/`, y deja en la vista solo `$panel.Children.Add((New-LoQueSea ...)) | Out-Null`.
No hay que registrar el archivo: la carpeta se carga entera.

**Componente → categoría.** Si el componente decide algo mirando qué categoría es, ese
dato pertenece a la declaración. Añade un campo en `Register-Category` / `New-Setting`
y que el componente lo lea sin saber de quién viene.

**`ui/` → `core/`.** Al bajar lógica de sistema:
- No puede volver ni un control de WPF ni una cadena traducida.
- **No puede lanzar hacia arriba.** Devuelve un estado (`read` / `missing` / `denied` /
  `badpath`), nunca una excepción.
- `core/` está dividido por lo que toca de Windows: `core/Registry/` y
  `core/Diagnostics/`. Un mecanismo nuevo (red, servicios, energía) es una
  **subcarpeta nueva** ahí dentro, y entra al `.exe` sola porque el bloque
  `# @@EMBED_DIR:core@@` es recursivo.

## 4. Mover, renombrar y borrar archivos

Antes de renombrar o mover, pregúntate qué se rompe:

- **Las siete carpetas de capa** (`ui/Design`, `ui/Engine`, `ui/Index`, `core`,
  `ui/Data`, `ui/Components`, `ui/Views`) se cargan **enteras y recursivas**, por
  orden de ruta. Dentro de una carpeta el orden da igual: esos archivos solo definen
  funciones y tablas.
- **Lo que NO da igual es el orden entre bloques de `main.ps1`.** Los datos se
  registran al cargarse: `ui/Data` necesita `ui/Engine` ya cargado. Hay una prueba
  que vigila ese orden.
- **Sacar un archivo de esas carpetas lo deja fuera del `.exe`.** No hay forma de
  incluir uno suelto: `build.ps1` solo entiende `@@EMBED_DIR@@` y `@@EMBED_XAML@@`.
  Un archivo cargado a mano funciona en desarrollo y falla compilado.
- **Ids**: los `Id` de `ViewOptionsIndex.ps1` y de las preferencias se guardan en
  `settings.json` (`View.<Id>`). Cambiar un `Id` **olvida lo que el usuario eligió**.
  No es un error, pero decídelo a propósito.
- **`RegisterName('Nav<Id>', ...)`**: cambiar el `Id` de una entrada de navegación
  rompe cualquier `FindName('NavAlgo')`.
- **Borrar una sección** es borrar su archivo de `ui/Data/Categories/` y su línea del
  índice. Nada más.

## 5. Eliminar un concepto de todo el proyecto

Receta probada (así se retiró la etiqueta *Preference*). El fallo típico es dejar la
mitad: la declaración fuera pero el mecanismo, el color o la traducción dentro.

```bash
# 1. Inventario COMPLETO antes de tocar nada
grep -rn "Concepto" --include=*.ps1 --include=*.xaml --include=*.md . | grep -v build/
```

Recorre la lista y clasifica cada hit en una de estas cinco, que son los sitios donde
un concepto suele estar repartido:

| Sitio | Ejemplo |
| --- | --- |
| Declaraciones | `ui/Data/Categories/*.ps1`, `ui/Data/Preferences/*.ps1` |
| Mecanismo | bucles y mapas en `CategoryRegistry.ps1`, índices |
| Presentación | `ui/Components/*.ps1`, `ui/Design/UiKit.ps1` (mapas de color, listas de estilos) |
| Idioma | `ui/Data/Lang/es.ps1` — la etiqueta **y sus tooltips** |
| Documentación | `README.md`, `CLAUDE.md`, cabeceras de comentario, ejemplos |

**Ojo con los homónimos.** `grep "Preference"` devuelve también `ui/Data/Preferences/`,
`PreferenceRegistry.ps1` y `PreferenceCard.ps1`, que son la pantalla de Settings: otro
concepto que se llama parecido. Filtra antes de borrar:

```bash
grep -rn "Concepto" . | grep -v "OtraCosaQueSeLlamaIgual"
```

Cierre: un `grep` final que no devuelva nada, comprobar el BOM de todo lo tocado y las
dos suites verdes. Y busca también las **secuelas visuales**: al quitar la etiqueta
había que quitar su píldora del resumen y arreglar el dibujito ASCII de la cabecera
del componente, cosas que ningún grep del nombre encuentra.

## 6. Qué NO refactorizar por tu cuenta

- **Los dos marcadores de `build.ps1`** (`@@EMBED_DIR@@` y `@@EMBED_XAML@@`) y el
  orden con que se recorren las carpetas (`-Recurse` + `Sort-Object FullName`). Ese
  recorrido está **escrito tres veces**: en `main.ps1`, en `build.ps1` y en
  `tests/Harness/AppHost.ps1`. Si cambias uno, cambia los tres a la vez, o el `.exe`
  cargará algo distinto de lo que probaste.
- **Las excepciones conscientes**, que están documentadas y no son descuidos: las
  líneas del log sin traducir, `Close-LogOverlay` separada de su animación,
  `Update-UiNow` haciendo `DoEvents`. Cada una tiene su porqué escrito al lado.
- **Convertir la maqueta en lógica real.** Escribir en el registro no es un refactor.

## 7. Cierre

1. `grep` de comprobación sin resultados (excluyendo `build/`).
2. `file` sobre cada `.ps1` tocado → *UTF-8 (with BOM)*.
3. Las dos suites verdes.
4. Documentación al día: si el refactor cambió una regla o una estructura, `CLAUDE.md`
   y `README.md` también son código.
5. Di qué cambió y qué **no** cambió. Un refactor que sí alteró comportamiento hay que
   declararlo, no esconderlo.
