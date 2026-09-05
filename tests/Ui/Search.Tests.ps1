# ============================================================
# Pruebas del buscador global.
#
# Se prueba contra las secciones DE VERDAD, no contra un montaje
# de mentira: lo que se quiere saber es si buscando "telemetría" o
# media ruta del registro aparece lo que hay declarado en
# ui/Data/Categories/, y con una categoría inventada eso no se
# comprueba.
#
# El desplegable se prueba por su CONTENIDO -New-SearchPopupCard-
# y no abriéndolo. Un Popup con IsOpen = $true se crea su propia
# ventana de Windows, y estas pruebas corren sin ventana a la
# vista: abrirlo pintaría una tarjeta flotante en la pantalla de
# quien las lanza, y con -BothHosts serían dos.
#
# El índice se guarda entre búsquedas, así que cualquier prueba
# que cambie de idioma o toque el registro tiene que llamar a
# Reset-SearchIndex — igual que hace la aplicación.
# ============================================================

$SearchWindow = New-AppWindow

# Con las claves ya leídas: el Current y el Status de cada ajuste
# solo existen después de preguntarle al equipo, y los dos se
# indexan. Sin esto no habría forma de probar que se busca por el
# valor que hay puesto ahora mismo.
Update-CategoryRegistryState -Category (Get-CategoryById 'regedit') | Out-Null
Reset-SearchIndex

# La primera clave declarada de la sección regedit, para preguntar
# por su ruta de verdad en vez de por una escrita a mano aquí.
function Get-SearchTestKey {
    foreach ($setting in @((Get-CategoryById 'regedit').Items)) {
        foreach ($key in @($setting.Registry)) { return $key }
    }
    $null
}

function Get-SearchTestSetting {
    foreach ($setting in @((Get-CategoryById 'regedit').Items)) {
        if (@($setting.Registry).Count -gt 0) { return $setting }
    }
    $null
}

# Los nombres de los ajustes que ha devuelto una búsqueda.
function Get-SearchNames {
    param($Results)
    , @(@($Results) | Where-Object { $_.Setting } | ForEach-Object { [string]$_.Setting.Name })
}


Describe 'ui/Engine/Search.ps1 - el índice' {

    It 'trae una entrada por sección y otra por cada ajuste' {
        $esperadas = 0
        foreach ($cat in Get-OptimizationCategories) {
            $esperadas += 1 + @($cat.Items).Count
        }
        Assert-Equal $esperadas @(Get-SearchIndex).Count
    }

    It 'se reutiliza mientras nadie lo tire' {
        # No se comparan los dos arrays: devolver un array desde una
        # función lo manda por la tubería y el que llama recibe uno
        # nuevo cada vez, aunque el guardado sea el mismo. Lo que sí
        # sobrevive es la marca puesta en una entrada.
        (Get-SearchIndex)[0] | Add-Member -NotePropertyName 'Marca' -NotePropertyValue 'sí' -Force
        Assert-Equal 'sí' ([string](Get-SearchIndex)[0].Marca) 'el índice se está reconstruyendo en cada búsqueda'
    }

    It 'reiniciarlo lo vuelve a construir' {
        (Get-SearchIndex)[0] | Add-Member -NotePropertyName 'Marca' -NotePropertyValue 'sí' -Force
        Reset-SearchIndex
        Assert-Equal '' ([string](Get-SearchIndex)[0].Marca) 'Reset-SearchIndex no ha tirado el índice'
    }

    It 'cada entrada lleva su pajar en minúsculas' {
        foreach ($entrada in (Get-SearchIndex)) {
            Assert-Equal $entrada.Haystack $entrada.Haystack.ToLowerInvariant()
        }
    }
}


