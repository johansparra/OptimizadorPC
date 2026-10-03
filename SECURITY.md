# Seguridad — Optimizador PC

Documento de referencia para auditoría técnica y de seguridad. Describe el modelo de
amenaza, el contrato de escritura al registro, la superficie de ataque, las invariantes
que las pruebas vigilan y los riesgos aceptados o pendientes.

Última revisión completa: **2026-09-06** (commit base `464ea1c`). Complementa a
`README.md` (arquitectura), `CLAUDE.md` (reglas de trabajo) y
`.claude/skills/security-reviewer/SKILL.md` (guía de revisión de cambios).

**Repaso 2026-09-07** (commit base `bd2f12a`). Se auditaron las funcionalidades
añadidas desde la revisión completa —menús Expandir/Contraer del panel Regedit
(`ui/Components/Shell/ChipMenu.ps1`, `ui/Views/CategoryDetailView.ps1`) y la
preferencia "Formato de hora" (`ui/Engine/TimeFormat.ps1`,
`ui/Data/Preferences/40-TimeFormat.ps1`)— y **no introducen superficie nueva**: cero
escrituras al sistema, cero ejecución dinámica, cero red, y el único dato en disco es
la cadena `'24'`/`'12'` de la preferencia, por `Set-AppSetting` como el resto. PSSA y
Semgrep, ya instalables en la máquina de desarrollo, se ejecutaron (resultados en §9).
Se corrigió la CI de Semgrep (§8, §11 riesgo 4).

---

## 1. Qué es esto y por qué importa

Optimizador PC es un **`.exe` portable de un solo archivo**, compilado con ps2exe, que:

| Propiedad del build | Consecuencia de seguridad |
| --- | --- |
| `-requireAdmin` | **Todo el código corre con privilegios de administrador.** |
| `-noConsole` | El usuario **no ve mensajes**: un fallo o un cambio es silencioso. |
| Portable | Puede acabar en un USB, una descarga o una carpeta escribible por todos. |
| Sin firma Authenticode | SmartScreen lo marca como no confiable al abrirlo. |

Los tres riesgos reales, por gravedad:

1. **Dejar el equipo menos seguro que antes.** El riesgo principal: un "tweak
   recomendado" que apaga UAC, Defender, SmartScreen, el firewall, Windows Update o el
   cifrado. El usuario acepta un optimizador, no una rebaja de seguridad.
2. **Dejar el equipo roto y sin vuelta atrás.** Un cambio elevado sin valor de
   restauración es irreversible para quien no sabe editar el registro.
3. **Ejecutar código ajeno con privilegios de administrador.** Cualquier entrada
   externa (una ruta, un valor, un archivo, una descarga) que acabe ejecutándose.

---

## 2. Superficie de ataque

La aplicación **no habla con la red**, no abre puertos, no carga plugins y no lee
archivos que le pase un tercero. Las únicas entradas externas son:

| Entrada | Origen | Cómo se trata |
| --- | --- | --- |
| `%APPDATA%\OptimizadorPC\settings.json` | Disco, escrito por la propia app | Parseo defensivo: un JSON corrupto o ausente se **ignora** y se arranca con valores por defecto (`ui/Engine/AppSettings.ps1`). Solo guarda preferencias de interfaz (tema, idioma, opciones de vista, formato de hora, carpeta de guardado del log). Un valor desconocido en `TimeFormat` cae al de partida (`Get-AppTimeFormat`); el patrón `.ToString(...)` es un literal de `ui/Engine/TimeFormat.ps1`, nunca la cadena guardada. |
| El **registro de Windows** que se lee | El equipo | Se abre siempre `RegistryView::Registry64`. Un `DWord` llega como `Int32` con signo y se reinterpreta sin signo (`Format-RegistryValue`). `core/` **nunca lanza**: devuelve un estado (`read`/`missing`/`denied`/`badpath`). |
| URLs de referencia (`-Link` de cada ajuste) | **Escritas en el propio repositorio** (`ui/Data/Categories/*.ps1`) | Antes de llegar al shell se validan: tiene que ser una URI absoluta con esquema `http` o `https` (`core/Shell/ExternalLink.ps1`). Cualquier otra cosa se rechaza sin tocar el shell. |
| `-Recommended` / `-Default` de cada clave de registro | **Escritas en el propio repositorio** | Es el contrato de aplicación y de reversión. No proviene de entrada del usuario. |

