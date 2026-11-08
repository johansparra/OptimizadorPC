# Graph Report - OptimizadorPC  (2026-11-08)

## Corpus Check
- 61 files · ~177,566 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1036 nodes · 2614 edges · 53 communities (45 shown, 7 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 651 edges (avg confidence: 0.86)
- Token cost: 733,642 input · 0 output

## Community Hubs (Navigation)
- Tema, animaciones y peor caso
- Escritura y estado del registro
- Capas, carga y empaquetado
- Buscador global
- Comandos y limpieza (core)
- Cajon del log
- Piezas genericas (UiKit)
- Fixtures y pruebas de tarjetas
- Marco de ejecucion de pasos
- Preferencias, idioma y material
- Vistas y cabecera de pagina
- Guias y lector Markdown
- Contenido de las guias
- Secciones y filtro por estado
- Ventana del log y progreso
- XAML de la ventana
- Pruebas de core y comandos
- Skills de PowerShell
- Detalles tecnicos y copiar
- Acerca de y version
- Aserciones del TestKit
- Auditoria y Semgrep
- Menu lateral
- Equipo de agentes
- Reglas de dos hosts y calidad
- Exploracion y delegacion
- Contexto del proyecto (doc)
- Enrutador e idioma
- Menu lateral y cajon (XAML)
- Tarjeta de ajuste y baldosa
- Hook de codificacion y reglas
- Contenedores del shell (XAML)
- Skill windows-desktop-architect
- Preferencias y refactor
- Detalle desplegable
- Enlaces externos y hora
- Analisis estatico y lo no cubierto
- Invariantes de seguridad
- Agente arquitecto
- Referencia de un ajuste
- Fixtures de limpieza
- Sonda de cableado
- Flujos de salida de PowerShell
- Desplegable (XAML)
- Barra de progreso (XAML)
- Guia: tareas de diagnostico
- Fondo vivo (XAML)
- Guia: Game Mode
- Guia: apps en segundo plano
- Guia: Green Ethernet
- Guia: control de flujo
- Guia: Large Send Offload

## God Nodes (most connected - your core abstractions)
1. `Set-TextFg()` - 75 edges
2. `Test suite (Run-Tests.ps1, no Pester)` - 43 edges
3. `Window` - 42 edges
4. `Set-BoxBg()` - 36 edges
5. `New-Icon()` - 28 edges
6. `Write-RegistryValue()` - 22 edges
7. `Show-CategoryDetailView()` - 20 edges
8. `Command-step sections (Internet, Limpieza, Energia)` - 20 edges
9. `Skill: windows-desktop-architect` - 20 edges
10. `T()` - 19 edges

## Surprising Connections (you probably didn't know these)
- `Selectable text: read-only TextBox instead of TextBlock (New-MonoField)` --references--> `New-MonoField()`  [EXTRACTED]
  CLAUDE.md → ui/Components/Cards/TechnicalDetails.ps1
- `Read-RegistryValueRaw()` --implements--> `Always open RegistryView::Registry64`  [INFERRED]
  core/Registry/Reader.ps1 → CLAUDE.md
- `Activity log (core/Diagnostics/Log.ps1 + LogPanel/LogWindow)` --references--> `BtnLog`  [INFERRED]
  CLAUDE.md → ui/MainWindow.xaml
- `Set-SettingOptimization()` --implements--> `Registry write via allowlist (SettingApply -> Writer)`  [INFERRED]
  core/Registry/SettingApply.ps1 → CLAUDE.md
- `Test-RegistryWriteAllowed()` --implements--> `Registry write via allowlist (SettingApply -> Writer)`  [INFERRED]
  core/Registry/Writer.ps1 → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Allowlist-gated elevated side effects** — security_registry_write_allowlist, security_command_execution_contract, security_external_link, security_security_tests_invariants [EXTRACTED 1.00]
- **Single-file packaging contract (main.ps1 / build.ps1 / AppHost)** — claude_embed_dir_markers, readme_build_pipeline, tests_readme_apphost, claude_layer_architecture [EXTRACTED 1.00]
- **Live theme repaint flow** — readme_live_theme_switch, claude_theme_resources_rule, claude_frozen_brushes, claude_gradient_tokens [INFERRED 0.85]
- **Three allowlisted mechanisms that touch the machine** — claude_registry_write_mechanism, claude_command_step_sections, claude_folder_cleanup [EXTRACTED 1.00]
- **Testability without a shown window (no message loop)** — claude_count_up, claude_step_run_engine, claude_log_drawer_not_a_view, claude_search_popup_testing, claude_log_save [INFERRED 0.85]
- **PowerShell language traps that misbehave silently** — claude_list_object_pitfall, claude_method_comma_pitfall, claude_param_name_case_pitfall, claude_no_getnewclosure_rule, claude_search_popup_deferred_open [INFERRED 0.85]
- **Elevated side-effect gates: one allowlisted door per kind of side effect** — core_registry_writer, core_commands_commandrunner, core_commands_foldercleanup, core_shell_externallink, tests_source_security_tests, security_security_tests_invariants [EXTRACTED 1.00]
- **Guides pipeline: embedded as Base64, registered, rendered read-only, links via ExternalLink** — build, ui_engine_guideregistry, ui_engine_markdown, core_shell_externallink_invoke_externallink, security_guides_display_only, ui_data_guides_claves_registro_bf6_guide, ui_data_guides_gpedit_gaming_tweaks_guide, ui_data_guides_nic_i211_gaming_tweaks_guide, ui_data_guides_task_scheduler_gaming_tweaks_guide [INFERRED 0.85]
- **The 4 NIC settings with measurable gaming impact** — ui_data_guides_nic_i211_gaming_tweaks_interrupt_moderation, ui_data_guides_nic_i211_gaming_tweaks_energy_efficient_ethernet, ui_data_guides_nic_i211_gaming_tweaks_large_send_offload, ui_data_guides_nic_i211_gaming_tweaks_flow_control [EXTRACTED 1.00]
- **Circuito de entregas arquitecto -> dev -> tester** — claude_agents_arquitecto_arquitecto, claude_agents_dev_dev_agent, _claude_agents_tester_tester_agent, claude_agents_arquitecto_plan_de_cambio, claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **Recorrido de carpetas de capa escrito tres veces (main, build, AppHost)** — claude_skills_refactoring_agent_skill_que_no_refactorizar, main, build, tests_harness_apphost [EXTRACTED 1.00]
- **Kit de animación de Theme.ps1 revisado por review-animations** — claude_skills_review_animations_standards_normas_de_animacion, ui_design_theme_new_ease, ui_design_theme_new_anim, ui_design_theme_start_entertransition, ui_design_theme_start_staggeredenter, ui_design_theme_add_hoverlift [EXTRACTED 1.00]

## Communities (53 total, 7 thin omitted)

### Community 0 - "Tema, animaciones y peor caso"
Cohesion: 0.06
Nodes (69): Live backdrop at 20 fps without BlurEffect, Start-CountUp writes the final value without a live window, Frozen brushes / Set-AppTheme, $GradientTokens composed from palette keys, Add-HoverLift stationary wrapper, Never declare an animated Freezable in a style Setter, Selectable text: read-only TextBox instead of TextBlock (New-MonoField), Catálogo del peor caso (break-ui) (+61 more)

### Community 1 - "Escritura y estado del registro"
Cohesion: 0.06
Nodes (65): Activity log (core/Diagnostics/Log.ps1 + LogPanel/LogWindow), Al implementar optimizaciones (core/, New-Setting, Writer.ps1, AllowsSecurityTradeoff), core/ never throws upward, DWord arrives as signed Int32 (Format-RegistryValue), Layer 4 System: core/ (talks to Windows), @() over a New-Object List[object] throws (use .ToArray()), Comma inside method parentheses separates arguments (-f pitfall), One setting per registry key (never group keys) (+57 more)

### Community 2 - "Capas, carga y empaquetado"
Cohesion: 0.06
Nodes (47): Get-IncludedContent(), Que el archivo nuevo entre al .exe (marcadores EMBED_DIR, EMBED_GUIDES, EMBED_XAML), @@EMBED_DIR / @@EMBED_XAML build markers, Seven-layer architecture (one folder per layer), Layer 6 Pieces: ui/Components, Layer 1 Base: ui/Design (Theme, UiKit), Layer 2 Mechanism: ui/Engine, Layer 3 Policy: ui/Index (the main files) (+39 more)

### Community 3 - "Buscador global"
Cohesion: 0.09
Nodes (45): Global search (flat index, ui/Engine/Search.ps1), Search box Tag belongs to the popup, not the placeholder, Search popup: debounce, Enter, Escape, reopen on click, Popup opening deferred via Dispatcher.BeginInvoke ($script:SearchReopenBox), Test popups by popup.Child, not IsOpen, Typing repaints the body, never the header, Clicking a result opens its section with the setting highlighted, Get-SearchResultTitle() (+37 more)

### Community 4 - "Comandos y limpieza (core)"
Cohesion: 0.09
Nodes (46): Command output read as bytes, decoded afterwards, Command-step sections (Internet), Never an interpreter (no cmd /c, no powershell -c), Complete-CommandStep(), ConvertFrom-CommandOutput(), ConvertTo-CommandArgumentString(), Format-CommandLine(), Format-CommandOutput() (+38 more)

### Community 5 - "Cajon del log"
Cohesion: 0.10
Nodes (46): Saving the log to a file (Guardar como, Export-AppLog), Clear-AppLog(), Export-AppLog(), Format-AppLogLine(), Format-AppLogText(), Get-AppLog(), Get-AppLogCount(), Get-AppLogDetailCount() (+38 more)

### Community 6 - "Piezas genericas (UiKit)"
Cohesion: 0.14
Nodes (41): Firmas de rotura: lo que se ve, causa y arreglo WPF, Colores siempre por recurso de tema, Add-CategoryStatusPills(), Add-CategoryStepPills(), Add-CategoryTagPills(), New-CategoryCard(), New-CategoryStats(), New-CategoryTile() (+33 more)

### Community 7 - "Fixtures y pruebas de tarjetas"
Cohesion: 0.07
Nodes (29): Declaración New-Setting con -Registry, Recommended y Default, No inventar rutas del registro ni valores de fábrica (pendiente de verificar), Sin valor de restauración real no se puede aplicar un ajuste, Se cambian los datos, no la pieza, New-FakeSetting(), Find-Visuals(), Get-VisualText(), Get-TestRegFullPath() (+21 more)

### Community 8 - "Marco de ejecucion de pasos"
Cohesion: 0.10
Nodes (35): El XAML va como aquí-string literal y no puede llamar a T, Admin gating of steps (-RequiresAdmin, effective selection), Step-run queue (120 ms DispatcherTimer, state in $StepRun), Get-AppHostKind(), Get-AppRuntimeInfo(), Get-WindowsSummary(), Get-WindowsVersionValue(), Set-AppElevationOverride() (+27 more)

### Community 9 - "Preferencias, idioma y material"
Cohesion: 0.07
Nodes (22): Preferences persist via Set-AppSetting (%APPDATA% settings.json), Mica/Acrylic exclusive with own gradient, Navegación y estado: Show-View, el log no es vista, Set-AppSetting, All visible text goes through T (source-text keyed translation), Initialize-SystemBackdrop(), Set-WindowBackdrop(), Test-SystemBackdropSupport(), Adding a language (Register-Language, LanguageIndex) (+14 more)

### Community 10 - "Vistas y cabecera de pagina"
Cohesion: 0.10
Nodes (32): ContentDock: fixed frame for the step-run panel, List or grid is a view option, not a separate view, Navigation flow (OptimizationsList <-> CategoryDetail, Settings), Add-PageAction(), Add-PageActionLabel(), Clear-PageHeader(), New-SectionHeader(), Set-PageDock() (+24 more)

### Community 11 - "Guias y lector Markdown"
Cohesion: 0.11
Nodes (33): Guides section (Guias, ui/Data/Guides .md), Markdown reader subset (Get-MarkdownBlocks), Parameter-name case pitfall ([string]$Title vs $title), Get-TestBlocks(), Copy-GuideText(), New-GuideCopyButton(), New-GuideDocument(), Add-MarkdownInlines() (+25 more)

### Community 12 - "Contenido de las guias"
Cohesion: 0.09
Nodes (32): Defined categories (Regedit, Internet, Cleanup, Power, Update), Declaring a section (Register-Category, New-Setting), Guides shown as text only (Base64 in exe, never executed), $RegistryWriteAllowlist / $RegistryWriteAllowedValues, Harness/Fixtures.ps1 (HKCU test branch per PID), BF6 network tweaks .reg file, Prefetcher EnablePrefetcher, Guide: Claves de registro — BF6 / Gaming Network Tweaks (+24 more)

### Community 13 - "Secciones y filtro por estado"
Cohesion: 0.11
Nodes (26): Components/Layout: page pieces, Fase 1: mapa de la superficie (campo, origen, tipo, límite), Summary pills as status filter, Get-SearchTestKey(), Get-SearchTestSetting(), Get-FilterTestCategory(), Get-PresentStatuses(), Open-FilterTestSection() (+18 more)

### Community 14 - "Ventana del log y progreso"
Cohesion: 0.09
Nodes (18): Components/Shell: the window frame, Detached log window (LogWindow.ps1, New-LogContent), Peor caso: estados del programa (sin admin, Locked, opciones de vista), Update-UiNow es un DoEvents: dejar la ventana sorda, Enable-WorkAreaMaximize(), Initialize-WorkAreaMaximize(), Add-LogWindowDrag(), Clear-LogWindowState() (+10 more)

### Community 15 - "XAML de la ventana"
Cohesion: 0.11
Nodes (28): SelectionBoxItem, Tag, AdminBadgeIcon, AdminBadgeText, AppVersionBadge, BtnClose, BtnHelp, BtnLog (+20 more)

### Community 16 - "Pruebas de core y comandos"
Cohesion: 0.10
Nodes (5): Security invariants (tests/Source/Security.Tests.ps1), New-TestStep(), Test suite (Run-Tests.ps1, no Pester), Get-InternetCategory(), New-CommandStep()

### Community 17 - "Skills de PowerShell"
Cohesion: 0.13
Nodes (17): Anatomía de una función PowerShell, Errores: fallar pronto, no usar throw para el flujo normal, Idempotencia: leer antes de escribir, Parámetros tipados y validados en la firma, Skill: powershell-best-practices, Rendimiento y legibilidad: nada de alias, nada de +=, Reversibilidad: capturar el valor previo antes de tocar, Scripts sueltos: #requires y StrictMode (+9 more)

### Community 18 - "Detalles tecnicos y copiar"
Cohesion: 0.23
Nodes (15): Close-DisclosureSection(), New-DisclosureSection(), Open-DisclosureSection(), Copy-TechnicalValue(), New-CopyButton(), New-CurrentLine(), New-MonoField(), New-RegistryKeyRow() (+7 more)

### Community 19 - "Acerca de y version"
Cohesion: 0.25
Nodes (14): Layer 5 Data: ui/Data (declarations only), AppInfo.ps1: single source of the version, Get-AboutElevationLabel(), Get-AboutHostLabel(), Get-AboutText(), Initialize-AboutMenu(), New-AboutCard(), New-AboutDetails() (+6 more)

### Community 20 - "Aserciones del TestKit"
Cohesion: 0.27
Nodes (12): Assert-Contains(), Assert-Equal(), Assert-False(), Assert-Match(), Assert-NotEqual(), Assert-NoThrow(), Assert-NotNull(), Assert-Null() (+4 more)

### Community 21 - "Auditoria y Semgrep"
Cohesion: 0.21
Nodes (14): actions/checkout pinned by SHA, Push trigger without paths filter, Semgrep CI workflow, Security and quality audit 2026-09-07, New-ChipMenu / New-ViewMenu deliberate duplication, Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix), Audit history convention, Accepted and pending risks table (+6 more)