Describe 'ui/Engine/Search.ps1 - buscar' {

    It 'sin texto no devuelve nada' {
        Assert-Equal 0 @(Get-SearchResults '').Count
        Assert-Equal 0 @(Get-SearchResults '   ').Count
    }

    It 'no distingue mayúsculas de minúsculas' {
        $ajuste = Get-SearchTestSetting
        $arriba = Get-SearchNames (Get-SearchResults $ajuste.Name.ToUpperInvariant())
        $abajo  = Get-SearchNames (Get-SearchResults $ajuste.Name.ToLowerInvariant())

        Assert-True ($arriba.Count -gt 0) "no encuentra '$($ajuste.Name)'"
        Assert-Equal ($abajo -join '|') ($arriba -join '|')
    }

    It 'encuentra por un trozo de palabra' {
        $ajuste = Get-SearchTestSetting
        $trozo = $ajuste.Name.Substring(1, [Math]::Min(6, $ajuste.Name.Length - 1))

        Assert-Contains $ajuste.Name (Get-SearchNames (Get-SearchResults $trozo))
    }

    It 'encuentra por un trozo de la ruta del registro' {
        $clave = Get-SearchTestKey
        Assert-NotNull $clave 'la sección regedit no declara ninguna clave'

        # Un tramo de en medio, que es como se busca de verdad: se
        # recuerda un pedazo de la ruta, no la ruta entera.
        $tramos = @($clave.Path -split '\\')
        $trozo = $tramos[$tramos.Count - 1]

        $encontrados = Get-SearchNames (Get-SearchResults $trozo)
        Assert-True ($encontrados.Count -gt 0) "'$trozo' no encuentra nada"
    }

    It 'encuentra por la ruta entera del registro' {
        $clave = Get-SearchTestKey
        $encontrados = Get-SearchNames (Get-SearchResults $clave.Path)
        Assert-True ($encontrados.Count -gt 0) "la ruta '$($clave.Path)' no encuentra nada"
    }

    It 'encuentra por el nombre del valor del registro' {
        $clave = Get-SearchTestKey
        $encontrados = Get-SearchNames (Get-SearchResults $clave.Name)
        Assert-True ($encontrados.Count -gt 0) "el valor '$($clave.Name)' no encuentra nada"
    }

    It 'encuentra por la sección aunque ningún ajuste se llame así' {
        $seccion = Get-CategoryById 'regedit'
        $entradas = @(Get-SearchResults $seccion.Name)
        $secciones = @($entradas | Where-Object { $_.Kind -eq 'category' })

        Assert-True ($secciones.Count -gt 0) "buscar '$($seccion.Name)' no devuelve la sección"
    }

    It 'varias palabras piden todas, no la frase' {
        $ajuste = Get-SearchTestSetting

        # Su nombre y algo que solo está en su sección: las dos
        # cosas juntas siguen encontrándolo.
        $consulta = '{0} {1}' -f $ajuste.Name, (Get-CategoryById 'regedit').Name
        Assert-Contains $ajuste.Name (Get-SearchNames (Get-SearchResults $consulta))

        # Y una palabra imposible junto a otra buena no devuelve nada.
        $imposible = '{0} zzqqxx' -f $ajuste.Name
        Assert-Equal 0 @(Get-SearchResults $imposible).Count
    }

    It 'lo que no está no aparece' {
        Assert-Equal 0 @(Get-SearchResults 'zzqqxx-esto-no-existe').Count
    }

    It 'dice por qué campo ha encajado' {
        $clave = Get-SearchTestKey
        $entradas = @(Get-SearchResults $clave.Path)

        Assert-True ($entradas.Count -gt 0) 'sin resultados no hay nada que explicar'
        foreach ($entrada in $entradas) {
            Assert-NotNull $entrada.Match "un resultado de '$($clave.Path)' sin campo que lo explique"
        }
        Assert-Equal 'Registry path' $entradas[0].Match.Label
    }
}


