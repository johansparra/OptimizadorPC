# ------------------------------------------------------------
# Opción: material de la ventana
#
# Mica y Acrílico son el fondo translúcido de Windows 11: la
# ventana deja ver el escritorio, borroso y teñido. Lo pone
# ui/Components/Shell/WindowMaterial.ps1, que explica por qué
# viene apagado y por qué es EXCLUYENTE con el degradado propio.
#
# La lista de opciones es dinámica: en un Windows que no lo
# admita solo aparece "Solid", en vez de ofrecer algo que no va a
# hacer nada.
# ------------------------------------------------------------

Register-Preference @{
    Order       = 30
    Id          = 'material'
    Group       = 'Appearance'
    Label       = 'Window material'
    Description = 'Let the Windows 11 background show through the app. Needs Windows 11 22H2 or newer'
    Type        = 'Choice'

    Options = {
        $list = @(
            @{ Value = 'None'; Label = 'Solid' }
        )
        if (Test-SystemBackdropSupport) {
            $list += @{ Value = 'Mica';    Label = 'Mica' }
            $list += @{ Value = 'Acrylic'; Label = 'Acrylic' }
        }
        $list
    }

    Get = { Get-WindowMaterial }

    Set = {
        param($Value)
        Set-WindowMaterialChoice $Value
    }
}
