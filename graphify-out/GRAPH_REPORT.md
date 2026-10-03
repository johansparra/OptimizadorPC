# Graph Report - OptimizadorPC  (2026-10-03)

## Corpus Check
- 127 files · ~147,082 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 821 nodes · 1502 edges · 80 communities (32 shown, 11 thin omitted)
- Extraction: 73% EXTRACTED · 27% INFERRED · 0% AMBIGUOUS · INFERRED: 407 edges (avg confidence: 0.85)
- Token cost: 120,969 input · 0 output

## Community Hubs (Navigation)
- Tarjetas, baldosas y desplegables
- Skills de exploracion y buenas practicas
- XAML de la ventana
- Arnes y fixtures de pruebas
- Ejecucion de comandos de red
- Tarjeta de ajuste y cabecera
- Pruebas de comandos, busqueda y filtro
- Buscador global
- Escritura y estado del registro
- Fondo vivo y menu lateral
- Cajon del log
- Info del sistema y Acerca de
- Maximizar y ventana del log
- Arquitectura y equipo de agentes
- Log de actividad (core)
- Material de ventana
- Aserciones del TestKit
- Versionado y guia del proyecto (doc)
- Reglas de core (doc)
- Contrato de seguridad (doc)
- Progreso y traduccion
- Agentes dev/tester y trampas (doc)
- Auditoria y CI de seguridad
- Enlaces externos y referencia
- Opciones de vista y lista
- Riesgos y pruebas pendientes (doc)
- Navegacion y contenedores (doc)
- Log y ajustes guardados (doc)
- Contrato de escritura y filtro (doc)
- Animaciones (doc)
- Tema y degradados (doc)
- Guardia de errores de UI
- Contrato de ajustes con registro
- Sonda de cableado
- Skill powershell-engineer
- Regla de las dos suites
- Hook de codificacion (skill)
- Skill powershell-best-practices
- Skill refactoring-agent
- Skill versionado
- Hook de codificacion (doc)
- Trabajo pendiente (doc)
- Find-Visuals (doc)

## God Nodes (most connected - your core abstractions)
1. `Set-TextFg()` - 61 edges
2. `Window` - 41 edges
3. `Set-BoxBg()` - 31 edges
4. `New-Icon()` - 18 edges
5. `Write-RegistryValue()` - 18 edges
6. `T()` - 16 edges
7. `Skill: windows-desktop-architect` - 15 edges
8. `Sync-StepRunPanel()` - 15 edges
9. `Show-CategoryDetailView()` - 15 edges
10. `Glyph()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Computed registry status (optimized/factory/custom/unknown)` --semantically_similar_to--> `Setting status states (optimized/factory/custom/unknown)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Test suite (tests/Run-Tests.ps1 -BothHosts, no Pester)` --semantically_similar_to--> `Test coverage areas (core, UI, wiring, rules, security invariants)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Mica and Acrylic preference` --semantically_similar_to--> `Mica/Acrylic exclusive with own gradient`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md
- `Design system (palette, gradients, live theme switch)` --semantically_similar_to--> `$GradientTokens composed from palette keys`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md
- `Languages (Register-Language, Get-MissingTranslations)` --semantically_similar_to--> `Translation via T (source-text keyed)`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Circuito de entregas: cada rol produce un documento de formato fijo que el siguiente lee** — _claude_agents_arquitecto_arquitecto, _claude_agents_arquitecto_plan_de_cambio, _claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **Disciplina de los dos hosts (5.1 del .exe y pwsh 7 de main.ps1)** — _claude_skills_powershell_engineer_skill_contrato_de_los_dos_hosts, _claude_skills_powershell_engineer_skill_utf8_con_bom, _claude_skills_refactoring_agent_skill_ciclo_de_refactor, _claude_skills_powershell_best_practices_skill_checklist, _claude_skills_windows_desktop_architect_skill_checklist_interfaz [EXTRACTED 1.00]
- **Trampas de WPF por recurso compartido o árbol mal colgado** — _claude_skills_windows_desktop_architect_skill_pinceles_congelados, _claude_skills_windows_desktop_architect_skill_freezable_en_setter, _claude_skills_windows_desktop_architect_skill_popup_arbol_logico, _claude_skills_windows_desktop_architect_skill_colores_por_recurso_de_tema [EXTRACTED 1.00]
- **Agent and skill development workflow** — _claude_agents_dev_dev_agent, _claude_agents_tester_tester_agent, _claude_skills_security_reviewer_skill_security_reviewer, _claude_skills_versionado_skill_versionado [INFERRED 0.85]
- **Allowlist-gated elevated side effects** — security_registry_write_allowlist, security_command_execution_contract, security_external_link, security_security_tests_invariants [EXTRACTED 1.00]
- **Single-file packaging contract (main.ps1 / build.ps1 / AppHost)** — claude_embed_dir_markers, readme_build_pipeline, tests_readme_apphost, claude_layer_architecture [EXTRACTED 1.00]
- **Live theme repaint flow** — readme_live_theme_switch, claude_theme_resources_rule, claude_frozen_brushes, claude_gradient_tokens [INFERRED 0.85]

