# ============================================================
# Pruebas del código fuente: las reglas de CLAUDE.md que se
# pueden comprobar leyendo los archivos.
#
# No ejecutan la aplicación; la miran. Son las que más barato
# salen y las que más disgustos ahorran, porque los fallos que
# cubren tienen todos la misma pinta: no se ven al desarrollar y
# aparecen al compilar el .exe o al abrirlo en otro host.
#
#   - Sin BOM             -> 5.1 lee el archivo como ANSI y el
#                            parser revienta con "token inesperado"
#   - Fuera de main.ps1   -> build.ps1 no lo mete en el .exe y la
#                            función "no se reconoce" solo ahí
#   - .GetNewClosure()    -> el clic falla en main.ps1 y no en el .exe
#   - Glifo inventado     -> excepción al pintar la pantalla
# ============================================================

# Todo el código de la aplicación. Las pruebas quedan fuera a
# propósito: no se compilan y no tienen por qué seguir las
# mismas reglas.
function Get-SourceFiles {
    @(Get-ChildItem -Path (Join-Path (Get-AppRoot) 'ui'), (Join-Path (Get-AppRoot) 'core') -Recurse -Filter '*.ps1')
}

# La ruta relativa con barras normales, como la escribe main.ps1.
function Get-SourceRelativePath {
    param($File)
    $File.FullName.Substring((Get-AppRoot).Length).TrimStart('\') -replace '\\', '/'
}

Describe 'reglas del proyecto - codificación' {

    It 'todos los .ps1 se guardan en UTF-8 con BOM' {
        # Sin BOM, Windows PowerShell 5.1 los lee como ANSI: los
        # acentos de los comentarios se vuelven mojibake y el
        # parser falla. En pwsh 7 el mismo archivo va bien, así que
        # el fallo solo sale al compilar o al abrir el .exe.
        foreach ($archivo in Get-SourceFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($archivo.FullName)
            $tiene = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            Assert-True $tiene ('falta el BOM en ' + (Get-SourceRelativePath $archivo))
        }
    }

    It 'main.ps1, build.ps1 y el XAML también' {
        foreach ($nombre in @('main.ps1', 'build.ps1', 'ui\MainWindow.xaml')) {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path (Get-AppRoot) $nombre))
            $tiene = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            Assert-True $tiene "falta el BOM en $nombre"
        }
    }

    It 'los archivos de las pruebas también, que corren en 5.1' {
        # $PSScriptRoot es tests/Source; se sube a tests/ para mirar
        # también el arnés y las demás carpetas de pruebas.
        foreach ($archivo in (Get-ChildItem -Path (Split-Path -Parent $PSScriptRoot) -Recurse -Filter '*.ps1')) {
            $bytes = [System.IO.File]::ReadAllBytes($archivo.FullName)
            $tiene = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            Assert-True $tiene ('falta el BOM en tests/' + $archivo.Name)
        }
    }

    It 'todo el código fuente parsea' {
        foreach ($archivo in Get-SourceFiles) {
            $errores = $null
            [System.Management.Automation.Language.Parser]::ParseFile($archivo.FullName, [ref]$null, [ref]$errores) | Out-Null
            if ($errores -and $errores.Count -gt 0) {
                throw ('{0}: {1}' -f (Get-SourceRelativePath $archivo), $errores[0].Message)
            }
        }
    }
}

