# ============================================================
# Pruebas de core/Registry/Writer.ps1 — ESCRIBIR en el registro.
#
# Como las de lectura, van contra el registro DE VERDAD: la mitad
# de lo que puede salir mal (un DWord sin signo, un tipo que no
# cuadra, una ruta protegida) solo aparece cuando contesta Windows.
#
# Se escribe SOLO en HKEY_CURRENT_USER\Software\OptimizadorPC\Tests\<PID>
# -que está en la lista blanca de Writer.ps1 y no necesita admin- y
# se borra al terminar (tests/Harness/Fixtures.ps1).
#
# El arnés DESARMA la escritura (AppHost.ps1). El bloque que prueba
# escrituras de verdad la rearma y la vuelve a desarmar al acabar;
# el final del archivo la desarma otra vez por si algo se saltó.
# ============================================================

New-TestRegFixture

Describe 'core/Registry/Writer.ps1 - la lista blanca' {

    It 'la rama de la clave de red real está permitida' {
        Assert-True (Test-RegistryWriteAllowed 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile')
    }

    It 'lo que cuelga de una rama permitida también' {
        Assert-True (Test-RegistryWriteAllowed 'HKCU\Software\OptimizadorPC\Tests\123\Sub')
        Assert-True (Test-RegistryWriteAllowed (Get-TestRegFullPath))
    }

    It 'la raíz abreviada y las mayúsculas dan igual' {
        Assert-True (Test-RegistryWriteAllowed 'hkcu\SOFTWARE\optimizadorpc\tests')
        Assert-True (Test-RegistryWriteAllowed 'HKLM\Software\Policies\Microsoft\Windows')
    }

    It 'lo que NO está en la lista se rechaza' {
        foreach ($ruta in @(
                'HKEY_LOCAL_MACHINE\SAM\SAM',
                'HKEY_LOCAL_MACHINE\SECURITY\Policy',
                'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip',
                'HKEY_CURRENT_USER\Software\Otra\Cosa',
                'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia',
                'HKEY_LO_QUE_SEA\Software',
                'HKEY_CURRENT_USER',
                '')) {
            Assert-False (Test-RegistryWriteAllowed $ruta) "no debería permitir: '$ruta'"
        }
    }
}

Describe 'core/Registry/Writer.ps1 - texto declarado a valor tipado' {

    It 'DWord: decimal, hexadecimal y negativo' {
        Assert-Equal 10 (ConvertTo-RegistryData -Text '10' -Type 'DWord').Data
        Assert-Equal 10 (ConvertTo-RegistryData -Text '0x0000000A' -Type 'DWord').Data
        # 0xFFFFFFFF se escribe como Int32 -1.
        Assert-Equal (-1) (ConvertTo-RegistryData -Text '0xFFFFFFFF' -Type 'DWord').Data
        Assert-Equal (-1) (ConvertTo-RegistryData -Text '-1' -Type 'DWord').Data
    }

    It 'DWord: lo que no es número, o no cabe en 32 bits, falla' {
        Assert-False (ConvertTo-RegistryData -Text 'diez' -Type 'DWord').Ok
        Assert-False (ConvertTo-RegistryData -Text '0x1FFFFFFFF' -Type 'DWord').Ok
    }

    It 'QWord: acepta 64 bits' {
        Assert-Equal ([int64]-1) (ConvertTo-RegistryData -Text '0xFFFFFFFFFFFFFFFF' -Type 'QWord').Data
        Assert-Equal ([int64]5)  (ConvertTo-RegistryData -Text '5' -Type 'QWord').Data
    }

    It 'String y ExpandString: el texto tal cual, sin expandir' {
        Assert-Equal 'hola'                (ConvertTo-RegistryData -Text 'hola' -Type 'String').Data
        Assert-Equal '%SystemRoot%\np.exe' (ConvertTo-RegistryData -Text '%SystemRoot%\np.exe' -Type 'ExpandString').Data
    }

    It 'Binary: pares hexadecimales -> byte[]' {
        $d = (ConvertTo-RegistryData -Text '01 02 FF' -Type 'Binary').Data
        Assert-Equal 3 $d.Length
        Assert-Equal 255 $d[2]
        # También sin espacios y con comas.
        Assert-Equal 2 (ConvertTo-RegistryData -Text '0a0b' -Type 'Binary').Data.Length
        Assert-Equal 2 (ConvertTo-RegistryData -Text '0A,0B' -Type 'Binary').Data.Length
    }

    It 'Binary: longitud impar o dígito no hex falla' {
        Assert-False (ConvertTo-RegistryData -Text '010' -Type 'Binary').Ok
        Assert-False (ConvertTo-RegistryData -Text '0G' -Type 'Binary').Ok
    }

    It 'MultiString todavía no se sabe escribir' {
        $c = ConvertTo-RegistryData -Text 'a' -Type 'MultiString'
        Assert-False $c.Ok
        Assert-Equal 'unsupported' $c.Reason
    }

    It 'un tipo que no se reconoce falla' {
        Assert-False (ConvertTo-RegistryData -Text 'x' -Type 'Loquesea').Ok
    }

    It 'acepta las formas REG_*' {
        Assert-Equal 'hola' (ConvertTo-RegistryData -Text 'hola' -Type 'REG_SZ').Data
        Assert-Equal 7 (ConvertTo-RegistryData -Text '7' -Type 'REG_DWORD').Data
    }
}

Describe 'core/Registry/Writer.ps1 - diagnóstico del fallo' {

    It 'traduce cada excepción a un motivo accionable' {
        $den = [System.UnauthorizedAccessException]::new('nope')
        $sec = [System.Security.SecurityException]::new('nope')
        $arg = [System.ArgumentException]::new('bad kind')
        $io  = [System.IO.IOException]::new('key gone')
        $misc = [System.InvalidOperationException]::new('?')

        Assert-Equal 'ACCESS_DENIED'     (Get-RegistryWriteFailReason $den)
        Assert-Equal 'ACCESS_DENIED'     (Get-RegistryWriteFailReason $sec)
        Assert-Equal 'TYPE_MISMATCH'     (Get-RegistryWriteFailReason $arg)
        Assert-Equal 'KEY_NOT_FOUND'     (Get-RegistryWriteFailReason $io)
        Assert-Equal 'BACKEND_EXCEPTION' (Get-RegistryWriteFailReason $misc)
    }

    It 'desenvuelve la MethodInvocationException de PowerShell' {
        # Un método .NET que lanza llega envuelto; la de verdad va dentro.
        try { [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey('SECURITY\SAM\SAM\x\y\z') | Out-Null }
        catch { $err = $_ }

        if ($err) {
            $real = Resolve-RegistryException $err
            Assert-NotEqual 'System.Management.Automation.MethodInvocationException' $real.GetType().FullName `
                'debería haber desenvuelto la excepción interna'
        }
        else { Skip-Test 'esta máquina ha dejado crear la subclave de prueba' }
    }

    It 'Test-RegistryKeyExists distingue está / no está / no se sabe' {
        Assert-True  (Test-RegistryKeyExists (Get-TestRegFullPath))
        Assert-False (Test-RegistryKeyExists 'HKEY_CURRENT_USER\Software\NoExisteEstaRama\NiEsta')
        Assert-Null  (Test-RegistryKeyExists 'HKEY_LO_QUE_SEA\x')
    }

    It 'Test-ProcessElevated no lanza y devuelve un booleano' {
        Assert-NoThrow { Test-ProcessElevated }
        Assert-True ((Test-ProcessElevated) -is [bool])
    }

    It 'Format-HResult saca el código Win32 sin reventar con el signo' {
        # 0x80070005 llega como Int32 negativo; el cast directo a
        # uint32 revienta en 5.1.
        $den = [System.UnauthorizedAccessException]::new('x')
        Assert-Match '^0x8[0-9A-F]{7}$' (Format-HResult $den)
        Assert-Equal '' (Format-HResult $null)
    }
}

Describe 'core/Registry/Writer.ps1 - desarmada en las pruebas' {

    It 'el arnés la ha desarmado' {
        Assert-False (Get-RegistryWriteArmed)
    }

    It 'desarmada no escribe nada y lo dice' {
        Clear-AppLog
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'NoDeberiaExistir' -Type 'DWord' -Text '5'
        Assert-Equal 'disarmed' $r.State
        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'NoDeberiaExistir').State
        Assert-Equal 'disarmed' @(Get-AppLog -Source 'registry')[0].Status
    }
}

Describe 'core/Registry/Writer.ps1 - escribir de verdad' {

    Set-RegistryWriteArmed $true

    It 'rechaza una ruta fuera de la lista blanca sin tocar nada' {
        $r = Write-RegistryValue -Path 'HKEY_CURRENT_USER\Software\FueraDeLista' -Name 'X' -Type 'DWord' -Text '1'
        Assert-Equal 'blocked' $r.State
    }

    It 'rechaza una raíz inventada' {
        Assert-Equal 'badpath' (Write-RegistryValue -Path 'HKEY_LO_QUE_SEA\x' -Name 'X' -Type 'DWord' -Text '1').State
    }

    It 'un tipo que no cuadra no escribe' {
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'MalTipo' -Type 'DWord' -Text 'noesnumero'
        Assert-Equal 'typefail' $r.State
        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'MalTipo').State
    }

    It 'MultiString devuelve unsupported sin escribir' {
        Assert-Equal 'unsupported' (Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'Multi' -Type 'MultiString' -Text 'a').State
    }

    It 'escribe un DWord y lo confirma por relectura' {
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwNuevo' -Type 'DWord' -Text '42' -Requested 'ON'
        Assert-Equal 'written' $r.State
        Assert-True  $r.Verified

        $leido = Read-RegistryValue (Get-TestRegFullPath) 'DwNuevo'
        Assert-Equal 42 $leido.Value
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::DWord) $leido.Kind
    }

    It 'un DWord de 0xFFFFFFFF se guarda y se lee sin signo' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwFull' -Type 'DWord' -Text '0xFFFFFFFF' | Out-Null
        $leido = Read-RegistryValue (Get-TestRegFullPath) 'DwFull'
        Assert-Equal '0xFFFFFFFF' (Format-RegistryValue $leido.Value $leido.Kind 'hex')
    }

    It 'escribe un QWord' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'QwNuevo' -Type 'QWord' -Text '0xFFFFFFFFFFFFFFFF' | Out-Null
        $leido = Read-RegistryValue (Get-TestRegFullPath) 'QwNuevo'
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::QWord) $leido.Kind
        Assert-Equal '18446744073709551615' (Format-RegistryValue $leido.Value $leido.Kind)
    }

    It 'escribe un String' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'SzNuevo' -Type 'String' -Text 'un valor' | Out-Null
        $leido = Read-RegistryValue (Get-TestRegFullPath) 'SzNuevo'
        Assert-Equal 'un valor' $leido.Value
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::String) $leido.Kind
    }

    It 'escribe un ExpandString SIN expandir, y la relectura de verdad sí lo expande' {
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'ExNuevo' -Type 'ExpandString' -Text '%SystemRoot%\notepad.exe'
        Assert-Equal 'written' $r.State
        Assert-True  $r.Verified 'la comprobación no expande: compara lo escrito con lo declarado'

        # Read-RegistryValue (el camino normal) sí expande.
        $leido = Read-RegistryValue (Get-TestRegFullPath) 'ExNuevo'
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::ExpandString) $leido.Kind
        Assert-Match 'notepad\.exe' $leido.Value
        Assert-True ($leido.Value -notmatch '%SystemRoot%') 'debería venir expandida'
    }

    It 'escribe un Binary' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'BinNuevo' -Type 'Binary' -Text 'DE AD BE EF' | Out-Null
        $leido = Read-RegistryValue (Get-TestRegFullPath) 'BinNuevo'
        Assert-Equal ([Microsoft.Win32.RegistryValueKind]::Binary) $leido.Kind
        Assert-Equal 'DE AD BE EF' (Format-RegistryValue $leido.Value $leido.Kind)
    }

    It 'si ya está en el valor destino, no reescribe (nochange)' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwIdem' -Type 'DWord' -Text '7' | Out-Null
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwIdem' -Type 'DWord' -Text '0x00000007'
        Assert-Equal 'nochange' $r.State
    }

    It 'guarda copia de seguridad del valor anterior antes de escribir' {
        Clear-RegistrySnapshots
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwSnap' -Type 'DWord' -Text '1' | Out-Null
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwSnap' -Type 'DWord' -Text '2' | Out-Null

        $snaps = @(Get-RegistrySnapshots)
        Assert-Equal 2 $snaps.Count
        # La primera: no existía. La segunda: valía 1.
        Assert-False $snaps[0].Existed
        Assert-True  $snaps[1].Existed
        Assert-Equal 1 $snaps[1].Value
    }

    It 'deja los tres bloques: attempt, post_write_validation y éxito' {
        Clear-AppLog
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwLog' -Type 'DWord' -Text '99' -Requested 'ON' -Action 'EnableOptimization' | Out-Null

        $lineas = @(Get-AppLog -Source 'registry')

        $intento = $lineas | Where-Object { $_.Status -eq 'write attempt' }
        Assert-NotNull $intento 'falta la línea [write attempt]'
        Assert-Match 'newvalue=99'   $intento.Detail
        Assert-Match 'convertible=True' $intento.Detail
        Assert-Match 'elevated='      $intento.Detail

        $post = $lineas | Where-Object { $_.Status -eq 'post write' }
        Assert-NotNull $post 'falta la línea [post write]'
        Assert-Match 'expected=99'    $post.Detail
        Assert-Match 'actual=99'      $post.Detail
        Assert-Match 'result=SUCCESS' $post.Detail

        $ok = $lineas | Where-Object { $_.Status -eq 'applied' }
        Assert-NotNull $ok
        Assert-Match 'action=EnableOptimization' $ok.Detail
        Assert-Match 'new=99' $ok.Detail
    }

    It 'un fallo por tipo distinto lo dice con motivo' {
        # El valor ya existe como String; se pide escribir como DWord.
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey((Get-TestRegPath))
        try   { $key.SetValue('TipoChoca', 'texto', [Microsoft.Win32.RegistryValueKind]::String) }
        finally { $key.Close() }

        Clear-AppLog
        $r = Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'TipoChoca' -Type 'DWord' -Text '1'
        Assert-Equal 'typemismatch' $r.State

        $fail = @(Get-AppLog -Source 'registry') | Where-Object { $_.Status -eq 'type mismatch' }
        Assert-NotNull $fail
        Assert-Match 'reason=TYPE_MISMATCH' $fail.Detail

        # Y no ha tocado el valor: sigue siendo la cadena.
        Assert-Equal 'texto' (Read-RegistryValue (Get-TestRegFullPath) 'TipoChoca').Value
    }

    It 'la validación previa registra clave, valor, tipo y elevación' {
        Clear-AppLog
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwPrev' -Type 'DWord' -Text '3' | Out-Null

        $intento = @(Get-AppLog -Source 'registry') | Where-Object { $_.Status -eq 'write attempt' }
        Assert-Match 'key_exists=True'   $intento.Detail
        Assert-Match 'value_exists=False' $intento.Detail
        Assert-Match 'type_match=n/a'    $intento.Detail
    }

    It '-WhatIf no escribe' {
        Write-RegistryValue -Path (Get-TestRegFullPath) -Name 'DwWhatIf' -Type 'DWord' -Text '5' -WhatIf | Out-Null
        Assert-Equal 'missing' (Read-RegistryValueRaw (Get-TestRegFullPath) 'DwWhatIf').State
    }

    It 'nunca lanza, le eches lo que le eches' {
        foreach ($ruta in @('', '\', 'HKCU\', (Get-TestRegFullPath))) {
            Assert-NoThrow { Write-RegistryValue -Path $ruta -Name 'X' -Type 'DWord' -Text 'x' } "con la ruta '$ruta'"
        }
    }

    Set-RegistryWriteArmed $false
}

Set-RegistryWriteArmed $false
Remove-TestRegFixture