Describe 'ui/Engine/Search.ps1 - agrupar' {

    It 'agrupa por sección sin repetir ninguna' {
        $entradas = @(Get-SearchResults 'e')
        Assert-True ($entradas.Count -gt 1) 'hacen falta varios resultados para probar el agrupado'

        $grupos = @(Group-SearchResults $entradas)
        $ids = @($grupos | ForEach-Object { [string]$_.Category.Id })

        Assert-Equal $ids.Count (@($ids | Sort-Object -Unique)).Count
    }

    It 'no se pierde ni se inventa ningún resultado' {
        $entradas = @(Get-SearchResults 'e')
        $sumados = 0
        foreach ($grupo in (Group-SearchResults $entradas)) { $sumados += $grupo.Entries.Count }

        Assert-Equal $entradas.Count $sumados
    }

    It 'los grupos salen en el orden en que aparecen' {
        $entradas = @(Get-SearchResults 'e')
        $grupos = @(Group-SearchResults $entradas)

        $primeroDelIndice = [string]$entradas[0].Category.Id
        Assert-Equal $primeroDelIndice ([string]$grupos[0].Category.Id)
    }
}


Describe 'ui/Engine/Search.ps1 - los dos idiomas' {

    It 'en español se busca en español' {
        # El texto traducido de verdad, sacado del diccionario: así
        # la prueba no depende de que nadie cambie una frase.
        Set-AppLanguage 'es'
        Reset-SearchIndex

        $ajuste = Get-SearchTestSetting
        $traducido = T $ajuste.Name

        if ($traducido -eq $ajuste.Name) {
            Set-AppLanguage 'en'
            Reset-SearchIndex
            Skip-Test "'$($ajuste.Name)' no está traducido: no hay nada que comprobar"
            return
        }

        $encontrados = @(Get-SearchResults $traducido)
        Set-AppLanguage 'en'
        Reset-SearchIndex

        Assert-True ($encontrados.Count -gt 0) "'$traducido' no encuentra su ajuste con la aplicación en español"
    }

    It 'en español el original en inglés sigue encontrando' {
        # Quien busca "telemetry" con la aplicación en español
        # espera encontrarlo igual: es el texto que sale en las
        # rutas y en la documentación.
        Set-AppLanguage 'es'
        Reset-SearchIndex

        $ajuste = Get-SearchTestSetting
        $encontrados = @(Get-SearchResults $ajuste.Name)

        Set-AppLanguage 'en'
        Reset-SearchIndex

        Assert-True ($encontrados.Count -gt 0) "'$($ajuste.Name)' deja de encontrarse en español"
    }

    It 'todas las etiquetas del buscador están traducidas' {
        # No se escriben aquí a mano: se sacan del índice, así que
        # una etiqueta nueva en Get-SettingSearchFields entra sola
        # en esta prueba.
        $etiquetas = @{}
        foreach ($entrada in (Get-SearchIndex)) {
            foreach ($campo in @($entrada.Fields)) { $etiquetas[[string]$campo.Label] = $true }
        }
        Assert-True ($etiquetas.Count -gt 3) 'el índice no trae campos con etiqueta'

        foreach ($idioma in Get-AvailableLanguages) {
            if ($idioma.Source) { continue }
            Set-AppLanguage $idioma.Code
            foreach ($etiqueta in $etiquetas.Keys) {
                Assert-NotEqual $etiqueta (T $etiqueta) "'$etiqueta' sin traducir en '$($idioma.Code)'"
            }
        }
        Set-AppLanguage 'en'
        Reset-SearchIndex
    }
}