Describe 'reglas del proyecto - qué entra en el .exe' {

    <#
        Lo que main.ps1 carga, leído con las MISMAS expresiones
        regulares de build.ps1. Si un archivo no sale de aquí, no
        entra en el ejecutable.
    #>
    It 'ningún archivo de ui/ o core/ se queda fuera de main.ps1' {
        $cargados = @{}
        foreach ($ruta in $AppLoadedFiles) { $cargados[$ruta] = $true }

        $huerfanos = @()
        foreach ($archivo in Get-SourceFiles) {
            $rel = Get-SourceRelativePath $archivo
            if (-not $cargados.ContainsKey($rel)) { $huerfanos += $rel }
        }

        Assert-Equal 0 $huerfanos.Count ('main.ps1 no carga: ' + ($huerfanos -join ', '))
    }

    It 'main.ps1 declara una capa por carpeta, y el XAML' {
        $main = Get-Content -Path (Join-Path (Get-AppRoot) 'main.ps1') -Raw

        foreach ($carpeta in @('ui/Design', 'ui/Engine', 'ui/Index', 'core',
                               'ui/Data', 'ui/Components', 'ui/Views')) {
            Assert-Match ('# @@EMBED_DIR:' + [regex]::Escape($carpeta) + '@@') $main "la carpeta $carpeta"
        }
        Assert-Match '# @@EMBED_XAML:ui/MainWindow.xaml@@' $main 'el XAML'
        Assert-Match '# @@ENDEMBED@@'                      $main 'el cierre de los bloques'
    }

    It 'las capas se cargan en el orden que exigen las dependencias' {
        # Los datos se registran al cargarse: ui/Data llama a
        # Register-Category y a Register-Preference, que viven en
        # ui/Engine. Si alguien mueve los bloques de sitio, el
        # programa muere al arrancar con "no se reconoce el término".
        $main = Get-Content -Path (Join-Path (Get-AppRoot) 'main.ps1') -Raw

        $posicion = @{}
        foreach ($encaje in ([regex]'# @@EMBED_DIR:([^@]+)@@').Matches($main)) {
            $posicion[$encaje.Groups[1].Value] = $encaje.Index
        }

        Assert-True ($posicion['ui/Design'] -lt $posicion['ui/Engine'])     'Design antes que Engine'
        Assert-True ($posicion['ui/Engine'] -lt $posicion['ui/Data'])       'Engine antes que Data'
        Assert-True ($posicion['ui/Index']  -lt $posicion['ui/Data'])       'Index antes que Data'
        Assert-True ($posicion['ui/Data']   -lt $posicion['ui/Components']) 'Data antes que Components'
    }

    It 'no queda ningún dot-source suelto en main.ps1' {
        # build.ps1 solo entiende @@EMBED_DIR@@ y @@EMBED_XAML@@.
        # Cualquier otra forma de cargar un archivo se copia tal cual
        # al script combinado, y el .exe intenta abrir algo que no
        # está a su lado. Un archivo nuevo va DENTRO de una carpeta
        # que ya se incrusta, no suelto.
        $sueltos = @(Get-Content -Path (Join-Path (Get-AppRoot) 'main.ps1') |
                     Where-Object { $_ -match '^\s*\.\s+\(Join-Path' })

        Assert-Equal 0 $sueltos.Count ('sobran: ' + ($sueltos -join ' | '))
    }

    It 'el paquete que arma build.ps1 parsea y lleva todo dentro' {
        # La prueba de fuego de la regla 2: se hace el empaquetado
        # de verdad -sin llamar a ps2exe, que es lo lento- y se
        # comprueba que el resultado es un script válido con todos
        # los archivos y el XAML incrustados.
        # A un archivo de ESTE proceso, no a build/_combined.ps1:
        # con -BothHosts las dos suites empaquetan a la vez y con la
        # ruta fija una leeria lo que la otra esta escribiendo. De
        # paso, pasar las pruebas deja de ensuciar el arbol.
        $combinado = Join-Path ([System.IO.Path]::GetTempPath()) ('optimizador-combinado-{0}.ps1' -f $PID)
        & (Join-Path (Get-AppRoot) 'build.ps1') -CombineOnly -OutFile $combinado 6>$null | Out-Null

        Assert-True (Test-Path $combinado) 'build.ps1 no ha dejado el script combinado'

        $errores = $null
        [System.Management.Automation.Language.Parser]::ParseFile($combinado, [ref]$null, [ref]$errores) | Out-Null
        if ($errores -and $errores.Count -gt 0) {
            throw ('el script combinado no parsea: {0} (línea {1})' -f $errores[0].Message, $errores[0].Extent.StartLineNumber)
        }

        $texto = Get-Content -Path $combinado -Raw
        foreach ($archivo in Get-SourceFiles) {
            $rel = Get-SourceRelativePath $archivo
            Assert-Match ('inicio incluido: ' + [regex]::Escape($rel)) $texto "no ha entrado $rel"
        }
        Assert-Match '<Window xmlns=' $texto 'no ha entrado el XAML'

        # Un marcador que sobreviva al empaquetado significa que
        # build.ps1 no lo ha reconocido y el .exe intentará leer
        # una carpeta que no tiene al lado. Solo cuentan los que
        # abren línea: main.ps1 los nombra de pasada en un comentario.
        Assert-True ($texto -notmatch '(?m)^\s*# @@EMBED_') 'ha quedado un marcador sin resolver'
        Assert-True ($texto -notmatch '(?m)^\s*# @@ENDEMBED')  'ha quedado un cierre sin resolver'

        Remove-Item -Path $combinado -Force -ErrorAction SilentlyContinue
    }

    It 'la carga es recursiva: los archivos anidados no se pierden' {
        # ui/Components/Cards/... y core/Registry/... están a dos
        # niveles. Si alguien quitara el -Recurse de main.ps1,
        # build.ps1 o AppHost.ps1, desaparecerían sin ruido: por eso
        # se comprueba que de verdad hay archivos anidados y que
        # main.ps1 los carga con su ruta completa.
        $anidados = @(Get-SourceFiles | Where-Object {
            (Get-SourceRelativePath $_).Split('/').Count -ge 3
        })
        Assert-True ($anidados.Count -gt 0) 'debería haber archivos en subcarpetas'

        $cargados = @{}
        foreach ($ruta in $AppLoadedFiles) { $cargados[$ruta] = $true }

        foreach ($archivo in $anidados) {
            $rel = Get-SourceRelativePath $archivo
            Assert-True $cargados.ContainsKey($rel) "main.ps1 no carga $rel"
        }
    }
}

