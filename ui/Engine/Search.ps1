# ============================================================
# Search.ps1
# El buscador global. Mecanismo, no datos.
#
# No sabe qué secciones hay ni qué ajustes existen: se los pregunta
# al registro de categorías, así que una sección nueva entra en el
# buscador sola, sin tocar este archivo.
#
# Cómo funciona
# -------------
# Se arma UN índice plano con una entrada por cada cosa buscable
# -cada sección, cada ajuste, cada paso de una sección de comandos y
# cada guía-, y cada entrada trae:
#
#   Fields     los datos que se pueden buscar, con su etiqueta. Es lo
#              que permite decir POR QUÉ ha salido un resultado.
#   Haystack   todos esos datos en minúsculas y en una sola cadena.
#              Buscar es mirar si están dentro todos los términos.
#
# El índice se guarda y se reutiliza; se tira cuando cambia lo que
# hay dentro. Hoy eso pasa en dos sitios, y los dos llaman a
# Reset-SearchIndex:
#
#   - Leer el registro de una sección, que rellena Current y Status.
#   - Cambiar de idioma: el índice guarda TAMBIÉN el texto traducido,
#     porque quien usa la aplicación en español busca en español.
#
# Lo técnico -rutas, nombres de valor, números- no se traduce nunca,
# ni aquí ni en pantalla: es texto para copiar y pegar.
# ============================================================

$SearchQuery = ''
$SearchIndex = $null

# Lo que se está buscando ahora mismo. Vive aquí y no en el control
# para que la vista se pueda repintar -al cambiar de idioma, por
# ejemplo- sin que nadie tenga que ir a leer la caja de texto.
function Set-SearchQuery { param([string]$Text) $script:SearchQuery = [string]$Text }
function Get-SearchQuery { $script:SearchQuery }

function Reset-SearchIndex { $script:SearchIndex = $null }

function Get-SearchIndex {
    if ($null -eq $script:SearchIndex) { $script:SearchIndex = New-SearchIndex }
    $script:SearchIndex
}

<#
    Un campo buscable: la etiqueta con la que se enseña y su texto.

    -Translate para lo que en pantalla pasa por T (nombres,
    descripciones, etiquetas): así "Recomendado" encuentra lo mismo
    que "Recommended" y el buscador funciona en los dos idiomas. Lo
    técnico se queda tal cual.
#>
function New-SearchField {
    param([string]$Label, $Value, [switch]$Translate)

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    $shown = $text
    $extra = ''
    if ($Translate) {
        $shown = T $text
        if ($shown -ne $text) { $extra = $text }   # el original también busca
    }

    [PSCustomObject]@{ Label = $Label; Text = $shown; Also = $extra }
}

<#
    Un campo hecho de varios valores sueltos: las etiquetas de un
    ajuste, las opciones de un desplegable.

    Se traduce CADA UNO y luego se juntan. Juntarlos antes y pasar
    la frase entera por T no traduciría nada -esa frase no está en
    ningún diccionario ni tiene por qué estar- y de paso ensuciaría
    la lista de textos pendientes que enseña Get-MissingTranslations.
