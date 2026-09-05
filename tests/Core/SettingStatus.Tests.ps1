# ============================================================
# Pruebas de core/Registry/SettingStatus.ps1 — en qué estado está un
# ajuste según lo que hay de verdad en el equipo.
#
# Es la parte que decide lo que el usuario acaba leyendo en la
# tarjeta ("Optimizado", "Recomendado de fábrica", "Personalizado"),
# así que se prueba a conciencia: primero la comparación de valores
# sueltos, luego una clave, luego el ajuste entero, y al final contra
# el registro de verdad usando la rama de tests/Harness/Fixtures.ps1.
# ============================================================

New-TestRegFixture

# Una clave de -Registry ya leída, sin tocar el registro.
function New-FakeKey {
    param([string]$Current, [string]$Recommended = '1', [string]$Default = '0', [string]$State = 'read')
    @{ Path = 'HKEY_CURRENT_USER\Software\Prueba'; Name = 'Valor'; Type = 'DWord'
       State = $State; Current = $Current; Recommended = $Recommended; Default = $Default }
}

function New-FakeSetting {
    param([hashtable[]]$Keys)
    New-Setting -Name 'Ajuste' -Description 'Solo para las pruebas' -Value $true -Registry $Keys
}

Describe 'core/Registry/SettingStatus.ps1 - comparar valores' {

    It 'el mismo número escrito de otra manera sigue siendo el mismo' {
        # Es el caso de todos los días: lo declarado va en hexadecimal
        # y lo leído puede llegar en decimal, o al revés.
        Assert-True (Test-RegistryValueMatch '0x0000000A' '10')
        Assert-True (Test-RegistryValueMatch '10' '0xA')
        Assert-True (Test-RegistryValueMatch '  0X0a  ' '10')
    }

    It 'un negativo declarado a mano es el valor sin signo que se lee' {
        # -1 en un DWord es 0xFFFFFFFF: quien escribe el archivo de la
        # sección puede poner cualquiera de los dos.
        Assert-True (Test-RegistryValueMatch '-1' '4294967295')
        Assert-True (Test-RegistryValueMatch '-1' '0xFFFFFFFF')
    }

    It 'los números distintos no se confunden' {
        Assert-False (Test-RegistryValueMatch '0x10' '10')
        Assert-False (Test-RegistryValueMatch '10' '11')
    }

    It 'lo que no es número se compara como texto, sin mayúsculas' {
        Assert-True  (Test-RegistryValueMatch 'Hola' 'hola')
        Assert-True  (Test-RegistryValueMatch ' hola ' 'hola')
        Assert-False (Test-RegistryValueMatch 'hola' 'adios')
        Assert-False (Test-RegistryValueMatch '10' 'diez')
    }

    It 'sin valor no hay coincidencia' {
        Assert-False (Test-RegistryValueMatch '' '0')
        Assert-False (Test-RegistryValueMatch $null '0')
        Assert-False (Test-RegistryValueMatch '0' '')
    }

    It 'un número descomunal no revienta, simplemente no es número' {
        Assert-NoThrow { Test-RegistryValueMatch '99999999999999999999999' '1' }
        Assert-False (Test-RegistryValueMatch '99999999999999999999999' '1')
    }
}

