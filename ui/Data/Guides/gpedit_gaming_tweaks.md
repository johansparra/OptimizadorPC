# gpedit.msc — Ajustes para gaming (BF6)

Todo esto vive en **Editor de directivas de grupo local** (`gpedit.msc`, solo
disponible en Windows Pro/Enterprise — no en Home). Reinicia el PC después de
aplicar cambios de directiva para que se propaguen del todo.

## 1) Programador de paquetes QoS

`Configuración del equipo > Plantillas administrativas > Red > Programador de paquetes QoS > Limitar ancho de banda reservable`

- **Habilitada**
- **Límite de ancho de banda (%): 0**

Esto es el equivalente por GPO de la clave `NonBestEffortLimit=0` que ya
tienes en el `.reg`. Por defecto Windows reserva 20% del ancho de banda para
QoS del sistema; con esto en 0% el juego tiene acceso al 100%. Lo que
mostraste en la captura está correcto, no hay que tocar nada más ahí.

> Nota: si aplicaste la clave de registro `NonBestEffortLimit` directamente
> en `HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched` (como en tu `.reg`),
> esta misma directiva de gpedit terminará mostrando "Habilitada" reflejando
> ese valor — son la misma configuración vista desde dos lugares distintos.
> No necesitas las dos, con una basta, pero tenerla en ambos no hace daño.

## 2) Delivery Optimization — reduce uso de ancho de banda en segundo plano

`Configuración del equipo > Plantillas administrativas > Componentes de Windows > Optimización de entrega`

- **"Descargar Mode"** → Habilitada → modo **"Simple"** o **"HTTP only"** (evita que tu PC suba/descargue actualizaciones de Windows a/desde otros equipos en internet mientras juegas)
- **"Limitar el ancho de banda máximo en segundo plano"** → Habilitada → **10-20%** (deja margen para que Windows Update no consuma ancho de banda de golpe mientras estás en partida)

## 3) Aplicaciones en segundo plano (privacidad de la app)

`Configuración del equipo > Plantillas administrativas > Componentes de Windows > Privacidad de la aplicación`

- **"No permitir que las aplicaciones de Windows se ejecuten en segundo plano"** → Habilitada → **"Forzar denegación"**

Corta procesos de apps UWP (Xbox app, Widgets, Noticias, etc.) que consumen
CPU/red en segundo plano sin que te des cuenta.

## 4) Windows Update — evita reinicios/descargas forzadas en medio de una partida

`Configuración del equipo > Plantillas administrativas > Componentes de Windows > Windows Update`

- **"No reiniciar automáticamente con usuarios conectados"** → **Habilitada**
- **"Configurar Windows Update automático"** → Habilitada → opción **"2 - Notificar antes de descargar"** o **"3 - Notificar antes de instalar"** (tú decides cuándo actualiza, no Windows a mitad de un combate)

## 5) BranchCache (si aparece en tu lista, normalmente ya deshabilitado)

`Configuración del equipo > Plantillas administrativas > Red > BranchCache`

- Verifica que esté **Deshabilitada/No configurada**. Es una función de caché
  de red corporativa que no aplica a un PC doméstico, pero si alguna vez se
  activó por error puede generar tráfico de red innecesario en segundo plano.

## 6) Eliminacion de paquetes

`Configuración del equipo > Plantillas administrativas >  Componentes de Windows > Implementacion de paquetes de la aplicacion > Elimina los paquetes  predeterminados de Microsft Store del Sistema`

- **Habilitada**
  - Centro de Opiniones
  - Microsoft copilot
  - Microsoft 365 Copilot
  - Microsoft news
  - Microsoft Solitaire Collection
  - MSN El tiempo
  - Outlook para Windows
  - Aplicacion de Juegos de Xbox
  - Xbox Identity Provider
  - Superposicion de conversacion de voz en texto de Xbox
  - XBox TCUI

ahora usar este powerhell para eliminar los paquetes de UWP que no quieras:

```Powershell
.\"Eliminar apps.ps1"
```

```Powershell
  # Ejecutar PowerShell como Administrador

# Ejecutar PowerShell como Administrador

$apps = @(
    "Microsoft.WindowsFeedbackHub"               # Centro de Opiniones
    "Microsoft.Copilot"                          # Microsoft Copilot
    "MicrosoftCorporationII.MicrosoftOfficeHub"  # Microsoft 365 / Copilot (verificar nombre real)
    "Microsoft.BingNews"                         # Microsoft News
    "Microsoft.MicrosoftSolitaireCollection"     # Solitaire Collection
    "Microsoft.BingWeather"                      # MSN El Tiempo
    "Microsoft.OutlookForWindows"                # Outlook para Windows
    "Microsoft.GamingApp"                        # Aplicacion de Juegos de Xbox
    "Microsoft.XboxIdentityProvider"             # Xbox Identity Provider
    "Microsoft.Xbox.TCUI"                        # Xbox TCUI
    "Microsoft.XboxSpeechToTextOverlay"          # Superposicion de voz a texto de Xbox
)

$resultados = @()

foreach ($app in $apps) {
    Write-Host ""
    Write-Host "=== Procesando: $app ===" -ForegroundColor Cyan

    $instalado = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue

    if (-not $instalado) {
        Write-Host "  No esta instalado (o el nombre no coincide). Se omite." -ForegroundColor DarkYellow
        $resultados += [PSCustomObject]@{ App = $app; Estado = "No encontrado" }
        continue
    }

    try {
        $instalado | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Host "  Desinstalado correctamente." -ForegroundColor Green
        $estadoPkg = "Desinstalado OK"
    }
    catch {
        Write-Host "  ERROR al desinstalar: $($_.Exception.Message)" -ForegroundColor Red
        $estadoPkg = "ERROR: $($_.Exception.Message)"
    }

    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object DisplayName -eq $app
        if ($prov) {
            $prov | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null
            Write-Host "  Paquete aprovisionado (reinstalacion automatica) eliminado." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ERROR al quitar el aprovisionamiento: $($_.Exception.Message)" -ForegroundColor Red
    }

    $resultados += [PSCustomObject]@{ App = $app; Estado = $estadoPkg }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           RESUMEN DE RESULTADOS          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$resultados | Format-Table -AutoSize

Write-Host ""
Write-Host "Proceso terminado. Revisa arriba si hubo errores en rojo." -ForegroundColor Yellow
Write-Host "Presiona ENTER para cerrar esta ventana..."
Read-Host
```

## Lo que NO necesitas tocar en gpedit para esto

- **Cliente DNS**, **Autenticación de zona con cobertura**, **Aislamiento de
  red**: son directivas de dominio/empresa (Active Directory), sin efecto en
  una red doméstica sin dominio.
- **Servicio WWAN / Servicio WLAN**: solo aplican si usas conexión móvil o
  WiFi — tu adaptador activo es Ethernet (Intel I211), así que no aportan
  nada en tu caso.

## Resumen de impacto

| Ajuste | Impacto en gaming |
| --- | --- |
| QoS Packet Scheduler = 0% | **Alto** — ya lo tienes |
| Delivery Optimization limitado | **Medio** — evita picos de ancho de banda por updates P2P |
| Apps en segundo plano forzado a denegar | **Medio** — menos CPU/red robada por procesos UWP |
| Windows Update con notificación previa | **Medio** — evita reinicios/descargas sorpresa a mitad de partida |
| BranchCache deshabilitado | **Bajo** — solo por higiene, en tu caso probablemente ya está así |
