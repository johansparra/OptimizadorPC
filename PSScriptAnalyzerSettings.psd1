# ============================================================
# PSScriptAnalyzerSettings.psd1
#
#   Invoke-ScriptAnalyzer -Path . -Recurse  auto-descubre este
#   archivo (no hace falta -Settings). Aquí solo se apagan reglas
#   que, para "cumplirse", exigirían cambiar comportamiento,
#   contratos o los nombres públicos de las funciones — justo lo
#   que este proyecto no quiere. Cada exclusión lleva su motivo.
#
#   Lo que SÍ tenía arreglo seguro (catch vacío, whitespace,
#   variable automática, variables muertas de test) se corrigió
#   en el código, no aquí.
# ============================================================

@{
    # Solo las reglas por defecto. Sin reglas propias.
    IncludeDefaultRules = $true

    ExcludeRules = @(

        # --------------------------------------------------------
        # PSUseShouldProcessForStateChangingFunctions
        # --------------------------------------------------------
        # Salta por el VERBO del nombre (New-, Set-, Update-,
        # Start-, Reset-). En este proyecto esas 130+ funciones son
        # constructores de controles WPF y setters de tema
        # (New-CategoryCard, Set-BoxBg, Update-UiLanguage,
        # Start-StaggeredEnter...). NO mutan el sistema.
        #
        # "Cumplir" la regla obliga a poner
        # [CmdletBinding(SupportsShouldProcess)] + $PSCmdlet.
        # ShouldProcess() en cada una: eso añade -WhatIf/-Confirm a
        # todos los constructores (cambio de interfaz) y, si
        # alguien pasa -WhatIf, la función no construye el control y
        # devuelve $null -> la interfaz se rompe.
        #
        # ESTADO: core/Registry/ ya escribe. Write-RegistryValue y
        # Set-SettingOptimization YA adoptaron
        # [CmdletBinding(SupportsShouldProcess)] + ShouldProcess a
        # propósito (soportan -WhatIf, lo prueban RegistryWriter y
        # SettingApply). La regla sigue excluida GLOBALMENTE por las
        # 130+ funciones de ui/ que no mutan nada; el hueco residual
        # es que una función NUEVA de core/ que cambie estado
        # tampoco se marcaría. Mitigación parcial:
        # tests/Source/Security.Tests.ps1 vigila las escrituras al
        # registro por otra vía. Si core/ crece mucho, toca un
        # análisis aparte más estricto SOLO sobre core/ sin esta
        # exclusión.
        'PSUseShouldProcessForStateChangingFunctions'

        # --------------------------------------------------------
        # PSReviewUnusedParameter
        # --------------------------------------------------------
        # Casi todo es el patrón obligatorio de la regla 4 de
        # CLAUDE.md para los handlers de eventos WPF:
        #     $ctrl.Add_Click({ param($s, $e) Hacer-Algo $s })
        # El segundo parámetro es la firma defensiva que la casa
        # exige aunque el handler no lo use. El resto son funciones
        # de mentira en las pruebas cuya firma debe calzar con el
        # contrato real que las llama (param($Window),
        # param($Done, $Total)). Quitar parámetros contradice la
        # regla 4 y arriesga el binding posicional.
        'PSReviewUnusedParameter'

        # --------------------------------------------------------
        # PSAvoidUsingPositionalParameters   (severidad: Information)
        # --------------------------------------------------------
        # Los 60 sitios son llamadas a funciones PROPIAS del
        # proyecto con su convención de la casa: el primer argumento
        # casi siempre es $Window
        #     New-StateLine $Window $label $valor 'Success'
        #     Add-ToLogRow  $grid (New-LogHeader $Window) 0
        # Nombrar 60 llamadas es churn enorme por un hallazgo
        # Information, con riesgo real de mal-bindear un nombre en
        # silencio. La convención posicional es deliberada.
        'PSAvoidUsingPositionalParameters'

        # --------------------------------------------------------
        # PSAvoidUsingWriteHost
        # --------------------------------------------------------
        # CERO usos en ui/ o core/ (lo que se compila al .exe).
        # Están solo en:
        #   - build.ps1                 progreso de compilación en color
        #   - tests/Run-Tests.ps1       salida del arnés a consola
        #   - tests/Harness/TestKit.ps1 idem (Describe/It/ok/mal)
        # En un runner y un script de build, Write-Host es lo
        # correcto: Write-Output contaminaría el pipeline/return
        # (trampa conocida del proyecto) y Write-Information queda
        # oculto sin -InformationAction. La regla 7 de CLAUDE.md ya
        # cubre que en el .exe no se debe depender de la consola.
        'PSAvoidUsingWriteHost'

        # --------------------------------------------------------
        # PSUseSingularNouns
        # --------------------------------------------------------
        # Renombrar Get-OptimizationCategories,
        # Get-MissingTranslations, Get-ThemeKeys, Import-AppSettings,
        # Get-SourceFiles, ... rompe TODAS las llamadas, la suite de
        # pruebas y los nombres que CLAUDE.md documenta y usa. Es
        # exactamente "cambiar interfaces públicas", que el encargo
        # prohíbe salvo que sea imprescindible. No lo es.
        'PSUseSingularNouns'
    )
}
