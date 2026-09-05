# ============================================================
# Pruebas de core/Diagnostics/Log.ps1 — el registro de actividad.
#
# Lo que se comprueba aquí es sobre todo que apuntar cosas no
# estorbe: que Write-AppLog no cuele nada en la salida de quien
# lo llama, que el buffer no crezca sin límite y que un volcado
# imposible devuelva $null en lugar de tumbar la ventana.
# ============================================================

Describe 'core/Diagnostics/Log.ps1 - apuntar' {

    It 'empieza vacío después de vaciarlo' {
        Clear-AppLog
        Assert-Equal 0 (Get-AppLogCount)
        Assert-Equal 0 (Get-AppLogDropped)
    }

    It 'guarda lo que se le da' {
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'warn' -Status 'not set' `
                     -Message 'HKEY_CURRENT_USER\Software\X' -Detail '0,4 ms'

        $entry = @(Get-AppLog)[0]
        Assert-Equal 'registry' $entry.Source
        Assert-Equal 'warn'     $entry.Level
        Assert-Equal 'not set'  $entry.Status
        Assert-Equal 'HKEY_CURRENT_USER\Software\X' $entry.Message
        Assert-Equal '0,4 ms'   $entry.Detail
        Assert-True  ($entry.Time -is [DateTime])
    }

    It 'no devuelve nada' {
        # Se llama desde funciones que están calculando otra cosa
        # (Read-RegistryValue, por ejemplo). Un valor suelto se
        # colaría en su salida y el que llama recibiría dos objetos.
        Clear-AppLog
        $salida = Write-AppLog -Message 'x'
        Assert-Null $salida
    }

    It 'el nivel solo admite info, warn y error' {
        Assert-Throws { Write-AppLog -Message 'x' -Level 'catastrofe' }
    }

    It 'admite un mensaje vacío' {
        Clear-AppLog
        Assert-NoThrow { Write-AppLog -Message '' }
        Assert-Equal 1 (Get-AppLogCount)
    }
}

Describe 'core/Diagnostics/Log.ps1 - consultar' {

    It 'filtra por origen y por nivel' {
        Clear-AppLog
        Write-AppLog -Message 'a' -Source 'registry' -Level 'info'
        Write-AppLog -Message 'b' -Source 'registry' -Level 'error'
        Write-AppLog -Message 'c' -Source 'app'      -Level 'info'

        Assert-Equal 3 @(Get-AppLog).Count
        Assert-Equal 2 @(Get-AppLog -Source 'registry').Count
        Assert-Equal 1 @(Get-AppLog -Level 'error').Count
        Assert-Equal 1 @(Get-AppLog -Source 'registry' -Level 'error').Count
        Assert-Equal 0 @(Get-AppLog -Source 'no-existe').Count
    }

    It 'devuelve las últimas N, de la más vieja a la más nueva' {
        Clear-AppLog
        foreach ($n in 1..10) { Write-AppLog -Message "linea $n" }

        $ultimas = @(Get-AppLog -Last 3)
        Assert-Equal 3 $ultimas.Count
        Assert-Equal 'linea 8'  $ultimas[0].Message
        Assert-Equal 'linea 10' $ultimas[2].Message
    }

    It 'una sola entrada envuelta en @() sigue siendo colección' {
        # PowerShell desenrolla lo que devuelve una función, así que
        # con una entrada llega el objeto pelado. La convención del
        # proyecto -la misma de @($Category.Items)- es que envuelva
        # quien llama; esto comprueba que ese envoltorio funciona.
        Clear-AppLog
        Write-AppLog -Message 'sola'

        $todas = @(Get-AppLog)
        Assert-Equal 1 $todas.Count
        Assert-Equal 'sola' $todas[0].Message
    }

    It 'lo que devuelve es una copia' {
        Clear-AppLog
        Write-AppLog -Message 'a'
        $copia = @(Get-AppLog)
        Write-AppLog -Message 'b'
        Assert-Equal 1 $copia.Count
        Assert-Equal 2 (Get-AppLogCount)
    }
}

Describe 'core/Diagnostics/Log.ps1 - el buffer es circular' {

    It 'no pasa del tope y cuenta lo que tira' {
        Clear-AppLog
        $tope = $AppLogCapacity
        foreach ($n in 1..($tope + 5)) { Write-AppLog -Message "linea $n" }

        Assert-Equal $tope (Get-AppLogCount)
        Assert-Equal 5     (Get-AppLogDropped)

        # Las que quedan son las últimas, no las primeras.
        Assert-Equal "linea $($tope + 5)" @(Get-AppLog -Last 1)[0].Message
    }

    It 'vaciar también pone a cero el contador de descartadas' {
        Clear-AppLog
        Assert-Equal 0 (Get-AppLogDropped)
    }
}

Describe 'core/Diagnostics/Log.ps1 - volcado a texto' {

    It 'una línea lleva hora, nivel, origen, estado, mensaje y detalle' {
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'error' -Status 'no access' `
                     -Message 'HKEY_LOCAL_MACHINE\SAM\SAM' -Detail '1,2 ms'

        $linea = Format-AppLogLine @(Get-AppLog)[0]
        Assert-Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[ERROR\] \[REGISTRY\]' $linea
        Assert-Match '\[no access\]' $linea
        Assert-Match 'SAM'        $linea
        Assert-Match '1,2 ms'     $linea
    }

    It 'los tres campos fijos van entre corchetes y en ese orden' {
        # Cuándo, con qué gravedad y de dónde. Es lo que hace que la
        # línea se pueda partir con una expresión regular aunque el
        # mensaje lleve espacios o barras.
        Clear-AppLog
        Write-AppLog -Source 'registry' -Level 'info' -Message 'Registry export finished'

        $linea = Format-AppLogLine @(Get-AppLog)[0]
        Assert-Match '^\[[^\]]+\] \[[A-Z]+\] \[[A-Z]+\] \S' $linea

        # Y el mensaje sale entero detrás del tercer corchete.
        $partes = [regex]::Match($linea, '^\[([^\]]+)\] \[([A-Z]+)\] \[([A-Z]+)\] (.+)$')
        Assert-True $partes.Success 'la línea no se deja partir'
        Assert-Equal 'INFO'     $partes.Groups[2].Value
        Assert-Equal 'REGISTRY' $partes.Groups[3].Value
        Assert-Equal 'Registry export finished' $partes.Groups[4].Value
    }

    It 'sin estado ni detalle no deja corchetes vacíos ni barras sueltas' {
        Clear-AppLog
        Write-AppLog -Message 'algo'
        $linea = Format-AppLogLine @(Get-AppLog)[0]

        # Los tres de siempre sí están; lo que no puede quedar es un
        # hueco vacío del estado que falta.
        Assert-Match '\[APP\] algo$' $linea
        Assert-True ($linea -notmatch '\[\s*\]') 'ha quedado un corchete vacío'
        Assert-True ($linea -notmatch '\|') 'no debería haber separador de detalle'
    }

    It 'el texto completo lleva cabecera y una línea por entrada' {
        Clear-AppLog
        Write-AppLog -Message 'uno'
        Write-AppLog -Message 'dos'

        $texto = Format-AppLogText
        Assert-Match 'Optimizador PC - activity log' $texto
        Assert-Match 'Entries: 2' $texto
        Assert-Match 'uno' $texto
        Assert-Match 'dos' $texto
    }
}

