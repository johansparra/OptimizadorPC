# Pruebas

```powershell
# Desde OptimizadorPC\
pwsh -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1 -BothHosts   # los DOS hosts, en paralelo
powershell -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1         # solo 5.1, para acotar
```

**Pásalas en los dos hosts.** El `.exe` corre sobre 5.1 con todo en ámbito global y
`main.ps1` sobre pwsh 7 en ámbito de script: hay fallos que solo salen en uno de los
dos (regla 8 de `CLAUDE.md`). Devuelve 0 si todo pasa y 1 si algo falla.

La CI (`.github/workflows/ci.yml`) las pasa en cada push y pull request, un runner
`windows-latest` por host, y en otro compila el `.exe` y le pasa la prueba de humo
elevada (`Smoke/`, más abajo). Ese runner es un **Windows Server**: lo que dependa de la
edición del sistema tiene que valer también ahí (ver `Core/SystemInfo.Tests.ps1`).

```powershell
.\tests\Run-Tests.ps1 -Timing                 # al final, los 10 archivos más lentos
.\tests\Run-Tests.ps1 -File 'Core*'           # solo una carpeta
.\tests\Run-Tests.ps1 -File '*Log*'           # Core/Log y Ui/LogPanel
.\tests\Run-Tests.ps1 -Filter '*registro*'    # solo las pruebas que encajen
```

`-File` se compara contra la **ruta relativa** (`Core/Log.Tests.ps1`), así que sirve
tanto para elegir una carpeta como un archivo suelto.

No hay nada que instalar. **No usan Pester**: la única versión que Windows trae de
serie es la 3.4, cuya sintaxis no se parece a la moderna, así que usarla obligaría a
un `Install-Module` antes de poder ejecutar nada — justo lo que este proyecto evita
en todo lo demás. `TestKit.ps1` son cuarenta líneas con `Describe` / `It` y un puñado
de comprobaciones, y hace el mismo trabajo.

## Qué hay dentro

```text
tests/
├── Run-Tests.ps1        El lanzador. Comprueba STA, carga todo y resume.
├── Harness/             EL ARNÉS. No prueba nada; hace que se pueda probar.
├── Core/                Pruebas de core/  — el sistema de verdad
├── Ui/                  Pruebas de ui/    — controles de WPF sin ventana
├── Source/              Pruebas del CÓDIGO FUENTE, sin ejecutarlo
└── Smoke/               La prueba de humo: no es un *.Tests.ps1 (ver más abajo)
```

