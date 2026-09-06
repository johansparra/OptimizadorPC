# ============================================================
# core/Shell/ExternalLink.ps1
# Abrir un enlace de referencia en el navegador del usuario.
#
# Vive en core/ porque habla con el shell de Windows (ShellExecute
# a traves de Start-Process): aqui no se sabe que existe una
# ventana de WPF. Quien llama recibe $true si el enlace se ha
# lanzado y $false en cualquier otro caso.
#
# COMO NO EXPLOTAR
#
#   Nada de aqui lanza. Si la URL no vale, si no hay navegador o
#   si Start-Process se queja, se devuelve $false y la interfaz
#   sigue igual. Una excepcion escapando de core/ tumbaria la
#   ventana.
#
#   El .exe corre ELEVADO (-requireAdmin). Pasarle una cadena
#   cualquiera a ShellExecute desde un proceso elevado abre lo
#   que sea -otro .exe, un .bat, un archivo local-, asi que solo
#   se dejan pasar esquemas http y https. Todo lo demas se
#   rechaza antes de tocar el shell.
#
# Todos los textos de este archivo estan en ingles o son
# comentarios: core/ no traduce (ver la regla 15).
# ============================================================

# Esquemas que se permite abrir. Cualquier otro -file, mailto,
# javascript, un .exe suelto- se rechaza.
$ExternalLinkSchemes = @('http', 'https')

<#
    ¿Se puede abrir esta URL?

    $true solo si es una URI absoluta y su esquema esta en la
    lista blanca. Es puro: no toca el shell, asi que se puede
    probar entero.
#>
function Test-ExternalLinkAllowed {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    $parsed = $null
    if (-not [uri]::TryCreate($Url.Trim(), [System.UriKind]::Absolute, [ref]$parsed)) { return $false }

    $ExternalLinkSchemes -contains $parsed.Scheme.ToLowerInvariant()
}

<#
    Abre la URL en el navegador por defecto.

        Invoke-ExternalLink 'https://learn.microsoft.com/...'

    Devuelve $true solo si el esquema esta permitido Y Start-Process
    no ha fallado. Un esquema no permitido ni siquiera llega al
    shell.
#>
function Invoke-ExternalLink {
    param([string]$Url)

    if (-not (Test-ExternalLinkAllowed $Url)) { return $false }

    try {
        Start-Process -FilePath $Url.Trim() -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}
