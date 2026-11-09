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
            $name = [string]$entry.Key.Name
            Assert-True (Test-RegistryWriteAllowed -Path $path -Name $name) `
                ("ruta fuera de la lista blanca en '$($entry.Category)' / '$($entry.Setting)': $path\$name")
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

    It 'cada clave de -Registry declara a dónde vuelve OFF: un Default o DefaultAbsent, no los dos' {
        # SECURITY.md §3.2 condición 1: un ajuste sin valor de
        # restauración real no se puede deshacer. OFF escribe el
        # Default, o BORRA el valor si la clave declara que de fábrica
        # no existe (DefaultAbsent = $true). Sin ninguno de los dos no
        # habría a dónde volver; con los dos, no se sabría cuál vale.
        foreach ($entry in Get-AllRegistryKeys) {
            $default = [string]$entry.Key.Default
            $hasDefault = -not [string]::IsNullOrWhiteSpace($default)
            $absent = ($entry.Key.DefaultAbsent -eq $true)
            $donde = "la clave '$($entry.Key.Name)' de '$($entry.Setting)' ($($entry.Category))"
            Assert-True ($hasDefault -or $absent) "$donde no declara Default ni DefaultAbsent: no habría a dónde volver con OFF"
            Assert-False ($hasDefault -and $absent) "$donde declara Default Y DefaultAbsent: OFF no sabría si escribir o borrar"
        }
    }

    It 'core/ nunca borra claves del registro, y solo Writer.ps1 borra valores' {
        # SECURITY.md §3.2. Volver a "no configurado" es quitar UN
        # valor (Remove-RegistryValue), por la lista blanca. Borrar una
        # clave se llevaría por delante todo lo que cuelga de ella.
        foreach ($archivo in Get-GuardedSourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            $rel = Get-GuardedRelPath $archivo
            Assert-True ($texto -notmatch '\.DeleteSubKey|\.DeleteTree\(|Remove-Item\s+[^\r\n]*(HK(LM|CU|EY_)|Registry::)|reg(\.exe)?\s+delete') `
                "borrado de claves del registro en ${rel} (ver SECURITY.md §3.2)"
            if ($rel -ne 'core/Registry/Writer.ps1') {
                Assert-True ($texto -notmatch '\.DeleteValue\(|Remove-ItemProperty') `
                    "borrado de valores del registro fuera de core/Registry/Writer.ps1 en ${rel}"
            }
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

    It 'Add-Type solo se usa en los archivos revisados de core/Interop/, con fuente literal' {
        # Cada Add-Type del proyecto compila una cadena de C# FIJA
        # (here-string de comillas simples). Add-Type con fuente
        # construida en tiempo de ejecución sería equivalente a iex.
        # Añadir un archivo a esta lista es una decisión de seguridad:
        # se revisa a mano y se apunta en SECURITY.md §11.
        $revisados = @(
            'core/Interop/SystemBackdrop.ps1'   # dwmapi: Mica / Acrílico
            'core/Interop/WorkArea.ps1'         # user32: maximizar al área de trabajo
        )
        foreach ($archivo in Get-GuardedSourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            if ($texto -notmatch 'Add-Type\s+-TypeDefinition') { continue }

            $rel = Get-GuardedRelPath $archivo
            Assert-True ($revisados -contains $rel) `
                "Add-Type -TypeDefinition nuevo en ${rel} - revísalo a mano, la fuente NO puede venir de fuera"
            Assert-True ($texto -match "(?s)\`$source\s*=\s*@'.*?'@") `
                "la fuente del Add-Type de ${rel} debería seguir siendo un here-string literal (@'...'@)"
        }
    }
}

Describe 'seguridad - ejecución de comandos (SECURITY.md §12)' {

    It 'solo core/Commands/CommandRunner.ps1 arranca procesos, y ExternalLink abre enlaces' {
        # Arrancar un proceso desde un programa elevado es la puerta
        # más ancha que hay. Tiene que estar en UN sitio, con su lista
        # blanca; cualquier otro Process.Start es un agujero nuevo.
        $permitidos = @{
            'core/Commands/CommandRunner.ps1' = 'ProcessStartInfo'
            'core/Shell/ExternalLink.ps1'    = 'Start-Process'
        }
        foreach ($archivo in Get-GuardedSourceFiles) {
            $texto = Get-Content -Path $archivo.FullName -Raw
            $rel = Get-GuardedRelPath $archivo
            foreach ($patron in 'ProcessStartInfo', 'Diagnostics\.Process\]::Start', 'Start-Process', '\bsaps\b', '\bstart\s+cmd') {
                if ($texto -notmatch $patron) { continue }
                $ok = $permitidos.ContainsKey($rel) -and ($texto -match $permitidos[$rel])
                Assert-True $ok "arranque de procesos en $rel ($patron): solo CommandRunner.ps1 / ExternalLink.ps1"
            }
        }
    }

    It 'la lista blanca de ejecutables no tiene intérpretes ni rutas' {
        foreach ($exe in $CommandAllowedExecutables) {
            Assert-False ($exe -match '[\\/:]') "'$exe' tiene que ser solo un nombre"
            Assert-False ($exe -match '^(cmd|powershell|pwsh|wscript|cscript|mshta|rundll32|regsvr32|bash|wsl)\.exe$') "'$exe' es un intérprete"
        }
    }

    It 'la lista blanca de servicios no toca la seguridad del equipo' {
        foreach ($svc in $CommandAllowedServices) {
            Assert-False ($svc -match '^(WinDefend|mpssvc|wuauserv|SecurityHealthService|wscsvc|BFE|EventLog)$') "'$svc' no debería poder arrancarse ni tocarse desde aquí"
        }
    }

    It 'todo paso declarado en cualquier sección pasa la lista blanca' {
        # Igual que las claves del registro: un paso fuera de la lista
        # acabaría en 'blocked' al pulsar, EN SILENCIO. Esto lo caza al
        # declararlo.
        $revisados = 0
        foreach ($cat in $CategoryList) {
            foreach ($step in @($cat.Steps)) {
                Assert-True (Test-CommandStepAllowed $step) "paso fuera de la lista blanca en '$($cat.Id)': $($step.Id) ($(Format-CommandLine $step))"
                $revisados++
            }
        }
        Assert-True ($revisados -ge 1) 'no se ha encontrado ningún paso que revisar'
    }

    It 'lo que borra reglas del firewall nunca viene marcado de serie' {
        # SECURITY.md §4: lo que baja la postura de seguridad no puede
        # venir activo por defecto. Resetear el firewall borra las
        # reglas propias; lo decide el usuario, paso a paso.
        foreach ($cat in $CategoryList) {
            foreach ($step in @($cat.Steps)) {
                if (@($step.Arguments) -contains 'advfirewall') {
                    Assert-False $step.Checked "'$($step.Id)' toca el firewall y viene marcado"
                    Assert-True ([bool]$step.Warning) "'$($step.Id)' toca el firewall y no avisa"
                }
            }
        }
    }

    It 'lo que cambia el DNS de un adaptador nunca viene marcado de serie, y avisa' {
        # §11, riesgo 8. Fijar el de Google sustituye el del router, y
        # volver a DHCP anula lo anterior: los dos se deciden a la vista.
        # Un paso con aviso, además, nunca se restaura marcado desde
        # settings.json (Restore-StepChoices).
        $revisados = 0
        foreach ($cat in $CategoryList) {
            foreach ($step in @($cat.Steps)) {
                $a = @($step.Arguments)
                if ($step.Kind -eq 'exe' -and $a -contains 'dns' -and ($a -contains 'set' -or $a -contains 'add')) {
                    Assert-False $step.Checked "'$($step.Id)' cambia el DNS y viene marcado"
                    Assert-True ([bool]$step.Warning) "'$($step.Id)' cambia el DNS y no avisa"
                    $revisados++
                }
            }
        }
        Assert-True ($revisados -ge 3) "se esperaban los dos pasos de Google y el de vuelta a DHCP; hay $revisados"
    }

    It 'solo core/Commands/FolderCleanup.ps1 borra archivos' {
        # Borrar desde un programa elevado no tiene vuelta atrás. Igual
        # que arrancar procesos: un sitio, con su lista blanca.
        foreach ($archivo in Get-GuardedSourceFiles) {
            $rel = Get-GuardedRelPath $archivo
            if ($rel -eq 'core/Commands/FolderCleanup.ps1') { continue }
            $texto = Get-Content -Path $archivo.FullName -Raw
            # Sin 'del' ni 'ri': en un comentario en español "del" es una
            # palabra, y el código de aquí no usa alias.
            foreach ($patron in 'Remove-Item', '\.Delete\(', 'File\]::Delete', 'Directory\]::Delete', 'Clear-RecycleBin') {
                Assert-False ($texto -match $patron) "borrado de archivos en $rel ($patron): solo FolderCleanup.ps1"
            }
        }
    }

    It 'la lista blanca de carpetas no sale de tu carpeta de usuario' {
        # §12: corriendo elevado, una entrada que resolviera a C:\Windows
        # o a la raíz de AppData borraría de más. Cada entrada nombra una
        # carpeta concreta, y solo %TEMP% puede ser la variable a secas.
        # La única excepción es C:\Windows\Temp, exacta.
        $usuario = [Environment]::GetFolderPath('UserProfile').TrimEnd('\') + '\'
        $winTemp = Join-Path ([Environment]::GetFolderPath('Windows')) 'Temp'
        foreach ($t in $CleanupAllowedFolders) {
            $partes = Split-CleanupTarget $t
            Assert-NotNull $partes "'$t' no tiene forma válida"
            if ($partes.Root -ne 'TEMP') {
                Assert-True ([bool]$partes.Relative) "'$t' vaciaría %$($partes.Root)% entera"
            }
            $r = Resolve-CleanupTarget $t
            $ok = [bool]$r.Path -and ($r.Path.StartsWith($usuario, [System.StringComparison]::OrdinalIgnoreCase) -or
                  [string]::Equals($r.Path, $winTemp, [System.StringComparison]::OrdinalIgnoreCase))
            Assert-True $ok "'$t' resuelve fuera de tu carpeta: $($r.Path) $($r.Problem)"
        }
    }

    It 'vaciar la papelera nunca viene marcado de serie, y avisa' {
        # Lo que hay en la papelera es lo único de la limpieza que el
        # usuario puso ahí A PROPÓSITO para poder recuperarlo.
        foreach ($cat in $CategoryList) {
            foreach ($step in @($cat.Steps)) {
                if ($step.Kind -eq 'recyclebin') {
                    Assert-False $step.Checked "'$($step.Id)' vacía la papelera y viene marcado"
                    Assert-True ([bool]$step.Warning) "'$($step.Id)' vacía la papelera y no avisa"
                }
            }
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
