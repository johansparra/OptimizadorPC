# Graph Report - OptimizadorPC  (2026-11-09)

## Corpus Check
- 80 files · ~213,998 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1118 nodes · 2609 edges · 64 communities (39 shown, 9 thin omitted)
- Extraction: 76% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 613 edges (avg confidence: 0.85)
- Token cost: 294,988 input · 0 output

## Community Hubs (Navigation)
- Search Box And Popup
- Audits And Command Allowlists
- Window Shell And Header
- Animation And Theme Rules
- Activity Log Panel
- Guides And Build Markers
- Command Steps And System Info
- Service Startup Mechanism
- Registry Sections And Links
- Section Declaration And Index
- Project Rules And Security Docs
- Test Fixtures
- Preferences And Window Material
- Setting Apply And Status
- Registry Read And Log Core
- Cards And Theme Colors
- Build Pipeline And Architecture
- PowerShell Best Practices
- Architect And Dev Agents
- Agent Delegation Rules
- Scheduled Task Mechanism
- Test Kit Assertions
- Category Card Pills
- App Info And About Menu
- Technical Details Rows
- Router And Translation Repaint
- Visual Review Skills
- Translation Engine
- Security Invariant Tests
- Setting Reference Facts
- Security Reviewer And Signing
- Seven Layer Architecture
- Navigation And View Options
- Sidebar
- Versioning And Smoke Test
- Optimizations List View
- Category Tiles And Disclosure
- Search Result Cards
- Cleanup Test Fixtures
- UI Error Guard
- Diagnostic And Feedback Tasks
- Both Hosts Rule
- Playwright Not Applicable
- Game Mode Policy
- App Background Privacy
- NIC Energy Efficient Ethernet
- NIC Flow Control
- NIC Large Send Offload

## God Nodes (most connected - your core abstractions)
1. `Set-TextFg()` - 74 edges
2. `Window` - 42 edges
3. `CLAUDE.md (OptimizadorPC)` - 36 edges
4. `Set-BoxBg()` - 35 edges
5. `New-Icon()` - 29 edges
6. `Write-RegistryValue()` - 24 edges
7. `Add-ToColumn()` - 21 edges
8. `Command-step sections (Internet, Limpieza, Energia)` - 19 edges
9. `Remove-RegistryValue()` - 19 edges
10. `Glyph()` - 19 edges

## Surprising Connections (you probably didn't know these)
- `Write-RegistryValue()` --implements--> `Always open RegistryView::Registry64`  [INFERRED]
  core/Registry/Writer.ps1 → CLAUDE.md
- `Read-RegistryValueRaw()` --implements--> `Always open RegistryView::Registry64`  [INFERRED]
  core/Registry/Reader.ps1 → CLAUDE.md
- `Parameter-name case pitfall ([string]$Title vs $title)` --references--> `Set-PageBreadcrumb()`  [EXTRACTED]
  CLAUDE.md → ui/Components/Layout/PageHeader.ps1
- `Locked is not decorative (IsEnabled = $false on the controls panel)` --references--> `New-SettingCard()`  [EXTRACTED]
  CLAUDE.md → ui/Components/Cards/SettingCard.ps1
- `Get-TestSettingsPath()` --implements--> `Tests never touch the user's settings, network or registry`  [INFERRED]
  tests/Harness/AppHost.ps1 → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Circuito de entregas arquitecto -> dev -> tester** — _claude_agents_arquitecto_plan_de_cambio, _claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **Arquitecto -> Dev -> Tester hand-off pipeline (plan, work report, verification report)** — _claude_agents_arquitecto_plan_de_cambio, _claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **Pinned supply chain across build and CI (ps2exe, PSScriptAnalyzer, checkout SHA, semgrep digest)** — _claude_skills_security_reviewer_skill_supply_chain_pinning, _github_workflows_ci_pssa_job, _github_workflows_ci_humo_job, _github_workflows_semgrep_semgrep_job [INFERRED 0.85]