Describe 'core/Registry/SettingStatus.ps1 - el estado de una clave' {

    It 'el valor recomendado es Optimizado' {
        Assert-Equal 'optimized' (Get-RegistryKeyStatus (New-FakeKey -Current '1' -Recommended '1' -Default '0'))
    }

    It 'el valor de fábrica es Recomendado de fábrica' {
        Assert-Equal 'factory' (Get-RegistryKeyStatus (New-FakeKey -Current '0' -Recommended '1' -Default '0'))
    }

    It 'cualquier otro valor es Personalizado' {
        Assert-Equal 'custom' (Get-RegistryKeyStatus (New-FakeKey -Current '7' -Recommended '1' -Default '0'))
    }

    It 'compara por valor, no por cómo esté escrito' {
        Assert-Equal 'optimized' (Get-RegistryKeyStatus (New-FakeKey -Current '0xFFFFFFFF' -Recommended '-1' -Default '0'))
    }

    It 'si lo recomendado ya es lo de fábrica, manda de fábrica' {
        # No hay nada aplicado: decir "Optimizado" sería apuntarse un
        # mérito que no es de nadie.
        Assert-Equal 'factory' (Get-RegistryKeyStatus (New-FakeKey -Current '5' -Recommended '5' -Default '5'))
    }

    It 'un valor que no está es estar de fábrica' {
        # Windows usa su valor interno, así que el equipo está como
        # salió de fábrica para ese ajuste, aunque no haya nada escrito.
        Assert-Equal 'factory' (Get-RegistryKeyStatus (New-FakeKey -Current $null -State 'missing'))
    }

    It 'lo que no se ha podido leer no se afirma' {
        foreach ($estado in @('denied', 'badpath')) {
            Assert-Equal 'unknown' (Get-RegistryKeyStatus (New-FakeKey -Current $null -State $estado)) "con State '$estado'"
        }
    }

    It 'una clave todavía sin leer es desconocida' {
        $clave = New-TestKey 'Dword'
        Assert-Equal 'unknown' (Get-RegistryKeyStatus $clave)
    }

    It 'sin nada declarado con lo que comparar, tampoco se afirma' {
        # Personalizado sería una acusación sin pruebas.
        Assert-Equal 'unknown' (Get-RegistryKeyStatus (New-FakeKey -Current '7' -Recommended '' -Default ''))
    }

    It 'no lanza ni con una clave vacía' {
        Assert-NoThrow { Get-RegistryKeyStatus $null }
        Assert-Equal 'unknown' (Get-RegistryKeyStatus $null)
    }
}

Describe 'core/Registry/SettingStatus.ps1 - el estado de un ajuste' {

    It 'un ajuste sin claves no tiene estado' {
        # No es desconocido: es que no hay nada que mirar. La tarjeta
        # se queda con sus etiquetas declaradas.
        Assert-Null (Get-SettingStatus (New-FakeSetting @()))
    }

    It 'con una sola clave, el estado es el de la clave' {
        $ajuste = New-FakeSetting @((New-FakeKey -Current '1' -Recommended '1' -Default '0'))
        Assert-Equal 'optimized' (Get-SettingStatus $ajuste)
    }

    It 'varias claves de acuerdo dan ese estado' {
        $ajuste = New-FakeSetting @(
            (New-FakeKey -Current '0' -Recommended '1' -Default '0'),
            (New-FakeKey -Current '0' -Recommended '1' -Default '0'))
        Assert-Equal 'factory' (Get-SettingStatus $ajuste)
    }

    It 'aplicado a medias es Personalizado' {
        $ajuste = New-FakeSetting @(
            (New-FakeKey -Current '1' -Recommended '1' -Default '0'),
            (New-FakeKey -Current '0' -Recommended '1' -Default '0'))
        Assert-Equal 'custom' (Get-SettingStatus $ajuste)
    }

    It 'una clave que no se ha podido leer deja el ajuste en desconocido' {
        $ajuste = New-FakeSetting @(
            (New-FakeKey -Current '1' -Recommended '1' -Default '0'),
            (New-FakeKey -Current $null -State 'denied'))
        Assert-Equal 'unknown' (Get-SettingStatus $ajuste)
    }

    It 'volcarlo deja el estado en el ajuste y en cada clave' {
        $clave = New-FakeKey -Current '1' -Recommended '1' -Default '0'
        $ajuste = New-FakeSetting @($clave)

        Assert-Equal 'optimized' (Update-SettingStatus $ajuste)
        Assert-Equal 'optimized' $ajuste.Status
        Assert-Equal 'optimized' $clave.Status
    }

    It 'no lanza sin ajuste' {
        Assert-NoThrow { Update-SettingStatus $null }
    }
}

