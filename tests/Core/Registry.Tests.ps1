# ============================================================
# Pruebas de core/Registry/Reader.ps1 — leer el registro de Windows.
#
# Esto es lo primero del programa que habla con el sistema, así
# que se prueba contra el registro DE VERDAD y no contra un
# simulacro: la mitad de lo que puede salir mal (un DWord con
# signo, una raíz que no existe, una clave protegida) solo
# aparece cuando contesta Windows.
#
# Las claves de prueba se crean en HKEY_CURRENT_USER, que no
# necesita permisos de administrador, y se borran al terminar.
# El montaje está en tests/Harness/Fixtures.ps1.
# ============================================================

New-TestRegFixture

Describe 'core/Registry/Reader.ps1 - leer valores' {

    It 'lee un DWord y dice de qué tipo es' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'DwordCinco'
        Assert-Equal 'read' $r.State
        Assert-Equal 5 $r.Value
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::DWord) $r.Kind
    }

    It 'lee una cadena' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Texto'
        Assert-Equal 'read' $r.State
        Assert-Equal 'hola' $r.Value
    }

    It 'expande una cadena expandible' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Expandible'
        Assert-Equal 'read' $r.State
        Assert-Match 'notepad\.exe' $r.Value
        Assert-True ($r.Value -notmatch '%SystemRoot%') 'debería venir ya expandida'
    }

    It 'acepta la raíz abreviada HKCU' {
        $r = Read-RegistryValue ('HKCU\' + (Get-TestRegPath)) 'Texto'
        Assert-Equal 'read' $r.State
    }

    It 'la raíz no distingue mayúsculas' {
        $r = Read-RegistryValue ('hkey_current_user\' + (Get-TestRegPath)) 'Texto'
        Assert-Equal 'read' $r.State
    }
}

Describe 'core/Registry/Reader.ps1 - lo que no se puede leer' {

    It 'un valor que no existe es missing, no un fallo' {
        # No es lo mismo que un error: quiere decir que Windows
        # está usando su valor interno, y la tarjeta lo dice así.
        $r = Read-RegistryValue (Get-TestRegFullPath) 'NoExisteEsteValor'
        Assert-Equal 'missing' $r.State
        Assert-Null $r.Value
    }

    It 'una ruta que no existe también es missing' {
        $r = Read-RegistryValue 'HKEY_CURRENT_USER\Software\NoExisteEstaRama\NiEsta' 'X'
        Assert-Equal 'missing' $r.State
    }

    It 'una raíz inventada es badpath' {
        $r = Read-RegistryValue 'HKEY_LO_QUE_SEA\Software' 'X'
        Assert-Equal 'badpath' $r.State
    }

    It 'una ruta sin barras es badpath' {
        $r = Read-RegistryValue 'HKEY_CURRENT_USER' 'X'
        Assert-Equal 'badpath' $r.State
    }

    It 'una clave protegida es denied' {
        # Las ramas de credenciales de Windows solo las abre SYSTEM,
        # ni siquiera un administrador. Si en esta máquina alguna
        # se dejara abrir, la prueba se salta en vez de fallar:
        # lo que se comprueba es el camino, no la seguridad del PC.
        $protegidas = @(
            'HKEY_LOCAL_MACHINE\SAM\SAM'
            'HKEY_LOCAL_MACHINE\SECURITY\Policy\Secrets'
            'HKEY_LOCAL_MACHINE\SECURITY\SAM'
        )

        foreach ($ruta in $protegidas) {
            if ((Read-RegistryValue $ruta 'X').State -eq 'denied') { return }
        }
        Skip-Test 'ninguna de las ramas protegidas ha dado denied en esta máquina'
    }

    It 'nunca lanza, le eches lo que le eches' {
        # La promesa de core/: una excepción escapando de aquí
        # tumbaría la ventana entera (ver CLAUDE.md).
        $basura = @(
            'HKEY_CURRENT_USER\'
            '\'
            'HKCU\' + ('x' * 300)
            'HKEY_CURRENT_USER\Software\<>|?*'
            ''
        )
        foreach ($ruta in $basura) {
            Assert-NoThrow { Read-RegistryValue $ruta 'X' } "con la ruta '$ruta'"
        }
    }
}

Describe 'core/Registry/Reader.ps1 - dar formato a los valores' {

    It 'un DWord de 0xFFFFFFFF no sale negativo' {
        # El fallo clásico: .NET lo devuelve como Int32 con signo,
        # así que sin reinterpretar saldría -1 y no cuadraría con
        # lo que enseña el Editor del registro.
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Dword'
        Assert-Equal -1 $r.Value 'en crudo sí llega con signo'
        Assert-Equal '4294967295' (Format-RegistryValue $r.Value $r.Kind)
        Assert-Equal '0xFFFFFFFF' (Format-RegistryValue $r.Value $r.Kind 'hex')
    }

    It 'un QWord de 0xFFFFFFFFFFFFFFFF tampoco' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Qword'
        Assert-Equal '18446744073709551615' (Format-RegistryValue $r.Value $r.Kind)
        Assert-Equal '0xFFFFFFFFFFFFFFFF'   (Format-RegistryValue $r.Value $r.Kind 'hex')
    }

    It 'el hexadecimal va con ceros por delante' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'DwordCinco'
        Assert-Equal '0x00000005' (Format-RegistryValue $r.Value $r.Kind 'hex')
    }

    It 'un binario sale en pares de dígitos' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Binario'
        Assert-Equal '01 02 FF' (Format-RegistryValue $r.Value $r.Kind)
    }

    It 'una lista de cadenas sale separada por punto y coma' {
        $r = Read-RegistryValue (Get-TestRegFullPath) 'Varias'
        Assert-Equal 'uno; dos' (Format-RegistryValue $r.Value $r.Kind)
    }

    It 'un valor nulo devuelve nulo' {
        Assert-Null (Format-RegistryValue $null $null)
    }
}