- **Packaging contract: seven layer folders, embed markers, walk replicated in main/build/AppHost** — _claude_agents_arquitecto_seven_layer_architecture, _claude_agents_dev_embed_markers, _claude_skills_refactoring_agent_skill_triple_walk_invariant [INFERRED 0.85]
- **Contrato de escritura al registro (lista blanca, DefaultAbsent, estados, invariantes)** — security_registry_allowlist, security_five_write_conditions, readme_default_absent, security_write_states, core_registry_writer_write_registryvalue, core_registry_writer_remove_registryvalue, tests_source_security_tests [EXTRACTED 1.00]
- **Ciclo de auditoria: informe fechado, historial y SECURITY.md vivo** — auditoria_2026_11_08_seguridad_calidad, auditoria_readme, security, claude [EXTRACTED 1.00]
- **Guias de gaming BF6 mostradas en la seccion Guias** — ui_data_guides_claves_registro_bf6, ui_data_guides_gpedit_gaming_tweaks, ui_data_guides_nic_i211_gaming_tweaks, ui_data_guides_task_scheduler_gaming_tweaks, claude_guides_section [INFERRED 0.85]

## Communities (64 total, 9 thin omitted)

### Community 0 - "Search Box And Popup"
Cohesion: 0.06
Nodes (58): Components/Layout: page pieces, ContentDock: fixed frame for the step-run panel, graphify graph: what it is for and what not, Search box Tag belongs to the popup, not the placeholder, Search popup: debounce, Enter, Escape, reopen on click, Popup opening deferred via Dispatcher.BeginInvoke ($script:SearchReopenBox), Test popups by popup.Child, not IsOpen, Typing repaints the body, never the header (+50 more)

### Community 1 - "Audits And Command Allowlists"
Cohesion: 0.06
Nodes (62): Threat model (-requireAdmin, -noConsole, portable exe), Security and quality audit 2026-09-07, New-ChipMenu / New-ViewMenu deliberate duplication, Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix), Auditoria 2026-11-08 seguridad y calidad, auditoria/README.md (historial de auditorias), Convencion de auditorias: un HTML fechado + fila en historial, Command allowlists ($CommandAllowedExecutables / $CommandAllowedServices) (+54 more)

### Community 2 - "Window Shell And Header"
Cohesion: 0.05
Nodes (56): IsDropDownOpen, SelectionBoxItem, Tag, Sliding indicator needs measurements (Move-NavIndicator), Sidebar collapse animates the Border width, not the Grid column, Shell containers (HeaderTitleArea, HeaderActionsArea, MainContent) via PageHeader, AdminBadge, AdminBadgeIcon (+48 more)

### Community 3 - "Animation And Theme Rules"
Cohesion: 0.07
Nodes (49): Animation standards for WPF, Cheap animatable properties (RenderTransform, Opacity), ClientAreaAnimation accessibility (reduced motion), Duration budgets (UI under 300 ms), Web to WPF animation mapping, Fondo vivo a 20 fps sin BlurEffect, Pinceles congelados (Freezable) y Resources.Add, Glyph catalog (Segoe Fluent Icons), never emoji (+41 more)

### Community 4 - "Activity Log Panel"
Cohesion: 0.09
Nodes (50): Saving the log to a file (Guardar como, Export-AppLog), Detached log window (LogWindow.ps1, New-LogContent), Las animaciones no avanzan sin una ventana pintándose, Add-LogHeaderButton(), Add-ToLogRow(), Close-LogOverlay(), Get-DesktopFolder(), Get-LogDrawerWidth() (+42 more)

### Community 5 - "Guides And Build Markers"
Cohesion: 0.09
Nodes (39): Marcadores de build.ps1 (@@EMBED_DIR, @@EMBED_GUIDES, @@EMBED_XAML), Guides section (Guias, ui/Data/Guides .md), Markdown reader subset (Get-MarkdownBlocks), Parameter-name case pitfall ([string]$Title vs $title), Copy-GuideText(), New-GuideCopyButton(), New-GuideDocument(), Update-GuideFind() (+31 more)

