---
name: security-reviewer
description: Revisor de seguridad de una aplicación que corre ELEVADA y va a escribir en el registro de Windows. Úsalo antes de mezclar cambios, al implementar cualquier escritura al sistema (registro, servicios, tareas programadas, directivas) y al revisar tweaks propuestos. Cubre el modelo de amenaza del .exe con -requireAdmin, ejecución de código, reversibilidad, ajustes que degradan la seguridad del equipo y cadena de suministro del build. Trigger words - seguridad, security, revisar, auditar, elevado, admin, UAC, permisos, registro, escribir, aplicar tweak, riesgo, reversible.
---

# Revisión de seguridad — Optimizador PC

## 1. Modelo de amenaza

Esto no es una web ni un servicio: es un **binario portable que el usuario ejecuta
como administrador en su propia máquina**.

```
-requireAdmin  -> todo el código corre con privilegios completos
-noConsole     -> el usuario NO ve mensajes; un fallo es silencioso
portable       -> puede acabar en un USB, una descarga o un pendrive ajeno
```

De ahí salen los tres riesgos reales, por orden de gravedad:

1. **Dejar el equipo menos seguro que antes.** Es el riesgo principal y el más fácil
   de colar: un "tweak recomendado" que apaga UAC, Defender, SmartScreen, el firewall
   o el cifrado. El usuario acepta un optimizador, no una rebaja de seguridad.
2. **Dejar el equipo roto y sin vuelta atrás.** Un cambio elevado sin valor de
   restauración es irreversible para quien no sabe editar el registro.
3. **Ejecutar código que no es nuestro con privilegios de administrador.** Cualquier
   entrada externa (una ruta, un valor, un archivo, una descarga) que acabe
   ejecutándose.

**El estado hoy:** `core/` **lee y escribe** el registro. La escritura vive en
`core/Registry/Writer.ps1` (una clave) y `core/Registry/SettingApply.ps1` (el toggle
ON/OFF de un ajuste). Solo hay **un** ajuste con `-Registry` — `NetworkThrottlingIndex`
en *Regedit*, benigno y reversible. La revisión completa que pedía "el primer
`SetValue`" ya se hizo; ahora el objeto de revisión es **cada ampliación de la lista
blanca de rutas y cada ajuste nuevo con `-Registry`**. `SECURITY.md` en la raíz del
repo tiene el contrato entero.

## 2. Ejecución de código — prohibiciones duras

Corriendo como administrador, nada de esto entra:

| Prohibido | Por qué |
| --- | --- |
| `Invoke-Expression`, `iex`, `& ([scriptblock]::Create($x))` | Ejecuta cadena como código. Con admin, es ejecución arbitraria. |
| `Add-Type` con código fuente construido en tiempo de ejecución | Lo mismo, compilado. |
| `DownloadString`, `DownloadFile`, `Invoke-WebRequest` a un script | La aplicación no habla con la red. Si algún día lo hace, es una decisión de producto, no un detalle de implementación. |
| `Start-Process` con la ruta sin comillas | Ruta sin comillas con espacios = *unquoted path*, ejecutable equivocado. |
| Ejecutar algo desde una carpeta escribible por todos | `C:\ProgramData`, `%TEMP%`, la carpeta del propio `.exe` si está en Descargas. |
| `-ExecutionPolicy Bypass` dentro del producto | Vale para desarrollo y para el `README`; no como algo que la aplicación haga a espaldas del usuario. |

```bash
# Barrido rápido
grep -rniE "invoke-expression|\biex\b|downloadstring|downloadfile|start-process" \
  --include=*.ps1 . | grep -v build/
```

## 3. Escribir en el registro — las condiciones

Cada cambio necesita **las cinco**. `core/Registry/Writer.ps1` ya las cumple; al
revisar un ajuste nuevo o una rama nueva de la lista blanca, comprueba que se siguen
cumpliendo:

1. **Valor de restauración documentado.** El `Default` declarado en
   `ui/Data/Categories/*.ps1` es ese contrato: `OFF` escribe ese valor. Un ajuste sin
   `Default` real no se puede revertir: no se aplica. `Writer.ps1` guarda además el
   valor previo en `$RegistrySnapshots` (**solo en memoria** — pendiente persistirlo).
2. **Distinguir "no existía" de "valía otra cosa".** `Writer.ps1` lo hace vía
   `Get-RegistryStoredValue` (`missing` vs `read`) y lo apunta en el snapshot
   (`Existed`). *Pendiente:* revertir un valor que no existía debería **borrarlo**, no
   escribir el `Default` — hoy escribe el `Default`.
3. **Ruta validada contra `$RegistryWriteAllowlist`** (`Test-RegistryWriteAllowed`),
   nunca concatenada con entrada libre. Se abre siempre `RegistryView::Registry64`.
   Fuera de la lista → estado `blocked`, no se escribe. **Ampliar esa lista es una
   decisión de seguridad**: `HKLM\SOFTWARE\Policies\Microsoft` (ya dentro) alcanza las
   claves GPO de Defender, Update y SmartScreen.
4. **Escribir el tipo declarado.** `ConvertTo-RegistryData` respeta el `Type`; un tipo
   real distinto al pedido → estado `typemismatch`, no se pisa. `MultiString` no se
   sabe escribir todavía (`unsupported`).
5. **Nada de tocar ACLs ni propietarios.** Clave protegida → `denied`, se enseña, no
   se fuerza. Cambiar el propietario de una clave del sistema es un agujero permanente.

**Preferir `HKCU` a `HKLM` siempre que exista la variante.** Afecta solo al usuario,
no necesita privilegios y el daño potencial es mucho menor.

**Pendiente (no implementado):** antes de la primera escritura elevada de una sesión,
recomendar al usuario dos redes de seguridad — exportar la rama afectada
(`reg export`) y un punto de restauración — y exponer un "deshacer" en la UI.

## 4. Ajustes que degradan la seguridad del equipo

**Esta es la revisión que más importa aquí.** Un ajuste que baja la postura de
seguridad no está prohibido, pero:

- **no puede llamarse "Recommended"** sin más,
- su descripción tiene que decir **qué protección se pierde**,
- y no puede estar activo por defecto.

Revisa `ui/Data/Categories/*.ps1` contra esta lista. Todo lo que toque:

`ConsentPromptBehaviorAdmin` · `PromptOnSecureDesktop` · `EnableLUA` ·
`LocalAccountTokenFilterPolicy` · Windows Defender / `DisableAntiSpyware` /
`DisableRealtimeMonitoring` / exclusiones · SmartScreen (`SmartScreenEnabled`,
`EnableSmartScreen`) · `PreventDeviceEncryption` / BitLocker · firewall ·
Windows Update / `NoAutoUpdate` · ejecución de macros · directivas de contraseña ·
UAC remoto

**Estado vivo en este repositorio** (verificado leyendo `ui/Data/Categories/Regedit.ps1`):

| Ajuste | Qué hace | Riesgo |
| --- | --- | --- |
| *Network Throttling Mechanism* (`NetworkThrottlingIndex = 0xFFFFFFFF`) | Quita el límite de 10 paquetes/ciclo que Windows impone mientras hay audio/vídeo activo. | Ninguno de seguridad. Reversible (`Default = 0x0000000A`). Rama permitida: `…\Multimedia\SystemProfile`. |

Los ajustes de UAC, BitLocker y Automatic Maintenance que antes vivían aquí **fueron
retirados**. Hoy no hay ningún ajuste que degrade la seguridad.

**Control automático:** `tests/Source/Security.Tests.ps1` recorre todos los `-Registry`
de `ui/Data/Categories/*` y **falla la suite** si alguno apunta a un nombre de valor de
la denylist de arriba sin llevar `AllowsSecurityTradeoff = $true` en el ajuste. Esa
marca obliga a una decisión explícita y revisable; no la pongas para "callar el test".

