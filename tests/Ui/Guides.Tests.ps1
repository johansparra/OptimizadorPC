# ============================================================
# Pruebas de la sección Guías:
#   ui/Engine/Markdown.ps1              leer Markdown
#   ui/Engine/GuideRegistry.ps1         registrar los .md
#   ui/Components/Layout/MarkdownDocument.ps1, Cards/GuideCard.ps1
#   ui/Views/GuidesView.ps1             las dos pantallas
#
# Las guías de verdad (ui/Data/Guides) las carga el arnés por el mismo
# marcador que main.ps1 (# @@EMBED_GUIDES@@).
# ============================================================

function Get-TestBlocks { param([string]$Text) @(Get-MarkdownBlocks $Text) }

Describe 'ui/Engine/Markdown.ps1 - bloques' {

    It 'títulos, separador y párrafo, en orden' {
        $b = Get-TestBlocks "# Uno`n`n## Dos`n---`ntexto"
        Assert-Equal 'heading heading rule paragraph' (($b | ForEach-Object { $_.Type }) -join ' ')
        Assert-Equal 1 $b[0].Level
        Assert-Equal 'Dos' $b[1].Text
    }

    It 'un párrafo cortado a mano se junta; una línea que empieza en negrita abre otra' {
        $p = (Get-TestBlocks "Todo esto en el editor,`ndentro de la biblioteca.")[0]
        Assert-Equal 1 @($p.Lines).Count
        Assert-Equal 'Todo esto en el editor, dentro de la biblioteca.' $p.Lines[0]

        $p = (Get-TestBlocks "**Qué hace:** limita`n**Valores:** 10")[0]
        Assert-Equal 2 @($p.Lines).Count 'cada dato de la guía va en su línea'
    }

    It 'el código conserva su sangría y su lenguaje, y lo de dentro no se interpreta' {
        $c = (Get-TestBlocks "``````Powershell`n  # dentro`n| no | tabla |`n``````")[0]
        Assert-Equal 'code' $c.Type
        Assert-Equal 'Powershell' $c.Lang
        Assert-Equal "  # dentro`n| no | tabla |" $c.Text
    }

    It 'una tabla: cabecera, filas, y la barra dentro de código no parte la celda' {
        $t = (Get-TestBlocks "| A | B |`n| --- | --- |`n| ``x|y`` | dos |")[0]
        Assert-Equal 'table' $t.Type
        Assert-Equal 'A | B' ($t.Header -join ' | ')
        Assert-Equal '`x|y`' $t.Rows[0][0]
        Assert-Equal 'dos' $t.Rows[0][1]
    }

    It 'las listas se anidan por sangría y las numeradas guardan su número' {
        $l = (Get-TestBlocks "- uno`n  - dentro`n- dos")[0]
        Assert-Equal '0 1 0' ((@($l.Items) | ForEach-Object { $_.Level }) -join ' ')
        $n = (Get-TestBlocks "3. tres`n4. cuatro")[0]
        Assert-True $n.Items[0].Ordered
        Assert-Equal 3 $n.Items[0].Number
    }

    It 'una cita junta sus líneas' {
        $q = (Get-TestBlocks "> Nota: esto`n> sigue aquí")[0]
        Assert-Equal 'quote' $q.Type
        Assert-Equal 'Nota: esto sigue aquí' $q.Lines[0]
    }
}

Describe 'ui/Engine/Markdown.ps1 - dentro de una línea' {

    It 'negrita con código dentro, enlaces sueltos sin el punto final, y cursiva' {
        $t = @(Get-MarkdownInlines 'Ver **`Clave` aquí** en https://x.com/a. y *(nota)*')
        $codigo = $t | Where-Object { $_.Code }
        Assert-Equal 'Clave' $codigo.Text
        Assert-True $codigo.Bold 'el código de dentro de la negrita también es negrita'
        $url = $t | Where-Object { $_.Url }
        Assert-Equal 'https://x.com/a' $url.Url
        Assert-True (($t | Where-Object { $_.Italic }).Text -eq '(nota)')
    }

    It 'un asterisco suelto no abre cursiva' {
        $t = @(Get-MarkdownInlines 'SharingViolation* y 2*3')
        Assert-Equal 0 @($t | Where-Object { $_.Italic }).Count
        Assert-Equal 'SharingViolation* y 2*3' (Get-MarkdownPlainText 'SharingViolation* y 2*3')
    }
}