#>
function New-SearchListField {
    param([string]$Label, $Values)

    $items = @(@($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -eq 0) { return $null }

    $original = ($items -join ' ')
    $mostrado = (@($items | ForEach-Object { T ([string]$_) }) -join ' ')

    $extra = ''
    if ($mostrado -ne $original) { $extra = $original }

    [PSCustomObject]@{ Label = $Label; Text = $mostrado; Also = $extra }
}

# Los campos de un ajuste: lo suyo, lo de su sección y lo de cada
# clave del registro que declare.
function Get-SettingSearchFields {
    param($Category, $Setting)

    $fields = New-Object System.Collections.Generic.List[object]

    $fields.Add((New-SearchField 'Name'        $Setting.Name        -Translate))
    $fields.Add((New-SearchField 'Description' $Setting.Description -Translate))
    $fields.Add((New-SearchField 'Section'     $Category.Name       -Translate))
    $fields.Add((New-SearchListField 'Tags' $Setting.Tags))

    # El valor de un interruptor es $true/$false y no aporta nada;
    # el de un desplegable sí, y además se traduce.
    if ($Setting.Options) {
        $fields.Add((New-SearchListField 'Options' $Setting.Options))
        $fields.Add((New-SearchField     'Value'   $Setting.Value -Translate))
    }

    foreach ($key in @($Setting.Registry)) {
        $fields.Add((New-SearchField 'Registry path'  $key.Path))
        $fields.Add((New-SearchField 'Registry value' $key.Name))
        $fields.Add((New-SearchField 'Type'           $key.Type))
        $fields.Add((New-SearchField 'Current value'  $key.Current))
        $fields.Add((New-SearchField 'Recommended'    $key.Recommended))
        $fields.Add((New-SearchField 'Factory'        $key.Default))
    }

    # El estado real, si ya se ha leído el equipo: buscar "optimizado"
    # saca lo que está aplicado.
    if ($Setting.Status) {
        $fields.Add((New-SearchField 'Status' (Get-StatusStyle $Setting.Status).Label -Translate))
    }

    $fields.ToArray() | Where-Object { $_ }
}

# Los campos de un paso de una sección de comandos: lo que se ve en
# su fila, y el comando tal cual (texto técnico, sin traducir).
function Get-StepSearchFields {
    param($Category, $Step)

    @(
        (New-SearchField 'Name'        $Step.Name        -Translate)
        (New-SearchField 'Description' $Step.Description -Translate)
        (New-SearchField 'Section'     $Category.Name    -Translate)
        (New-SearchField 'Command'     (Format-CommandLine $Step))
        (New-SearchField 'Warning'     $Step.Warning     -Translate)
    ) | Where-Object { $_ }
}

<#
    Los campos de una guía. El texto es del usuario: NO pasa por T. El
    texto entero va marcado Long, para que el resultado enseñe solo el
    trozo de alrededor de lo buscado (Get-SearchMatchField).
#>
function Get-GuideSearchFields {
    param($Guide)

    $text = New-SearchField 'Guide text' (ConvertTo-GuidePlainText $Guide)
    if ($text) { $text | Add-Member -NotePropertyName 'Long' -NotePropertyValue $true }
    @(
        (New-SearchField 'Name' $Guide.Title)
        (New-SearchField 'File' $Guide.FileName)
        $text
    ) | Where-Object { $_ }
}

<#
    La "sección" bajo la que se agrupan las guías en los resultados. No
    es una categoría registrada -las guías no son una sección de
    Optimizar-, pero tiene lo que piden la cabecera del grupo y la
    tarjeta: nombre, icono y colores.
#>
$GuideSearchCategory = [PSCustomObject]@{
    Id = 'guides'; Name = 'Guides'; Icon = 'Book'; Accent = 'Accent'; AccentSoft = 'AccentSoft'
    Description = 'Your reference notes: open one to read it and copy what you need'
}

# Una entrada del índice, con su pajar ya en minúsculas.
function New-SearchEntry {
    param([string]$Kind, $Category, $Setting, $Fields, $Step, $Guide)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($field in @($Fields)) {
        $parts.Add($field.Text)
        if ($field.Also) { $parts.Add($field.Also) }
    }

    [PSCustomObject]@{
        Kind     = $Kind
        Category = $Category
        Setting  = $Setting
        Step     = $Step
        Guide    = $Guide
        Fields   = @($Fields)
        Haystack = ($parts.ToArray() -join ' ').ToLowerInvariant()
    }
}

<#
    Arma el índice entero recorriendo las secciones visibles.

    Se indexa la sección además de sus ajustes, para que buscar
    "regedit" o "juegos" lleve a la sección aunque ningún ajuste
    concreto se llame así.
#>
function New-SearchIndex {
    $index = New-Object System.Collections.Generic.List[object]

    foreach ($category in Get-OptimizationCategories) {
        $catFields = @(
            (New-SearchField 'Section'     $category.Name        -Translate)
            (New-SearchField 'Description' $category.Description -Translate)
        ) | Where-Object { $_ }

        $index.Add((New-SearchEntry 'category' $category $null $catFields))

        foreach ($setting in @($category.Items)) {
            $index.Add((New-SearchEntry 'setting' $category $setting (Get-SettingSearchFields $category $setting)))
        }

        foreach ($step in @($category.Steps | Where-Object { $_ })) {
            $index.Add((New-SearchEntry 'step' $category $null (Get-StepSearchFields $category $step) -Step $step))
        }
    }

    foreach ($guide in @(Get-Guides)) {
        $index.Add((New-SearchEntry 'guide' $GuideSearchCategory $null (Get-GuideSearchFields $guide) -Guide $guide))
    }

    $index.ToArray()
}

# Los términos de una consulta: en minúsculas y separados por
# espacios. Buscar "windows update" pide las dos palabras, no la
# frase exacta, que es lo que uno espera al teclear.
function Get-SearchTerms {
    param([string]$Query)

    if ([string]::IsNullOrWhiteSpace($Query)) { return @() }
    @($Query.ToLowerInvariant() -split '\s+' | Where-Object { $_ })
}

<#
    Busca. Devuelve las entradas que encajan, cada una con el campo
    por el que ha encajado (Match), para poder enseñarlo.

    Coincidencia PARCIAL y sin distinguir mayúsculas: se mira si el
    término está DENTRO del texto, así que "throttl" encuentra
    NetworkThrottlingIndex y media ruta del registro encuentra la
    clave entera.
#>
function Get-SearchResults {
    param([string]$Query)

    $terms = Get-SearchTerms $Query
    if ($terms.Count -eq 0) { return @() }

    $found = New-Object System.Collections.Generic.List[object]

    foreach ($entry in (Get-SearchIndex)) {
        $ok = $true
        foreach ($term in $terms) {
            if ($entry.Haystack.IndexOf($term, [System.StringComparison]::Ordinal) -lt 0) { $ok = $false; break }
        }
        if (-not $ok) { continue }

        $entry | Add-Member -NotePropertyName 'Match' -NotePropertyValue (Get-SearchMatchField $entry $terms) -Force
        $found.Add($entry)
    }

    $found.ToArray()
}

# El campo que explica el resultado: el primero que contenga alguno
# de los términos. Sirve para que el usuario vea que ha encajado por
# la ruta del registro y no por el nombre.
function Get-SearchMatchField {
    param($Entry, [string[]]$Terms)

    foreach ($field in @($Entry.Fields)) {
        $texto = ($field.Text + ' ' + $field.Also).ToLowerInvariant()
        foreach ($term in $Terms) {
            $at = $texto.IndexOf($term, [System.StringComparison]::Ordinal)
            if ($at -lt 0) { continue }
            if (-not ($field.PSObject.Properties['Long'] -and $field.Long)) { return $field }
            return [PSCustomObject]@{ Label = $field.Label; Text = (Get-SearchExcerpt $field.Text $at); Also = '' }
        }
    }
    $null
}

# El trozo de un texto largo alrededor de una posición, en una línea:
# "…deshabilitar NetTrace si no estás depurando…".
function Get-SearchExcerpt {
    param([string]$Text, [int]$At, [int]$Around = 60)

    $from = [Math]::Max(0, $At - $Around)
    $to = [Math]::Min($Text.Length, $At + $Around)
    $cut = ($Text.Substring($from, $to - $from) -replace '\s+', ' ').Trim()
    if ($from -gt 0) { $cut = '…' + $cut }
    if ($to -lt $Text.Length) { $cut = $cut + '…' }
    $cut
}

<#
    Los resultados agrupados por sección, en el orden del índice de
    categorías. Cada grupo trae la categoría y sus entradas.

    Agrupar aquí y no en la vista deja la pantalla como debe ser: un
    bucle sobre grupos y nada de lógica.
#>
function Group-SearchResults {
    param($Results)

    $groups = New-Object System.Collections.Generic.List[object]
    $byId = @{}

    foreach ($entry in @($Results)) {
        # Una entrada vacía NO forma grupo. Sin esto, un $null que se
        # cuele -y se cuela: mira Update-SearchPopup- crea un grupo sin
        # categoría, y la cabecera acaba pidiendo un icono con el
        # nombre vacío y tumbando la ventana entera.
        if (-not $entry -or -not $entry.Category) { continue }

        $id = [string]$entry.Category.Id
        if (-not $byId.ContainsKey($id)) {
            $group = [PSCustomObject]@{
                Category = $entry.Category
                Entries  = New-Object System.Collections.Generic.List[object]
            }
            $byId[$id] = $group
            $groups.Add($group)
        }
        $byId[$id].Entries.Add($entry)
    }

    $groups.ToArray()
}
