# ============================================================
# core/Interop/SystemBackdrop.ps1
# El material de fondo de Windows 11: Mica y Acrílico.
#
# Es lo unico de todo el proyecto que llama a la API de Windows,
# y por eso vive en core/: aqui no se sabe que existe una ventana
# de WPF. Se recibe un descriptor (IntPtr) y se devuelve si el
# sistema ha aceptado el cambio. Nada mas.
#
# COMO NO EXPLOTAR
#
#   Nada de aqui lanza. El material es un adorno: si el equipo es
#   viejo, si falta dwmapi o si la llamada falla, se devuelve
#   $false y la aplicacion se queda con su fondo propio. Una
#   excepcion escapando de core/ tumbaria la ventana entera.
#
#   El tipo de interoperabilidad se compila UNA vez. Add-Type
#   lanza si el tipo ya existe, asi que primero se pregunta.
#
#   Hace falta Windows 11 22H2 (compilacion 22621) o superior:
#   DWMWA_SYSTEMBACKDROP_TYPE no existe antes y la llamada
#   devuelve error. Se comprueba antes de intentarlo.
#
# Todos los textos de este archivo estan en ingles o son
# comentarios: core/ no traduce (ver la regla 15).
# ============================================================

# DWMWINDOWATTRIBUTE. Los numeros son los de la cabecera dwmapi.h.
$DwmSystemBackdropType = 38
$DwmImmersiveDarkMode  = 20

# DWM_SYSTEMBACKDROP_TYPE. 'None' no es "sin material" sino "el
# que decida el sistema"; para quitarlo se usa Auto/None = 1.
$SystemBackdropKinds = @{
    'None'    = 1
    'Mica'    = 2
    'Acrylic' = 3
    'Tabbed'  = 4
}

# Compilacion minima: Windows 11 22H2.
$SystemBackdropMinBuild = 22621

function Test-SystemBackdropSupport {
    [Environment]::OSVersion.Version.Build -ge $SystemBackdropMinBuild
}

function Get-SystemBackdropKinds {
    $SystemBackdropKinds.Keys
}

<#
    Compila el puente a dwmapi.dll, una sola vez.

    Devuelve $true si el tipo esta disponible. Add-Type compila de
    verdad la primera vez -unas decimas- y por eso no se hace al
    cargar el programa sino cuando alguien pide material: quien no
    lo use no lo paga.
#>
function Initialize-SystemBackdrop {
    if ('OptimizadorPC.Dwm' -as [type]) { return $true }

    $source = @'
using System;
using System.Runtime.InteropServices;

namespace OptimizadorPC {
    public static class Dwm {
        [DllImport("dwmapi.dll", PreserveSig = true)]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

        [StructLayout(LayoutKind.Sequential)]
        public struct Margins {
            public int Left;
            public int Right;
            public int Top;
            public int Bottom;
        }

        [DllImport("dwmapi.dll", PreserveSig = true)]
        public static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref Margins margins);
    }
}
'@

    try {
        Add-Type -TypeDefinition $source -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

<#
    Pone (o quita) el material de fondo de una ventana.

        Set-WindowBackdrop -Handle $hwnd -Kind 'Mica' -Dark $true

    Devuelve $true solo si Windows lo ha aceptado. Cualquier otra
    cosa -equipo antiguo, descriptor invalido, dwmapi que se queja-
    es $false, y quien llama se queda con su fondo de siempre.

    -Dark le dice a DWM que el contenido es oscuro, para que el
    material y el borde de la ventana se tinten a juego. Sin eso,
    en tema oscuro el marco sigue saliendo claro.
#>
function Set-WindowBackdrop {
    param(
        [Parameter(Mandatory)][IntPtr]$Handle,
        [string]$Kind = 'None',
        [bool]$Dark = $false
    )

    if ($Handle -eq [IntPtr]::Zero) { return $false }
    if (-not $SystemBackdropKinds.ContainsKey($Kind)) { return $false }
    if (-not (Test-SystemBackdropSupport)) { return $false }
    if (-not (Initialize-SystemBackdrop)) { return $false }

    try {
        # El material solo se ve donde el marco esta extendido sobre
        # el area de cliente. -1 en los cuatro lados = toda la
        # ventana, que es lo que quiere una ventana sin cromo.
        $margins = New-Object OptimizadorPC.Dwm+Margins
        $margins.Left = -1; $margins.Right = -1; $margins.Top = -1; $margins.Bottom = -1
        [OptimizadorPC.Dwm]::DwmExtendFrameIntoClientArea($Handle, [ref]$margins) | Out-Null

        $mode = 0
        if ($Dark) { $mode = 1 }
        [OptimizadorPC.Dwm]::DwmSetWindowAttribute($Handle, $DwmImmersiveDarkMode, [ref]$mode, 4) | Out-Null

        $value = $SystemBackdropKinds[$Kind]
        $result = [OptimizadorPC.Dwm]::DwmSetWindowAttribute($Handle, $DwmSystemBackdropType, [ref]$value, 4)

        # S_OK = 0. Cualquier otro HRESULT es un no.
        return ($result -eq 0)
    }
    catch {
        return $false
    }
}