## Communities (80 total, 11 thin omitted)

### Community 0 - "Tarjetas, baldosas y desplegables"
Cohesion: 0.07
Nodes (64): New-CategoryTile(), Close-DisclosureSection(), New-DisclosureSection(), Open-DisclosureSection(), New-PreferenceCard(), New-PreferenceControl(), Get-SearchResultTitle(), New-SearchMatchLine() (+56 more)

### Community 1 - "Skills de exploracion y buenas practicas"
Cohesion: 0.06
Nodes (57): Agrupar llamadas independientes en un turno, Recetas de búsqueda con grep, Skill: exploracion, Mapa de dónde vive cada cosa, Qué NO hace falta leer, Trampas de esta máquina que cuestan turnos, Anatomía de una función PowerShell, Checklist de buenas prácticas (+49 more)

### Community 2 - "XAML de la ventana"
Cohesion: 0.05
Nodes (54): IsDropDownOpen, SelectionBoxItem, Tag, AdminBadge, AdminBadgeIcon, AdminBadgeText, AppVersionBadge, Backdrop (+46 more)

### Community 3 - "Arnes y fixtures de pruebas"
Cohesion: 0.09
Nodes (45): Complete-CommandStep(), ConvertFrom-CommandOutput(), ConvertTo-CommandArgumentString(), Format-CommandLine(), Format-CommandOutput(), Get-CommandOutputEncoding(), Get-CommandRunArmed(), Invoke-CommandStep() (+37 more)

### Community 4 - "Ejecucion de comandos de red"
Cohesion: 0.06
Nodes (29): New-FakeSetting(), Find-Visuals(), Get-AppRoot(), Get-VisualText(), New-AppWindow(), Get-TestRegFullPath(), Get-TestRegPath(), New-TestCategory() (+21 more)

### Community 5 - "Tarjeta de ajuste y cabecera"
Cohesion: 0.08
Nodes (33): Copy-DisclosureState(), Get-CardDisclosureHeaders(), Get-DisclosureLabel(), New-SettingCard(), New-SettingControl(), New-SettingInfo(), Add-PageAction(), Add-PageActionFirst() (+25 more)

### Community 6 - "Pruebas de comandos, busqueda y filtro"
Cohesion: 0.08
Nodes (30): New-TestStep(), Get-SearchTestKey(), Get-SearchTestSetting(), Get-FilterTestCategory(), Get-PresentStatuses(), Open-FilterTestSection(), Get-InternetCategory(), Add-CategoryStatusPills() (+22 more)

### Community 7 - "Buscador global"
Cohesion: 0.10
Nodes (33): Invoke-PendingSearch(), Invoke-SearchFocusPopup(), Invoke-SearchKey(), Invoke-SearchPopupReopen(), New-SearchBar(), New-SearchPopupCard(), New-SearchSeeAllRow(), Request-SearchPopupReopen() (+25 more)

### Community 8 - "Escritura y estado del registro"
Cohesion: 0.10
Nodes (28): Get-CategoryRegistryKeyCount(), Update-CategoryRegistryState(), Set-SettingOptimization(), ConvertTo-RegistryNumber(), Get-RegistryKeyStatus(), Get-SettingStatus(), Test-RegistryValueMatch(), Update-SettingStatus() (+20 more)

### Community 9 - "Fondo vivo y menu lateral"
Cohesion: 0.11
Nodes (28): Build-Backdrop(), New-BlobAnim(), Set-BackdropLayout(), Start-BlobDrift(), Build-Sidebar(), Move-NavIndicator(), New-NavButton(), Set-NavSelection() (+20 more)

### Community 10 - "Cajon del log"
Cohesion: 0.15
Nodes (29): Add-LogHeaderButton(), Add-ToLogRow(), Close-LogOverlay(), Get-DesktopFolder(), Get-LogDrawerWidth(), Get-LogPanelOpen(), Get-LogSaveFolder(), Get-LogSavePath() (+21 more)

### Community 11 - "Info del sistema y Acerca de"
Cohesion: 0.17
Nodes (17): Get-AppHostKind(), Get-AppRuntimeInfo(), Get-WindowsSummary(), Get-WindowsVersionValue(), Test-AppElevated(), Get-AboutElevationLabel(), Get-AboutHostLabel(), Get-AboutText() (+9 more)

