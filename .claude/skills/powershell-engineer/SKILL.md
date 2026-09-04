---
name: powershell-engineer
description: Ingeniero senior de PowerShell 5.1 / 7 para este proyecto. Úsalo al escribir, depurar o revisar cualquier .ps1 - trampas del lenguaje que no dan error sino resultado equivocado, disciplina de los dos hosts (Windows PowerShell 5.1 del .exe y pwsh 7 de main.ps1), codificación UTF-8 con BOM, flujos de salida, closures, tipos del registro. Trigger words - powershell, ps1, script, encoding, BOM, mojibake, closure, pipeline, "no funciona en el exe", "solo falla en 5.1", "Token inesperado".
---

# PowerShell senior — reglas de esta casa

Este proyecto corre **el mismo código en dos intérpretes distintos**. Casi todos los
fallos raros vienen de ahí o de la codificación. Empieza por las dos primeras
secciones antes de tocar nada.

## 1. El contrato de los dos hosts

| | `main.ps1` (desarrollo) | `OptimizadorPC.exe` (entrega) |
| --- | --- | --- |
| Intérprete | pwsh 7 | Windows PowerShell **5.1** |
| Ámbito de las funciones | de script | **global** (ps2exe las deja ahí) |
| Consola | sí | **no** (`-noConsole`) |
| Privilegios | los tuyos | **elevado** (`-requireAdmin`) |

Consecuencias directas:

- **Un bug puede existir en un host y no en el otro.** El caso canónico es
  `.GetNewClosure()`: en el `.exe` funciona porque las funciones están en ámbito
  global, y en `main.ps1` revienta con *"The term 'Show-...' is not recognized"*.
- **`Write-Host` no existe para el usuario final.** Para depurar, ejecuta
  `main.ps1`. Nunca dejes diagnóstico que solo se vea por consola.
- **Prueba SIEMPRE en los dos**, sin excepciones:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
  pwsh       -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
  ```

## 2. Codificación: UTF-8 **con BOM**, siempre

Windows PowerShell 5.1 lee un `.ps1` sin BOM como ANSI (Windows-1252). Los acentos de
los comentarios se vuelven mojibake y el parser muere con *"Token inesperado"* o
*"Falta la cadena en el terminador"*. pwsh 7 asume UTF-8 y no se entera: **el archivo
parsea en 7 y explota en 5.1**.

```powershell
# ✗ desde pwsh 7 NO pone BOM
Set-Content $ruta $texto -Encoding UTF8

# ✓ único método fiable en los dos hosts
[System.IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding($true)))
```

Trampas relacionadas:

- **`>` y `Out-File` en 5.1 escriben UTF-16LE** por defecto. Nunca generes un `.ps1`
  así.
- `sed -i` y `perl -i` **conservan** el BOM (operan sobre bytes): son seguros para
  editar estos archivos desde Bash.
- Verifica siempre después de escribir:
  ```bash
  file ui/Archivo.ps1        # debe decir: UTF-8 (with BOM)
  ```
- `tests/Source/Rules.Tests.ps1` ya comprueba el BOM de todo el árbol. Si lo rompes,
  las pruebas lo cazan — pero solo si las ejecutas.

## 3. Trampas que no dan error, dan resultado equivocado

Estas son las que cuestan horas. Ninguna lanza excepción donde la esperas.

### `@()` sobre `List[object]` creada con `New-Object`

```powershell
$lista = New-Object System.Collections.Generic.List[object]
$copia = @($lista)          # ✗ "los tipos de argumentos no coinciden" — en 5.1 Y en 7
$copia = $lista.ToArray()   # ✓
```
`New-Object` devuelve el objeto envuelto en un `PSObject`. Con `List[string]`,
`ArrayList` o `::new()` funciona, así que el fallo aparece **solo en algunos sitios**.
Recorrerla con `foreach`, mandarla por la tubería o devolverla sí funciona siempre.

### `-f` dentro de los paréntesis de un **método**

```powershell
$lista.Add('{0} de {1}' -f $hechas, $total)   # ✗ la coma separa ARGUMENTOS del método
$texto = '{0} de {1}' -f $hechas, $total
$lista.Add($texto)                            # ✓
```
Al llamar a un **comando** (`Write-Host (...)`, `-Detail (...)`) no pasa: ahí los
paréntesis envuelven una expresión.

### Todo lo que una función no consume, lo devuelve

```powershell
$panel.Children.Add($x)              # ✗ ArrayList.Add devuelve el índice -> contamina el return
$panel.Children.Add($x) | Out-Null   # ✓
```
Una función de PowerShell devuelve **todas** las expresiones sin capturar, no solo el
`return`. Un `.Add()` olvidado hace que `New-Algo` devuelva `@(0, $control)` en vez
del control. Se manifiesta lejos del sitio del error.

### Comparaciones

```powershell
if ($x -eq $null)     # ✗ si $x es un array, -eq FILTRA en vez de comparar
if ($null -eq $x)     # ✓ el $null va a la izquierda, siempre

