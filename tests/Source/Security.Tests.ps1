# ============================================================
# tests/Source/Security.Tests.ps1
# Invariantes de seguridad que hasta ahora solo vivían en prosa
# (SECURITY.md y .claude/skills/security-reviewer/SKILL.md).
#
# No ejecutan la aplicación: la miran, igual que Rules.Tests.ps1.
# Cada prueba fija UN riesgo concreto y falla la suite si alguien
# lo reintroduce. La app corre elevada (-requireAdmin), así que
# estos fallos no son de estilo: son de seguridad.
# ============================================================

# Los .ps1 que se compilan al .exe. Es lo mismo que Get-SourceFiles
# de Rules.Tests.ps1, con nombre propio para no depender del orden
# en que se cargan los archivos de prueba (-File '*Security*' suelto
# también tiene que funcionar).
function Get-GuardedSourceFiles {
    @(Get-ChildItem -Path (Join-Path (Get-AppRoot) 'ui'), (Join-Path (Get-AppRoot) 'core') -Recurse -Filter '*.ps1')
}

function Get-GuardedRelPath {
    param($File)
    $File.FullName.Substring((Get-AppRoot).Length).TrimStart('\') -replace '\\', '/'
}

# Todas las claves declaradas en -Registry, de TODAS las secciones
# registradas: visibles, ocultas o sin colocar en el índice. Se
# recorre $CategoryList (el registro crudo), no Get-OptimizationCategories
# (que filtra por ui/Index/CategoryIndex.ps1): una sección oculta con
# un -Registry peligroso también cuenta.
#
# $CategoryList es una List[object] creada con New-Object: NO se
# envuelve en @() -reventaría con "los tipos no coinciden" en los
# dos hosts (regla 19 de CLAUDE.md)-. foreach directo sí funciona.
function Get-AllRegistryKeys {
    $keys = New-Object System.Collections.Generic.List[object]
    foreach ($cat in $CategoryList) {
        foreach ($setting in @($cat.Items)) {
            foreach ($key in @($setting.Registry)) {
                $keys.Add([PSCustomObject]@{
                    Category = $cat.Id
                    Setting = $setting.Name
                    Key = $key
                    Owner = $setting
                })
            }
        }
    }
    $keys.ToArray()
}

Describe 'seguridad - escritura al registro' {

    It 'toda ruta de -Registry está dentro de la lista blanca de Writer.ps1' {
        # Una ruta fuera de $RegistryWriteAllowlist acaba en estado
        # 'blocked' en runtime, EN SILENCIO: el toggle no hace nada y
        # nadie se entera. Esto lo caza al declarar el ajuste, no al
        # pulsarlo. Ver SECURITY.md §3.1.
        $revisadas = 0
        foreach ($entry in Get-AllRegistryKeys) {
            $path = [string]$entry.Key.Path
            Assert-True (Test-RegistryWriteAllowed $path) `
                ("ruta fuera de la lista blanca en '$($entry.Category)' / '$($entry.Setting)': $path")
            $revisadas++
        }
        # Que la prueba de verdad esté mirando algo: hoy hay 1 clave.
        Assert-True ($revisadas -ge 1) 'no se ha encontrado ninguna clave -Registry que revisar'
    }

    It 'ningún ajuste toca un nombre de valor que degrada la seguridad sin declararlo' {
        # Ver SECURITY.md §3.4. Un ajuste que baje la postura de
        # seguridad del equipo (UAC, Defender, SmartScreen, Update,
        # BitLocker, firewall) debe llevar AllowsSecurityTradeoff = $true
        # en su declaración New-Setting. Sin esa marca, la suite falla:
        # obliga a una decisión explícita y revisable, no a un
        # "Recommended" a secas.
        #
        # NO pongas la marca para "callar el test": si un ajuste la
        # necesita, su -Description tiene que decir qué protección se
        # pierde y no puede venir activo por defecto.
        $peligrosos = @(
            'ConsentPromptBehaviorAdmin', 'ConsentPromptBehaviorUser', 'PromptOnSecureDesktop',
            'EnableLUA', 'FilterAdministratorToken', 'LocalAccountTokenFilterPolicy',
            'DisableAntiSpyware', 'DisableAntiVirus', 'DisableRealtimeMonitoring',
            'DisableBehaviorMonitoring', 'DisableOnAccessProtection',
            'SmartScreenEnabled', 'EnableSmartScreen', 'ShellSmartScreenLevel',
            'PreventDeviceEncryption',
            'NoAutoUpdate', 'NoAutoRebootWithLoggedOnUsers',
            'EnableFirewall', 'DoNotAllowExceptions'
        )

        foreach ($entry in Get-AllRegistryKeys) {
            $name = [string]$entry.Key.Name
            if ($peligrosos -notcontains $name) { continue }

            $owner = $entry.Owner
            $declara = [bool]($owner.PSObject.Properties['AllowsSecurityTradeoff'] -and $owner.AllowsSecurityTradeoff)
            Assert-True $declara ( `
                "el ajuste '$($entry.Setting)' ($($entry.Category)) escribe '$name', que degrada la seguridad del equipo. " +
                "Descríbelo en -Description, no lo llames 'Recommended' a secas y añade AllowsSecurityTradeoff = `$true. Ver SECURITY.md §3.4.")
        }
    }

    It 'cada clave de -Registry declara un Default con el que revertir' {
        # SECURITY.md §3.2 condición 1: un ajuste sin valor de
        # restauración real no se puede deshacer. OFF escribe el
        # Default; si no hay Default, el ajuste no debería aplicarse.
        foreach ($entry in Get-AllRegistryKeys) {
            $default = [string]$entry.Key.Default
            Assert-True (-not [string]::IsNullOrWhiteSpace($default)) `
                ("la clave '$($entry.Key.Name)' de '$($entry.Setting)' ($($entry.Category)) no declara Default: no habría a dónde volver con OFF")
        }
    }
}

Describe 'seguridad - ejecución de código y red' {

    It 'no hay ejecución dinámica de código ni llamadas de red en ui/ o core/' {
        # SECURITY.md §5. Corriendo elevado, convertir una cadena en
        # código o hablar con la red es ejecución arbitraria o
        # exfiltración. Add-Type se revisa aparte (prueba siguiente):
        # su uso legítimo es una cadena literal, no construida.
        $prohibido = 'Invoke-Expression|\biex\b|\[scriptblock\]::Create|Invoke-WebRequest|Invoke-RestMethod|DownloadString|DownloadFile|Start-BitsTransfer|Net\.WebClient|System\.Net\.Http'

        foreach ($archivo in Get-GuardedSourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            Assert-True ($texto -notmatch $prohibido) `
                ("primitiva de ejecución/red prohibida en " + (Get-GuardedRelPath $archivo) + " (ver SECURITY.md §5)")
        }
    }

    It 'Add-Type solo se usa en core/Interop/SystemBackdrop.ps1, con fuente literal' {
        # El único Add-Type del proyecto compila una cadena de C#
        # FIJA (here-string de comillas simples). Add-Type con fuente
        # construida en tiempo de ejecución sería equivalente a iex.
        foreach ($archivo in Get-GuardedSourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            if ($texto -notmatch 'Add-Type\s+-TypeDefinition') { continue }

            $rel = Get-GuardedRelPath $archivo
            Assert-Equal 'core/Interop/SystemBackdrop.ps1' $rel `
                "Add-Type -TypeDefinition nuevo en ${rel} - revísalo a mano, la fuente NO puede venir de fuera"
            Assert-True ($texto -match "(?s)\`$source\s*=\s*@'.*?'@") `
                "la fuente del Add-Type de ${rel} debería seguir siendo un here-string literal (@'...'@)"
        }
    }
}