Describe 'core/Diagnostics/Log.ps1 - guardar en archivo' {

    It 'el nombre sugerido es opt-<fecha>.log' {
        # opt-2026-09-05_14-30-12.log
        Assert-Match '^opt-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.log$' (Get-AppLogFileName)
    }

    It 'con el registro vacío no se escribe ningún archivo' {
        # Un archivo con la cabecera y ninguna línea no le sirve a
        # nadie. La interfaz apaga el botón, pero la garantía está
        # aquí, que es por donde pasa todo el que quiera guardar.
        Clear-AppLog

        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        Assert-Null (Export-AppLog -Path $destino)
        Assert-False (Test-Path $destino) 'no debería haber creado nada'
    }

    It 'ese nombre no lleva nada que Windows prohíba' {
        # Los dos puntos de la hora son la trampa: con ellos el
        # archivo no se escribiría y no habría forma de saber por qué.
        $nombre = Get-AppLogFileName
        $prohibidos = [System.IO.Path]::GetInvalidFileNameChars()
        $malos = @($nombre.ToCharArray() | Where-Object { $prohibidos -contains $_ })
        Assert-Equal 0 $malos.Count ("caracteres no válidos en '$nombre'")
    }

    It 'el archivo lleva el registro entero, no lo que haya pintado' {
        # Lo que se guarda es el buffer, no las filas del cajón: por
        # eso el archivo puede traer más de lo que se ve.
        Clear-AppLog
        foreach ($n in 1..5) { Write-AppLog -Source 'registry' -Status 'read' -Message "Clave$n" }

        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-{0}.log' -f [Guid]::NewGuid())
        try {
            Assert-NotNull (Export-AppLog -Path $destino)
            $contenido = Get-Content -Path $destino -Raw
            foreach ($n in 1..5) { Assert-Match "Clave$n" $contenido }
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
        }
    }

    It 'escribe el archivo y devuelve su ruta' {
        Clear-AppLog
        Write-AppLog -Source 'registry' -Status 'read' -Message 'HKCU\Software\X' -Detail '5'

        $destino = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-log-{0}.txt' -f [Guid]::NewGuid())
        try {
            $ruta = Export-AppLog -Path $destino
            Assert-Equal $destino $ruta
            Assert-True (Test-Path $destino)

            $contenido = Get-Content -Path $destino -Raw
            Assert-Match 'HKCU\\Software\\X' $contenido
        }
        finally {
            if (Test-Path $destino) { Remove-Item $destino -Force }
        }
    }

    It 'crea la carpeta si no existe' {
        Clear-AppLog
        Write-AppLog -Message 'x'

        $carpeta = Join-Path ([System.IO.Path]::GetTempPath()) ('opt-log-{0}' -f [Guid]::NewGuid())
        $destino = Join-Path $carpeta 'sub\log.txt'
        try {
            Assert-NotNull (Export-AppLog -Path $destino)
            Assert-True (Test-Path $destino)
        }
        finally {
            if (Test-Path $carpeta) { Remove-Item $carpeta -Recurse -Force }
        }
    }

    It 'una ruta imposible devuelve $null en vez de lanzar' {
        # Regla de core/: nada sube hacia arriba. Si no se puede
        # escribir, la interfaz enseña un aviso y sigue viva.
        Assert-NoThrow { Export-AppLog -Path 'ZZ:\no\existe\log.txt' }
        Assert-Null (Export-AppLog -Path 'ZZ:\no\existe\log.txt')
    }

    It 'la carpeta por defecto cuelga de APPDATA, no del .exe' {
        # Mismo motivo que settings.json: el ejecutable es portable
        # y su carpeta puede no admitir escritura.
        $carpeta = Get-AppLogFolder
        Assert-Match ([regex]::Escape($env:APPDATA)) $carpeta
        Assert-Match 'OptimizadorPC' $carpeta
    }
}