No hay ningún punto donde una cadena controlable por un tercero se convierta en código:
sin `Invoke-Expression`, sin `[scriptblock]::Create`, sin `Add-Type` con fuente
construida en tiempo de ejecución (los dos `Add-Type`, en
`core/Interop/SystemBackdrop.ps1` y `core/Interop/WorkArea.ps1`, usan una cadena
literal fija y revisada), sin
descargas. Lo vigila `tests/Source/Security.Tests.ps1`.

---

## 3. Escritura al registro — el contrato

La escritura vive en **`core/Registry/Writer.ps1`** (una clave por llamada) y se
dispara desde **`core/Registry/SettingApply.ps1`** (el toggle ON/OFF de un ajuste con
`-Registry`). Nada más escribe en el registro. Hoy hay **un** ajuste con `-Registry`:
`NetworkThrottlingIndex` en la sección *Regedit* — benigno, reversible, en una rama
permitida.

### 3.1 Lista blanca de rutas

`$RegistryWriteAllowlist` en `Writer.ps1`. Una ruta candidata se acepta solo si **es**
uno de estos prefijos o **cuelga** de él (comparación normalizada, sin distinguir
mayúsculas, raíz sin abreviar):

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft
HKEY_CURRENT_USER\Software\Policies\Microsoft
HKEY_CURRENT_USER\Control Panel\Desktop
HKEY_CURRENT_USER\Control Panel\Mouse
HKEY_CURRENT_USER\Software\OptimizadorPC          (rama de las pruebas)
```

No hay denylist: **lo que no está en la lista, no se toca** (estado `blocked`). SAM,
SECURITY, BCD, `...\Services` y todo lo demás quedan fuera por omisión.

**Lista de valores (`$RegistryWriteAllowedValues`, 2026-10-03).** Lo que no se puede
abrir como rama entera entra **valor a valor**: la clave tiene que ser *exactamente*
la declarada —sus subclaves no heredan el permiso— y el nombre del valor, uno de su
lista. Así entran el `Start` de siete servicios concretos (SysMain, DiagTrack, lfsvc,
MapsBroker, CscService, StorSvc, SharedAccess), cuatro valores de
`Tcpip\Parameters` (no `...\Interfaces`), seis de `LanmanServer\Parameters`,
`DisableWpbtExecution` de `Session Manager` (sin abrir `KnownDLLs`, `BootExecute`,
`Environment`), `EnablePrefetcher`, `HibernateEnabled` y los de privacidad del paquete
BF6. `Test-RegistryWriteAllowed` sin `-Name` nunca acepta esta lista.

> **Riesgo conocido [Media].** `HKLM\SOFTWARE\Policies\Microsoft` es un prefijo
> **amplio**: por debajo cuelgan las claves GPO de Windows Defender
> (`...\Windows Defender`), Windows Update (`...\Windows\WindowsUpdate`) y SmartScreen.
> La lista blanca gatea **rutas, no semántica**: hoy no hay ningún ajuste que abuse de
> esto, pero el gate por sí solo no lo impediría. La mitigación es la denylist de
> nombres de valor del §3.4 + la revisión manual de cada ajuste nuevo.
> **Antes de estrechar este prefijo** hay que saber qué claves concretas se querrán
> escribir (política de energía, telemetría, etc.).

### 3.2 Las cinco condiciones de cada escritura

`Writer.ps1` ya las cumple. Al añadir un ajuste con `-Registry` o ampliar la lista
blanca, comprueba que se siguen cumpliendo:

1. **Valor de restauración documentado.** El `Default` de cada clave: `OFF` lo escribe.
   Un ajuste sin `Default` real no se puede revertir → no se aplica.
2. **Distinguir "no existía" de "valía otra cosa".** `Get-RegistryStoredValue`
   distingue `missing` de `read` y lo guarda en el snapshot (`Existed`).
   *Pendiente:* revertir un valor que **no existía** debería borrarlo, no escribir el
   `Default` — hoy escribe el `Default`.
3. **Ruta validada** contra `$RegistryWriteAllowlist` (`Test-RegistryWriteAllowed`),
   nunca concatenada con entrada libre. `RegistryView::Registry64` explícito.
4. **Tipo declarado.** `ConvertTo-RegistryData` respeta el `Type` (`DWord`/`QWord`/
   `Binary`/`String`/`ExpandString`). Un tipo real distinto al pedido → `typemismatch`,
   no se pisa. `MultiString` → `unsupported`, no se escribe.
5. **Nada de ACLs ni propietarios.** Clave protegida → `denied`, se enseña, no se
   fuerza.

Además, `Writer.ps1` hace **copia del valor previo** (`$RegistrySnapshots`, en memoria),
**verificación por relectura** tras escribir (si no cuadra → `denied`, fallo visible en
el log), y soporta **`-WhatIf`** (`SupportsShouldProcess`).

### 3.3 Estados que devuelve `Write-RegistryValue`

| Estado | Qué pasó |
| --- | --- |
| `written` | Escrito y confirmado por relectura. |
| `nochange` | Ya estaba en el valor destino; no se reescribe. |
| `blocked` | La ruta no está en la lista blanca. |
| `badpath` | La raíz de la ruta no se reconoce. |
| `typefail` | El texto declarado no cuadra con el tipo. |
| `unsupported` | Tipo que aún no se sabe escribir (`MultiString`). |
| `typemismatch` | El valor ya existe con OTRO tipo; no se pisa en silencio. |
| `denied` | Sin permisos, o la relectura posterior no cuadra. |
| `disarmed` | La escritura está desarmada (solo en las pruebas). |

Cada intento deja en el registro de actividad (`core/Diagnostics/Log.ps1`) tres bloques
auditables: `write attempt` (con validación previa: clave existe, valor existe, tipo
real, si el proceso está elevado), `post write` (esperado vs. leído) y el resultado
(`applied`/`restored`/`write failed` con motivo accionable, excepción, HResult y traza).

### 3.4 Ajustes que degradan la seguridad del equipo

Un ajuste que baja la postura de seguridad **no está prohibido**, pero:

- no puede llamarse `Recommended` sin más,
- su descripción tiene que decir **qué protección se pierde**,
- no puede venir activo por defecto,
- y **debe llevar `AllowsSecurityTradeoff = $true`** en la declaración del ajuste.

`tests/Source/Security.Tests.ps1` recorre todos los `-Registry` de
`ui/Data/Categories/*` y **falla la suite** si alguno apunta a uno de estos nombres de
valor sin esa marca:

```text
ConsentPromptBehaviorAdmin  ConsentPromptBehaviorUser  PromptOnSecureDesktop
EnableLUA  FilterAdministratorToken  LocalAccountTokenFilterPolicy
DisableAntiSpyware  DisableAntiVirus  DisableRealtimeMonitoring
DisableBehaviorMonitoring  DisableOnAccessProtection
SmartScreenEnabled  EnableSmartScreen  ShellSmartScreenLevel
PreventDeviceEncryption  NoAutoUpdate  NoAutoRebootWithLoggedOnUsers
EnableFirewall  DoNotAllowExceptions
```

La lista es la de `tests/Source/Security.Tests.ps1` (`$peligrosos`); si crece, crece en
los dos sitios.

Estado actual: **cero ajustes** tocan esta lista. Los ajustes de UAC, BitLocker y
Automatic Maintenance que existieron en versiones anteriores fueron retirados.

---

## 4. Reversibilidad y rollback

- **Contrato duro:** el `Default` de cada clave. `OFF` (o el botón de restaurar) lo
  escribe. Se compara por valor, no por escritura (`0x0000000A` = `10` = `-1` según el
  tipo).
- **Copia adicional:** `$RegistrySnapshots` en `Writer.ps1` guarda el valor y el tipo
  **anteriores** a cada escritura (aunque estuvieran personalizados) y si la clave
  **existía**. Es el "deshacer" real.

> **Riesgo conocido [Media].** `$RegistrySnapshots` vive **solo en memoria** y se pierde
> al cerrar la aplicación. **No hay "deshacer" en la UI** ni exportación del snapshot.
> **No se avisa** al usuario de crear un punto de restauración ni de exportar la rama
> (`reg export`) antes de la primera escritura elevada. Pendientes, en este orden:
> (1) persistir el snapshot en `%APPDATA%`, (2) botón "deshacer último cambio",
> (3) aviso de punto de restauración.

---

## 5. Ejecución de código — prohibiciones duras

Corriendo como administrador, **nada de esto entra** en `ui/` ni en `core/`:

| Prohibido | Por qué |
| --- | --- |
| `Invoke-Expression`, `iex`, `& ([scriptblock]::Create($x))` | Ejecuta cadena como código. |
| `Add-Type` con fuente construida en tiempo de ejecución | Lo mismo, compilado. (Los dos `Add-Type` del proyecto usan una cadena literal fija.) |
| `Invoke-WebRequest`, `Invoke-RestMethod`, `DownloadString`, `DownloadFile`, `Start-BitsTransfer` | La aplicación no habla con la red. |
| `Start-Process` con la ruta sin comillas | *Unquoted path* → ejecutable equivocado. |
| Ejecutar algo desde una carpeta escribible por todos | `C:\ProgramData`, `%TEMP%`, la carpeta del `.exe` si está en Descargas. |
| `-ExecutionPolicy Bypass` dentro del producto | Vale para desarrollo y para el `README`; no como algo que la app haga a espaldas del usuario. |

`tests/Source/Security.Tests.ps1` falla la suite si aparece cualquiera de las
primeras tres familias en `ui/` o `core/`.

---

## 6. Enlaces externos

`core/Shell/ExternalLink.ps1` abre una URL en el navegador por defecto vía
`Start-Process` (ShellExecute). Desde un proceso elevado, ShellExecute abriría
cualquier cosa (otro `.exe`, un `.bat`, un archivo local), así que:

- `$ExternalLinkSchemes` es **exactamente** `http`, `https`.
- `Test-ExternalLinkAllowed` exige URI **absoluta** y esquema en esa lista. Es una
  función pura (no toca el shell) y se prueba entera.
- Un esquema no permitido **ni siquiera llega** a `Start-Process`.
- Nada de aquí lanza: si algo falla, devuelve `$false` y la interfaz sigue igual.

`tests/Source/Security.Tests.ps1` falla si esa lista deja de ser `{http, https}`.

---

## 7. Datos del usuario y registro de actividad

- `settings.json` en `%APPDATA%\OptimizadorPC\` (no junto al `.exe`, que puede estar en
  una carpeta sin permisos de escritura). Solo preferencias de interfaz. **Nada
  sensible**: ni credenciales, ni rutas de otros usuarios, ni identificadores de
  máquina.
- El **registro de actividad** (`core/Diagnostics/Log.ps1`) guarda las rutas y valores
  del registro leídos y escritos (viejo → nuevo). Se puede **exportar a un archivo** que
  elige el usuario ("Save to file" del cajón del log). Es divulgación de configuración
  del sistema **por acción propia del usuario** — aceptable. No sale a la red por sí
  solo. Hoy solo contiene claves de optimización, nada sensible.
- **Sin telemetría, sin red saliente.** Si algún día aparece cualquiera de las dos, es
  una decisión de producto con consentimiento explícito.

---

## 8. Cadena de suministro y build

`build.ps1` empaqueta todo el proyecto en `build/_combined.ps1` y lo compila con
ps2exe. Puntos de seguridad:

- **ps2exe fijado** (desde 2026-09): `-RequiredVersion 1.0.18` + `-Repository PSGallery`
  en el `Install-Module`, y `Import-Module -RequiredVersion`. Sin esto, cada
  compilación podría traer código distinto del compilador, o podría ganar otro
  repositorio de PowerShell registrado con prioridad. Subir de versión es un cambio
  consciente: se edita el número, se recompila y se pasan las pruebas.
- **El `.exe` no está firmado.** Un binario sin Authenticode que pide UAC es justo lo
  que Windows enseña a no ejecutar. *Bloquea distribuir a terceros.* Mitigación:
  firmar con un certificado de firma de código (idealmente EV, para reputación
  inmediata en SmartScreen).
- **CI (`.github/workflows/semgrep.yml`)** — corregido el 2026-09-07:
  - `actions/checkout` **fijado por SHA** (`d23441a…` = v6.1.0). Una etiqueta la puede
    repuntar el dueño de la acción en silencio; era el único hallazgo de Semgrep
    (`github-actions-mutable-action-tag`).
  - **Quitado el filtro `paths`** del disparador `push`: ahora cada push a `main`/
    `master` ejecuta Semgrep, no solo los que tocan el propio workflow. Antes, como el
    repo commitea directo a `master`, la cobertura efectiva era el `schedule` nocturno
    + `workflow_dispatch`.
  - *Pendiente:* la imagen `container: semgrep/semgrep` sigue sin fijar por tag/digest
    (es el analizador, no una dependencia del producto; `latest` suele ser lo deseado)
    y no se sube SARIF a *code scanning* (los hallazgos solo salen en los logs de
    Actions).

---

## 9. Análisis estático — estado y recomendaciones

### PSScriptAnalyzer

- **Configurado**: `PSScriptAnalyzerSettings.psd1` en la raíz (auto-descubierto por
  `Invoke-ScriptAnalyzer -Path . -Recurse`). Solo reglas por defecto; cinco exclusiones,
  cada una con su motivo escrito (verbos de constructores de WPF, parámetro `$e` de los
  handlers, posicionales de la casa, `Write-Host` solo en runner/build, plurales de
  nombres públicos).
- **Cómo correrlo**: `Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary`
- **Instalado en la máquina de desarrollo** (v1.25.0, 2026-09-07); antes había que
  esperar a la CI.
- **Estado 2026-09-07**: **0 errores, 2 avisos**, los dos falsos positivos de la misma
  familia — `PSUseDeclaredVarsMoreThanAssignments` sobre `$CategoryIndex`
  (`ui/Index/CategoryIndex.ps1`) y `$ScriptRoot` (`build/_combined.ps1`, generado): la
  variable se consume vía dot-source al mismo ámbito, algo que PSSA no ve archivo por
  archivo. Mismo patrón en el resto de `ui/Index/` y en `$GradientTokens`.
- **Segundo pase estricto solo sobre `core/`** (sin la exclusión de
  `PSUseShouldProcessForStateChangingFunctions`), ejecutado el 2026-09-07:
  `Invoke-ScriptAnalyzer -Path ./core -Recurse -Severity Error,Warning -ExcludeRule PSReviewUnusedParameter,PSAvoidUsingPositionalParameters,PSUseSingularNouns,PSAvoidUsingWriteHost`
  → **6 avisos, los 6 por el verbo del nombre, ninguno real**: `Set-WindowBackdrop`
  (llama a DWM sobre un handle, sin estado persistente), `Update-CategoryRegistryState`
  y `Update-SettingStatus` (solo **leen** y calculan), `New-RegistryResult` /
  `New-RegistryWriteResult` (fábricas de `PSCustomObject`), `Set-RegistryWriteArmed`
  (booleano en memoria del arnés). **La única función de `core/` que muta el sistema —
  `Write-RegistryValue` — ya lleva `[CmdletBinding(SupportsShouldProcess)]` +
  `$PSCmdlet.ShouldProcess`**, igual que `Set-SettingOptimization`. El "hueco residual"
  que menciona `PSScriptAnalyzerSettings.psd1` (una función nueva de `core/` que mutara
  el sistema sin adoptar `ShouldProcess`) queda **verificado: hoy no existe**.

### Semgrep

- **Configurado**: `.github/workflows/semgrep.yml` corre `semgrep ci` en un contenedor,
  con `SEMGREP_APP_TOKEN`. **No hay archivo de reglas en el repo**: depende de la
  config de la plataforma / registro de Semgrep.
- **Instalado en la máquina de desarrollo** (v1.176.1, 2026-09-07). Ejecutado el
  2026-09-07:
  `semgrep scan --config p/security-audit --config p/secrets --config p/github-actions --exclude build --exclude tests`
  (59 reglas, 180 archivos). `p/powershell` **ya no existe** en el registro (HTTP 404);
  la cobertura de PowerShell de Semgrep es de todos modos limitada —el guardarraíl real
  para `ui/`/`core/` es `tests/Source/Security.Tests.ps1` + PSScriptAnalyzer—.
- **Un hallazgo, ya corregido**: `actions/checkout@v6` era una etiqueta mutable
  (`github-actions-mutable-action-tag`). Fijado por SHA (§8). Repetido el escaneo:
  **0 hallazgos**.
- **Mejora pendiente**: subir SARIF a *GitHub code scanning* para que los hallazgos
  aparezcan en la pestaña Security y no solo en los logs de Actions; versionar los
  `--config` en el propio workflow para que la config no dependa solo de la plataforma.

### Por qué Snyk no encaja aquí

Snyk brilla escaneando **manifiestos de dependencias** (`package.json`,
`requirements.txt`, `pom.xml`…) y contenedores. Este proyecto **no tiene ninguno**: es
PowerShell puro sobre .NET Framework del sistema, sin paquetes de terceros en `ui/` ni
`core/`, y el único módulo externo (ps2exe) es una herramienta de build, ya fijada por
versión. Snyk Code (SAST) sí funcionaría, pero solaparía con Semgrep + PSScriptAnalyzer
sin añadir cobertura de PowerShell mejor que la de esos dos. **Alternativas que sí
aportan**, por orden de valor:

| Herramienta | Aporta | Límite |
| --- | --- | --- |
| **PSScriptAnalyzer** en CI (Windows runner) | Reglas específicas de PowerShell, gratis, sin token | Ya configurado; falta el workflow |
| **Semgrep** con rulesets fijados + SARIF | Patrones de seguridad e inyección, dedupe entre ramas | Ya en CI; falta afinar disparador y config |
| **Gitleaks** / `trufflehog` en pre-commit y CI | Secretos filtrados en el historial | Complementa a `p/secrets` |
| **Firma Authenticode del `.exe`** + hash publicado | Integridad del entregable | Necesita certificado |
| `System.Windows.Automation` (prueba de humo del `.exe`) | Que el binario elevado arranca y no rompe | Coste de mantenimiento |

---

## 10. Invariantes verificadas por pruebas

`tests/Source/Security.Tests.ps1` (nuevo en esta auditoría) fija en la suite lo que
antes solo vivía en prosa. **Falla la suite** si:

| Invariante | Riesgo que cubre |
| --- | --- |
| Toda ruta de `-Registry` en `ui/Data/Categories/*` pasa `Test-RegistryWriteAllowed` | Una ruta mal escrita o fuera de la lista blanca acabaría en `blocked` en runtime sin que nadie se entere. |
| Ningún `.ps1` de `ui/` o `core/` usa `Invoke-Expression`, `iex`, `[scriptblock]::Create`, `Invoke-WebRequest`, `Invoke-RestMethod`, `DownloadString`, `DownloadFile`, `Start-BitsTransfer` | Ejecución de código ajeno / llamada de red desde proceso elevado. |
| Ningún `-Registry` apunta a un nombre de valor de la denylist del §3.4 sin `AllowsSecurityTradeoff = $true` en el ajuste | Un "tweak recomendado" que apaga Defender/UAC/Update sin declararlo. |
| `core/Shell/ExternalLink.ps1` `$ExternalLinkSchemes` es exactamente `http`, `https` | Un proceso elevado abriendo `file:` / `ms-settings:` / un `.exe` local. |

Cobertura de `core/` relacionada (ya existente):
`tests/Core/RegistryWriter.Tests.ps1` (lista blanca, tipado, snapshot, relectura,
`type mismatch`, `-WhatIf`, nunca lanza) y `tests/Core/SettingApply.Tests.ps1`
(ON/OFF, recálculo de estado, rastro en el log).

---

## 11. Riesgos aceptados y pendientes

| # | Riesgo | Sev. | Estado |
| - | --- | --- | --- |
| 1 | Lista blanca de escritura amplia (`SOFTWARE\Policies\Microsoft` alcanza Defender/Update/SmartScreen) | Media | **Mitigado en parte** por la denylist de nombres de valor (§3.4) + revisión manual. Estrechar el prefijo requiere saber qué claves se querrán escribir. |
| 2 | Rollback solo en memoria; sin "deshacer" en UI; sin aviso de punto de restauración | Media | **Aceptado temporalmente** por decisión del propietario. Pendiente: persistir snapshot → botón deshacer → aviso de restauración. |
| 3 | `.exe` sin firma Authenticode | Media | **Aceptado** mientras no se distribuya a terceros. Bloquea la distribución. |
| 4 | CI de Semgrep incompleta | Baja | **Corregido en parte (2026-09-07):** `actions/checkout` fijado por SHA y quitado el filtro `paths` del `push` (cada push a master pasa por Semgrep). **Queda:** `container: semgrep/semgrep` sin fijar (es el analizador, no una dependencia), `--config` no versionados en el repo, sin subida de SARIF a *code scanning*. |
| 5 | Sin CI de PSScriptAnalyzer ni de la suite de pruebas (solo Semgrep) | Baja | **Documentado, no corregido.** Recomendación: un workflow en Windows runner que corra `tests/Run-Tests.ps1 -BothHosts` y `Invoke-ScriptAnalyzer`. Ambas herramientas ya están instaladas y se corren a mano (§9); falta el workflow. |
| 6 | `Add-Type` en `SystemBackdrop.ps1` y `WorkArea.ps1` compila una cadena de C# | Info | **Aceptado.** Las cadenas son literales fijos y revisados; no se construyen en runtime. `WorkArea.ps1` (2026-10-03) subclasifica la ventana propia con `SetWindowLongPtr` solo para corregir `WM_GETMINMAXINFO`; no toca otras ventanas ni otros procesos. |
| 7 | Contadores de las píldoras de la lista son fijos, no calculados | Info | Sin impacto de seguridad; cosmético. Ya documentado en `README.md`. |

---

## 12. Cómo reportar una vulnerabilidad

Es un proyecto personal, repositorio público en GitHub
(`github.com/johansparra/OptimizadorPC`). Para reportar un problema de seguridad, abre
un *issue* marcándolo como sensible o usa el contacto del perfil del repositorio.
Describe la **clase** de problema y un escenario de fallo con valores reales; no hace
falta un exploit funcional.
