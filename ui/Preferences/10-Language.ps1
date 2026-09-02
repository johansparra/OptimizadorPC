# ------------------------------------------------------------
# Opción: idioma de la interfaz
#
# Ejemplo de opción con lista dinámica: las opciones salen de
# ui/LanguageIndex.ps1, así que añadir un idioma allí lo hace
# aparecer aquí sin tocar este archivo.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 10
    Id          = 'language'
    Group       = 'General'
    Label       = 'Language'
    Description = 'Language used across the whole interface'
    Type        = 'Choice'

    # Los nombres de idioma no se traducen: van siempre en el suyo.
    TranslateOptions = $false

    Options = {
        Get-AvailableLanguages | ForEach-Object {
            # La etiqueta va en su propio idioma a propósito: quien
            # busca "Español" lo reconoce aunque la app esté en inglés.
            @{ Value = $_.Code; Label = $_.Label }
        }
    }

    Get = { Get-AppLanguage }

    Set = {
        param($Value)
        Set-AppLanguage $Value
        Set-AppSetting 'Language' $Value
        Update-UiLanguage      # repinta el menú y la pantalla actual
    }
}
