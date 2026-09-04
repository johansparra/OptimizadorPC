# ============================================================
# Pruebas de core/Registry/CategoryState.ps1 — volcar el estado real en
# los datos de ui/Data/Categories/.
#
# Es el puente entre leer el registro y lo que acaba viéndose en
# la tarjeta, así que lo importante es que rellene las claves EN
# EL SITIO (son hashtables y la tarjeta las lee tal cual) y que
# avise del avance para que la barra de progreso se mueva.
#
# La sección de mentira y las claves de prueba salen de
# tests/Harness/Fixtures.ps1.
# ============================================================

New-TestRegFixture

Describe 'core/Registry/CategoryState.ps1 - contar claves' {

    It 'cuenta las que declaran los ajustes' {
        $cat = New-TestCategory @((New-TestKey 'Dword'), (New-TestKey 'Texto'))
        Assert-Equal 2 (Get-CategoryRegistryKeyCount $cat)
    }

    It 'una categoría sin claves cuenta cero' {
        $cat = New-TestCategory @()
        Assert-Equal 0 (Get-CategoryRegistryKeyCount $cat)
    }

    It 'las categorías de verdad no lanzan al contarlas' {
        foreach ($cat in Get-OptimizationCategories) {
            Assert-NoThrow { Get-CategoryRegistryKeyCount $cat } "en la sección '$($cat.Id)'"
        }
    }
}

Describe 'core/Registry/CategoryState.ps1 - volcar el estado' {

    It 'rellena Current y State en la propia clave' {
        $clave = New-TestKey 'DwordCinco'
        $cat = New-TestCategory @($clave)

        Assert-Equal 1 (Update-CategoryRegistryState -Category $cat)
        Assert-Equal 'read' $clave.State
        Assert-Equal '5'    $clave.Current
    }

    It 'respeta el Display de la clave' {
        $clave = New-TestKey 'Dword' 'hex'
        Update-CategoryRegistryState -Category (New-TestCategory @($clave)) | Out-Null
        Assert-Equal '0xFFFFFFFF' $clave.Current
    }

    It 'sin Display sale en decimal' {
        $clave = New-TestKey 'Dword'
        Update-CategoryRegistryState -Category (New-TestCategory @($clave)) | Out-Null
        Assert-Equal '4294967295' $clave.Current
    }

    It 'lo que no se puede leer deja Current vacío pero con State' {
        $clave = New-TestKey 'NoExisteEsteValor'
        Update-CategoryRegistryState -Category (New-TestCategory @($clave)) | Out-Null
        Assert-Equal 'missing' $clave.State
        Assert-Null  $clave.Current
    }

    It 'pisa el Current que viniera escrito a mano' {
        # El valor bueno es el del equipo: lo que hubiera en
        # ui/Data/Categories/ es como mucho una suposición vieja.
        $clave = New-TestKey 'DwordCinco'
        $clave['Current'] = 'inventado'
        Update-CategoryRegistryState -Category (New-TestCategory @($clave)) | Out-Null
        Assert-Equal '5' $clave.Current
    }

    It 'una categoría sin claves sale por la puerta de atrás' {
        $cat = New-TestCategory @()
        Assert-Equal 0 (Update-CategoryRegistryState -Category $cat)
    }
}

Describe 'core/Registry/CategoryState.ps1 - avisar del avance' {

    It 'avisa una vez al empezar y una por clave' {
        $avisos = New-Object System.Collections.Generic.List[string]
        $cat = New-TestCategory @((New-TestKey 'Dword'), (New-TestKey 'Texto'), (New-TestKey 'Qword'))

        Update-CategoryRegistryState -Category $cat -OnProgress {
            param($Done, $Total)
            $avisos.Add("$Done/$Total")
        } | Out-Null

        Assert-Equal @('0/3', '1/3', '2/3', '3/3') $avisos.ToArray()
    }

    It 'sin claves no avisa de nada' {
        $avisos = New-Object System.Collections.Generic.List[string]
        Update-CategoryRegistryState -Category (New-TestCategory @()) -OnProgress {
            param($Done, $Total)
            $avisos.Add('x')
        } | Out-Null
        Assert-Equal 0 $avisos.Count
    }

    It 'sin OnProgress funciona igual' {
        Assert-NoThrow { Update-CategoryRegistryState -Category (New-TestCategory @((New-TestKey 'Dword'))) }
    }
}

Describe 'core/Registry/CategoryState.ps1 - rastro de la sección' {

    It 'abre y cierra el bloque en el log' {
        Clear-AppLog
        $cat = New-TestCategory @((New-TestKey 'Dword'), (New-TestKey 'Texto'))
        Update-CategoryRegistryState -Category $cat | Out-Null

        $todo = @(Get-AppLog)
        # cabecera + una por clave + resumen
        Assert-Equal 4 $todo.Count

        Assert-Equal 'reading' $todo[0].Status
        Assert-Equal 'Prueba'  $todo[0].Message
        Assert-Match '2 keys'  $todo[0].Detail

        Assert-Equal 'done'   $todo[3].Status
        Assert-Equal 'Prueba' $todo[3].Message
        Assert-Match '2 read' $todo[3].Detail
        Assert-Match 'ms'     $todo[3].Detail
    }

    It 'el resumen cuenta cada clase de resultado' {
        Clear-AppLog
        $cat = New-TestCategory @((New-TestKey 'Dword'), (New-TestKey 'NoExisteEsteValor'))
        Update-CategoryRegistryState -Category $cat | Out-Null

        $resumen = @(Get-AppLog -Last 1)[0].Detail
        Assert-Match '1 missing' $resumen
        Assert-Match '1 read'    $resumen
    }

    It 'una categoría sin claves no apunta nada' {
        Clear-AppLog
        Update-CategoryRegistryState -Category (New-TestCategory @()) | Out-Null
        Assert-Equal 0 (Get-AppLogCount)
    }
}

Describe 'core/Registry/CategoryState.ps1 - contra las secciones de verdad' {

    It 'Regedit se lee entera sin lanzar y todas sus claves quedan con estado' {
        $cat = Get-CategoryById 'regedit'
        Assert-NotNull $cat 'debería existir ui/Data/Categories/Regedit.ps1'

        # Sin Assert-NoThrow a propósito: un scriptblock se ejecuta
        # en su propio ámbito y $total se quedaría a cero fuera. Si
        # esto lanzara, la prueba falla igual con el error de verdad.
        $total = Update-CategoryRegistryState -Category $cat
        Assert-True ($total -gt 0) 'Regedit declara claves, debería leer alguna'

        foreach ($ajuste in @($cat.Items)) {
            foreach ($clave in @($ajuste.Registry)) {
                Assert-NotNull $clave.State "la clave '$($clave.Name)' se ha quedado sin estado"
                Assert-Contains $clave.State @('read', 'missing', 'denied', 'badpath')
            }
        }
    }

    It 'ninguna sección declara una raíz que no exista' {
        # badpath es un error de escritura en ui/Data/Categories/, no del
        # equipo: sale igual en cualquier Windows.
        foreach ($cat in Get-OptimizationCategories) {
            Update-CategoryRegistryState -Category $cat | Out-Null
            foreach ($ajuste in @($cat.Items)) {
                foreach ($clave in @($ajuste.Registry)) {
                    Assert-NotEqual 'badpath' $clave.State "la ruta '$($clave.Path)' no arranca por una raíz conocida"
                }
            }
        }
    }
}

Remove-TestRegFixture
