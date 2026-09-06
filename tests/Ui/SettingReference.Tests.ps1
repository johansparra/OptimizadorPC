# ============================================================
# Pruebas de ui/Components/Cards/SettingReference.ps1 — la franja
# plegable "Referencia".
#
# Funciona como "Detalles técnicos": oculta por defecto, sale al
# activar su opción del menú Vista ('reference'), se pliega con el
# mismo mecanismo (New-DisclosureSection). Dentro van tres bloques
# de consulta de la clave: Valores, Óptimo para gaming y Enlace.
# El "Qué hace" NO está aquí: es el contenido principal y vive en
# la descripción de la tarjeta.
#
# 'reference' se enciende y se apaga en cada prueba: escribe en el
# settings.json redirigido del arnés, nunca en el del usuario.
# ============================================================

$RefWindow = New-AppWindow

function New-RefSetting {
    param([string]$GamingOptimal = 'yes', $Link = 'https://learn.microsoft.com/x')
    New-Setting -Name 'Clave de prueba' -Description 'qué hace' `
        -Values '0x0A (10) - 1-70 - 0xFFFFFFFF' `
        -GamingOptimal $GamingOptimal -GamingNote 'quita el throttling en partida' `
        -Link $Link -Value $true `
        -Registry @(
            @{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; Name = 'V'; Type = 'DWord'
               Recommended = '1'; Default = '0' }
        )
}

# Texto de la tarjeta con "Referencia" encendida.
function Get-RefCardText {
    param($Setting)
    Set-ViewOption 'reference' $true
    try { Get-VisualText (New-SettingCard $RefWindow $Setting) }
    finally { Set-ViewOption 'reference' $false }
}

# Las filas que abren/cierran una franja: Border con el cuerpo en
# el Tag. Find-Visuals ya devuelve el array envuelto; se reenvía
# con la misma coma y SIN @() (ver tests/Harness/AppHost.ps1).
function Get-Disclosures {
    param($Root)
    $encontrados = Find-Visuals $Root {
        param($el)
        $el -is [System.Windows.Controls.Border] -and
        $el.Tag -and $el.Tag.PSObject.Properties['Body']
    }
    , $encontrados
}

Describe 'ui/Components/Cards/SettingReference.ps1 - cuándo aparece' {

    It 'la opción "reference" arranca apagada' {
        Assert-False (Get-ViewOption 'reference')
    }

    It 'con la opción apagada, la franja no está' {
        $texto = Get-VisualText (New-SettingCard $RefWindow (New-RefSetting))
        Assert-False ($texto -match 'Good for gaming') 'la franja Referencia no debería estar'
    }

    It 'encendida y con clave de registro, sale con su cabecera y sus tres bloques' {
        $texto = Get-RefCardText (New-RefSetting)
        Assert-Match 'Reference'       $texto 'falta la cabecera de la franja'
        Assert-Match 'Values'          $texto
        Assert-Match 'Good for gaming' $texto
        Assert-Match 'Link'            $texto
    }

    It 'no incluye "Qué hace": ese es el contenido principal de la tarjeta' {
        Assert-False ((Get-RefCardText (New-RefSetting)) -match 'What it does')
    }

    It 'un ajuste sin clave de registro no la recibe' {
        Set-ViewOption 'reference' $true
        try {
            $ajuste = New-Setting -Name 'Toggle' -Description 'x' -Values 'y' -GamingOptimal 'yes' -Value $true
            Assert-False ((Get-VisualText (New-SettingCard $RefWindow $ajuste)) -match 'Good for gaming')
        }
        finally { Set-ViewOption 'reference' $false }
    }
}

