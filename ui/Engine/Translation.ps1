# ============================================================
# Translation.ps1
# Mecanismo de idiomas. NO contiene textos.
#
# Se traduce POR TEXTO ORIGINAL, no por clave: el inglés es el
# idioma fuente y cada archivo de ui/Data/Lang/ es un diccionario
# "texto en inglés" -> "texto traducido".
#
# Gracias a eso los archivos de ui/Data/Categories/ no necesitan
# tocarse: siguen leyéndose en inglés claro. Y si falta una
# traducción, sale el original en vez de romperse.
#
#   -> Añadir un idioma = crear ui/Data/Lang/<código>.ps1
#                         y su línea en ui/Index/LanguageIndex.ps1
#   -> El inglés no necesita archivo: es la fuente.
# ============================================================

$Translations = @{}       # código -> tabla de textos
$CurrentLanguage = 'en'
$SeenStrings = @{}        # todo lo que ha pasado por T, para auditar

function Register-Language {
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][hashtable]$Strings
    )
    if (-not $Translations.ContainsKey($Code)) { $Translations[$Code] = @{} }
    foreach ($key in $Strings.Keys) { $Translations[$Code][$key] = $Strings[$key] }
}

function Set-AppLanguage {
    param([Parameter(Mandatory)][string]$Code)
    $script:CurrentLanguage = $Code
}

function Get-AppLanguage { $script:CurrentLanguage }

<#
    Traduce un texto al idioma activo.

        $t.Text = T 'Optimizations'
        $t.Text = (T '{0} settings') -f 6

    Si el idioma activo es el fuente, o no hay traducción para
    ese texto, devuelve el original tal cual.
#>
function T {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $script:SeenStrings[$Text] = $true

    $dict = $Translations[$script:CurrentLanguage]
    if ($dict -and $dict.ContainsKey($Text)) { return $dict[$Text] }
    $Text
}

<#
    Textos que la interfaz ha pedido traducir y que faltan en el
    idioma indicado. Sirve para saber qué queda por traducir tras
    añadir ajustes nuevos:

        Get-MissingTranslations 'es'

    Solo ve lo que se haya mostrado en esta sesión, así que
    conviene navegar por la aplicación antes de consultarlo.
#>
function Get-MissingTranslations {
    param([string]$Code = $CurrentLanguage)

    $dict = $Translations[$Code]
    if (-not $dict) { return $SeenStrings.Keys }
    $SeenStrings.Keys | Where-Object { -not $dict.ContainsKey($_) } | Sort-Object
}

<#
    Olvida lo visto hasta ahora y empieza a apuntar de cero.

    Get-MissingTranslations acumula desde que arrancó el programa,
    así que sin esto no hay forma de preguntar por una pantalla
    concreta: arrastraría todo lo que se haya pintado antes.

        Reset-TranslationAudit
        Show-View -Name 'Show-SettingsView'
        Get-MissingTranslations 'es'
#>
function Reset-TranslationAudit {
    $script:SeenStrings = @{}
}
