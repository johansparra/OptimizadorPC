# ============================================================
# Vista: sección de comandos (hoy Internet)
#
# La abre Show-CategoryDetailView cuando la sección declara Steps.
# Solo ensambla:
#
#   cabecera   breadcrumb + "N de M marcados" + selección rápida
#   fijo       el marco de ejecución (ui/Components/Layout/StepRunPanel.ps1),
#              bajo el título y fuera del scroll: se ve siempre
#   cuerpo     una fila por paso (ui/Components/Cards/StepRow.ps1),
#              agrupadas por fase, en el ORDEN DE EJECUCIÓN
#
# Si hay una ejecución en marcha -o terminada- se pinta tal cual
# está: el estado vive en el marco, no en esta pantalla.
# ============================================================

function Show-CategoryStepsView {
    param($Window, $Category)

    $steps = @($Category.Steps)

    # ---- 1. Cabecera ----
    Clear-PageHeader $Window
    Set-PageBreadcrumb -Window $Window -Category $Category

    Add-PageAction $Window (New-StepSelectedLabel $Window)

    # Selección rápida. Cada botón lleva la sección en el Tag (regla 4).
    $chips = @(
        @{ Name = 'StepSelectDefault'; Text = 'Recommended'; Icon = 'StarFill'; Mode = 'default'
           Tip = 'Select the commands that come checked by default' }
        @{ Name = 'StepSelectAll';     Text = 'All';         Icon = 'CheckOn';  Mode = 'all'
           Tip = 'Select every command' }
        @{ Name = 'StepSelectNone';    Text = 'None';        Icon = 'CheckOff'; Mode = 'none'
           Tip = 'Clear the selection' }
    )
    foreach ($c in $chips) {
        $chip = New-ChipButton $Window $c.Text $c.Icon
        $chip.ToolTip = T $c.Tip
        $chip.Tag = [PSCustomObject]@{ Category = $Category; Mode = $c.Mode }
        $chip.Add_Click({ param($s, $e) Set-StepSelection -Category $s.Tag.Category -Mode $s.Tag.Mode })
        Register-StepRunName $Window $c.Name $chip
        Add-PageAction $Window $chip
    }

    # ---- 2. El marco fijo de ejecución ----
    Set-PageDock $Window (New-StepRunPanel -Window $Window -Category $Category)

    # ---- 3. Cuerpo: los pasos, por fase y en orden ----
    $list = New-Object System.Windows.Controls.StackPanel
    $list.Margin = New-Object System.Windows.Thickness 0, 6, 0, 0
    Register-StepRunName $Window 'StepList' $list

    if ($Category.Locked) { $list.Children.Add((New-LockedBanner)) | Out-Null }

    $group = $null
    $number = 0
    foreach ($step in $steps) {
        $number++
        if ($step.Group -and $step.Group -ne $group) {
            $group = $step.Group
            $list.Children.Add((New-SectionHeader $Window (T $group))) | Out-Null
        }
        $list.Children.Add((New-StepRow -Window $Window -Step $step -Number $number)) | Out-Null
    }

    $Window.FindName('MainContent').Content = $list
    Start-StaggeredEnter $list

    Sync-StepRunPanel
}