| Archivo | Cubre |
| ------- | ----- |
| `Run-Tests.ps1` | El lanzador. Comprueba STA, carga todo y resume. `-BothHosts` lanza 5.1 y 7 en paralelo. |
| `Harness/TestKit.ps1` | `Describe` / `It`, `Assert-*`, `Skip-Test`. |
| `Harness/AppHost.ps1` | Carga la aplicación sin abrir la ventana. `New-AppWindow`, `Find-Visuals`, `Get-VisualText`. Redirige `settings.json` a un temporal, **desarma la escritura al registro** (regla 28) y **la ejecución de comandos** —ni red ni borrados— (`Set-CommandRunArmed $false`, sin pausas), carga las guías de `ui/Data/Guides` por el mismo marcador que `main.ps1`, y se porta como el `.exe`: elevado (`Set-AppElevationOverride $true`). |
| `Harness/Fixtures.ps1` | Claves de prueba en `HKCU\Software\OptimizadorPC\Tests\<PID>`, secciones de mentira, entradas de log. |
| `Core/Log.Tests.ps1` | El registro de actividad: apuntar, filtrar, el tope del buffer, el volcado a archivo, el `Id` de cada entrada y el detalle (`Items`) con y sin vista extendida. |
| `Core/Registry.Tests.ps1` | Leer el registro **de verdad**: los cuatro estados, el DWord con signo, que nunca lance. |
| `Core/RegistryWriter.Tests.ps1` | **Escribir** el registro contra la rama `HKCU` de pruebas: lista blanca, texto→valor tipado (DWord/QWord/Binary/String/ExpandString, `MultiString` no soportado), snapshot previo, verificación por relectura, `type mismatch`, `nochange`, `-WhatIf`, diagnóstico del fallo, y que nunca lance. Y **borrar** un valor (`Remove-RegistryValue`): solo el valor y no la clave, misma lista blanca, nombre vacío, otro tipo, `-WhatIf`, desarmado, copia previa con su estado, rastro en el log; y la primera copia de la sesión (`Get-RegistrySnapshotOrigin`). |
| `Core/SettingApply.Tests.ps1` | El toggle: `ON`→`Recommended`, `OFF`→`Default` de todas las claves del ajuste (o **borrar** el valor si la clave declara `DefaultAbsent` o la primera copia lo vio ausente; con `-WhatIf` y desarmado no borra), recálculo del `Status`, `-WhatIf`, ruta fuera de lista blanca sin romper, y el rastro `applying`/`applied`/`checked`/`done` en el log. |
| `Core/RegistryState.Tests.ps1` | El volcado a los datos de `ui/Data/Categories/` y el aviso de avance. |
| `Core/SettingStatus.Tests.ps1` | En qué estado queda cada ajuste al comparar lo leído con lo declarado, también con `DefaultAbsent` (ausente = de fábrica), y Regedit y Actualizaciones enteras contra el equipo. |
| `Core/ExternalLink.Tests.ps1` | Que solo se abran URLs `http`/`https` absolutas y que un esquema no permitido ni llegue al shell. |
| `Core/CommandRunner.Tests.ps1` | Ejecutar los pasos de las secciones de comandos: lista blanca de ejecutables y servicios, rutas e intérpretes rechazados, carpetas de `-Clean` solo de la lista, desarmado, `blocked`, `-SkipIf`, el detalle de un programa, el apartado del log de cada sección, un proceso **real** de solo lectura (`netsh interface show interface`) y la salida con tildes en UTF-8 y en OEM. |
| `Core/FolderCleanup.Tests.ps1` | Vaciar carpetas, sobre una carpeta de mentira en `%TEMP%`: lista blanca, `%TEMP%` fuera del perfil, los dos modos de borrado, que una unión no se siga, por trozos, y el detalle de lo borrado y lo saltado (con su motivo). La papelera de verdad no se toca. |
| `Core/SystemInfo.Tests.ps1` | Sobre qué corre el programa: Windows (sin el "Windows 10" falso: desde la compilación 22000 tiene que decir "Windows 11", pero solo en un equipo cliente, `InstallationType = Client`; un Windows Server de la misma compilación, como el runner de la CI, no se renombra), PowerShell, exe/script, arquitectura. |
| `Core/WorkArea.Tests.ps1` | Maximizar al área de trabajo, con una ventana Win32 invisible y `WM_GETMINMAXINFO` a mano. |
| `Ui/Window.Tests.ps1` | La ventana, los temas, la barra de título, el menú lateral, las vistas. |
| `Ui/LogPanel.Tests.ps1` | El cajón del log: abrir, cerrar, las filas, el idioma. |
| `Ui/LogWindow.Tests.ps1` | El log sacado a su propia ventana y devuelto al cajón. |
| `Ui/DetailList.Tests.ps1` | El detalle desplegable bajo una entrada del log y bajo la fila de un paso: que no se cierre al rehacer la lista, que el clic no marque el paso, y guardar el log con detalle o sin él. |
| `Ui/DisclosureBulk.Tests.ps1` | Los menús Expandir / Contraer del panel Regedit: abrir y cerrar a la vez las franjas de todas las tarjetas, por tipo. |
| `Ui/TimeFormat.Tests.ps1` | El formato de hora (24 h / 12 h): medianoche, mediodía y dónde se aplica. |
| `Ui/TechnicalDetails.Tests.ps1` | El pie de la tarjeta: que la ruta y el valor se puedan seleccionar y copiar. |
| `Ui/SettingCard.Tests.ps1` | La fila del detalle: el control que sale según el `Type`, el estado inicial del toggle desde el registro, el bloqueo. |
| `Ui/SettingReference.Tests.ps1` | El bloque de referencia de un ajuste (qué hace, valores, enlace). |
| `Ui/Search.Tests.ps1` | El buscador global: índice, coincidencia parcial, desplegable, página de resultados, foco. |
| `Ui/ViewMenu.Tests.ps1` | El chip "Vista" y su desplegable de opciones. |
| `Ui/Visuals.Tests.ps1` | Entrada en cascada, `Get-EnterTarget`, indicadores deslizantes, `Start-CountUp` sin ventana. |
| `Ui/Language.Tests.ps1` | Que no quede ni un texto sin traducir en toda la interfaz. |
| `Ui/StepsView.Tests.ps1` | Las secciones de comandos (Internet, Limpieza, Energía): solo lo marcado y SIEMPRE en el orden del archivo, detener, bloqueo, lo que viene desmarcado y con aviso (y no se restaura marcado desde `settings.json`), el paso de vuelta a DHCP detrás de los del DNS de Google, el plan de energía a un GUID fijo, y el caso sin permisos de administrador (pasos apagados, fuera de la cola) y la insignia de la barra. |
| `Ui/Guides.Tests.ps1` | La sección Guías: el lector de Markdown (bloques y trozos de línea), el registro de las guías, la vuelta desde Base64, el texto normal de "Copiar todo", las dos pantallas, y que el contenido del usuario no pase por `T`. |
| `Ui/StatusFilter.Tests.ps1` | Las píldoras del resumen como filtro: uno, varios, quitar, "Mostrar todos", y que llegar desde la búsqueda lo quite. |
| `Ui/AboutMenu.Tests.ps1` | El panel "Acerca de" y que la versión salga de una sola fuente. |
| `Ui/Wiring.Tests.ps1` | Que los botones de `main.ps1` respondan al pulsarlos. |
| `Source/Rules.Tests.ps1` | Las reglas de `CLAUDE.md` que se ven leyendo el código, el orden de carga de las capas y que el paquete de `build.ps1` parsee y lleve dentro todos los `.ps1`, el XAML y cada guía (que vuelva igual desde Base64). |
| `Source/Security.Tests.ps1` | Invariantes de seguridad: rutas de `-Registry` dentro de la lista blanca, cada clave con `Default` o `DefaultAbsent` (no los dos), ningún borrado de claves del registro y borrado de valores solo en `Writer.ps1`, sin ejecución dinámica ni red en `ui/`/`core/`, sin nombres de valor que degraden la seguridad sin declararlo, `ExternalLink` solo `http`/`https`, solo `CommandRunner.ps1` arranca procesos y solo `FolderCleanup.ps1` borra archivos, las carpetas de la limpieza dentro del perfil, y ni la papelera ni lo que cambia el DNS de un adaptador vienen marcados de serie. Ver `SECURITY.md`. |

