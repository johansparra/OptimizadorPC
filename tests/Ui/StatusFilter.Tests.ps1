# ============================================================
# Pruebas del filtro por estado: las píldoras del resumen de una
# sección (ui/Components/Layout/CategorySummary.ps1) como botones.
#
# Se usa Regedit, que lee el registro de verdad: los recuentos son los
# de esta máquina, así que las pruebas no dan por hecho ningún número,
# los sacan de Get-CategoryStatusCounts.
# ============================================================

function Get-FilterTestCategory { Get-CategoryById 'regedit' }

# Las tarjetas de ajuste visibles en la pantalla de detalle.
function Get-VisibleSettingCards {
    param($Window)
    @($Window.FindName('MainContent').Content.Children | Where-Object {
        $_.Tag -and $_.Tag.PSObject.Properties['Registry'] -and $_.Visibility -eq 'Visible'
    })
}

# Un estado con al menos un ajuste (y otro, si hay).
function Get-PresentStatuses {
    param($Category)
    $counts = Get-CategoryStatusCounts $Category
    @(Get-SettingStatusNames | Where-Object { [int]$counts.$_ -gt 0 })
}

function Open-FilterTestSection {
    $ventana = New-AppWindow -Language 'en'
    $cat = Get-FilterTestCategory
    Clear-CategoryStatusFilter -Category $cat
    Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
    $ventana
}

Describe 'ui/Components/Layout/CategorySummary.ps1 - el filtro por estado' {

    It 'sin filtro se ven todos los ajustes' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        Assert-Equal @($cat.Items).Count (Get-VisibleSettingCards $ventana).Count
    }

    It 'pulsar una píldora deja solo los ajustes de ese estado' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]

        Switch-CategoryStatusFilter -Category $cat -Status $estado
        try {
            $visibles = Get-VisibleSettingCards $ventana
            Assert-Equal ([int](Get-CategoryStatusCounts $cat).$estado) $visibles.Count
            foreach ($c in $visibles) { Assert-Equal $estado $c.Tag.Status "se ve '$($c.Tag.Name)'" }
        }
        finally { Clear-CategoryStatusFilter -Category $cat }
    }

    It 'se pueden combinar varios estados' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $presentes = Get-PresentStatuses $cat
        if ($presentes.Count -lt 2) { Skip-Test 'esta máquina solo tiene un estado en Regedit' }

        Switch-CategoryStatusFilter -Category $cat -Status $presentes[0]
        Switch-CategoryStatusFilter -Category $cat -Status $presentes[1]
        try {
            $counts = Get-CategoryStatusCounts $cat
            $esperado = [int]$counts.($presentes[0]) + [int]$counts.($presentes[1])
            Assert-Equal $esperado (Get-VisibleSettingCards $ventana).Count
        }
        finally { Clear-CategoryStatusFilter -Category $cat }
    }

    It 'volver a pulsar la misma píldora quita ese estado del filtro' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]

        Switch-CategoryStatusFilter -Category $cat -Status $estado
        Switch-CategoryStatusFilter -Category $cat -Status $estado
        Assert-Equal 0 @(Get-CategoryStatusFilter $cat).Count
        Assert-Equal @($cat.Items).Count (Get-VisibleSettingCards $ventana).Count
    }

    It 'con filtro sale Mostrar todos, y lo quita' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]

        $fila = $ventana.FindName('HeaderSummaryArea').Children[0]
        Assert-False ((Get-VisualText $fila) -match 'Show all') 'sin filtro no hay nada que quitar'

        Switch-CategoryStatusFilter -Category $cat -Status $estado
        $fila = $ventana.FindName('HeaderSummaryArea').Children[0]
        Assert-Match 'Show all' (Get-VisualText $fila)

        Clear-CategoryStatusFilter -Category $cat
        Assert-Equal @($cat.Items).Count (Get-VisibleSettingCards $ventana).Count
    }

    It 'la píldora marcada lleva borde y las otras se atenúan' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]
        Switch-CategoryStatusFilter -Category $cat -Status $estado
        try {
            $pildoras = @($ventana.FindName('HeaderSummaryArea').Children[0].Children | Where-Object { $_.Tag -and $_.Tag.PSObject.Properties['Status'] })
            foreach ($p in $pildoras) {
                if ($p.Tag.Status -eq $estado) { Assert-Equal 1.0 $p.Opacity "la marcada ($estado)" }
                else { Assert-True ($p.Opacity -lt 1) "la no marcada ($($p.Tag.Status)) tendría que atenuarse" }
            }
        }
        finally { Clear-CategoryStatusFilter -Category $cat }
    }

    It 'el filtro sigue puesto al volver a la sección' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]
        Switch-CategoryStatusFilter -Category $cat -Status $estado
        try {
            Show-View -Name 'Show-OptimizationsListView'
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
            Assert-Equal ([int](Get-CategoryStatusCounts $cat).$estado) (Get-VisibleSettingCards $ventana).Count
        }
        finally { Clear-CategoryStatusFilter -Category $cat }
    }

    It 'llegar desde la búsqueda quita el filtro para que se vea el ajuste buscado' {
        $ventana = Open-FilterTestSection
        $cat = Get-FilterTestCategory
        $estado = (Get-PresentStatuses $cat)[0]
        $otro = @($cat.Items | Where-Object { $_.Status -ne $estado }) | Select-Object -First 1
        if (-not $otro) { Skip-Test 'todos los ajustes están en el mismo estado' }

        Switch-CategoryStatusFilter -Category $cat -Status $estado
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat; Highlight = $otro }
        Assert-Equal 0 @(Get-CategoryStatusFilter $cat).Count
        Assert-Equal @($cat.Items).Count (Get-VisibleSettingCards $ventana).Count
    }
}
