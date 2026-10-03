# ============================================================
# Pruebas de core/Interop/WorkArea.ps1 — maximizar sin tapar la
# barra de tareas.
#
# Ninguna prueba enseña una ventana, así que no se maximiza nada de
# verdad. Se hace lo mismo que Windows por dentro: se crea una
# ventana Win32 INVISIBLE (HwndSource, sin WS_VISIBLE), se engancha
# y se le manda WM_GETMINMAXINFO a mano. Lo que vuelve es lo que
# Windows usaría al maximizar: tiene que ser el área de trabajo del
# monitor, no el monitor entero.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms

if (-not ('WorkAreaProbe' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WorkAreaProbe {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);

    // MINMAXINFO: cinco POINT seguidos. Se piden posición y tamaño
    // maximizados: índices 4-5 y 2-3 de los diez enteros.
    public static int[] MinMaxInfo(IntPtr hwnd) {
        IntPtr buffer = Marshal.AllocHGlobal(40);
        try {
            for (int i = 0; i < 10; i++) Marshal.WriteInt32(buffer, i * 4, 0);
            SendMessage(hwnd, 0x0024, IntPtr.Zero, buffer);
            int[] values = new int[10];
            Marshal.Copy(buffer, values, 0, 10);
            return values;
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }
}
'@
}

# Una ventana Win32 de verdad, pero sin WS_VISIBLE: tiene descriptor
# y recibe mensajes, y no aparece en pantalla.
function New-HiddenHwnd {
    $p = New-Object System.Windows.Interop.HwndSourceParameters 'WorkAreaTest'
    $p.WindowStyle = 0x00CF0000   # WS_OVERLAPPEDWINDOW, sin WS_VISIBLE
    $p.Width = 400; $p.Height = 300
    New-Object System.Windows.Interop.HwndSource $p
}

Describe 'core/Interop/WorkArea.ps1 - maximizar al área de trabajo' {

    It 'el puente compila en este host' {
        Assert-True (Initialize-WorkAreaMaximize)
    }

    It 'un descriptor vacío es $false, no una excepción' {
        Assert-NoThrow { Enable-WorkAreaMaximize -Handle ([IntPtr]::Zero) }
        Assert-False (Enable-WorkAreaMaximize -Handle ([IntPtr]::Zero))
    }

    It 'engancharse dos veces a la misma ventana no hace nada la segunda' {
        $src = New-HiddenHwnd
        try {
            Assert-True (Enable-WorkAreaMaximize -Handle $src.Handle)
            Assert-True (Enable-WorkAreaMaximize -Handle $src.Handle)
            Assert-True ([OptimizadorPC.WorkArea]::IsAttached($src.Handle))
        }
        finally { $src.Dispose() }
    }

    It 'maximizar pide el área de trabajo de su monitor, no el monitor entero' {
        $src = New-HiddenHwnd
        try {
            $null = Enable-WorkAreaMaximize -Handle $src.Handle
            $v = [WorkAreaProbe]::MinMaxInfo($src.Handle)

            $screen = [System.Windows.Forms.Screen]::FromHandle($src.Handle)
            $work = $screen.WorkingArea
            $mon  = $screen.Bounds

            Assert-Equal ($work.Width)  $v[2] 'ancho maximizado'
            Assert-Equal ($work.Height) $v[3] 'alto maximizado'
            Assert-Equal ($work.Left - $mon.Left) $v[4] 'posición X maximizada'
            Assert-Equal ($work.Top  - $mon.Top)  $v[5] 'posición Y maximizada'
        }
        finally { $src.Dispose() }
    }

    It 'al destruirse la ventana se suelta sola' {
        $src = New-HiddenHwnd
        $h = $src.Handle
        $null = Enable-WorkAreaMaximize -Handle $h
        $src.Dispose()
        Assert-False ([OptimizadorPC.WorkArea]::IsAttached($h))
    }
}