**`Harness/` es la única carpeta que no contiene pruebas.** Sus tres archivos se
cargan con punto desde `Run-Tests.ps1` antes que nada, para que todo lo demás vea sus
funciones. Las carpetas restantes se recorren solas: un `*.Tests.ps1` nuevo en
cualquiera de ellas se ejecuta sin registrarlo en ningún sitio.

**`Find-Visuals` NO se envuelve en `@()`.** Termina en `, $found.ToArray()` a
propósito, para que el array llegue entero aunque traiga un solo elemento o ninguno.
Poner `@(Find-Visuals ...)` mete ese array DENTRO de otro, y el fallo no se ve: la
lista pasa a tener un elemento que es a su vez la lista, y `$_.Tag.Text` sobre ella
devuelve todos los textos pegados por la enumeración de miembros de PowerShell. Se
usa tal cual, y si hace falta devolverlo desde una función auxiliar, con la misma
coma delante. Y **el orden no está garantizado** —va con una pila, así que sale al
revés—: se comprueba por contenido, nunca por índice.

`Ui/Wiring.Tests.ps1` es el raro: `main.ps1` no se puede cargar como los demás porque
termina en `ShowDialog()`. Hace una copia sin esa línea, le pega unas pulsaciones al
final y la ejecuta en otro proceso con el mismo host. Es la única forma de cazar la
regla 4 —un manejador con closure falla **al pulsar**, solo ejecutando `main.ps1`, y
en el `.exe` no se nota—, y cuesta unos dos segundos.

`AppHost.ps1` **no repite la lista de archivos**: lee `main.ps1` con las mismas
expresiones regulares que `build.ps1`. Así las pruebas cargan exactamente lo que
carga el programa y, de paso, validan el contrato de empaquetado.

## Sobre Playwright

**No sirve aquí, y no es cuestión de configurarlo: Playwright automatiza navegadores.**
Habla el protocolo DevTools con Chromium, Firefox y WebKit, y su selector busca nodos
del DOM. Esto es WPF: no hay DOM, no hay navegador y no hay nada a lo que conectarse.
Lo mismo vale para Cypress, Selenium o Puppeteer.

Lo que sí existe para automatizar una ventana de Windows es **UI Automation**, y hay
tres formas de llegar a él:

| | Qué es | Coste |
| --- | ------ | ----- |
| `System.Windows.Automation` | El cliente de UIA que ya trae .NET Framework | Cero: `Add-Type -AssemblyName UIAutomationClient` y a funcionar |
| **FlaUI** | Envoltorio moderno sobre UIA, mucho más cómodo | Una DLL de NuGet |
| **WinAppDriver** | Appium para Windows; permite escribir las pruebas con clientes de Selenium | Un servicio aparte, y Microsoft lo dejó de mantener en 2022 |

Ninguno hacía falta para lo que hay hoy. Estas pruebas construyen los controles de
WPF **de verdad** —la misma clase `Button`, el mismo `Grid`, el XAML real— y miran el
árbol resultante, solo que sin enseñar la ventana. Eso ya contesta a casi todo lo que
querrías preguntar (¿está el botón?, ¿se llenó la lista?, ¿se tradujo el título?) y
tarda un par de minutos por host —631 pruebas— en vez de mucho más, sin ventanas abriéndose por delante de
lo que estés haciendo.

Los manejadores de `main.ps1` sí se prueban, y sin UIA: `Ui/Wiring.Tests.ps1` levanta
la ventana y dispara el evento `Click` a mano.