Describe 'ui/Views/SearchResultsView.ps1' {

    It 'pinta una cabecera de grupo y una tarjeta por resultado' {
        Set-SearchQuery 'e'
        Show-View -Name 'Show-SearchResultsView'

        $cuerpo = $SearchWindow.FindName('MainContent').Content
        $tarjetas = Find-Visuals $cuerpo { param($el) $el -is [System.Windows.Controls.Border] -and $el.Tag -and $el.Tag.PSObject.Properties['Category'] }

        Assert-Equal @(Get-SearchResults 'e').Count $tarjetas.Count
    }

    It 'dice cuántos ha encontrado' {
        Set-SearchQuery 'e'
        Show-View -Name 'Show-SearchResultsView'

        # El -f va FUERA de los paréntesis del método: dentro, la
        # coma separa argumentos y {1} se quedaría sin valor
        # (regla 20 de CLAUDE.md).
        $esperado = (T '{0} results for "{1}"') -f @(Get-SearchResults 'e').Count, 'e'

        $texto = Get-VisualText $SearchWindow.FindName('MainContent').Content
        Assert-Match ([regex]::Escape($esperado)) $texto
    }

    It 'sin coincidencias avisa, no deja la página en blanco' {
        Set-SearchQuery 'zzqqxx-esto-no-existe'
        Show-View -Name 'Show-SearchResultsView'

        $texto = Get-VisualText $SearchWindow.FindName('MainContent').Content
        Assert-Match 'zzqqxx-esto-no-existe' $texto
        Assert-True ($texto.Length -gt 0) 'la página se ha quedado vacía'
    }

    It 'sin texto invita a escribir en vez de decir que nada coincide' {
        Set-SearchQuery ''
        Show-View -Name 'Show-SearchResultsView'

        $texto = Get-VisualText $SearchWindow.FindName('MainContent').Content
        Assert-Match ([regex]::Escape((T 'Type to search'))) $texto
    }

    It 'repintar el cuerpo no destruye la caja de búsqueda' {
        # Es la razón de ser de Update-SearchResults: si la cabecera
        # se rehiciera, cada tecla se llevaría por delante el control
        # en el que se está escribiendo.
        Set-SearchQuery 'e'
        Show-View -Name 'Show-SearchResultsView'

        $cabecera = $SearchWindow.FindName('HeaderActionsArea')
        $antes = (Find-Visuals $cabecera { param($el) $el -is [System.Windows.Controls.TextBox] })[0]

        Set-SearchQuery 'ee'
        Update-SearchResults $SearchWindow

        $despues = (Find-Visuals $cabecera { param($el) $el -is [System.Windows.Controls.TextBox] })[0]
        Assert-True ([object]::ReferenceEquals($antes, $despues)) 'la caja de búsqueda se ha vuelto a crear'

        Set-SearchQuery ''
    }

    It 'un resultado de ajuste lleva a su sección con el ajuste marcado' {
        $ajuste = Get-SearchTestSetting
        Set-SearchQuery $ajuste.Name
        Show-View -Name 'Show-SearchResultsView'

        $cuerpo = $SearchWindow.FindName('MainContent').Content
        $tarjeta = (Find-Visuals $cuerpo {
            param($el)
            $el -is [System.Windows.Controls.Border] -and $el.Tag -and
            $el.Tag.PSObject.Properties['Setting'] -and $el.Tag.Setting -and
            [string]$el.Tag.Setting.Name -eq $ajuste.Name
        })[0]
        Assert-NotNull $tarjeta "no hay tarjeta para '$($ajuste.Name)'"

        Open-SearchResult $tarjeta

        Assert-Equal 'Show-CategoryDetailView' (Get-CurrentViewName)

        # Y la fila de ese ajuste sale marcada: es lo que evita
        # tener que buscarla a ojo entre veinte iguales.
        $marcadas = Find-Visuals $SearchWindow.FindName('MainContent').Content {
            param($el)
            $el -is [System.Windows.Controls.Border] -and $el.BorderThickness.Left -eq 1.6
        }
        Assert-Equal 1 $marcadas.Count

        Set-SearchQuery ''
        Show-View -Name 'Show-OptimizationsListView'
    }
}