Describe 'core/Registry/SettingStatus.ps1 - contra el registro de verdad' {

    It 'leer la sección deja a cada ajuste con su estado' {
        # De punta a punta: se lee el equipo y el ajuste queda
        # clasificado sin que nadie de la interfaz toque nada.
        $clave = New-TestKey 'DwordCinco' -Recommended '5' -Default '0'
        $cat = New-TestCategory @($clave)

        Update-CategoryRegistryState -Category $cat | Out-Null

        Assert-Equal '5' $clave.Current
        Assert-Equal 'optimized' $clave.Status
        Assert-Equal 'optimized' @($cat.Items)[0].Status
    }

    It 'el mismo valor contra otro declarado sale de fábrica' {
        $cat = New-TestCategory @((New-TestKey 'DwordCinco' -Recommended '1' -Default '5'))
        Update-CategoryRegistryState -Category $cat | Out-Null
        Assert-Equal 'factory' @($cat.Items)[0].Status
    }

    It 'y contra dos que no cuadran, personalizado' {
        $cat = New-TestCategory @((New-TestKey 'DwordCinco' -Recommended '1' -Default '0'))
        Update-CategoryRegistryState -Category $cat | Out-Null
        Assert-Equal 'custom' @($cat.Items)[0].Status
    }

    It 'da igual el formato en que se declare' {
        # La clave 'Dword' vale -1, que se lee como 0xFFFFFFFF.
        foreach ($declarado in @('-1', '0xFFFFFFFF', '4294967295')) {
            $cat = New-TestCategory @((New-TestKey 'Dword' 'hex' -Recommended $declarado -Default '0'))
            Update-CategoryRegistryState -Category $cat | Out-Null
            Assert-Equal 'optimized' @($cat.Items)[0].Status "declarado como '$declarado'"
        }
    }

    It 'un valor que no existe deja el ajuste de fábrica' {
        $cat = New-TestCategory @((New-TestKey 'NoExisteEsteValor' -Recommended '1' -Default '0'))
        Update-CategoryRegistryState -Category $cat | Out-Null
        Assert-Equal 'factory' @($cat.Items)[0].Status
    }

    It 'refrescar vuelve a decidir, no se queda con lo de antes' {
        # Es lo que pide el botón de refrescar: el estado sale de la
        # lectura de AHORA, no de la primera vez que se entró.
        $clave = New-TestKey 'DwordCinco' -Recommended '5' -Default '0'
        $cat = New-TestCategory @($clave)
        Update-CategoryRegistryState -Category $cat | Out-Null
        Assert-Equal 'optimized' @($cat.Items)[0].Status

        # Cambia lo declarado -como si se corrigiera el archivo de la
        # sección- y se vuelve a leer: el estado tiene que moverse.
        $clave['Recommended'] = '1'
        $clave['Default'] = '5'
        Update-CategoryRegistryState -Category $cat | Out-Null
        Assert-Equal 'factory' @($cat.Items)[0].Status
    }

    It 'Regedit entera queda con un estado válido en cada ajuste' {
        $cat = Get-CategoryById 'regedit'
        Update-CategoryRegistryState -Category $cat | Out-Null

        foreach ($ajuste in @($cat.Items)) {
            Assert-NotNull $ajuste.Status "el ajuste '$($ajuste.Name)' se ha quedado sin estado"
            Assert-Contains $ajuste.Status (Get-SettingStatusNames) "el ajuste '$($ajuste.Name)'"
        }
    }

    It 'las secciones que no leen el registro no se inventan un estado' {
        foreach ($cat in Get-OptimizationCategories) {
            if ((Get-CategoryRegistryKeyCount $cat) -gt 0) { continue }

            Update-CategoryRegistryState -Category $cat | Out-Null
            foreach ($ajuste in @($cat.Items)) {
                Assert-Null $ajuste.Status "el ajuste '$($ajuste.Name)' de '$($cat.Id)' no declara claves"
            }
        }
    }
}

Remove-TestRegFixture
