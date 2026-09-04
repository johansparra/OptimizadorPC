# ============================================================
# tests/Harness/TestKit.ps1
# El armazón de las pruebas: Describe / It y las comprobaciones.
#
# Son cuarenta líneas de nada y a propósito: el proyecto no
# depende de ningún módulo, el .exe es portable y las pruebas
# tienen que correr tal cual en los dos hosts (powershell 5.1 y
# pwsh 7) sin instalar nada. Pester haría lo mismo, pero la única
# versión que trae Windows de serie es la 3.4, cuya sintaxis no
# se parece a la moderna: acabaríamos pidiendo un Install-Module
# para arrancar. Ver tests/README.md.
#
# Se carga UNA vez desde tests/Run-Tests.ps1, y los archivos
# *.Tests.ps1 se cargan a continuación en ese mismo ámbito: así
# ven estas funciones y también las de la aplicación.
# ============================================================

$TestState = [PSCustomObject]@{
    Passed   = 0
    Failed   = 0
    Skipped  = 0
    Group    = ''
    Filter   = ''
    Failures = New-Object System.Collections.Generic.List[object]
}

# ---- Estructura ---------------------------------------------

function Describe {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )

    $script:TestState.Group = $Name
    Write-Host ''
    Write-Host "  $Name" -ForegroundColor Cyan
    & $Body
}

<#
    Una prueba. Pasa si el bloque termina sin lanzar.

        It 'un DWord de 0xFFFFFFFF no sale negativo' {
            Assert-Equal '4294967295' (Format-RegistryValue -1 $dword)
        }

    Para saltarla sin marcarla como fallo, Skip-Test.
#>
function It {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )

    if ($TestState.Filter -and
        $Name -notlike $TestState.Filter -and
        $TestState.Group -notlike $TestState.Filter) { return }

    try {
        & $Body | Out-Null
        $script:TestState.Passed++
        Write-Host '    ok    ' -NoNewline -ForegroundColor Green
        Write-Host $Name -ForegroundColor DarkGray
    }
    catch {
        $message = [string]$_.Exception.Message

        if ($message -like 'SKIP:*') {
            $script:TestState.Skipped++
            Write-Host '    --    ' -NoNewline -ForegroundColor Yellow
            Write-Host ('{0}  ({1})' -f $Name, $message.Substring(5).Trim()) -ForegroundColor DarkGray
            return
        }

        $script:TestState.Failed++
        $script:TestState.Failures.Add([PSCustomObject]@{
            Group   = $TestState.Group
            Name    = $Name
            Message = $message
            Where   = [string]$_.InvocationInfo.PositionMessage
        })
        Write-Host '    FALLA ' -NoNewline -ForegroundColor Red
        Write-Host $Name -ForegroundColor Red
        Write-Host ('          ' + $message) -ForegroundColor DarkRed
    }
}

# Salta la prueba sin contarla como fallo. Para lo que depende
# de cómo esté montada la máquina (permisos, claves protegidas).
function Skip-Test {
    param([Parameter(Mandatory)][string]$Reason)
    throw "SKIP: $Reason"
}

# ---- Comprobaciones -----------------------------------------

# Cómo se enseña un valor en el mensaje de error. Un $null tiene
# que verse: '' y $null se confunden y suelen ser el fallo.
function Show-TestValue {
    param($Value)

    if ($null -eq $Value) { return '<null>' }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return '@(' + ((@($Value) | ForEach-Object { Show-TestValue $_ }) -join ', ') + ')'
    }
    if ($Value -is [bool]) { if ($Value) { return '$true' } else { return '$false' } }
    "'$Value'"
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Because)

    $same = $false
    if ($Expected -is [array] -or $Actual -is [array]) {
        $same = (Show-TestValue $Expected) -ceq (Show-TestValue $Actual)
    }
    else {
        $same = ($Expected -eq $Actual)
    }

    if (-not $same) {
        throw ('esperaba {0} y llegó {1}{2}' -f (Show-TestValue $Expected), (Show-TestValue $Actual), (Get-TestBecause $Because))
    }
}