### Community 6 - "Command Steps And System Info"
Cohesion: 0.09
Nodes (39): El XAML va como aquí-string literal y no puede llamar a T, Admin gating of steps (-RequiresAdmin, effective selection), Step-run queue (120 ms DispatcherTimer, state in $StepRun), Get-AppHostKind(), Get-AppRuntimeInfo(), Get-WindowsSummary(), Get-WindowsVersionValue(), Set-AppElevationOverride() (+31 more)

### Community 7 - "Service Startup Mechanism"
Cohesion: 0.08
Nodes (37): Add-ServiceSnapshot(), ConvertFrom-ServiceStartMode(), Get-ServiceStartModeRaw(), Get-ServiceWriteArmed(), New-ServiceReadResult(), New-ServiceWriteResult(), Read-ServiceStartMode(), Set-ServiceStartMode() (+29 more)

### Community 8 - "Registry Sections And Links"
Cohesion: 0.07
Nodes (39): Uso del grafo graphify: sirve para path/explain, no para query en lenguaje natural, Invoke-ExternalLink(), Test-ExternalLinkAllowed(), Enlaces externos solo http/https, Guides shown as text only (Base64 in exe, never executed), Registry write contract (Writer.ps1 / SettingApply.ps1), Guia: Claves de registro BF6 / Gaming Network Tweaks, BF6 network tweaks .reg file (+31 more)

### Community 9 - "Section Declaration And Index"
Cohesion: 0.08
Nodes (34): PSScriptAnalyzer baseline, Baseline matched by rule + file, not line, Layer load order decided by main.ps1, Locked is not decorative (IsEnabled = $false on the controls panel), Get-SettingStatusNames(), Indice de secciones (CategoryIndex: Visible / Locked), Declaring a section (Register-Category, New-Setting), New-AppWindow() (+26 more)

### Community 10 - "Project Rules And Security Docs"
Cohesion: 0.11
Nodes (38): Security and quality audits (auditoria/ dated reports), @() over a New-Object List[object] throws (use .ToArray()), Comma inside method parentheses separates arguments (-f pitfall), One setting per registry key (never group keys), Optimizador PC working context (CLAUDE.md), Registry write via allowlist (SettingApply -> Writer), Every registry/service change must be reversible (Default + snapshot), Security-degrading settings must be declared (never plain Recommended) (+30 more)

### Community 11 - "Test Fixtures"
Cohesion: 0.08
Nodes (24): New-FakeSetting(), Find-Visuals(), Get-VisualText(), Get-TestRegFullPath(), Get-TestRegPath(), New-TestCategory(), New-TestKey(), New-TestRegFixture() (+16 more)

### Community 12 - "Preferences And Window Material"
Cohesion: 0.08
Nodes (26): Preferences persist via Set-AppSetting (%APPDATA% settings.json), Mica y degradado propio son excluyentes, Tests never touch the user's settings, network or registry, Initialize-SystemBackdrop(), Set-WindowBackdrop(), Test-SystemBackdropSupport(), Enable-WorkAreaMaximize(), Initialize-WorkAreaMaximize() (+18 more)

### Community 13 - "Setting Apply And Status"
Cohesion: 0.13
Nodes (30): Get-CategoryRegistryKeyCount(), Get-CategoryTargetKinds(), Update-CategoryRegistryState(), Update-SettingTargetState(), Set-SettingOptimization(), Test-RegistryRestoreByDelete(), ConvertTo-RegistryNumber(), Get-RegistryKeyStatus() (+22 more)

### Community 14 - "Registry Read And Log Core"
Cohesion: 0.11
Nodes (27): Registro de actividad (boton log), DWord arrives as signed Int32 (Format-RegistryValue), Layer 4 System: core/ (talks to Windows), Log entry detail (Items) folded with New-DetailList, Always open RegistryView::Registry64, DWord llega como Int32 con signo, Sync-LogView: new log lines are not painted by themselves, Export-AppLog() (+19 more)