### Community 12 - "Maximizar y ventana del log"
Cohesion: 0.13
Nodes (10): Enable-WorkAreaMaximize(), Initialize-WorkAreaMaximize(), Add-LogWindowDrag(), Clear-LogWindowState(), New-LogWindow(), Open-LogWindow(), Set-LogWindowState(), Show-LogWindowFront() (+2 more)

### Community 13 - "Arquitectura y equipo de agentes"
Cohesion: 0.14
Nodes (18): Agente arquitecto (solo lectura), Arquitectura de siete capas (Design, Engine, Index, core, Data, Components, Views), Optimizacion fuera del registro = mecanismo nuevo en core/, Orden de carga de capas, Plan de cambio (formato de entrega del arquitecto), Programa/OptimizadorPC.ps1 como referencia de Apply/Revert, Parte de trabajo (dev delivery format), Los agentes arrancan en frio (no ven la conversacion) (+10 more)

### Community 14 - "Log de actividad (core)"
Cohesion: 0.17
Nodes (12): Export-AppLog(), Format-AppLogLine(), Format-AppLogText(), Get-AppLogFileName(), Get-AppLogFolder(), Write-AppLog(), Format-LogValue(), Format-RegistryValue() (+4 more)

### Community 15 - "Material de ventana"
Cohesion: 0.17
Nodes (11): Initialize-SystemBackdrop(), Set-WindowBackdrop(), Test-SystemBackdropSupport(), Get-WindowMaterial(), Set-MaterialSurfaces(), Set-WindowMaterialChoice(), Sync-WindowMaterial(), Set-PanelBg() (+3 more)

### Community 16 - "Aserciones del TestKit"
Cohesion: 0.22
Nodes (12): Assert-Contains(), Assert-Equal(), Assert-False(), Assert-Match(), Assert-NotEqual(), Assert-NoThrow(), Assert-NotNull(), Assert-Null() (+4 more)

### Community 17 - "Versionado y guia del proyecto (doc)"
Cohesion: 0.16
Nodes (16): Revisar cambios antes de confirmar, estado.ps1 status script, One commit by default policy, versionado skill, Agent delegation policy, @@EMBED_DIR / @@EMBED_XAML build markers, graphify graph: uses and limits, graphify graph usage limits (+8 more)

### Community 18 - "Reglas de core (doc)"
Cohesion: 0.15
Nodes (13): Code execution prohibitions, Five registry write conditions, Diff security review order, core/ never throws upward, DWord arrives as signed Int32 (Format-RegistryValue), Global search (flat index, ui/Engine/Search.ps1), Mica/Acrylic exclusive with own gradient, Computed registry status (optimized/factory/custom/unknown) (+5 more)

### Community 19 - "Contrato de seguridad (doc)"
Cohesion: 0.23
Nodes (13): Command-step sections (Internet), Test coverage areas (core, UI, wiring, rules, security invariants), Add-Type literal C# in SystemBackdrop.ps1 and WorkArea.ps1, Attack surface (no network, repo-authored inputs), Code execution hard prohibitions, Command execution contract (CommandRunner.ps1), ExternalLink http/https only, $RegistryWriteAllowlist / $RegistryWriteAllowedValues (+5 more)

### Community 20 - "Progreso y traduccion"
Cohesion: 0.21
Nodes (4): Set-ProgressFill(), Set-ProgressStrip(), Show-ProgressStrip(), Update-UiNow()

### Community 21 - "Agentes dev/tester y trampas (doc)"
Cohesion: 0.29
Nodes (11): Dev agent, Tester agent, @() over List[object] pitfall (use .ToArray()), No .GetNewClosure() in event handlers (pass data via Tag), Tests redirect $AppSettingsPath, Test on both hosts (5.1 .exe and pwsh 7 main.ps1), UTF-8 with BOM rule, Harness/AppHost.ps1 (+3 more)

### Community 22 - "Auditoria y CI de seguridad"
Cohesion: 0.24
Nodes (10): security-reviewer skill, Threat model of elevated portable exe, actions/checkout pinned by SHA, Push trigger without paths filter, Semgrep CI workflow, Security and quality audit 2026-09-07, New-ChipMenu / New-ViewMenu deliberate duplication, Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix) (+2 more)

### Community 23 - "Enlaces externos y referencia"
Cohesion: 0.38
Nodes (8): Invoke-ExternalLink(), Test-ExternalLinkAllowed(), New-FactBlock(), New-GamingFactBlock(), New-GamingTag(), New-LinkFactBlock(), New-ReferenceBody(), New-SettingReference()

### Community 24 - "Opciones de vista y lista"
Cohesion: 0.33
Nodes (8): Get-ViewOption(), Get-ViewOptionDefinition(), Get-ViewOptionKey(), Get-ViewOptions(), Set-ViewOption(), New-CategoryItem(), New-CategoryPanel(), Show-OptimizationsListView()