### Community 22 - "Menu lateral"
Cohesion: 0.27
Nodes (10): Sidebar built by code from NavigationIndex, NavigationIndex, Build-Sidebar(), New-NavButton(), Set-NavSelection(), Set-SidebarExpanded(), Switch-Sidebar(), Sync-NavSelection() (+2 more)

### Community 23 - "Equipo de agentes"
Cohesion: 0.23
Nodes (13): Informe de verificacion (tester report format), Tester agent, estado.ps1 status script, One commit by default policy, versionado skill, Plan de cambio (formato de entrega del arquitecto), Agente dev, Parte de trabajo (formato de entrega del dev) (+5 more)

### Community 24 - "Reglas de dos hosts y calidad"
Cohesion: 0.20
Nodes (11): Checklist de buenas prácticas, SupportsShouldProcess: -WhatIf y -Confirm gratis, Nadie cierra una tarea sin las dos suites verdes, El archivo de datos del peor caso nunca entra en el .exe, Informe de break-ui (Roto/Feo/Frágil, decisiones, lo que aguantó) y parar, Qué NO hace falta leer (build/_combined.ps1, lo ya escrito, CLAUDE.md), El contrato de los dos hosts (5.1 del .exe y pwsh 7 de main.ps1), UTF-8 con BOM siempre (+3 more)