Describe 'core/Registry/Reader.ps1 - deja rastro en el log' {

    It 'apunta cada lectura con su estado' {
        Clear-AppLog
        Read-RegistryValue (Get-TestRegFullPath) 'DwordCinco' | Out-Null

        $entrada = @(Get-AppLog -Source 'registry')[0]
        Assert-NotNull $entrada
        Assert-Equal 'read' $entrada.Status
        Assert-Equal 'info' $entrada.Level
        Assert-Equal ((Get-TestRegFullPath) + '\DwordCinco') $entrada.Message
    }

    It 'el detalle trae el valor en decimal y en hexadecimal' {
        # En la tarjeta cada clave pide una forma u otra con su
        # campo Display; aquí no hay quien lo pida, así que van las dos.
        Clear-AppLog
        Read-RegistryValue (Get-TestRegFullPath) 'Dword' | Out-Null

        $detalle = @(Get-AppLog -Source 'registry')[0].Detail
        Assert-Match '4294967295'   $detalle
        Assert-Match '0xFFFFFFFF'   $detalle
        Assert-Match 'DWord'        $detalle
        Assert-Match 'ms'           $detalle
    }

    It 'un valor que falta se apunta como aviso, no como fallo' {
        Clear-AppLog
        Read-RegistryValue (Get-TestRegFullPath) 'NoExisteEsteValor' | Out-Null

        $entrada = @(Get-AppLog -Source 'registry')[0]
        Assert-Equal 'warn'    $entrada.Level
        Assert-Equal 'not set' $entrada.Status
    }

    It 'una raíz inventada sí se apunta como fallo' {
        Clear-AppLog
        Read-RegistryValue 'HKEY_LO_QUE_SEA\Software' 'X' | Out-Null

        $entrada = @(Get-AppLog -Source 'registry')[0]
        Assert-Equal 'error'            $entrada.Level
        Assert-Equal 'unknown root key' $entrada.Status
    }

    It 'una lectura apunta exactamente una línea' {
        Clear-AppLog
        Read-RegistryValue (Get-TestRegFullPath) 'Texto' | Out-Null
        Assert-Equal 1 (Get-AppLogCount)
    }

    It 'la lectura pelada no apunta nada' {
        # Read-RegistryValueRaw existe justo para eso: separar leer
        # de contar que se ha leído.
        Clear-AppLog
        $r = Read-RegistryValueRaw (Get-TestRegFullPath) 'Texto'
        Assert-Equal 'read' $r.State
        Assert-Equal 0 (Get-AppLogCount)
    }

    It 'un texto larguísimo se recorta en el log' {
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try   { $key.SetValue('Larguisimo', ('a' * 500), [Microsoft.Win32.RegistryValueKind]::String) }
        finally { $key.Close() }

        Clear-AppLog
        Read-RegistryValue (Get-TestRegFullPath) 'Larguisimo' | Out-Null

        $detalle = @(Get-AppLog)[0].Detail
        Assert-True ($detalle.Length -lt 200) "el detalle mide $($detalle.Length)"
        Assert-Match '\.\.\.' $detalle
    }
}

Remove-TestRegFixture
