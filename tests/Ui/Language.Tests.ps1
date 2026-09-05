# ============================================================
# Pruebas de los idiomas.
#
# La gorda es la última: recorre TODA la interfaz y comprueba
# que no ha quedado ni un texto sin traducir. Es la única forma
# de cazar la regla 15 de CLAUDE.md, porque un literal que no
# pasa por T no falla — simplemente sale en inglés y nadie se
# entera hasta que lo ve un usuario.
#
# Se dibuja todo aquí dentro en vez de fiarse de lo que hayan
# pintado los demás archivos, para que valga igual lanzada sola.
# ============================================================

Describe 'ui/Engine/Translation.ps1 - el mecanismo' {

    It 'sin traducción devuelve el original' {
        Set-AppLanguage 'es'
        Assert-Equal 'Esto no está en el diccionario' (T 'Esto no está en el diccionario')
        Set-AppLanguage 'en'
    }

    It 'en el idioma fuente no traduce nada' {
        Set-AppLanguage 'en'
        Assert-Equal 'Settings' (T 'Settings')
    }

    It 'un texto vacío sale tal cual' {
        Assert-Equal '' (T '')
    }

    It 'cada idioma del índice tiene su diccionario, salvo el fuente' {
        foreach ($idioma in Get-AvailableLanguages) {
            if ($idioma.Source) { continue }

            Set-AppLanguage $idioma.Code
            Assert-NotEqual 'Settings' (T 'Settings') "el idioma '$($idioma.Code)' no traduce nada: ¿falta ui/Data/Lang/$($idioma.Code).ps1?"
        }
        Set-AppLanguage 'en'
    }

    It 'los cuatro estados de un ajuste están traducidos' {
        # La prueba gorda de abajo solo ve los textos que se han
        # pintado, y de los cuatro estados este equipo enseñará uno.
        # Los otros tres se quedarían sin auditar hasta que alguien
        # los viera en pantalla, así que se comprueban a mano.
        foreach ($idioma in Get-AvailableLanguages) {
            if ($idioma.Source) { continue }
            Set-AppLanguage $idioma.Code

            foreach ($estado in Get-SettingStatusNames) {
                $estilo = Get-StatusStyle $estado
                foreach ($texto in @($estilo.Label, $estilo.Tip, $estilo.Count)) {
                    Assert-NotEqual $texto (T $texto) "'$texto' sin traducir en '$($idioma.Code)'"
                }
            }
        }
        Set-AppLanguage 'en'
    }

    It 'el idioma por defecto existe en el índice' {
        Assert-Contains (Get-DefaultLanguage) (@(Get-AvailableLanguages).Code)
    }
}

Describe 'ui/Lang - no falta ninguna traducción' {

    It 'toda la interfaz en español está traducida' {
        # Un literal escrito sin T no aparece por aquí -no pasa por
        # el diccionario, así que no se puede saber que existe-,
        # pero sí salta lo contrario: el texto que sí pide
        # traducción y no la tiene.
        $ventana = New-AppWindow -Language 'es'

        # De cero: el registro de textos vistos acumula desde que
        # arrancó el proceso y arrastraría lo que hayan pedido las
        # demás pruebas, empezando por las de esta misma página.
        Reset-TranslationAudit

        Update-TitleBarTexts $ventana
        Build-Sidebar -Window $ventana

        Show-View -Name 'Show-OptimizationsListView'
        Show-View -Name 'Show-SettingsView'
        foreach ($cat in Get-OptimizationCategories) {
            Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }
        }

        # La búsqueda tiene tres caras y cada una con su texto: con
        # resultados, sin ninguno y sin nada escrito. Ninguna sale
        # sola al pintar, hay que pedir las tres.
        Set-SearchQuery 'e'
        Show-View -Name 'Show-SearchResultsView'
        Set-SearchQuery 'zzqqxx-esto-no-existe'
        Update-SearchResults $ventana
        Set-SearchQuery ''
        Update-SearchResults $ventana

        # Y la fila del desplegable que lleva a la página completa,
        # que solo aparece cuando no caben todos.
        New-SearchSeeAllRow $ventana $null 12 | Out-Null

        # El aviso de refrescado no sale al pintar la pantalla:
        # solo aparece tras pulsar, así que hay que pedirlo aquí o
        # su texto no pasaría nunca por el diccionario.
        Show-PageToast -Window $ventana -Text 'Registry values updated' | Out-Null

        # La cabecera flotante del log tiene sus propios botones, y
        # solo se construyen al sacarlo fuera.
        New-LogContent $ventana -Floating | Out-Null

        # El "Copiado" de los detalles técnicos tampoco sale al pintar:
        # solo al pulsar el botón de copiar. No se toca el portapapeles,
        # que es lo único de ahí que no es asunto de la traducción.
        $copiar = New-CopyButton 'HKEY_CURRENT_USER\Software' 'Copy the registry path'
        Show-CopyFeedback $copiar
        Reset-CopyFeedback

        New-TestLogEntries 2
        Show-LogPanel $ventana
        Hide-LogPanel $ventana

        $faltan = @(Get-MissingTranslations 'es')
        Set-AppLanguage 'en'

        Assert-Equal 0 $faltan.Count ('sin traducir: ' + ($faltan -join ' | '))
    }

    It 'el inglés es el idioma fuente: nada se escribe ya traducido' {
        # Una descripción escrita directamente en español sale
        # SIEMPRE en español, también con la aplicación en inglés,
        # y encima no aparece como pendiente de traducir.
        foreach ($cat in Get-OptimizationCategories) {
            foreach ($ajuste in @($cat.Items)) {
                foreach ($texto in @($ajuste.Name, $ajuste.Description)) {
                    Assert-True ($texto -notmatch '[áéíóúñ¿¡]') `
                        ("parece español en '$($cat.Id)': $texto")
                }
            }
        }
    }
}