### Community 25 - "Exploracion y delegacion"
Cohesion: 0.17
Nodes (12): Los agentes arrancan en frío (no ven la conversación), Los agentes solo se cargan con la sesión abierta en OptimizadorPC/, Criterio de delegación: dos o más frentes que no comparten archivos, Lanzar en paralelo exige el MISMO mensaje, Secuencial sobre los mismos archivos, settings.local.json: permisos como freno principal, Agrupar llamadas independientes en un mismo turno, Recetas de búsqueda con grep (uso, definición, índice de funciones) (+4 more)

### Community 26 - "Contexto del proyecto (doc)"
Cohesion: 0.36
Nodes (12): Security and quality audits (auditoria/ dated reports), Command allowlists ($CommandAllowedExecutables / $CommandAllowedServices), Command-step sections (Internet, Limpieza, Energia), OptimizadorPC.exe: portable, elevated, console-less (-requireAdmin -noConsole), Folder cleanup (FolderCleanup.ps1, the only place that deletes files), graphify graph usage limits, Optimizador PC working context (CLAUDE.md), Registry write via allowlist (SettingApply -> Writer) (+4 more)

### Community 27 - "Enrutador e idioma"
Cohesion: 0.27
Nodes (9): Glyph catalog (Segoe Fluent Icons), never emoji, The log drawer is not a view (Close-LogOverlay), Router: Show-View and language repaint (Update-UiLanguage), Sidebar built in code from NavigationIndex, Get-AppWindow(), Get-CurrentViewName(), Show-CurrentView(), Update-UiLanguage() (+1 more)

