# ============================================================
# Pruebas del pie plegable de cada tarjeta de ajuste: el que
# enseña las claves del registro que toca ese ajuste.
#
# Lo que se comprueba aquí es que la ruta y el valor se pueden
# SELECCIONAR y COPIAR. En WPF eso no sale gratis: un TextBlock no
# se puede seleccionar con el ratón, así que el dato va en un
# TextBox de solo lectura y la prueba vigila que siga siéndolo -de
# solo lectura y sin cromo-, porque cualquiera de las dos cosas se
# pierde con un descuido.
#
# NO se prueba el portapapeles de verdad. Es un recurso de todo
# Windows: escribir en él le pisaría al usuario lo que tuviera
# copiado, y con -BothHosts hay dos suites corriendo a la vez que
# se lo quitarían la una a la otra. Lo que sí se prueba es todo lo
# demás: que el botón lleva el texto entero, que avisa y que
# vuelve a su sitio.
# ============================================================

$TechWindow = New-AppWindow

# Una clave con una ruta larga de las de verdad, para ver que no se
# sale de la tarjeta y que se copia entera.
$TechPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'

function New-TechTestSetting {
    New-Setting -Name 'Ajuste de prueba' -Description 'Solo para las pruebas' -Value $true -Registry @(
        @{ Path = $TechPath; Name = 'NetworkThrottlingIndex'; Type = 'DWord'
           State = 'read'; Current = '10'; Status = 'custom'
           Recommended = '0xFFFFFFFF'; Default = '0x00000000' }
    )
}

# Find-Visuals ya devuelve el array envuelto para que no se desenrolle
# (ver tests/Harness/AppHost.ps1), así que aquí NADA de @(): volver a
# envolverlo mete el array dentro de otro. Se devuelve con la misma
# coma por el mismo motivo.
function Get-TechBoxes {
    param($Root)
    $cajas = Find-Visuals $Root { param($el) $el -is [System.Windows.Controls.TextBox] }
    , $cajas
}

function Get-TechCopyButtons {
    param($Root)
    $botones = Find-Visuals $Root { param($el) $el -is [System.Windows.Controls.Border] -and $el.Name -eq 'BtnCopy' }
    , $botones
}

# El orden en que salen del árbol no está garantizado -Find-Visuals va
# con una pila-, así que se comprueban como conjunto.
function Get-TechTexts {
    param($Elements)
    , @($Elements | ForEach-Object { [string]$_.Text })
}

function Get-TechTagTexts {
    param($Elements)
    , @($Elements | ForEach-Object { [string]$_.Tag.Text })
}

Describe 'ui/Components/Cards/TechnicalDetails.ps1 - el pie' {

    It 'el título nombra las claves de registro de Windows' {
        $pie = New-TechnicalDetails $TechWindow (New-TechTestSetting)
        $texto = Get-VisualText $pie

        Assert-Match 'Windows registry keys' $texto
        Assert-False ($texto -match 'Registry changes') 'el título viejo sigue ahí'
    }

    It 'un ajuste sin claves sigue avisando en vez de romperse' {
        $sinClaves = New-Setting -Name 'Sin claves' -Description 'x' -Value $true
        Assert-Match 'No registry keys declared' (Get-VisualText (New-TechnicalDetails $TechWindow $sinClaves))
    }
}