### Community 15 - "Cards And Theme Colors"
Cohesion: 0.16
Nodes (31): Components/Shell: the window frame, Colores siempre por recurso de tema, New-CategoryCard(), New-CategoryTile(), New-GuideCard(), New-GuideEmptyState(), New-SettingCard(), New-SettingControl() (+23 more)

### Community 16 - "Build Pipeline And Architecture"
Cohesion: 0.11
Nodes (20): build.ps1 embed markers (@@EMBED_DIR@@, @@EMBED_GUIDES@@, @@EMBED_XAML@@), Layer folder walk written three times (main.ps1, build.ps1, AppHost.ps1), CLAUDE.md (OptimizadorPC), OptimizadorPC.exe: portable, elevated, console-less (-requireAdmin -noConsole), Envoltorio quieto para hover (RenderTransform mueve la zona sensible), Arquitectura en 7 capas (Design, Engine, Index, core, Data, Components, Views), Pildoras del resumen como filtro por estado, Las pruebas no escriben en settings.json del usuario (+12 more)

### Community 17 - "PowerShell Best Practices"
Cohesion: 0.11
Nodes (26): Anatomía de una función PowerShell, Checklist de buenas prácticas, Errores: fallar pronto, no usar throw para el flujo normal, Los cinco flujos de salida de PowerShell, Idempotencia: leer antes de escribir, Devolver objetos, no texto, Parámetros tipados y validados en la firma, Skill: powershell-best-practices (+18 more)

### Community 18 - "Architect And Dev Agents"
Cohesion: 0.11
Nodes (24): Arquitecto agent, core/ returns states, never throws (read/missing/denied/badpath), Prefer declarative file over new code, Plan de cambio (change plan format), Seven-layer architecture (Design, Engine, Index, core, Data, Components, Views), Dev agent, DWord read as signed Int32 (0xFFFFFFFF = -1), Never .GetNewClosure(); pass data via Tag (+16 more)

### Community 19 - "Agent Delegation Rules"
Cohesion: 0.10
Nodes (21): Los agentes arrancan en frío (no ven la conversación), Los agentes solo se cargan con la sesión abierta en OptimizadorPC/, Criterio de delegación: dos o más frentes que no comparten archivos, Equipo de agentes (arquitecto, dev, tester), Lanzar en paralelo exige el MISMO mensaje, Secuencial sobre los mismos archivos, settings.local.json: permisos como freno principal, Los agentes son roles; el conocimiento vive en skills (+13 more)

### Community 20 - "Scheduled Task Mechanism"
Cohesion: 0.19
Nodes (14): Add-ScheduledTaskSnapshot(), Format-ScheduledTaskName(), Get-ScheduledTaskEnabledRaw(), Get-ScheduledTaskWriteArmed(), New-ScheduledTaskReadResult(), New-ScheduledTaskWriteResult(), Read-ScheduledTaskEnabled(), Set-ScheduledTaskEnabled() (+6 more)

### Community 21 - "Test Kit Assertions"
Cohesion: 0.22
Nodes (15): Test suite (tests/Run-Tests.ps1 -BothHosts, no Pester), Assert-Contains(), Assert-Equal(), Assert-False(), Assert-Match(), Assert-NotEqual(), Assert-NoThrow(), Assert-NotNull() (+7 more)

### Community 22 - "Category Card Pills"
Cohesion: 0.21
Nodes (14): Start-CountUp writes the final value without a live window, Add-CategoryStatusPills(), Add-CategoryStepPills(), Add-CategoryTagPills(), New-CategoryStats(), New-SettingInfo(), Get-StatusStyle(), New-Badge() (+6 more)

### Community 23 - "App Info And About Menu"
Cohesion: 0.25
Nodes (14): Layer 5 Data: ui/Data (declarations only), AppInfo.ps1: single source of the version, Get-AboutElevationLabel(), Get-AboutHostLabel(), Get-AboutText(), Initialize-AboutMenu(), New-AboutCard(), New-AboutDetails() (+6 more)