Describe 'ui/Components/Shell/SearchBar.ps1' {

    It 'la caja y el desplegable no se pelean por el Tag' {
        # El marcador "Buscar optimizaciones..." usaba el Tag de la
        # caja; el desplegable lo necesita. Si vuelve a haber dos
        # dueños, una de las dos cosas deja de funcionar.
        $barra = New-SearchBar -Window $SearchWindow
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]

        Assert-True ($caja.Tag -is [System.Windows.Controls.Primitives.Popup]) 'el Tag de la caja no lleva el desplegable'

        $marcador = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.StackPanel] -and -not $el.IsHitTestVisible })[0]
        Assert-NotNull $marcador 'no está el marcador de posición'
        Assert-Equal 'Visible' ([string]$marcador.Visibility)

        $caja.Text = 'algo'
        Assert-Equal 'Collapsed' ([string]$marcador.Visibility) 'el marcador no se aparta al escribir'

        $caja.Text = ''
        Assert-Equal 'Visible' ([string]$marcador.Visibility) 'el marcador no vuelve al borrar'
    }

    It 'nace con el texto que se le pase y sin abrir nada' {
        $barra = New-SearchBar -Window $SearchWindow -Text 'telemetry'
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]

        Assert-Equal 'telemetry' $caja.Text
        Assert-False $caja.Tag.IsOpen 'repintar con una búsqueda en marcha abre el desplegable solo'
    }

    It 'borrar la caja cierra el desplegable' {
        $barra = New-SearchBar -Window $SearchWindow
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]

        $caja.Text = ''
        Update-SearchPopup $caja

        Assert-False $caja.Tag.IsOpen 'el desplegable se queda abierto sin nada que enseñar'
        Assert-Equal '' (Get-SearchQuery)
    }

    It 'Enter lleva a la página de resultados' {
        $barra = New-SearchBar -Window $SearchWindow
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]
        $caja.Text = 'telemetry'

        # Un doble de los argumentos de la tecla: montar un
        # KeyEventArgs de verdad pide un HwndSource, y lo único que
        # mira Invoke-SearchKey es Key y Handled.
        $tecla = [PSCustomObject]@{ Key = [System.Windows.Input.Key]::Enter; Handled = $false }
        Invoke-SearchKey $caja $tecla

        Assert-True $tecla.Handled 'la tecla no se ha dado por atendida'
        Assert-Equal 'Show-SearchResultsView' (Get-CurrentViewName)
        Assert-Equal 'telemetry' (Get-SearchQuery)

        Set-SearchQuery ''
        Show-View -Name 'Show-OptimizationsListView'
    }

    It 'Enter con la caja vacía no lleva a ninguna parte' {
        $barra = New-SearchBar -Window $SearchWindow
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]
        $caja.Text = '   '

        $tecla = [PSCustomObject]@{ Key = [System.Windows.Input.Key]::Enter; Handled = $false }
        Invoke-SearchKey $caja $tecla

        Assert-False $tecla.Handled 'ha atendido una tecla que no hacía nada'
        Assert-Equal 'Show-OptimizationsListView' (Get-CurrentViewName)
    }

    It 'Escape sin desplegable abierto deja pasar la tecla' {
        # Si se la quedara, Escape dejaría de cerrar el cajón del log.
        $barra = New-SearchBar -Window $SearchWindow
        $caja = (Find-Visuals $barra { param($el) $el -is [System.Windows.Controls.TextBox] })[0]

        $tecla = [PSCustomObject]@{ Key = [System.Windows.Input.Key]::Escape; Handled = $false }
        Invoke-SearchKey $caja $tecla

        Assert-False $tecla.Handled 'la caja se ha quedado un Escape que no era suyo'
    }
}


Describe 'ui/Components/Shell/SearchBar.ps1 - el desplegable' {

    It 'enseña las primeras filas agrupadas' {
        $tarjeta = New-SearchPopupCard -Window $SearchWindow -Popup $null -Results (Get-SearchResults 'e') -Query 'e'

        $filas = Find-Visuals $tarjeta { param($el) $el -is [System.Windows.Controls.Border] -and $el.Tag -and $el.Tag.PSObject.Properties['Category'] }
        Assert-Equal $SearchPopupMax $filas.Count
    }

    It 'con más resultados de los que caben ofrece verlos todos' {
        $todos = @(Get-SearchResults 'e')
        Assert-True ($todos.Count -gt $SearchPopupMax) 'hacen falta más resultados de los que caben'

        $esperado = (T 'See all {0} results') -f $todos.Count

        $tarjeta = New-SearchPopupCard -Window $SearchWindow -Popup $null -Results $todos -Query 'e'
        $texto = Get-VisualText $tarjeta

        Assert-Match ([regex]::Escape($esperado)) $texto
    }

    It 'sin coincidencias lo dice ahí mismo' {
        $tarjeta = New-SearchPopupCard -Window $SearchWindow -Popup $null -Results @() -Query 'zzqqxx'
        Assert-Match 'zzqqxx' (Get-VisualText $tarjeta)
    }
}
