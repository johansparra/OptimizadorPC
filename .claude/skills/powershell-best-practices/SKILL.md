---
name: powershell-best-practices
description: Buenas prácticas para escribir scripts y funciones de PowerShell bien formados. Úsalo al crear una función nueva, un script de utilidad o cualquier código que vaya a APLICAR cambios al sistema - verbos aprobados, validación de parámetros, ShouldProcess con -WhatIf/-Confirm, idempotencia, streams de salida, ayuda basada en comentarios, objetos en vez de texto. Complementa a powershell-engineer (que cubre las trampas del lenguaje y los dos hosts). Trigger words - buenas practicas, best practices, estilo, convenciones, funcion nueva, script nuevo, WhatIf, Confirm, ShouldProcess, validacion, parametros, idempotente, aplicar tweak.
---

# Buenas prácticas de PowerShell

`powershell-engineer` cubre **las trampas** del lenguaje y de los dos hosts. Esto
cubre **cómo se escribe bien** una función o un script desde cero. Si vas a escribir
código que *cambia* el sistema, la sección 3 es la importante.

## 1. Anatomía de una función

```powershell
<#
    Qué hace, en una frase.

    Qué NO hace, si alguien podría suponerlo.

    Ejemplo:
        Set-RegistryValue -Path 'HKCU\Software\X' -Name 'Y' -Value 1 -Type DWord
#>
function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')]
        [string]$Type = 'DWord'
    )
    ...
}
```

- **Verbo-Sustantivo, con verbo aprobado.** `Get-`, `Set-`, `New-`, `Remove-`,
  `Test-`, `Read-`, `Write-`, `Update-`, `Show-`. Comprueba con `Get-Verb`. Un verbo
  inventado (`Apply-`, `Change-`) hace el código ilegible para cualquiera que sepa
  PowerShell. Sustantivo **en singular**, aunque devuelva varios.
- **Sustantivo con prefijo propio** cuando pueda chocar con un cmdlet del sistema:
  este proyecto usa `Read-RegistryValue`, no `Read-Value`.
- **El nombre dice el efecto.** `Get-`/`Read-`/`Test-` **no cambian nada**. `Set-`,
  `New-`, `Remove-` sí. No escondas una escritura dentro de un `Get-`.
- **Una función, una responsabilidad.** El proyecto ya lo hace: `Read-RegistryValue`
  cronometra y apunta, `Read-RegistryValueRaw` solo lee. Separarlas permite probar la
  lectura sin el registro de actividad de por medio.
- **Comentario de cabecera que explica el porqué**, no el qué. Mira cualquier archivo
  de `core/` o de `ui/`: ese es el tono de la casa.

## 2. Parámetros

- Declara **el tipo siempre**: `[string]`, `[int]`, `[switch]`, `[hashtable[]]`.
  Un `[string[]]` acepta un valor suelto y lo convierte en array de uno.
- `[Parameter(Mandatory)]` para lo que no tiene defecto sensato. **Nunca** pidas un
  dato por `Read-Host`: rompe cualquier ejecución no interactiva y, en un `.exe`
  `-noConsole`, cuelga el programa sin que se vea nada.
- Valida en la firma, no dentro del cuerpo:
  `[ValidateSet(...)]`, `[ValidateRange(0,100)]`, `[ValidateNotNullOrEmpty()]`,
  `[ValidatePattern('^HK(LM|CU)\\')]`. Un error de validación es claro y llega antes
  de tocar nada.
- **Booleano = `[switch]`**, no `[bool]`. `-Locked` se lee mejor que `-Locked $true`.
- Muchos parámetros → **splatting**, no continuaciones con backtick:
  ```powershell
  $args = @{ Path = $p; Name = $n; Type = 'DWord' }
  Set-RegistryValue @args
  ```

## 3. Código que CAMBIA el sistema

Esta sección es la que importa para lo que viene: aplicar tweaks de registro, red,
servicios y energía.

### `SupportsShouldProcess` — `-WhatIf` gratis

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(...)

