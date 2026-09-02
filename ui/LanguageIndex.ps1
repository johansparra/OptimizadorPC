# ============================================================
# LanguageIndex.ps1
#
#   *** ARCHIVO PRINCIPAL DE LOS IDIOMAS ***
#
# Qué idiomas ofrece el programa y en qué orden salen en el
# desplegable de Settings.
#
#   Code     Código corto. Debe coincidir con el nombre del
#            archivo de ui/Lang/ (es -> ui/Lang/es.ps1).
#   Label    Cómo se llama el idioma EN SU PROPIO IDIOMA, que es
#            lo que espera ver quien lo busca. No se traduce.
#   Source   $true en el idioma en el que está escrito el código
#            fuente. Ese no lleva archivo en ui/Lang/.
#   Default  Idioma de arranque la primera vez. Después manda lo
#            que haya guardado en %APPDATA% (ver AppSettings.ps1).
#   Visible  $false lo esconde sin borrar su archivo.
#
# Para añadir un idioma:
#   1. crear ui/Lang/<código>.ps1 copiando ui/Lang/es.ps1
#   2. añadir su línea aquí
# ============================================================

$LanguageIndex = @(

    @{ Code = 'en'; Label = 'English';  Visible = $true; Source = $true; Default = $true }
    @{ Code = 'es'; Label = 'Español';  Visible = $true }

)

function Get-AvailableLanguages {
    $LanguageIndex | Where-Object { -not $_.ContainsKey('Visible') -or $_.Visible }
}

function Get-DefaultLanguage {
    $default = $LanguageIndex | Where-Object { $_.Default } | Select-Object -First 1
    if ($default) { $default.Code } else { 'en' }
}

function Get-LanguageLabel {
    param([string]$Code)
    $found = $LanguageIndex | Where-Object { $_.Code -eq $Code } | Select-Object -First 1
    if ($found) { $found.Label } else { $Code }
}
