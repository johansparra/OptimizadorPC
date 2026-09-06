# ============================================================
# Pruebas de core/Shell/ExternalLink.ps1 — abrir un enlace de
# referencia en el navegador.
#
# Lo que de verdad importa aquí es la lista blanca: el .exe corre
# elevado y no puede pasarle una cadena cualquiera al shell. Se
# comprueba entero Test-ExternalLinkAllowed, que es puro.
#
# El camino feliz de Invoke-ExternalLink NO se prueba: abriría un
# navegador de verdad. Solo se comprueba que un esquema no
# permitido se queda en $false sin llegar a Start-Process, igual
# que se hace con el diálogo modal del log.
# ============================================================

Describe 'core/Shell/ExternalLink.ps1 - qué se deja abrir' {

    It 'http y https pasan' {
        Assert-True (Test-ExternalLinkAllowed 'https://learn.microsoft.com/en-us/windows')
        Assert-True (Test-ExternalLinkAllowed 'http://example.com/page')
    }

    It 'el esquema no distingue mayúsculas y se recortan los espacios' {
        Assert-True (Test-ExternalLinkAllowed 'HTTPS://EXAMPLE.COM')
        Assert-True (Test-ExternalLinkAllowed '   https://example.com   ')
    }

    It 'cualquier otro esquema se rechaza' {
        foreach ($url in @(
                'ftp://host/file',
                'file:///C:/Windows/System32/calc.exe',
                'mailto:someone@example.com',
                'javascript:alert(1)',
                'C:\Windows\System32\calc.exe')) {
            Assert-False (Test-ExternalLinkAllowed $url) "debería rechazar: $url"
        }
    }

    It 'lo que no es una URI absoluta se rechaza' {
        foreach ($url in @('not a url', 'example.com', '/ruta/relativa', '', '   ')) {
            Assert-False (Test-ExternalLinkAllowed $url) "debería rechazar: '$url'"
        }
    }

    It 'un valor nulo no lanza y se rechaza' {
        Assert-False (Test-ExternalLinkAllowed $null)
    }
}

Describe 'core/Shell/ExternalLink.ps1 - abrir' {

    It 'un esquema no permitido devuelve $false sin tocar el shell' {
        Assert-False (Invoke-ExternalLink 'ftp://host/file')
        Assert-False (Invoke-ExternalLink 'file:///C:/Windows/System32/calc.exe')
    }

    It 'una cadena vacía devuelve $false' {
        Assert-False (Invoke-ExternalLink '')
        Assert-False (Invoke-ExternalLink $null)
    }
}