### Community 28 - "Menu lateral y cajon (XAML)"
Cohesion: 0.20
Nodes (11): Sliding indicator needs measurements (Move-NavIndicator), Sidebar collapse animates the Border width, not the Grid column, AdminBadge, bd, LogDrawer, LogScrim, NavIndicator, ProgressStrip (+3 more)

### Community 29 - "Tarjeta de ajuste y baldosa"
Cohesion: 0.29
Nodes (8): Components/Cards: the cards, New-CategoryTilePanel(), Update-CategoryTileWidths(), Copy-DisclosureState(), Get-CardDisclosureHeaders(), Get-DisclosureLabel(), New-SettingCard(), New-SettingControl()

### Community 30 - "Hook de codificacion y reglas"
Cohesion: 0.33
Nodes (8): Agent delegation policy (only for 2+ independent fronts), Normalize-PsEncoding PostToolUse hook, How to work fast here (ordered time-savers), No .GetNewClosure() in event handlers (pass data via Tag), Skills load at task start (break-ui render.ps1 as screenshot), Test on both hosts (5.1 .exe and pwsh 7 main.ps1), UTF-8 with BOM rule, Run tests on both hosts (-BothHosts)

### Community 31 - "Contenedores del shell (XAML)"
Cohesion: 0.22
Nodes (10): Shell containers (HeaderTitleArea, HeaderActionsArea, MainContent) via PageHeader, ContentDock, HeaderActionsArea, HeaderSummaryArea, HeaderTitleArea, MainContent, NavBottom, NavTop (+2 more)