Describe 'ui/Engine/GuideRegistry.ps1 - registrar' {

    It 'las cuatro guías de ui/Data/Guides están registradas, con su título' {
        $ids = @(Get-Guides | ForEach-Object { $_.Id })
        foreach ($id in 'claves_registro_bf6', 'gpedit_gaming_tweaks', 'nic_i211_gaming_tweaks', 'task_scheduler_gaming_tweaks') {
            Assert-Contains $id $ids "falta $id"
        }
        Assert-Match '^gpedit\.msc' (Get-GuideById 'gpedit_gaming_tweaks').Title 'el título es el primer "# ", sin marcas'
    }

    It 'título, resumen, secciones y minutos salen del propio texto' {
        $copia = $GuideList.ToArray()
        try {
            Register-Guide -FileName 'prueba.md' -Markdown "# Mi **guía**`n`nIntro que`nsigue.`n`n## 1) Primera`ntexto`n## 2b) Segunda"
            $g = Get-GuideById 'prueba'
            Assert-Equal 'Mi guía' $g.Title
            Assert-Equal 'Intro que sigue.' $g.Summary
            Assert-Equal 2 $g.Sections
            Assert-True ($g.Minutes -ge 1)

            # Sin entrada, el resumen son las secciones, sin su numeración.
            Register-Guide -FileName 'prueba.md' -Markdown "## 1) Una`n## 6-13) Otra"
            $g = Get-GuideById 'prueba'
            Assert-Equal 'prueba' $g.Title 'sin "# " el título es el nombre del archivo'
            Assert-Equal 'Una · Otra' $g.Summary
            Assert-Equal 1 @(Get-Guides | Where-Object { $_.Id -eq 'prueba' }).Count 'registrarla otra vez la ha duplicado'
        }
        finally {
            $GuideList.Clear()
            foreach ($g in $copia) { $GuideList.Add($g) }
        }
    }

    It 'lo que build.ps1 mete en Base64 vuelve igual, aunque el .md traiga de todo' {
        # Un '@ a principio de línea cerraría un aquí-string: por eso Base64.
        $texto = "# Título`n'@`n""comillas"" y 'simples' ✅ — ñ`n```````n@'`n```````n"
        $b64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($texto))
        Assert-Equal $texto (ConvertFrom-GuideBase64 $b64)
    }

    It 'como texto normal: sin asteriscos ni barras, y las tablas con tabuladores' {
        $plano = ConvertTo-GuidePlainText (Get-GuideById 'gpedit_gaming_tweaks')
        Assert-False ($plano -match '\*\*') 'quedan asteriscos de negrita'
        Assert-Match "QoS Packet Scheduler = 0%`tAlto" $plano
        Assert-Match '(?m)^gpedit\.msc' $plano
    }
}

