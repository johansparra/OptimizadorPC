# ============================================================
# ui/Components/Shell/WindowBounds.ps1
# Que maximizar no tape la barra de tareas.
#
# Las ventanas de la aplicación no tienen cromo de Windows y, sin
# él, maximizar ocupa el monitor entero. La corrección es de Win32 y
# vive en core/Interop/WorkArea.ps1; aquí solo se saca el descriptor
# de la ventana de WPF y se le pasa.
#
# Se llama en SourceInitialized: antes no hay descriptor. Vale para
# la principal y para la ventana suelta del log.
# ============================================================

function Enable-WindowWorkArea {
    param($Window)

    if (-not $Window) { return $false }
    try {
        $handle = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle
        Enable-WorkAreaMaximize -Handle $handle
    }
    catch { $false }
}
