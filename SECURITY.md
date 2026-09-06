# Seguridad — Optimizador PC

Documento de referencia para auditoría técnica y de seguridad. Describe el modelo de
amenaza, el contrato de escritura al registro, la superficie de ataque, las invariantes
que las pruebas vigilan y los riesgos aceptados o pendientes.

Última revisión completa: **2026-09-06** (commit base `464ea1c` + trabajo de esta
auditoría). Complementa a `README.md` (arquitectura), `CLAUDE.md` (reglas de trabajo) y
`.claude/skills/security-reviewer/SKILL.md` (guía de revisión de cambios).

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
| `%APPDATA%\OptimizadorPC\settings.json` | Disco, escrito por la propia app | Parseo defensivo: un JSON corrupto o ausente se **ignora** y se arranca con valores por defecto (`ui/Engine/AppSettings.ps1`). Solo guarda preferencias de interfaz (tema, idioma, opciones de vista, carpeta de guardado del log). |
| El **registro de Windows** que se lee | El equipo | Se abre siempre `RegistryView::Registry64`. Un `DWord` llega como `Int32` con signo y se reinterpreta sin signo (`Format-RegistryValue`). `core/` **nunca lanza**: devuelve un estado (`read`/`missing`/`denied`/`badpath`). |
| URLs de referencia (`-Link` de cada ajuste) | **Escritas en el propio repositorio** (`ui/Data/Categories/*.ps1`) | Antes de llegar al shell se validan: tiene que ser una URI absoluta con esquema `http` o `https` (`core/Shell/ExternalLink.ps1`). Cualquier otra cosa se rechaza sin tocar el shell. |
| `-Recommended` / `-Default` de cada clave de registro | **Escritas en el propio repositorio** | Es el contrato de aplicación y de reversión. No proviene de entrada del usuario. |

No hay ningún punto donde una cadena controlable por un tercero se convierta en código:
sin `Invoke-Expression`, sin `[scriptblock]::Create`, sin `Add-Type` con fuente
construida en tiempo de ejecución (el único `Add-Type`, en
`core/Interop/SystemBackdrop.ps1`, usa una cadena literal fija y revisada), sin
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
| `Add-Type` con fuente construida en tiempo de ejecución | Lo mismo, compilado. (El único `Add-Type` del proyecto usa una cadena literal fija.) |
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
- **CI (`.github/workflows/semgrep.yml`)**: la imagen `semgrep/semgrep` y
  `actions/checkout` van sin fijar por digest — mismo tipo de riesgo, menor impacto.
  Además el disparador `push` tiene un filtro `paths: [.github/workflows/semgrep.yml]`,
  así que **un push que cambia código no ejecuta Semgrep** (solo lo hacen
  `pull_request`, el `schedule` nocturno y `workflow_dispatch`). Como el repo commitea
  directo a `master`, la cobertura efectiva de Semgrep es nocturna + manual. *No se ha
  tocado la CI en esta auditoría por decisión del propietario; queda como recomendación
  (§11).*

---

## 9. Análisis estático — estado y recomendaciones

### PSScriptAnalyzer

- **Configurado**: `PSScriptAnalyzerSettings.psd1` en la raíz (auto-descubierto por
  `Invoke-ScriptAnalyzer -Path . -Recurse`). Solo reglas por defecto; cinco exclusiones,
  cada una con su motivo escrito (verbos de constructores de WPF, parámetro `$e` de los
  handlers, posicionales de la casa, `Write-Host` solo en runner/build, plurales de
  nombres públicos).
- **Cómo correrlo**: `Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary`
- **Estado 2026-09-06**: **0 errores, 1 aviso**. El aviso
  (`PSUseDeclaredVarsMoreThanAssignments` sobre `$CategoryIndex` en
  `ui/Index/CategoryIndex.ps1`) es un **falso positivo**: la variable se consume en
  `ui/Engine/CategoryRegistry.ps1` vía dot-source al mismo ámbito, algo que PSSA no ve
  al analizar archivo por archivo. Mismo patrón en los otros archivos de `ui/Index/` y
  en `$GradientTokens`.
- **Pendiente sugerido**: un segundo pase más estricto **solo sobre `core/`**, sin la
  exclusión de `PSUseShouldProcessForStateChangingFunctions`, para que una función
  nueva de `core/` que cambie estado y no adopte `ShouldProcess` salte.

### Semgrep

- **Configurado**: `.github/workflows/semgrep.yml` corre `semgrep ci` en un contenedor,
  con `SEMGREP_APP_TOKEN`. **No hay archivo de reglas en el repo**: depende de la
  config de la plataforma / registro de Semgrep.
- **No se puede ejecutar localmente** (semgrep no está instalado en la máquina de
  desarrollo). Los hallazgos salen del contenedor de CI.
- **Rulesets recomendados** para este proyecto (añadir como `--config` en el workflow o
  en un `semgrep.yml` versionado, y así queda fijado en el repo):
  `p/powershell`, `p/security-audit`, `p/secrets`, `p/github-actions`.
- **Mejoras sugeridas** (§11): quitar el filtro `paths` del disparador `push`; subir
  SARIF a *GitHub code scanning* para que los hallazgos aparezcan en la pestaña
  Security y no solo en los logs de Actions.

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
| 4 | CI de Semgrep: disparador `push` filtrado a `paths`, imagen y `checkout` sin digest, sin config de reglas versionada, sin SARIF | Baja | **Documentado, no corregido** (decisión del propietario). Recomendación: quitar `paths`, fijar por digest, versionar `semgrep.yml` con `p/powershell p/security-audit p/secrets p/github-actions`, subir SARIF. |
| 5 | Sin CI de PSScriptAnalyzer ni de la suite de pruebas (solo Semgrep) | Baja | **Documentado, no corregido.** Recomendación: un workflow en Windows runner que corra `tests/Run-Tests.ps1` y `Invoke-ScriptAnalyzer`. |
| 6 | `Add-Type` en `SystemBackdrop.ps1` compila una cadena de C# | Info | **Aceptado.** La cadena es un literal fijo y revisado; no se construye en runtime. |
| 7 | Contadores de las píldoras de la lista son fijos, no calculados | Info | Sin impacto de seguridad; cosmético. Ya documentado en `README.md`. |

---

## 12. Cómo reportar una vulnerabilidad

Es un proyecto personal, repositorio público en GitHub
(`github.com/johansparra/OptimizadorPC`). Para reportar un problema de seguridad, abre
un *issue* marcándolo como sensible o usa el contacto del perfil del repositorio.
Describe la **clase** de problema y un escenario de fallo con valores reales; no hace
falta un exploit funcional.
