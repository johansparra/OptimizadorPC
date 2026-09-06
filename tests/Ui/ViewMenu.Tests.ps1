# ============================================================
# Pruebas del menú del botón "Vista" (ui/Components/Shell/ViewMenu.ps1).
#
# Se comprueba el árbol de controles sin enseñar la ventana, como
# en el resto de tests/Ui. Las filas se leen con Get-VisualText:
# el desplegable cuelga del Grid que devuelve New-ViewMenu, así
# que su texto se ve aunque el Popup esté cerrado.
#
# Lo que se vigila:
#   - sin -Hide salen las tres opciones de siempre;
#   - -Hide quita esa fila y deja intactas las demás;
#   - ocultar la fila NO toca la preferencia global (View.grid);
#   - el detalle de Regedit esconde "Grid view" -y solo Regedit-,
#     porque lo pide su archivo de categoría con HideViewOptions;
#   - la lista principal y las demás secciones la conservan.
# ============================================================

Describe 'ui/Components/Shell/ViewMenu.ps1 - ocultar filas con -Hide' {

    It 'sin -Hide salen las tres opciones' {
        $ventana = New-AppWindow -Language 'en'
        $texto = Get-VisualText (New-ViewMenu $ventana)

        Assert-Match 'Technical details' $texto
        Assert-Match 'New badges'        $texto
        Assert-Match 'Grid view'         $texto
    }

    It '-Hide grid quita esa fila y deja las demás' {
        $ventana = New-AppWindow -Language 'en'
        $texto = Get-VisualText (New-ViewMenu $ventana -Hide 'grid')

        Assert-Match 'Technical details' $texto 'se ha llevado por delante otra fila'
        Assert-Match 'New badges'        $texto 'se ha llevado por delante otra fila'
        Assert-False ($texto -match 'Grid view') 'la fila de cuadrícula seguía en el menú'
    }

    It 'ocultar la fila no cambia el valor guardado de la opción' {
        $ventana = New-AppWindow
        Set-ViewOption 'grid' $true
        try {
            New-ViewMenu $ventana -Hide 'grid' | Out-Null
            Assert-True (Get-ViewOption 'grid') 'construir el menú sin la fila ha tocado la preferencia'
        }
        finally { Set-ViewOption 'grid' $false }
    }

    It 'un id que no existe en -Hide no rompe nada' {
        $ventana = New-AppWindow -Language 'en'
        Assert-NoThrow { New-ViewMenu $ventana -Hide 'noexiste' }
        $texto = Get-VisualText (New-ViewMenu $ventana -Hide 'noexiste')
        Assert-Match 'Grid view' $texto 'no debía quitar ninguna fila'
    }
}

Describe 'ui/Views/CategoryDetailView.ps1 - el menú Vista por sección' {

    It 'Regedit lo pide en sus datos' {
        Assert-Contains 'grid' (Get-CategoryById 'regedit').HideViewOptions `
            'Regedit ya no declara HideViewOptions'
    }

    It 'el detalle de Regedit no ofrece "Grid view"' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'regedit') }

        $texto = Get-VisualText $ventana.FindName('HeaderActionsArea')
        Assert-Match 'Technical details' $texto 'el menú Vista no se ha pintado'
        Assert-False ($texto -match 'Grid view') 'Regedit sigue ofreciendo la cuadrícula'
    }

    It 'el detalle de las demás secciones sí la ofrece' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = (Get-CategoryById 'power') }

        Assert-Match 'Grid view' (Get-VisualText $ventana.FindName('HeaderActionsArea')) `
            'una sección sin HideViewOptions ha perdido la opción'
    }

    It 'la lista principal conserva "Grid view"' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-OptimizationsListView'

        Assert-Match 'Grid view' (Get-VisualText $ventana.FindName('HeaderActionsArea'))
    }
}