Describe 'ui/Components/Cards/TechnicalDetails.ps1 - seleccionar y copiar' {

    It 'la ruta y el valor son texto seleccionable' {
        $pie = New-TechnicalDetails $TechWindow (New-TechTestSetting)
        $cajas = Get-TechBoxes $pie

        Assert-Equal 2 $cajas.Count 'una caja por campo: ruta y valor'

        $textos = Get-TechTexts $cajas
        Assert-Contains $TechPath $textos
        Assert-Contains 'NetworkThrottlingIndex' $textos
    }

    It 'son de solo lectura, no campos de escribir' {
        foreach ($caja in (Get-TechBoxes (New-TechnicalDetails $TechWindow (New-TechTestSetting)))) {
            Assert-True $caja.IsReadOnly "'$($caja.Text)' se podría editar"
            Assert-False $caja.IsReadOnlyCaretVisible 'no debería enseñar cursor de escritura'
        }
    }

    It 'no se les nota que son cajas de texto' {
        # Sin borde y con el fondo transparente se ven como el texto
        # de al lado: el aspecto del bloque no cambia por poder
        # seleccionarlo.
        foreach ($caja in (Get-TechBoxes (New-TechnicalDetails $TechWindow (New-TechTestSetting)))) {
            Assert-Equal 0 $caja.BorderThickness.Left
            Assert-Equal 0 $caja.BorderThickness.Bottom
            Assert-Equal 0 $caja.Background.Color.A 'el fondo tiene que ser transparente'
            Assert-Equal 0 $caja.Padding.Left
        }
    }

    It 'una ruta larga baja de línea en vez de salirse' {
        foreach ($caja in (Get-TechBoxes (New-TechnicalDetails $TechWindow (New-TechTestSetting)))) {
            Assert-Equal 'Wrap' ([string]$caja.TextWrapping)
        }
    }

    It 'cada campo trae su botón de copiar' {
        $botones = Get-TechCopyButtons (New-TechnicalDetails $TechWindow (New-TechTestSetting))

        Assert-Equal 2 $botones.Count
        foreach ($boton in $botones) {
            Assert-Equal (Glyph 'Copy') ([string]$boton.Child.Text)
            Assert-NotNull $boton.ToolTip
        }
    }

    It 'el botón lleva el texto ENTERO, no lo que se ve' {
        # Es lo que importa con las rutas largas: se copia la ruta
        # completa aunque en pantalla haya bajado de línea.
        $textos = Get-TechTagTexts (Get-TechCopyButtons (New-TechnicalDetails $TechWindow (New-TechTestSetting)))

        Assert-Contains $TechPath $textos
        Assert-Contains 'NetworkThrottlingIndex' $textos
    }

    It 'al copiar avisa con una marca verde y luego vuelve a su sitio' {
        $boton = New-CopyButton 'HKEY_CURRENT_USER\Software' 'Copy the registry path'

        Show-CopyFeedback $boton
        Assert-Equal (Glyph 'Check') ([string]$boton.Child.Text)
        Assert-Equal (T 'Copied') ([string]$boton.ToolTip)

        # El temporizador no corre sin bucle de mensajes, así que se
        # llama a lo que él llamaría.
        Reset-CopyFeedback
        Assert-Equal (Glyph 'Copy') ([string]$boton.Child.Text)
        Assert-Equal (T 'Copy the registry path') ([string]$boton.ToolTip)
    }

    It 'solo un botón avisa a la vez' {
        $uno = New-CopyButton 'uno' 'Copy the registry path'
        $dos = New-CopyButton 'dos' 'Copy the value name'

        Show-CopyFeedback $uno
        Show-CopyFeedback $dos

        Assert-Equal (Glyph 'Copy')  ([string]$uno.Child.Text) 'el primero debería haber vuelto a su sitio'
        Assert-Equal (Glyph 'Check') ([string]$dos.Child.Text)

        Reset-CopyFeedback
    }

    It 'apagar el aviso sin nadie avisando no hace nada' {
        Reset-CopyFeedback
        Assert-NoThrow { Reset-CopyFeedback }
    }

    It 'un botón sin texto no dice que ha copiado' {
        # Sin nada que copiar no se toca el portapapeles ni se avisa:
        # SetText con cadena vacía lanza.
        $vacio = New-CopyButton '' 'Copy the registry path'
        Assert-False (Copy-TechnicalValue $vacio)
        Assert-Equal (Glyph 'Copy') ([string]$vacio.Child.Text)
    }
}

Describe 'ui/Components/Cards/TechnicalDetails.ps1 - dentro de la pantalla' {

    It 'la sección de verdad enseña sus claves copiables' {
        $ventana = New-AppWindow
        $cat = Get-CategoryById 'regedit'
        Show-View -Name 'Show-CategoryDetailView' -Arguments @{ Category = $cat }

        $contenido = $ventana.FindName('MainContent').Content
        $claves = 0
        foreach ($ajuste in @($cat.Items)) { $claves += @($ajuste.Registry).Count }

        # Dos campos copiables por clave: la ruta y el valor.
        Assert-Equal ($claves * 2) (Get-TechBoxes $contenido).Count
        Assert-Equal ($claves * 2) (Get-TechCopyButtons $contenido).Count

        # Y llevan la ruta de verdad de la sección, no un texto suelto.
        $rutas = Get-TechTagTexts (Get-TechCopyButtons $contenido)
        Assert-Contains @($cat.Items)[0].Registry[0].Path $rutas
    }
}