### Community 24 - "Technical Details Rows"
Cohesion: 0.28
Nodes (15): Selectable text: read-only TextBox instead of TextBlock (New-MonoField), Copy-TechnicalValue(), New-CopyButton(), New-CurrentLine(), New-MonoField(), New-RegistryKeyRow(), New-ServiceTargetRow(), New-StateLine() (+7 more)

### Community 25 - "Router And Translation Repaint"
Cohesion: 0.24
Nodes (11): The log drawer is not a view (Close-LogOverlay), Router: Show-View and language repaint (Update-UiLanguage), Clicking a result opens its section with the setting highlighted, Todo texto visible pasa por T y hay que repintar al cambiar de idioma, Navegación y estado: Show-View, el log no es vista, Set-AppSetting, Get-AppWindow(), Get-CurrentViewName(), Show-CurrentView() (+3 more)

### Community 26 - "Visual Review Skills"
Cohesion: 0.19
Nodes (12): What the tests cannot see (look, .exe, real mouse, animations, real registry writes), break-ui worst-case catalog, Plural bug ('1 ajustes'), break-ui skill, emilkowalski/skills (upstream skill source), Off-screen PNG rendering via render.ps1, Roto / Feo / Fragil severity scale, Trim, wrap or limit decision per field (+4 more)

### Community 27 - "Translation Engine"
Cohesion: 0.18
Nodes (5): Todo texto visible pasa por T (traduccion por texto original), All visible text goes through T (source-text keyed translation), Adding a language (Register-Language, LanguageIndex), Get-MissingTranslations(), Register-Language()

### Community 28 - "Security Invariant Tests"
Cohesion: 0.19
Nodes (10): -AllowsSecurityTradeoff switch, Security-degrading settings denylist (UAC, Defender, SmartScreen, BitLocker, Update...), Regla: no usar .GetNewClosure() en handlers, Invariantes verificadas por pruebas (§10), Get-AppRoot(), Get-SourceFiles(), Get-SourceRelativePath(), Get-AllSystemTargets() (+2 more)

### Community 29 - "Setting Reference Facts"
Cohesion: 0.32
Nodes (12): New-GuideFindBox(), New-FactBlock(), New-GamingFactBlock(), New-GamingTag(), New-LinkFactBlock(), New-ReferenceBody(), New-SettingReference(), New-LogMessage() (+4 more)

### Community 30 - "Security Reviewer And Signing"
Cohesion: 0.23
Nodes (12): New-Setting with one -Registry key, Recommended + Default/DefaultAbsent, security-reviewer skill, Authenticode signing of the .exe (unsigned, blocks third-party distribution), Code execution bans (Invoke-Expression, dynamic Add-Type, DownloadString, unquoted Start-Process), Five registry write conditions, $RegistryWriteAllowlist, settings.json is untrusted input, Supply chain pinning (ps2exe 1.0.18, PSScriptAnalyzer 1.25.0, checkout SHA, semgrep digest) (+4 more)

### Community 31 - "Seven Layer Architecture"
Cohesion: 0.24
Nodes (10): Seven-layer architecture (one folder per layer), Layer 6 Pieces: ui/Components, Layer 1 Base: ui/Design (Theme, UiKit), Layer 2 Mechanism: ui/Engine, Layer 3 Policy: ui/Index (the main files), Layer 7 Screens: ui/Views, Module diagram (load order and who uses whom), One responsibility per file (a change opens one file) (+2 more)

### Community 32 - "Navigation And View Options"
Cohesion: 0.21
Nodes (7): Recetas: dónde va cada cosa, Register-Preference(), Get-ViewOption(), Get-ViewOptionDefinition(), Get-ViewOptionKey(), Get-ViewOptions(), Set-ViewOption()

### Community 33 - "Sidebar"
Cohesion: 0.33
Nodes (9): Sidebar built by code from NavigationIndex, Al plegar el menú se anima el ancho del Border, nunca la columna, Build-Sidebar(), New-NavButton(), Set-NavSelection(), Set-SidebarExpanded(), Switch-Sidebar(), Sync-NavSelection() (+1 more)

