# ============================================================
# PreferenceRegistry.ps1
# Registro de las opciones de la pantalla Settings.
#
# NO contiene opciones: solo el mecanismo. Cada opción vive en
# su propio archivo dentro de ui/Preferences/, igual que cada
# sección vive en ui/Categories/.
#
#   -> Añadir una opción  = crear un archivo en ui/Preferences/
#   -> Quitarla           = borrar ese archivo
#   -> Reordenar          = cambiar su campo Order
#
# La pantalla Settings se dibuja sola a partir de lo que haya
# registrado: no hay que tocar la vista para añadir opciones.
# ============================================================

$PreferenceList = New-Object System.Collections.Generic.List[object]

<#
    Da de alta una opción. Campos:

    Id           (string)   Identificador único: 'language', 'theme'...
    Order        (int)      Posición. 10, 20, 30... como las secciones.
    Group        (string)   Cabecera bajo la que se agrupa. Se traduce.
    Label        (string)   Título de la opción. Se traduce.
    Description  (string)   Explicación gris debajo. Se traduce.
    Type         (string)   'Choice'  -> desplegable
                            'Toggle'  -> interruptor
    Options      (array o scriptblock)
                            Solo para 'Choice'. Cada opción es
                            @{ Value = 'es'; Label = 'Español' }.
                            Si es un scriptblock se evalúa al pintar,
                            que es lo que permite listas dinámicas.
    TranslateOptions (bool) $false si las etiquetas de las opciones NO
                            deben traducirse. Es el caso de los nombres
                            de idioma, que van siempre en su propio
                            idioma. Por defecto $true.
    Get          (scriptblock)  Devuelve el valor actual.
    Set          (scriptblock)  param($Value) aplica el valor nuevo.
                                Es responsable de guardarlo si procede.
#>
function Register-Preference {
    param([Parameter(Mandatory)][hashtable]$Definition)

    $defaults = @{
        Order = 999; Group = 'General'; Description = ''
        Type = 'Choice'; Options = @(); TranslateOptions = $true
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Definition.ContainsKey($key)) { $Definition[$key] = $defaults[$key] }
    }

    foreach ($required in @('Id', 'Label', 'Get', 'Set')) {
        if (-not $Definition[$required]) {
            throw "Register-Preference: falta el campo obligatorio '$required'."
        }
    }

    $PreferenceList.Add([PSCustomObject]$Definition)
}

function Get-Preferences {
    $PreferenceList | Sort-Object Order
}

# Los grupos, en el orden en que aparece su primera opción.
function Get-PreferenceGroups {
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($preference in Get-Preferences) {
        if (-not $seen.Contains($preference.Group)) { $seen.Add($preference.Group) }
    }
    $seen
}

# Resuelve las opciones, ya vengan como array o como scriptblock.
function Get-PreferenceOptions {
    param($Preference)
    if ($Preference.Options -is [scriptblock]) { & $Preference.Options } else { $Preference.Options }
}

function Get-PreferenceById {
    param([string]$Id)
    $PreferenceList | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}