### Community 32 - "Skill windows-desktop-architect"
Cohesion: 0.25
Nodes (8): Las reglas que más se incumplen, No usar GetNewClosure: el dato viaja por el Tag, Iconos: Glyph del catálogo de Theme.ps1, nunca emoji, Todo texto visible pasa por T y hay que repintar al cambiar de idioma, IsEnabled = $false bloquea todo el subárbol (Locked), Pinceles congelados: Resources.Add en vez del indexador, Un Popup tiene que colgar del árbol lógico, Skill: windows-desktop-architect

### Community 33 - "Preferencias y refactor"
Cohesion: 0.25
Nodes (7): graphify graph: what it is for and what not, Peor caso: nombres y descripciones de ajustes (el español es lo que se rompe), Eliminar un concepto de todo el proyecto (receta de la etiqueta Preference), Los olores propios de este proyecto, Las siete capas, de datos a pantalla, New-PreferenceCard(), New-PreferenceControl()

### Community 34 - "Detalle desplegable"
Cohesion: 0.54
Nodes (7): Log entry detail (Items) folded with New-DetailList, New-DetailList(), New-DetailListText(), Set-DetailListOpen(), Switch-DetailList(), Sync-DetailList(), Test-DetailListOpen()

### Community 35 - "Enlaces externos y hora"
Cohesion: 0.36
Nodes (6): Invoke-ExternalLink(), Test-ExternalLinkAllowed(), Attack surface (no network, repo-authored inputs), ExternalLink http/https only, Format-AppTime(), Get-AppTimeFormat()