### Community 34 - "Versioning And Smoke Test"
Cohesion: 0.20
Nodes (5): versionado skill, Three-call commit flow (estado.ps1, both-host tests, add+commit), Push only on request; no force-push, amend or rebase, Release procedure (AppInfo Version, build, smoke, tag, gh release), humo job (elevated smoke test of compiled .exe)

### Community 35 - "Optimizations List View"
Cohesion: 0.29
Nodes (7): List or grid is a view option, not a separate view, Navigation flow (OptimizationsList <-> CategoryDetail, Settings), Indice del menu lateral (NavigationIndex), Get-OptimizationCategories(), New-CategoryItem(), New-CategoryPanel(), Show-OptimizationsListView()

### Community 36 - "Category Tiles And Disclosure"
Cohesion: 0.31
Nodes (7): Components/Cards: the cards, New-CategoryTilePanel(), Update-CategoryTileWidths(), Close-DisclosureSection(), New-DisclosureSection(), Open-DisclosureSection(), Glyph()

### Community 37 - "Search Result Cards"
Cohesion: 0.57
Nodes (7): Get-SearchResultDescription(), Get-SearchResultTitle(), New-SearchMatchLine(), New-SearchResultCard(), New-SearchResultRow(), New-SearchResultTag(), Open-SearchResult()

### Community 38 - "Cleanup Test Fixtures"
Cohesion: 0.70
Nodes (4): Get-CleanupFixtureRoot(), Invoke-TestCleanupJob(), New-CleanupFixture(), Remove-CleanupFixture()

## Ambiguous Edges - Review These
- `Guia: Task Scheduler ajustes para gaming` → `Rollback solo en memoria ($RegistrySnapshots), riesgo aceptado`  [AMBIGUOUS]
  SECURITY.md · relation: semantically_similar_to

## Knowledge Gaps
- **35 isolated node(s):** `Scripts sueltos: #requires y StrictMode`, `Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix)`, `LanmanServer SMB parameters (autodisconnect, Size, EnableOplocks, IRPStackSize, SharingViolation*)`, `BranchCache disabled`, `Remove default Microsoft Store packages policy` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 148 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Guia: Task Scheduler ajustes para gaming` and `Rollback solo en memoria ($RegistrySnapshots), riesgo aceptado`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **Why does `CLAUDE.md (OptimizadorPC)` connect `Build Pipeline And Architecture` to `Audits And Command Allowlists`, `Animation And Theme Rules`, `Guides And Build Markers`, `Service Startup Mechanism`, `Registry Sections And Links`, `Project Rules And Security Docs`, `Preferences And Window Material`, `Setting Apply And Status`, `Registry Read And Log Core`, `Agent Delegation Rules`, `Scheduled Task Mechanism`, `Technical Details Rows`, `Translation Engine`, `Security Invariant Tests`?**
  _High betweenness centrality (0.226) - this node is a cross-community bridge._
- **Why does `Set-TextFg()` connect `Setting Reference Facts` to `Search Box And Popup`, `Sidebar`, `Animation And Theme Rules`, `Category Tiles And Disclosure`, `Search Result Cards`, `Command Steps And System Info`, `Guides And Build Markers`, `Activity Log Panel`, `Section Declaration And Index`, `Registry Read And Log Core`, `Cards And Theme Colors`, `Category Card Pills`, `Technical Details Rows`?**
  _High betweenness centrality (0.137) - this node is a cross-community bridge._
- **Why does `Window` connect `Window Shell And Header` to `Search Box And Popup`, `Animation And Theme Rules`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Are the 71 inferred relationships involving `Set-TextFg()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`Set-TextFg()` has 71 INFERRED edges - model-reasoned connections that need verification._
- **Are the 33 inferred relationships involving `Set-BoxBg()` (e.g. with `New-DetailList()` and `New-DisclosureSection()`) actually correct?**
  _`Set-BoxBg()` has 33 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `New-Icon()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`New-Icon()` has 23 INFERRED edges - model-reasoned connections that need verification._