Describe 'ui/Views/GuidesView.ps1 - la lista' {

    It 'el menú lateral trae Guías y lleva a su pantalla' {
        $ventana = New-AppWindow -Language 'en'
        Build-Sidebar -Window $ventana
        Assert-NotNull $ventana.FindName('NavGuides')
        Show-View -Name 'Show-GuidesView'
        Assert-Equal 'sel' ([string]$ventana.FindName('NavGuides').Tag)
    }

    It 'una tarjeta por guía, con su título' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-GuidesView'
        $lista = $ventana.FindName('MainContent').Content
        Assert-Equal @(Get-Guides).Count $lista.Children.Count
        $texto = Get-VisualText $lista
        foreach ($g in @(Get-Guides)) { Assert-Match ([regex]::Escape($g.Title)) $texto }
    }

    It 'sin guías, lo dice y explica dónde ponerlas' {
        $copia = $GuideList.ToArray()
        try {
            $GuideList.Clear()
            $ventana = New-AppWindow -Language 'en'
            Show-View -Name 'Show-GuidesView'
            Assert-Match 'No guides yet' (Get-VisualText $ventana.FindName('MainContent').Content)
        }
        finally { foreach ($g in $copia) { $GuideList.Add($g) } }
    }

    It 'pulsar una tarjeta abre su guía' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-GuidesView'
        $tarjeta = $ventana.FindName('MainContent').Content.Children[0]
        $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
        $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
        $tarjeta.RaiseEvent($clic)
        Assert-Equal 'Show-GuideView' (Get-CurrentViewName)
        Assert-Equal $tarjeta.Tag.Id $CurrentView.Arguments.Guide.Id
    }
}

Describe 'ui/Views/GuidesView.ps1 - una guía abierta' {

    It 'se lee en un RichTextBox de solo lectura: se selecciona y se copia' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-GuideView' -Arguments @{ Guide = (Get-GuideById 'gpedit_gaming_tweaks') }
        # Sin @(): Find-Visuals ya devuelve el array entero, y envuelto
        # quedaría un array dentro de otro (y Array.IsReadOnly es $false).
        $caja = Find-Visuals $ventana.FindName('MainContent').Content { param($el) $el -is [System.Windows.Controls.RichTextBox] }
        Assert-Equal 1 $caja.Count
        Assert-True $caja[0].IsReadOnly
        Assert-True $caja[0].IsDocumentEnabled 'sin esto los enlaces y los botones de copiar no responden'

        $doc = $caja[0].Document
        $todo = (New-Object System.Windows.Documents.TextRange $doc.ContentStart, $doc.ContentEnd).Text
        Assert-Match 'Programador de paquetes QoS' $todo
        Assert-False ($todo -match '\*\*') 'se ven los asteriscos del Markdown'
    }

    It 'trae una tabla, una lista anidada, enlaces y un botón de copiar por bloque de código' {
        $ventana = New-AppWindow -Language 'en'
        $guia = Get-GuideById 'gpedit_gaming_tweaks'
        $doc = New-GuideDocument -Window $ventana -Guide $guia
        $flow = $doc.Child.Document
        $bloques = @($flow.Blocks)
        Assert-True (@($bloques | Where-Object { $_ -is [System.Windows.Documents.Table] }).Count -ge 1) 'falta la tabla'
        $listas = @($bloques | Where-Object { $_ -is [System.Windows.Documents.List] })
        $anidada = @($listas | Where-Object { @($_.ListItems | Where-Object { @($_.Blocks | Where-Object { $_ -is [System.Windows.Documents.List] }).Count }).Count })
        Assert-True ($anidada.Count -ge 1) 'la lista anidada se ha aplanado'

        $codigos = @(@(Get-GuideBlocks $guia) | Where-Object { $_.Type -eq 'code' }).Count
        # Solo las de código (empiezan con la franja del botón): el índice también es una Section.
        $secciones = @($bloques | Where-Object { $_ -is [System.Windows.Documents.Section] -and $_.Blocks.FirstBlock -is [System.Windows.Documents.BlockUIContainer] })
        Assert-Equal $codigos $secciones.Count
        $boton = $secciones[0].Blocks.FirstBlock.Child.Children | Where-Object { $_.Name -eq 'BtnCopy' }
        Assert-NotNull $boton 'el bloque de código no trae su botón de copiar'
        Assert-Equal '.\"Eliminar apps.ps1"' $boton.Tag.Text
    }

    It 'la miga vuelve a Guías, y el título es el de la guía sin traducir' {
        $ventana = New-AppWindow -Language 'es'
        try {
            Reset-TranslationAudit
            $guia = Get-GuideById 'nic_i211_gaming_tweaks'
            Show-View -Name 'Show-GuideView' -Arguments @{ Guide = $guia }
            $cabecera = Get-VisualText $ventana.FindName('HeaderTitleArea')
            Assert-Match 'Guías' $cabecera
            Assert-Match ([regex]::Escape($guia.Title)) $cabecera
            Assert-Equal 0 @(Get-MissingTranslations 'es').Count ('sin traducir: ' + (@(Get-MissingTranslations 'es') -join ' | '))

            $atras = $ventana.FindName('HeaderTitleArea').Children[0].Children[0]
            $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
            $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
            $atras.RaiseEvent($clic)
            Assert-Equal 'Show-GuidesView' (Get-CurrentViewName)
        }
        finally { Set-AppLanguage 'en' }
    }

    It 'la lista de guías tampoco deja nada sin traducir' {
        $null = New-AppWindow -Language 'es'
        try {
            Reset-TranslationAudit
            Show-View -Name 'Show-GuidesView'
            Assert-Equal 0 @(Get-MissingTranslations 'es').Count ('sin traducir: ' + (@(Get-MissingTranslations 'es') -join ' | '))
        }
        finally { Set-AppLanguage 'en' }
    }
}