### Community 25 - "Riesgos y pruebas pendientes (doc)"
Cohesion: 0.22
Nodes (9): Pending: persistent rollback and undo UI, Accepted and pending risks table, $RegistrySnapshots in-memory rollback, Semgrep, Supply chain: ps2exe pinned 1.0.18, unsigned exe, Semgrep CI, Pending smoke test of compiled .exe, What the tests do not cover, Why Playwright does not apply (WPF, no DOM) (+1 more)

### Community 26 - "Navegacion y contenedores (doc)"
Cohesion: 0.32
Nodes (8): Glyph catalog (Segoe Fluent Icons), Router / Show-View, Sidebar built by code (Build-Sidebar, Set-NavSelection, Sync-NavSelection), Sidebar built in code from NavigationIndex, Navigation flow (OptimizationsList -> CategoryDetail -> Settings), NavigationIndex, Shell containers (HeaderTitleArea/HeaderActionsArea/MainContent) via PageHeader, XAML view containers (HeaderTitleArea, HeaderActionsArea, MainContent)

### Community 27 - "Log y ajustes guardados (doc)"
Cohesion: 0.33
Nodes (7): Activity log (core/Diagnostics/Log.ps1 + LogPanel/LogWindow), Set-AppSetting / settings.json in %APPDATA%, Test suite (tests/Run-Tests.ps1 -BothHosts, no Pester), Tests do not write user settings (AppHost redirects $AppSettingsPath), Update-UiNow as DoEvents, Register-Preference (Settings screen auto-built), User data and activity log export

### Community 28 - "Contrato de escritura y filtro (doc)"
Cohesion: 0.33
Nodes (6): Always RegistryView::Registry64, Computed setting Status (optimized/factory/custom/unknown), Summary pills as status filter, Five conditions of each write, Registry write contract (Writer.ps1 / SettingApply.ps1), Write-RegistryValue result states

### Community 29 - "Animaciones (doc)"
Cohesion: 0.50
Nodes (5): Live backdrop at 20 fps without BlurEffect, Add-HoverLift stationary wrapper, Add-HoverLift static wrapper (RenderTransform hit-test loop), Start-StaggeredEnter / Get-EnterTarget, Effects and transitions table

### Community 30 - "Tema y degradados (doc)"
Cohesion: 0.50
Nodes (5): Frozen brushes / Set-AppTheme, $GradientTokens composed from palette keys, Colors via theme resources (DynamicResource / Set-TextFg), Design system (palette, gradients, live theme switch), Live theme switching via DynamicResource

### Community 34 - "Contrato de ajustes con registro"
Cohesion: 0.67
Nodes (3): core/Registry/CategoryState.ps1 (rellena el Current al entrar en la seccion), Declaracion New-Setting con -Registry, Recommended y Default, Sin valor de restauracion real no se puede aplicar un ajuste

## Knowledge Gaps
- **40 isolated node(s):** `Scripts sueltos: #requires y StrictMode`, `Programa/OptimizadorPC.ps1 como referencia de Apply/Revert`, `Skill security-reviewer`, `Skill windows-desktop-architect`, `Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix)` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 171 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Set-TextFg()` connect `Tarjetas, baldosas y desplegables` to `Arnes y fixtures de pruebas`, `Tarjeta de ajuste y cabecera`, `Pruebas de comandos, busqueda y filtro`, `Buscador global`, `Fondo vivo y menu lateral`, `Cajon del log`, `Enlaces externos y referencia`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `Set-BoxBg()` connect `Tarjetas, baldosas y desplegables` to `Arnes y fixtures de pruebas`, `Buscador global`, `Fondo vivo y menu lateral`, `Cajon del log`, `Material de ventana`, `Enlaces externos y referencia`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Why does `Sync-StepRunPanel()` connect `Arnes y fixtures de pruebas` to `Tarjetas, baldosas y desplegables`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Are the 60 inferred relationships involving `Set-TextFg()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`Set-TextFg()` has 60 INFERRED edges - model-reasoned connections that need verification._
- **Are the 30 inferred relationships involving `Set-BoxBg()` (e.g. with `New-DisclosureSection()` and `New-SearchResultRow()`) actually correct?**
  _`Set-BoxBg()` has 30 INFERRED edges - model-reasoned connections that need verification._
- **Are the 12 inferred relationships involving `New-Icon()` (e.g. with `New-CategoryTile()` and `New-DisclosureSection()`) actually correct?**
  _`New-Icon()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `Write-RegistryValue()` (e.g. with `Set-SettingOptimization()` and `Test-RegistryValueMatch()`) actually correct?**
  _`Write-RegistryValue()` has 2 INFERRED edges - model-reasoned connections that need verification._