function Assert-NotEqual {
    param($Expected, $Actual, [string]$Because)
    if ($Expected -eq $Actual) {
        throw ('no debía ser {0}{1}' -f (Show-TestValue $Expected), (Get-TestBecause $Because))
    }
}

function Assert-True {
    param($Condition, [string]$Because)
    if (-not $Condition) { throw ('esperaba verdadero{0}' -f (Get-TestBecause $Because)) }
}

function Assert-False {
    param($Condition, [string]$Because)
    if ($Condition) { throw ('esperaba falso{0}' -f (Get-TestBecause $Because)) }
}

function Assert-NotNull {
    param($Value, [string]$Because)
    if ($null -eq $Value) { throw ('esperaba algo y llegó <null>{0}' -f (Get-TestBecause $Because)) }
}

function Assert-Null {
    param($Value, [string]$Because)
    if ($null -ne $Value) { throw ('esperaba <null> y llegó {0}{1}' -f (Show-TestValue $Value), (Get-TestBecause $Because)) }
}

function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Because)
    if ($Text -notmatch $Pattern) {
        throw ("'{0}' no encaja con /{1}/{2}" -f $Text, $Pattern, (Get-TestBecause $Because))
    }
}

function Assert-Contains {
    param($Expected, $Collection, [string]$Because)
    if (@($Collection) -notcontains $Expected) {
        throw ('{0} no está en {1}{2}' -f (Show-TestValue $Expected), (Show-TestValue $Collection), (Get-TestBecause $Because))
    }
}

# Comprueba que algo SÍ falla. Lo usan las pruebas de las reglas
# de la casa: por ejemplo, que un glifo inventado sea un error
# ruidoso y no un cuadrado vacío en pantalla.
function Assert-Throws {
    param([Parameter(Mandatory)][scriptblock]$Body, [string]$Because)

    try { & $Body | Out-Null }
    catch { return }
    throw ('esperaba una excepción y no hubo ninguna{0}' -f (Get-TestBecause $Because))
}

# Lo contrario, y la comprobación más repetida del proyecto:
# core/ promete no lanzar nunca hacia arriba (ver CLAUDE.md).
function Assert-NoThrow {
    param([Parameter(Mandatory)][scriptblock]$Body, [string]$Because)

    try { & $Body | Out-Null }
    catch {
        throw ('no debía lanzar y lanzó: {0}{1}' -f $_.Exception.Message, (Get-TestBecause $Because))
    }
}

function Get-TestBecause {
    param([string]$Because)
    if ($Because) { " ($Because)" } else { '' }
}

# ---- Resumen final ------------------------------------------

function Write-TestSummary {
    Write-Host ''
    Write-Host ('  ' + ('-' * 62)) -ForegroundColor DarkGray

    if ($TestState.Failures.Count -gt 0) {
        Write-Host ''
        Write-Host '  Fallos:' -ForegroundColor Red
        foreach ($failure in $TestState.Failures) {
            Write-Host ''
            Write-Host ('   {0} > {1}' -f $failure.Group, $failure.Name) -ForegroundColor Red
            Write-Host ('     ' + $failure.Message) -ForegroundColor DarkRed
            if ($failure.Where) {
                Write-Host ('     ' + ($failure.Where.Trim() -replace "`r?`n", "`n     ")) -ForegroundColor DarkGray
            }
        }
        Write-Host ''
    }

    $line = '  {0} bien, {1} mal, {2} saltadas' -f $TestState.Passed, $TestState.Failed, $TestState.Skipped
    if ($TestState.Failed -gt 0) { Write-Host $line -ForegroundColor Red }
    else                         { Write-Host $line -ForegroundColor Green }
    Write-Host ''
}