Describe 'reglas del proyecto - trampas conocidas' {

    It 'no hay ningún .GetNewClosure()' {
        # Un scriptblock con closure queda atado a un módulo
        # dinámico desde el que no se ven las funciones del script:
        # el clic falla con "el término no se reconoce". En el .exe
        # no se nota porque ps2exe deja todo en ámbito global, así
        # que el bug solo aparece ejecutando main.ps1.
        foreach ($archivo in Get-SourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            Assert-True ($texto -notmatch '\.GetNewClosure\(\)') ('lo usa ' + (Get-SourceRelativePath $archivo))
        }
    }

    It 'los glifos que se piden por su nombre existen en el catálogo' {
        # Glyph lanza si el nombre no está, y lo hace mientras se
        # pinta la pantalla: la ventana se cae entera.
        foreach ($archivo in Get-SourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            foreach ($encaje in ([regex]"Glyph '([^']+)'").Matches($texto)) {
                $nombre = $encaje.Groups[1].Value
                Assert-NoThrow { Glyph $nombre } ("'$nombre' en " + (Get-SourceRelativePath $archivo))
            }
        }
    }

    It 'los colores se piden por su clave de tema, no a pelo' {
        # Un #RRGGBB escrito en el código no cambia al alternar
        # claro y oscuro. En el XAML sí hay algunos a propósito
        # (la paleta de partida y el rojo de cerrar), por eso solo
        # se miran los .ps1.
        #
        # Se comprueban contra Get-ThemeKeys y no contra la paleta:
        # desde que hay degradados, el tema publica DOS familias de
        # pinceles y las dos son claves válidas.
        $claves = Get-ThemeKeys

        foreach ($archivo in Get-SourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            foreach ($llamada in ([regex]"Set-(?:TextFg|BoxBg|BoxLine|PanelBg|ShapeFill)\s+\`$\w+\s+'([^']+)'").Matches($texto)) {
                $clave = $llamada.Groups[1].Value
                Assert-Contains $clave $claves ("'$clave' en " + (Get-SourceRelativePath $archivo))
            }
        }
    }

    It 'cada degradado se compone de colores que existen' {
        # Un token que apunte a una clave mal escrita no falla al
        # cargar: falla al cambiar de tema, con la ventana ya
        # abierta y un ColorConverter quejándose de $null.
        $paleta = (Get-Palette 'Light').Keys

        foreach ($nombre in $GradientTokens.Keys) {
            $token = $GradientTokens[$nombre]
            Assert-Contains $token.From $paleta "el degradado '$nombre' sale de un color que no existe"
            if ($token.Kind -ne 'Radial') {
                Assert-Contains $token.To $paleta "el degradado '$nombre' acaba en un color que no existe"
            }
        }
    }

    It 'core/ no toca WPF' {
        # La regla de la casa: core/ habla con Windows y no sabe
        # que existe una ventana. En cuanto necesite un control,
        # está en el sitio equivocado.
        foreach ($archivo in (Get-ChildItem -Path (Join-Path (Get-AppRoot) 'core') -Recurse -Filter '*.ps1')) {
            $rel = Get-SourceRelativePath $archivo
            $texto = Get-Content -Path $archivo.FullName -Raw
            Assert-True ($texto -notmatch 'System\.Windows') ("habla de WPF en $rel")
            Assert-True ($texto -notmatch '\bT\s+''')        ("traduce dentro de $rel")
        }
    }
}