if ($PSCmdlet.ShouldProcess("$Path\$Name", "escribir $Value")) {
    # aquí, y SOLO aquí, se escribe
}
```

Envuelve **cada** escritura. A cambio obtienes `-WhatIf` (enseña lo que haría sin
hacerlo) y `-Confirm`, sin escribir una línea más. En una aplicación que corre elevada
y toca el registro, un modo "simulación" no es un lujo: es cómo se prueba un tweak sin
arriesgar el equipo.

### Idempotencia

Aplicar dos veces debe dar el mismo resultado que aplicar una. Antes de escribir, lee:
si ya vale lo que quieres, **no escribas** y dilo. Menos escrituras al registro, menos
ruido en el log y revertir sigue siendo posible.

### Reversibilidad

Todo cambio necesita su vuelta atrás **capturada antes de tocar**, no deducida
después. Y hay que distinguir dos casos que no son el mismo:

| Estado previo | Revertir es |
| --- | --- |
| El valor existía y valía X | volver a escribir X |
| El valor **no existía** | **borrarlo**, no ponerlo a 0 |

`core/Registry/Reader.ps1` ya distingue `read` de `missing` justo para esto.

### Errores

- Falla **pronto y con contexto**: qué ruta, qué valor, qué se esperaba.
- `try { ... } catch { ... }` solo captura errores **terminantes**. Para un cmdlet:
  `-ErrorAction Stop` dentro del `try`.
- `-ErrorAction SilentlyContinue` silencia el mensaje, **no** el fallo.
- **No uses `throw` para el flujo normal.** Aquí, `core/` devuelve un estado
  (`read` / `missing` / `denied` / `badpath`) y la interfaz lo pinta. Una excepción
  escapando tumbaría la ventana.
- Nada de `catch {}` vacío. Si un fallo no importa, escribe por qué no importa.

## 4. Salida: objetos, no texto

Una función devuelve **datos**; quien la llama decide cómo se ven.

```powershell
# mal: la función decide la presentación y no se puede reutilizar
Write-Host "Leído $Name = $Value"

# bien: datos estructurados
[PSCustomObject]@{ Name = $Name; Value = $Value; State = 'read' }
```

Los cinco flujos y para qué es cada uno:

| Flujo | Para | Notas |
| --- | --- | --- |
| Success (`return`, expresión suelta) | **los datos** | Lo consume quien llama |
| `Write-Verbose` | detalle de diagnóstico | Se activa con `-Verbose` |
| `Write-Warning` | algo raro pero no fatal | |
| `Write-Error` | fallo | Con `-ErrorAction Stop` se vuelve terminante |
| `Write-Host` | **texto para una consola** | En el `.exe` (`-noConsole`) **no se ve**: no lo uses para nada que importe |

Recuerda que **todo lo que no capturas se devuelve**: un `.Add()` sin `| Out-Null`
contamina el valor de retorno (ver `powershell-engineer`).

## 5. Rendimiento y legibilidad

- `+=` sobre arrays es O(n²). Usa `[System.Collections.Generic.List[object]]::new()`.
- Filtra lo antes posible: `Get-X | Where-Object {...}` mejor que traerlo todo y
  descartar al final. Mejor aún, filtra en el origen si el cmdlet lo permite.
- **Nada de alias en código guardado.** `%`, `?`, `gci`, `ls`, `cat` valen en la
  consola; en un `.ps1` se escribe `ForEach-Object`, `Where-Object`,
  `Get-ChildItem`, `Get-Content`. Cambian entre hosts y entre sistemas.
- Nombres de variable descriptivos y en la lengua del archivo. `$categoria`, `$fila`,
  `$hechas` — no `$x`, `$tmp`, `$data2`.
- Una función que no cabe en pantalla probablemente son dos funciones.

## 6. Scripts sueltos (utilidades fuera de la aplicación)

Para un `.ps1` que se ejecuta a mano:

```powershell
#requires -Version 5.1
#requires -RunAsAdministrator      # solo si de verdad hace falta
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

- `#requires` falla **antes** de ejecutar nada, con un mensaje claro.
- `Set-StrictMode` convierte en error usar una variable sin definir o una propiedad
  que no existe — errores que si no se tragan en silencio.
- **Nunca pidas admin "por si acaso".** Si el script funciona sin elevación, que no la
  pida.
- Rutas: `Join-Path` y `$PSScriptRoot`, nunca concatenar con `\`.
- El script debe poder ejecutarse desde cualquier directorio de trabajo.

## 7. Checklist

1. ¿Verbo aprobado y sustantivo singular? ¿El nombre dice si cambia algo?
2. ¿Parámetros tipados y validados en la firma?
3. Si escribe en el sistema: ¿`ShouldProcess`? ¿es idempotente? ¿captura el valor
   previo antes de tocar? ¿distingue "no existía"?
4. ¿Devuelve objetos y no texto? ¿Ningún `Write-Host` para algo que importa?
5. ¿Ningún alias? ¿Ningún `catch {}` vacío?
6. ¿Cabecera de comentario con qué hace y qué no?
7. UTF-8 con BOM y pruebas verdes **en los dos hosts**.