**Cuándo tocaría dar el salto a UIA:** cuando haya que comprobar cosas que solo
existen con la ventana pintada y un ratón de verdad. Por ejemplo:

- que un clic del ratón llegue al control correcto, con las plantillas de WPF ya
  construidas y el hit-testing funcionando (disparar el evento `Click` se salta esa
  parte);
- que `IsHitTestVisible = $false` bloquee el ratón como se espera;
- que las animaciones terminen (las de WPF **no avanzan sin una ventana
  pintándose**, y por eso `Close-LogOverlay` está separada del manejador que la
  dispara: para poder probar el cierre del cajón sin depender de eso);
- una prueba de humo sobre el `.exe` compilado, que es el artefacto que se entrega.

Ese último caso es el que más valdría la pena, y ya existe a medias con
`System.Windows.Automation` —sin instalar nada—: `Smoke/Invoke-Smoke.ps1` (abajo)
arranca el programa empaquetado y lo mira desde fuera, y desde 2026-11-09 también el
`.exe` **elevado** sin intervención (`-Exe`, en la CI). Ahora que un clic **escribe y
borra valores en `HKLM` con privilegios de administrador**, lo que falta importa más
que antes: que **pulse** algo. Sigue pendiente porque cuesta bastante más de mantener y la escritura y el borrado ya
están cubiertos a nivel de `core/` contra una rama de pruebas en `HKCU`
(`Core/RegistryWriter.Tests.ps1`, `Core/SettingApply.Tests.ps1`).

## La prueba de humo (`Smoke/Invoke-Smoke.ps1`)

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1        # el script empaquetado, sin elevar
powershell -ExecutionPolicy Bypass -File .\tests\Smoke\Invoke-Smoke.ps1 -Exe   # el .exe, desde una terminal ELEVADA
```

Arranca **de verdad** lo que va en el `.exe` (`build/_combined.ps1`, con Windows
PowerShell 5.1 y sin elevar) y lo mira desde fuera con `System.Windows.Automation`: que
sale la ventana con el título del programa (`$AppInfo.Name`), que el menú trae sus cuatro
entradas y que el proceso no se muere. No pulsa nada y la cierra con su botón (si no
responde, `CloseMainWindow`, y matarlo cuenta como fallo). No es un `*.Tests.ps1` a
propósito: abre una ventana delante de lo que estés haciendo, así que `Run-Tests.ps1` no
la recoge. Hay que compilar antes.

**Con `-Exe` arranca `build/OptimizadorPC.exe`, elevado y sin nadie delante.** UAC no se
salta: el `.exe` lleva `-requireAdmin`, y lanzado desde un proceso que **ya** está
elevado arranca elevado sin diálogo. Además de lo de arriba comprueba en el token del
proceso que de verdad corre elevado. Así corre en la CI (job `humo` de `ci.yml`: el
runner de Windows es administrador sin UAC) y en local desde una terminal "Ejecutar como
administrador". **Sin elevar no arranca nada**: dice `SALTADO` y sale con **2** (0 bien,
1 falla), en vez de sacar un UAC y quedarse esperando.

## Lo que estas pruebas NO cubren

- **El aspecto.** Si una tarjeta se ve torcida, si un color queda ilegible en el tema
  oscuro o si un glifo es el equivocado, esto no se entera. Para eso hay que abrir la
  aplicación y mirarla.
- **El `.exe` funcionando.** Se comprueba que el paquete que arma `build.ps1` parsea
  y lleva todo dentro, pero `Run-Tests.ps1` no ejecuta el binario. La prueba de humo
  con `-Exe` sí lo arranca, elevado y sin intervención (en la CI, o en local desde una
  terminal elevada), pero sin pulsar nada.
- **El ratón de verdad.** Se disparan los eventos, no se mueve un cursor.
- **La escritura al registro EN EL EQUIPO REAL.** El arnés la desarma
  (`Set-RegistryWriteArmed $false` en `AppHost.ps1`); las pruebas de `core/` la rearman
  solo contra `HKCU\Software\OptimizadorPC\Tests\<PID>`. Que el ajuste real de *Regedit*
  escriba de verdad en `HKLM` al pulsarlo en la aplicación compilada no se prueba: eso
  necesitaría el `.exe` elevado y la prueba de humo con UI Automation de arriba.
- **El `.exe` elevado, pulsando.** Las pruebas corren en tu sesión normal; el `.exe`
  elevado solo lo arranca y lo cierra la prueba de humo (`-Exe`).
- **Los comandos de verdad.** El arnés desarma `CommandRunner`: solo corre de verdad el
  paso de lectura `netsh interface show interface`. La limpieza se prueba sobre una
  carpeta de mentira, y ni la papelera, ni `powercfg`, ni DISM se ejecutan nunca en
  las pruebas.
