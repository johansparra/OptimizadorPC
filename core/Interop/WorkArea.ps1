# ============================================================
# core/Interop/WorkArea.ps1
# Maximizar sin tapar la barra de tareas.
#
# Una ventana sin cromo de Windows (WindowStyle None + WindowChrome)
# pierde lo que el marco normal hacía solo: al maximizar, Windows le
# da el MONITOR entero en vez del área de trabajo, y la ventana se
# mete debajo de la barra de tareas. Lo arregla contestar a
# WM_GETMINMAXINFO con el área de trabajo del monitor en el que está
# la ventana -sea cual sea, y con la barra donde la tenga el usuario-.
#
# POR QUÉ EN C# Y NO CON UN HOOK DE POWERSHELL
#
#   El procedimiento de ventana recibe TODOS los mensajes: cada
#   movimiento del ratón, cada repintado. Un scriptblock ahí haría
#   pasar por PowerShell cientos de mensajes por segundo para usar
#   uno. Aquí el filtro es C# compilado y PowerShell no se entera.
#
# POR QUÉ SUBCLASIFICANDO CON SetWindowLongPtr
#
#   Es Win32 puro: no hace falta HwndSource ni ningún tipo de WPF, y
#   core/ sigue sin saber que existe una interfaz. Se llama primero
#   al procedimiento anterior -el de WPF, que aplica MinWidth y
#   MinHeight- y DESPUÉS se corrige solo la posición y el tamaño
#   maximizados, así que lo demás sigue igual.
#
# CÓMO NO EXPLOTAR
#
#   Nada de aquí lanza. Si no compila o Windows se niega, se
#   devuelve $false y la ventana maximiza como antes. Dentro del
#   procedimiento de ventana una excepción tumbaría el proceso, así
#   que la corrección va envuelta en su propio try.
#
#   El delegado vive en un campo estático: si el recolector se lo
#   llevara, Windows llamaría a un puntero muerto.
#
#   Al destruirse la ventana (WM_NCDESTROY) se deja el procedimiento
#   original y se olvida el descriptor.
#
# Todos los textos de este archivo están en inglés o son
# comentarios: core/ no traduce (ver la regla 15).
# ============================================================

<#
    Compila el puente a user32.dll, una sola vez. Add-Type lanza si
    el tipo ya existe, así que primero se pregunta.
#>
function Initialize-WorkAreaMaximize {
    if ('OptimizadorPC.WorkArea' -as [type]) { return $true }

    $source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace OptimizadorPC {
    public static class WorkArea {
        private const int  GWLP_WNDPROC     = -4;
        private const uint WM_GETMINMAXINFO = 0x0024;
        private const uint WM_NCDESTROY     = 0x0082;
        private const uint MONITOR_DEFAULTTONEAREST = 2;

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

        [StructLayout(LayoutKind.Sequential)]
        private struct MINMAXINFO {
            public POINT Reserved;
            public POINT MaxSize;
            public POINT MaxPosition;
            public POINT MinTrackSize;
            public POINT MaxTrackSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MONITORINFO {
            public int  Size;
            public RECT Monitor;
            public RECT Work;
            public uint Flags;
        }

        private delegate IntPtr WndProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
        private static extern IntPtr SetWindowLongPtr64(IntPtr hwnd, int index, IntPtr value);

        [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
        private static extern IntPtr SetWindowLong32(IntPtr hwnd, int index, IntPtr value);

        [DllImport("user32.dll")]
        private static extern IntPtr CallWindowProc(IntPtr previous, IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

        [DllImport("user32.dll")]
        private static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);

        // Vivo mientras viva el proceso: Windows guarda su puntero.
        private static readonly WndProc Hook = Filter;
        private static readonly Dictionary<IntPtr, IntPtr> Previous = new Dictionary<IntPtr, IntPtr>();

        private static IntPtr SetProc(IntPtr hwnd, IntPtr proc) {
            return IntPtr.Size == 8 ? SetWindowLongPtr64(hwnd, GWLP_WNDPROC, proc)
                                    : SetWindowLong32(hwnd, GWLP_WNDPROC, proc);
        }

        public static bool Attach(IntPtr hwnd) {
            if (hwnd == IntPtr.Zero) return false;
            if (Previous.ContainsKey(hwnd)) return true;

            IntPtr previous = SetProc(hwnd, Marshal.GetFunctionPointerForDelegate(Hook));
            if (previous == IntPtr.Zero) return false;
            Previous[hwnd] = previous;
            return true;
        }

        public static bool IsAttached(IntPtr hwnd) {
            return Previous.ContainsKey(hwnd);
        }

        private static IntPtr Filter(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam) {
            IntPtr previous;
            if (!Previous.TryGetValue(hwnd, out previous)) return IntPtr.Zero;

            if (msg == WM_NCDESTROY) {
                SetProc(hwnd, previous);
                Previous.Remove(hwnd);
                return CallWindowProc(previous, hwnd, msg, wParam, lParam);
            }

            IntPtr result = CallWindowProc(previous, hwnd, msg, wParam, lParam);
            if (msg == WM_GETMINMAXINFO) FitToWorkArea(hwnd, lParam);
            return result;
        }

        // Posición y tamaño maximizados = el área de trabajo del
        // monitor. La posición va relativa al origen del monitor.
        private static void FitToWorkArea(IntPtr hwnd, IntPtr lParam) {
            try {
                IntPtr monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
                if (monitor == IntPtr.Zero) return;

                MONITORINFO info = new MONITORINFO();
                info.Size = Marshal.SizeOf(typeof(MONITORINFO));
                if (!GetMonitorInfo(monitor, ref info)) return;

                MINMAXINFO mmi = (MINMAXINFO)Marshal.PtrToStructure(lParam, typeof(MINMAXINFO));
                mmi.MaxPosition.X = info.Work.Left - info.Monitor.Left;
                mmi.MaxPosition.Y = info.Work.Top  - info.Monitor.Top;
                mmi.MaxSize.X     = info.Work.Right  - info.Work.Left;
                mmi.MaxSize.Y     = info.Work.Bottom - info.Work.Top;
                Marshal.StructureToPtr(mmi, lParam, false);
            }
            catch { }
        }
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
    Hace que la ventana de ese descriptor maximice al área de trabajo
    de su monitor, sin tapar la barra de tareas.

        Enable-WorkAreaMaximize -Handle $hwnd

    Devuelve $true si queda enganchada (o ya lo estaba). Llamarla dos
    veces con la misma ventana no hace nada la segunda.
#>
function Enable-WorkAreaMaximize {
    param([IntPtr]$Handle)

    if ($Handle -eq [IntPtr]::Zero) { return $false }
    if (-not (Initialize-WorkAreaMaximize)) { return $false }

    try { [OptimizadorPC.WorkArea]::Attach($Handle) }
    catch { $false }
}