### Community 36 - "Analisis estatico y lo no cubierto"
Cohesion: 0.25
Nodes (7): Pending: persistent rollback and undo UI, Static analysis (PSScriptAnalyzer, Semgrep; Snyk rejected), Pending smoke test of compiled .exe, What the tests do not cover, Playwright (not applicable to WPF), Why Playwright does not apply (WPF, no DOM), UI Automation (System.Windows.Automation / FlaUI / WinAppDriver)

### Community 37 - "Invariantes de seguridad"
Cohesion: 0.32
Nodes (7): Security-degrading value-name denylist + AllowsSecurityTradeoff, Get-AppRoot(), Get-SourceFiles(), Get-SourceRelativePath(), Get-AllRegistryKeys(), Get-GuardedRelPath(), Get-GuardedSourceFiles()

### Community 38 - "Agente arquitecto"
Cohesion: 0.29
Nodes (7): Agente arquitecto (solo lectura), Arquitectura de siete capas (Design, Engine, Index, core, Data, Components, Views), Optimización fuera del registro = mecanismo nuevo en core/, Orden de carga de capas, Preferir el archivo declarativo al código; un plan que no cabe en una pantalla son dos, Preguntas que responde cada plan (capa, declarativo, estados de core/, qué se rompe), Programa/OptimizadorPC.ps1 (versión monolítica con Apply/Revert, Set-Reg, Set-SvcState)

