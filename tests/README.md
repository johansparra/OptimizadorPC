# Pruebas

```powershell
# Desde Proyecto\
powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1   # Windows PowerShell 5.1
pwsh       -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1   # PowerShell 7
```

**Pásalas en los dos hosts.** El `.exe` corre sobre 5.1 con todo en ámbito global y
`main.ps1` sobre pwsh 7 en ámbito de script: hay fallos que solo salen en uno de los
dos (regla 8 de `CLAUDE.md`). Devuelve 0 si todo pasa y 1 si algo falla.

```powershell
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

```
tests/
├── Run-Tests.ps1        El lanzador. Comprueba STA, carga todo y resume.
├── Harness/             EL ARNÉS. No prueba nada; hace que se pueda probar.
├── Core/                Pruebas de core/  — el sistema de verdad
├── Ui/                  Pruebas de ui/    — controles de WPF sin ventana
└── Source/              Pruebas del CÓDIGO FUENTE, sin ejecutarlo
```

| Archivo | Cubre |
| ------- | ----- |
| `Run-Tests.ps1` | El lanzador. Comprueba STA, carga todo y resume. |
| `Harness/TestKit.ps1` | `Describe` / `It`, `Assert-*`, `Skip-Test`. |
| `Harness/AppHost.ps1` | Carga la aplicación sin abrir la ventana. `New-AppWindow`, `Find-Visuals`, `Get-VisualText`. |
| `Harness/Fixtures.ps1` | Claves de prueba en `HKCU`, secciones de mentira, entradas de log. |
| `Core/Log.Tests.ps1` | El registro de actividad: apuntar, filtrar, el tope del buffer, el volcado a archivo. |
| `Core/Registry.Tests.ps1` | Leer el registro **de verdad**: los cuatro estados, el DWord con signo, que nunca lance. |
| `Core/RegistryState.Tests.ps1` | El volcado a los datos de `ui/Data/Categories/` y el aviso de avance. |
| `Ui/Window.Tests.ps1` | La ventana, los temas, la barra de título, el menú lateral, las vistas. |
| `Ui/LogPanel.Tests.ps1` | El cajón del log: abrir, cerrar, las filas, el idioma. |
| `Ui/Language.Tests.ps1` | Que no quede ni un texto sin traducir en toda la interfaz. |
| `Ui/Wiring.Tests.ps1` | Que los botones de `main.ps1` respondan al pulsarlos. |
| `Source/Rules.Tests.ps1` | Las reglas de `CLAUDE.md` que se ven leyendo el código, el orden de carga de las capas y que el paquete de `build.ps1` parsee. |

**`Harness/` es la única carpeta que no contiene pruebas.** Sus tres archivos se
cargan con punto desde `Run-Tests.ps1` antes que nada, para que todo lo demás vea sus
funciones. Las carpetas restantes se recorren solas: un `*.Tests.ps1` nuevo en
cualquiera de ellas se ejecuta sin registrarlo en ningún sitio.

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
tarda ocho segundos en vez de varios minutos, sin ventanas abriéndose por delante de
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

Ese último caso es el que más valdría la pena, y se haría con
`System.Windows.Automation` sobre `OptimizadorPC.exe` — sin instalar nada. Queda
pendiente a propósito: cuesta bastante más de mantener y todavía no hay lógica que
escriba en el sistema, que es cuando de verdad importará.

## Lo que estas pruebas NO cubren

- **El aspecto.** Si una tarjeta se ve torcida, si un color queda ilegible en el tema
  oscuro o si un glifo es el equivocado, esto no se entera. Para eso hay que abrir la
  aplicación y mirarla.
- **El `.exe` funcionando.** Se comprueba que el paquete que arma `build.ps1` parsea
  y lleva todo dentro, pero no se ejecuta el binario.
- **El ratón de verdad.** Se disparan los eventos, no se mueve un cursor.
- **Escribir en el registro.** Todavía no existe.