Describe 'ui/Components/Cards/SettingReference.ps1 - el contenido' {

    It 'el estado de gaming sale como Sí / No / N/A' {
        Assert-Match 'Yes' (Get-RefCardText (New-RefSetting -GamingOptimal 'yes'))
        Assert-Match 'No'  (Get-RefCardText (New-RefSetting -GamingOptimal 'no'))
        Assert-Match 'N/A' (Get-RefCardText (New-RefSetting -GamingOptimal 'na'))
    }

    It 'sin enlace, lo dice en vez de dejar un hueco' {
        Assert-Match 'No reference link' (Get-RefCardText (New-RefSetting -Link $null))
    }

    It 'el enlace es un texto pulsable con la URL y su pie de ayuda' {
        Set-ViewOption 'reference' $true
        try {
            $tarjeta = New-SettingCard $RefWindow (New-RefSetting -Link 'https://example.com/docs')
            $link = (Find-Visuals $tarjeta {
                param($el)
                $el -is [System.Windows.Controls.TextBlock] -and $el.Tag -eq 'https://example.com/docs'
            })[0]
            Assert-NotNull $link 'no se ha encontrado el enlace'
            Assert-Equal 'https://example.com/docs' ([string]$link.Text)
            Assert-Equal 'Hand' ([string]$link.Cursor)
            Assert-NotNull $link.ToolTip
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'pulsar un enlace con esquema no permitido no lanza ni abre nada' {
        Set-ViewOption 'reference' $true
        try {
            $tarjeta = New-SettingCard $RefWindow (New-RefSetting -Link 'ftp://host/x')
            $link = (Find-Visuals $tarjeta {
                param($el)
                $el -is [System.Windows.Controls.TextBlock] -and $el.Tag -eq 'ftp://host/x'
            })[0]
            $clic = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
            $clic.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
            Assert-NoThrow { $link.RaiseEvent($clic) }
        }
        finally { Set-ViewOption 'reference' $false }
    }
}

Describe 'ui/Components/Cards/SettingReference.ps1 - se pliega como "Detalles técnicos"' {

    It 'el cuerpo arranca plegado' {
        Set-ViewOption 'reference' $true
        try {
            $tarjeta = New-SettingCard $RefWindow (New-RefSetting)
            # Asignar antes de filtrar: Get-Disclosures devuelve el
            # array con la coma y encauzarlo directo lo pasaría entero
            # como un solo elemento (ver AppHost.ps1).
            $filas = Get-Disclosures $tarjeta
            $ref = ($filas | Where-Object {
                (Get-VisualText $_.Tag.Body) -match 'Good for gaming'
            })[0]
            Assert-NotNull $ref 'no se ha encontrado la franja Referencia'
            Assert-Equal 'Collapsed' ([string]$ref.Tag.Body.Visibility)
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'con "Detalles técnicos" debajo, "Referencia" no redondea el pie de la tarjeta' {
        # 'technical' viene encendida por defecto: "Referencia" queda
        # en medio y su fila NO debe redondear, o taparía en cuadrado
        # la esquina de la tarjeta a mitad del cuerpo (ver el bug de
        # hover que arregló Disclosure.ps1).
        Set-ViewOption 'reference' $true
        try {
            $filas = Get-Disclosures (New-SettingCard $RefWindow (New-RefSetting))
            Assert-Equal 2 $filas.Count 'deberían salir las dos franjas'

            $ref = $filas | Where-Object { -not $_.Tag.Flush }
            $tec = $filas | Where-Object { $_.Tag.Flush }
            Assert-NotNull $ref 'Referencia debería ir sin redondeo'
            Assert-NotNull $tec 'Detalles técnicos debería ir con redondeo'
            Assert-Equal 0  $ref.CornerRadius.BottomLeft
            Assert-Equal 15 $tec.CornerRadius.BottomLeft
        }
        finally { Set-ViewOption 'reference' $false }
    }

    It 'sola (sin "Detalles técnicos"), "Referencia" sí redondea el pie' {
        Set-ViewOption 'reference' $true
        Set-ViewOption 'technical' $false
        try {
            $filas = Get-Disclosures (New-SettingCard $RefWindow (New-RefSetting))
            Assert-Equal 1 $filas.Count
            Assert-Equal 15 $filas[0].CornerRadius.BottomLeft
        }
        finally {
            Set-ViewOption 'reference' $false
            Set-ViewOption 'technical' $true
        }
    }
}