[bool]'0'             # $true  — toda cadena no vacía es verdadera
[bool]'False'         # $true
```
Importante al leer el registro: un valor `String` que vale `'0'` **no** es `$false`.
Compara contra el texto, o conviértelo explícitamente con `[int]`.

### DWord con signo

.NET entrega un `DWord` como `Int32` **con signo**: `0xFFFFFFFF` llega como `-1`. Hay
que reinterpretarlo sin signo antes de enseñarlo o compararlo (ver
`Format-RegistryValue` en `core/Registry/Reader.ps1`). Es exactamente el caso de
`NetworkThrottlingIndex`.

### `+=` sobre arrays es O(n²)

Cada `+=` crea un array nuevo y copia. Con listas que crecen usa
`[System.Collections.Generic.List[object]]::new()` y `.Add()`.

## 4. Closures: NO uses `.GetNewClosure()`

Un scriptblock con closure queda ligado a un módulo dinámico y **desde ahí no se ven
las funciones del script**. Tampoco captures una variable de bucle directamente: al
dispararse apuntaría al último elemento.

```powershell
# ✓ el dato viaja por el Tag y la ventana sale del emisor
$card.Tag = $cat
$card.Add_MouseLeftButtonUp({
    param($s, $e)
    Show-CategoryDetailView -Window ([System.Windows.Window]::GetWindow($s)) -Category $s.Tag
})
```
Si necesitas llevar varias cosas, mete un `[PSCustomObject]@{...}` en el `Tag`
(ver `ui/Components/Cards/PreferenceCard.ps1`). `Ui/Wiring.Tests.ps1` caza esta regla
pulsando los botones de verdad.

## 5. Errores y robustez

- **`core/` nunca lanza hacia arriba.** Una clave inexistente o sin permisos es una
  *respuesta* (`read` / `missing` / `denied` / `badpath`), no un fallo. Una excepción
  que escape de ahí tumba la ventana.
- Un error **no terminante** no entra en `catch`. Para capturarlo:
  `Cmdlet ... -ErrorAction Stop` dentro del `try`.
- `-ErrorAction SilentlyContinue` silencia el *mensaje*, no el fallo.
- Un JSON corrupto en `settings.json` se ignora y se arranca con los valores por
  defecto: nunca dejes que una preferencia guardada impida abrir la aplicación.

## 6. Estilo del proyecto

- Comentarios y nombres de cara al usuario **en español**; los identificadores de
  código y las claves de traducción, en inglés (el inglés es el idioma fuente).
- Parámetros declarados con tipo: `[string[]]$Tags = @()`, `[Parameter(Mandatory)]`.
  Un `[string[]]` acepta un único valor y lo convierte en array de uno — por eso
  `-Tags 'Default'` es válido.
- Cabecera de comentario en cada archivo explicando **qué es y qué NO es**. Sigue ese
  tono: se explica el porqué, no el qué.
- Nada de `Install-Module` en tiempo de ejecución. Solo `build.ps1` instala algo
  (ps2exe) y es a propósito.

## 7. Antes de dar algo por terminado

1. `file` sobre cada `.ps1` tocado → *UTF-8 (with BOM)*.
2. Pruebas verdes en **5.1 y en 7**.
3. ¿Algún `.Add()` sin `| Out-Null`?
4. ¿Algún `.GetNewClosure()` o variable de bucle capturada?
5. ¿El archivo nuevo está DENTRO de una de las siete carpetas de capa? Es la única
   forma de que entre al `.exe` (regla 2 de `CLAUDE.md`).
6. Si añadiste texto visible, ¿pasa por `T` y está en `ui/Data/Lang/es.ps1`?