Describe 'ui/Components/Layout/MarkdownDocument.ps1 - índice y buscar dentro' {

    It 'una guía con tres o más secciones trae su índice, justo después del título' {
        $ventana = New-AppWindow -Language 'en'
        $doc = (New-GuideDocument -Window $ventana -Guide (Get-GuideById 'gpedit_gaming_tweaks')).Child.Document
        $segundo = @($doc.Blocks)[1]
        Assert-True ($segundo -is [System.Windows.Documents.Section]) 'el índice no está tras el título'
        $todo = (New-Object System.Windows.Documents.TextRange $segundo.ContentStart, $segundo.ContentEnd).Text
        Assert-Match 'Contents' $todo
        Assert-Match 'Programador de paquetes QoS' $todo
    }

    It 'una guía con menos de tres secciones no lo trae' {
        $ventana = New-AppWindow -Language 'en'
        $doc = (New-GuideDocument -Window $ventana -Guide (Get-GuideById 'nic_i211_gaming_tweaks')).Child.Document
        Assert-Equal 0 @(@($doc.Blocks) | Where-Object { $_ -is [System.Windows.Documents.Section] -and
            (New-Object System.Windows.Documents.TextRange $_.ContentStart, $_.ContentEnd).Text -match '^Contents' }).Count
    }

    It 'buscar marca la primera aparición, cuenta todas y Enter pasa a la siguiente' {
        $ventana = New-AppWindow -Language 'en'
        $caja = (New-GuideDocument -Window $ventana -Guide (Get-GuideById 'gpedit_gaming_tweaks')).Child
        $n = Select-MarkdownMatch $caja 'habilitada' -FromStart
        Assert-True ($n -ge 2) "debería haber varias, hay $n"
        # Si la aparición abre un elemento de lista, Selection.Text trae delante la viñeta y un tabulador.
        Assert-Equal 'habilitada' ($caja.Selection.Text -replace '^[^\p{L}]+', '').ToLowerInvariant()
        $primera = $caja.Selection.Start
        Select-MarkdownMatch $caja 'habilitada' | Out-Null
        Assert-True ($caja.Selection.Start.CompareTo($primera) -gt 0) 'no ha pasado a la siguiente'
        Assert-Equal 0 (Select-MarkdownMatch $caja 'zzzz-no-existe' -FromStart)
    }

    It 'la caja de la cabecera dice cuántas hay' {
        $ventana = New-AppWindow -Language 'en'
        Show-View -Name 'Show-GuideView' -Arguments @{ Guide = (Get-GuideById 'gpedit_gaming_tweaks') }
        $caja = Find-Visuals $ventana.FindName('HeaderActionsArea') { param($el) $el -is [System.Windows.Controls.TextBox] }
        $caja[0].Text = 'QoS'
        Assert-Match '\d+ matches|1 match' $caja[0].Tag.Status.Text
    }
}