Describe 'seguridad - enlaces externos' {

    It 'ExternalLink solo abre http y https' {
        # core/Shell/ExternalLink.ps1. Desde un proceso elevado,
        # ShellExecute con 'file:' o 'ms-settings:' abriría cualquier
        # cosa. La lista tiene que quedarse en esos dos esquemas.
        $esquemas = @($ExternalLinkSchemes | ForEach-Object { ([string]$_).ToLowerInvariant() })
        Assert-Equal 2 $esquemas.Count "ExternalLink debería permitir exactamente 2 esquemas, hay: $($esquemas -join ', ')"
        Assert-Contains 'http'  $esquemas 'falta http'
        Assert-Contains 'https' $esquemas 'falta https'
    }

    It 'Test-ExternalLinkAllowed rechaza lo que no sea http/https absoluto' {
        foreach ($mala in @(
                'file:///C:/Windows/System32/cmd.exe',
                'ms-settings:privacy',
                'javascript:alert(1)',
                'C:\Windows\System32\calc.exe',
                'ftp://example.com/x',
                '//example.com',
                'notepad.exe',
                '')) {
            Assert-False (Test-ExternalLinkAllowed $mala) "no debería permitir: '$mala'"
        }
        Assert-True (Test-ExternalLinkAllowed 'https://learn.microsoft.com/x') 'un https absoluto debería valer'
    }
}
