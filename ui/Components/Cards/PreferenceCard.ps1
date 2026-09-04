# ============================================================
# Componente: tarjeta de preferencia
#
# Dibuja una opción de ui/Data/Preferences/. Mismo aspecto que las
# tarjetas de ajuste de una categoría, pero conectada a los
# scriptblocks Get y Set de la preferencia.
# ============================================================

function New-PreferenceCard {
    param($Window, $Preference)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $Window.FindResource('StaticCardStyle')
    $card.Padding = New-Object System.Windows.Thickness 20, 15, 20, 16

    $grid = New-Object System.Windows.Controls.Grid
    Add-GridColumns $grid '*', 'Auto'

    # ---- izquierda: título y explicación ----
    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = 'Center'

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = T $Preference.Label
    $label.FontFamily = $Window.FindResource('DisplayFont')
    $label.FontWeight = 'SemiBold'
    $label.FontSize = 13.5
    Set-TextFg $label 'Text'
    $left.Children.Add($label) | Out-Null

    if ($Preference.Description) {
        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = T $Preference.Description
        $desc.FontSize = 11.5
        $desc.TextWrapping = 'Wrap'
        $desc.LineHeight = 17
        $desc.Margin = New-Object System.Windows.Thickness 0, 5, 30, 0
        Set-TextFg $desc 'TextMuted'
        $left.Children.Add($desc) | Out-Null
    }

    Add-ToColumn $grid $left 0
    Add-ToColumn $grid (New-PreferenceControl $Window $Preference) 1

    $card.Child = $grid
    $card
}

function New-PreferenceControl {
    param($Window, $Preference)

    $holder = New-Object System.Windows.Controls.StackPanel
    $holder.Orientation = 'Horizontal'
    $holder.VerticalAlignment = 'Center'

    switch ($Preference.Type) {

        'Choice' {
            $options = @(Get-PreferenceOptions $Preference)
            $current = & $Preference.Get

            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Style = $Window.FindResource('ModernComboStyle')
            $combo.Width = 220
            foreach ($option in $options) {
                if ($Preference.TranslateOptions) { $combo.Items.Add((T $option.Label)) | Out-Null }
                else                              { $combo.Items.Add($option.Label)     | Out-Null }
            }

            $index = 0
            for ($i = 0; $i -lt $options.Count; $i++) {
                if ($options[$i].Value -eq $current) { $index = $i }
            }
            $combo.SelectedIndex = $index

            # El Tag lleva lo necesario para resolver el cambio sin
            # closures (regla 4 de CLAUDE.md).
            $combo.Tag = [PSCustomObject]@{ Preference = $Preference; Options = $options }

            # El handler se engancha DESPUÉS de fijar la selección
            # inicial, o saltaría al construir la tarjeta.
            $combo.Add_SelectionChanged({
                param($s, $e)
                $info = $s.Tag
                if ($s.SelectedIndex -lt 0) { return }
                $value = $info.Options[$s.SelectedIndex].Value
                if ($value -eq (& $info.Preference.Get)) { return }
                & $info.Preference.Set $value
            })

            $holder.Children.Add($combo) | Out-Null
        }

        'Toggle' {
            $current = [bool](& $Preference.Get)

            $state = New-Object System.Windows.Controls.TextBlock
            if ($current) { $state.Text = T 'On' } else { $state.Text = T 'Off' }
            $state.FontSize = 11.5
            $state.FontWeight = 'SemiBold'
            $state.Width = 30
            $state.TextAlignment = 'Right'
            $state.VerticalAlignment = 'Center'
            $state.Margin = New-Object System.Windows.Thickness 0, 0, 10, 0
            Set-TextFg $state 'TextMuted'
            $holder.Children.Add($state) | Out-Null

            $toggle = New-ToggleSwitch -Window $Window -InitialState $current -Label $state
            # Se añade la preferencia al Tag que ya usa el interruptor
            # para su propio estado.
            $toggle.Tag | Add-Member -NotePropertyName Preference -NotePropertyValue $Preference -Force
            $toggle.Add_MouseLeftButtonUp({
                param($s, $e)
                & $s.Tag.Preference.Set $s.Tag.State
            })
            $holder.Children.Add($toggle) | Out-Null
        }
    }

    $holder
}