### Community 39 - "Referencia de un ajuste"
Cohesion: 0.62
Nodes (6): New-FactBlock(), New-GamingFactBlock(), New-GamingTag(), New-LinkFactBlock(), New-ReferenceBody(), New-SettingReference()

### Community 40 - "Fixtures de limpieza"
Cohesion: 1.00
Nodes (3): Get-CleanupFixtureRoot(), New-CleanupFixture(), Remove-CleanupFixture()

### Community 41 - "Sonda de cableado"
Cohesion: 0.67
Nodes (3): Ui/Wiring.Tests.ps1, Get-WiringProbe(), Invoke-WiringProbe()

### Community 42 - "Flujos de salida de PowerShell"
Cohesion: 1.00
Nodes (3): Los cinco flujos de salida de PowerShell, Devolver objetos, no texto, Todo lo que no se consume se devuelve (Out-Null)

### Community 43 - "Desplegable (XAML)"
Cohesion: 0.67
Nodes (3): IsDropDownOpen, tgl, ToggleButton

### Community 44 - "Barra de progreso (XAML)"
Cohesion: 0.67
Nodes (3): ProgressDone, ProgressLeft, ColumnDefinition

## Ambiguous Edges - Review These
- `Computed setting Status (optimized/factory/custom/unknown)` → `One setting per registry key (never group keys)`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to

## Knowledge Gaps
- **32 isolated node(s):** `IsDropDownOpen`, `SelectionBoxItem`, `Tag`, `Canvas`, `ContentControl` (+27 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 114 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Computed setting Status (optimized/factory/custom/unknown)` and `One setting per registry key (never group keys)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Test suite (Run-Tests.ps1, no Pester)` connect `Pruebas de core y comandos` to `Skill windows-desktop-architect`, `Tema, animaciones y peor caso`, `Capas, carga y empaquetado`, `Analisis estatico y lo no cubierto`, `Invariantes de seguridad`, `Fixtures y pruebas de tarjetas`, `Fixtures de limpieza`, `Sonda de cableado`, `Guias y lector Markdown`, `Contenido de las guias`, `Secciones y filtro por estado`, `Auditoria y Semgrep`, `Menu lateral`, `Equipo de agentes`, `Reglas de dos hosts y calidad`, `Contexto del proyecto (doc)`, `Hook de codificacion y reglas`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **Why does `Set-TextFg()` connect `Piezas genericas (UiKit)` to `Tema, animaciones y peor caso`, `Preferencias y refactor`, `Detalle desplegable`, `Buscador global`, `Cajon del log`, `Referencia de un ajuste`, `Marco de ejecucion de pasos`, `Vistas y cabecera de pagina`, `Guias y lector Markdown`, `Secciones y filtro por estado`, `Detalles tecnicos y copiar`, `Menu lateral`, `Tarjeta de ajuste y baldosa`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Why does `Layer 4 System: core/ (talks to Windows)` connect `Escritura y estado del registro` to `Capas, carga y empaquetado`, `Enlaces externos y hora`, `Comandos y limpieza (core)`, `Cajon del log`, `Marco de ejecucion de pasos`, `Preferencias, idioma y material`, `Ventana del log y progreso`, `Acerca de y version`?**
  _High betweenness centrality (0.082) - this node is a cross-community bridge._
- **Are the 69 inferred relationships involving `Set-TextFg()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`Set-TextFg()` has 69 INFERRED edges - model-reasoned connections that need verification._
- **Are the 31 inferred relationships involving `Set-BoxBg()` (e.g. with `New-DetailList()` and `New-DisclosureSection()`) actually correct?**
  _`Set-BoxBg()` has 31 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `New-Icon()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`New-Icon()` has 22 INFERRED edges - model-reasoned connections that need verification._