Al revisar un tweak nuevo, comprueba siempre **el valor numérico**, no el nombre del
ajuste. El nombre lo escribimos nosotros; el número es lo que ejecuta Windows.

## 5. Datos del usuario

- `settings.json` vive en `%APPDATA%\OptimizadorPC\`: correcto (no junto al `.exe`,
  que puede estar en una carpeta sin permisos).
- **No debe guardar nada sensible.** Preferencias de interfaz, nada más. Ni rutas de
  otros usuarios, ni credenciales, ni identificadores de máquina.
- El **registro de actividad** (`core/Diagnostics/Log.ps1`) guarda rutas y valores del
  registro del equipo (y ahora también las escrituras: valor viejo → valor nuevo). Ya
  se puede **exportar a un archivo** que elige el usuario ("Save to file" del cajón del
  log). Es divulgación de configuración del sistema **por acción propia del usuario** —
  aceptable, pero: no debe salir a la red por sí solo, y si algún día hay "enviar
  informe", revisa qué se manda. Hoy solo son claves de optimización, nada sensible.
- Sin telemetría, sin red saliente. Si aparece cualquiera de las dos, es una decisión
  de producto con consentimiento explícito, no un añadido silencioso.

## 6. Cadena de suministro

`build.ps1` instala su compilador desde internet. Desde 2026-09 va **fijado**:

```powershell
$Ps2ExeVersion = '1.0.18'
Install-Module -Name ps2exe -RequiredVersion $Ps2ExeVersion -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
Import-Module ps2exe -RequiredVersion $Ps2ExeVersion
```

Al revisar: que `-RequiredVersion` y `-Repository PSGallery` sigan ahí (sin ellos, cada
compilación podría traer código distinto o ganar otro repositorio registrado), y que
subir de versión sea un cambio consciente con recompilación y prueba. `-Force
-AllowClobber` sobrescribe sin preguntar: aceptable para un build local.

**Sin resolver:** el `.exe` **no está firmado** (Authenticode). Un binario sin firma
que pide UAC es justo lo que Windows enseña a no ejecutar. Bloquea distribuir a
terceros hasta que haya firma. El contenedor `semgrep/semgrep` y `actions/checkout` de
la CI van sin fijar por digest — mismo tipo de riesgo, menor impacto.

## 7. Cómo revisar y cómo reportar

Revisión de un diff, en este orden:

1. ¿Aparece alguna escritura al sistema nueva? (`SetValue`, `Set-Service`,
   `New-ItemProperty`, `schtasks`, `bcdedit`, `netsh`) → revisión completa de §3.
2. ¿Algún ajuste toca la lista de §4? → comprueba el número y la etiqueta.
3. ¿Entra código desde fuera? → §2.
4. ¿Algo escapa de `core/` como excepción? Con `-noConsole` eso es una ventana que se
   cierra sin explicación.
5. ¿Se guarda algo nuevo en disco? → §5.

Reporta cada hallazgo así, y **ordénalos por gravedad real** (ejemplo ilustrativo, no
es un caso vivo):

```
[Alta] ui/Data/Categories/Ejemplo.ps1:53 — ConsentPromptBehaviorAdmin Recommended = 0
Qué pasa: al aplicar el ajuste, cualquier proceso que pida elevación la obtiene sin
que el usuario vea el aviso. UAC deja de ser una barrera.
Arreglo: usar 5 (por defecto) o 2 como recomendado, describir la pérdida, y marcar
AllowsSecurityTradeoff = $true para que pase Security.Tests.ps1 de forma explícita.
```

Sé concreto y sin dramatismo: un escenario de fallo con valores reales convence; una
categoría genérica de riesgo, no. Y **no inventes hallazgos**: si el diff está limpio,
dilo en una línea.
