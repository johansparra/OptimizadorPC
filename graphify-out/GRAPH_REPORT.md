# Graph Report - OptimizadorPC  (2026-10-03)

## Corpus Check
- 119 files · ~131,472 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 747 nodes · 1405 edges · 73 communities (28 shown, 9 thin omitted)
- Extraction: 72% EXTRACTED · 28% INFERRED · 0% AMBIGUOUS · INFERRED: 396 edges (avg confidence: 0.85)
- Token cost: 111,134 input · 0 output

## Community Hubs (Navigation)
- Tarjetas y piezas de interfaz
- Skills de exploracion y buenas practicas
- XAML de la ventana
- Arnes y fixtures de pruebas
- Fondo vivo y menu lateral
- Escritura y estado del registro
- Cajon del log
- Estado de categoria y desplegables
- Buscador global
- Acerca de e info del sistema
- Cabecera de pagina y avisos
- Maximizar y ventana del log
- Reglas de core y seguridad (doc)
- Resumen de categorias y busqueda
- Arquitectura y equipo de agentes
- Auditoria y CI de seguridad
- Log de actividad (core)
- Material de ventana
- Aserciones del TestKit
- Riesgos y contrato de escritura
- Versionado, tester y build (doc)
- Tema, traduccion y capas (doc)
- Navegacion, idioma y ajustes (doc)
- Agente dev y trampas (doc)
- Enlaces externos y referencia
- Indice de navegacion
- Barra de progreso
- Guardia de errores de UI
- Animaciones y fondo (doc)
- Contrato de ajustes con registro
- Sonda de cableado
- Skill powershell-engineer
- Regla de las dos suites
- Hook de codificacion (doc)
- Skill powershell-best-practices
- Skill refactoring-agent
- Skill versionado

## God Nodes (most connected - your core abstractions)
1. `Set-TextFg()` - 52 edges
2. `Window` - 37 edges
3. `Set-BoxBg()` - 26 edges
4. `SECURITY.md security reference` - 24 edges
5. `New-Icon()` - 22 edges
6. `CLAUDE.md project guide` - 22 edges
7. `T()` - 19 edges
8. `Write-RegistryValue()` - 18 edges
9. `Skill: windows-desktop-architect` - 15 edges
10. `Add-GridColumns()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `@@EMBED_DIR@@ / @@EMBED_XAML@@ build markers` --semantically_similar_to--> `Build pipeline (build.ps1 -> _combined.ps1 -> ps2exe)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Why Snyk does not fit` --semantically_similar_to--> `Why Playwright does not fit`  [INFERRED] [semantically similar]
  SECURITY.md → tests/README.md
- `Computed registry status (optimized/factory/custom/unknown)` --semantically_similar_to--> `Setting status states (optimized/factory/custom/unknown)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Mica and Acrylic preference` --semantically_similar_to--> `Mica and custom gradient are mutually exclusive`  [INFERRED] [semantically similar]
  README.md → CLAUDE.md
- `actions/checkout pinned by SHA` --semantically_similar_to--> `ps2exe pinned to 1.0.18 from PSGallery`  [INFERRED] [semantically similar]
  .github/workflows/semgrep.yml → SECURITY.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Circuito de entregas: cada rol produce un documento de formato fijo que el siguiente lee** — _claude_agents_arquitecto_arquitecto, _claude_agents_arquitecto_plan_de_cambio, _claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **Disciplina de los dos hosts (5.1 del .exe y pwsh 7 de main.ps1)** — _claude_skills_powershell_engineer_skill_contrato_de_los_dos_hosts, _claude_skills_powershell_engineer_skill_utf8_con_bom, _claude_skills_refactoring_agent_skill_ciclo_de_refactor, _claude_skills_powershell_best_practices_skill_checklist, _claude_skills_windows_desktop_architect_skill_checklist_interfaz [EXTRACTED 1.00]
- **Registry write safety contract** — security_registry_write_allowlist, security_registry_write_allowed_values, security_tradeoff_denylist, security_registry_snapshots, security_write_states, _claude_skills_security_reviewer_skill_five_write_conditions, security_test_invariants [EXTRACTED 1.00]
- **Trampas de WPF por recurso compartido o árbol mal colgado** — _claude_skills_windows_desktop_architect_skill_pinceles_congelados, _claude_skills_windows_desktop_architect_skill_freezable_en_setter, _claude_skills_windows_desktop_architect_skill_popup_arbol_logico, _claude_skills_windows_desktop_architect_skill_colores_por_recurso_de_tema [EXTRACTED 1.00]
- **Agent and skill development workflow** — _claude_agents_dev_dev_agent, _claude_agents_tester_tester_agent, _claude_skills_security_reviewer_skill_security_reviewer, _claude_skills_versionado_skill_versionado [INFERRED 0.85]
- **Supply chain hardening and static analysis** — _github_workflows_semgrep_semgrep_workflow, _github_workflows_semgrep_checkout_sha_pin, security_ps2exe_pinning, security_psscriptanalyzer, security_semgrep_analysis, security_unsigned_exe [INFERRED 0.85]
- **Registry write safety chain (allowlists, conditions, snapshots, tests)** — security_registry_write_contract, security_registry_write_allowlist, security_registry_write_allowed_values, security_five_write_conditions, security_registry_snapshots, security_tradeoff_denylist, security_security_tests [EXTRACTED 1.00]
- **PowerShell 5.1 vs 7 dual-host pitfalls** — claude_two_hosts_rule, claude_utf8_bom_rule, claude_no_getnewclosure_rule, claude_list_object_pitfall, claude_encoding_hook [INFERRED 0.85]
- **Live theme repaint system** — claude_theme_resource_colors, claude_frozen_brushes, claude_gradient_tokens, readme_design_system [INFERRED 0.85]

## Communities (73 total, 9 thin omitted)

### Community 0 - "Tarjetas y piezas de interfaz"
Cohesion: 0.08
Nodes (70): Add-CategoryStatusPills(), Add-CategoryTagPills(), New-CategoryCard(), New-CategoryStats(), New-CategoryTile(), New-DisclosureSection(), New-PreferenceCard(), New-PreferenceControl() (+62 more)

### Community 1 - "Skills de exploracion y buenas practicas"
Cohesion: 0.06
Nodes (58): Agrupar llamadas independientes en un turno, Recetas de búsqueda con grep, Skill: exploracion, Mapa de dónde vive cada cosa, Qué NO hace falta leer, Revisar cambios antes de confirmar, Trampas de esta máquina que cuestan turnos, Anatomía de una función PowerShell (+50 more)

### Community 2 - "XAML de la ventana"
Cohesion: 0.06
Nodes (50): IsDropDownOpen, SelectionBoxItem, Tag, AppVersionBadge, Backdrop, bd, BtnClose, BtnHelp (+42 more)

### Community 3 - "Arnes y fixtures de pruebas"
Cohesion: 0.06
Nodes (28): New-FakeSetting(), Find-Visuals(), Get-AppRoot(), Get-VisualText(), New-AppWindow(), Get-TestRegFullPath(), Get-TestRegPath(), New-TestCategory() (+20 more)

### Community 4 - "Fondo vivo y menu lateral"
Cohesion: 0.11
Nodes (28): Build-Backdrop(), New-BlobAnim(), Set-BackdropLayout(), Start-BlobDrift(), Build-Sidebar(), Move-NavIndicator(), New-NavButton(), Set-NavSelection() (+20 more)

### Community 5 - "Escritura y estado del registro"
Cohesion: 0.12
Nodes (26): Set-SettingOptimization(), ConvertTo-RegistryNumber(), Get-RegistryKeyStatus(), Get-SettingStatus(), Test-RegistryValueMatch(), Update-SettingStatus(), Write-SettingEvalLog(), Add-RegistrySnapshot() (+18 more)

### Community 6 - "Cajon del log"
Cohesion: 0.14
Nodes (31): Add-LogHeaderButton(), Add-ToLogRow(), Close-LogOverlay(), Get-DesktopFolder(), Get-LogDrawerWidth(), Get-LogPanelOpen(), Get-LogSaveFolder(), Get-LogSavePath() (+23 more)

### Community 7 - "Estado de categoria y desplegables"
Cohesion: 0.12
Nodes (24): Get-CategoryRegistryKeyCount(), Update-CategoryRegistryState(), Close-DisclosureSection(), Open-DisclosureSection(), Copy-DisclosureState(), Get-CardDisclosureHeaders(), Get-DisclosureLabel(), Get-AppWindow() (+16 more)

### Community 8 - "Buscador global"
Cohesion: 0.13
Nodes (27): Invoke-PendingSearch(), Invoke-SearchFocusPopup(), Invoke-SearchKey(), Invoke-SearchPopupReopen(), New-SearchBar(), New-SearchPopupCard(), New-SearchSeeAllRow(), Request-SearchPopupReopen() (+19 more)

### Community 9 - "Acerca de e info del sistema"
Cohesion: 0.16
Nodes (17): Get-AppHostKind(), Get-AppRuntimeInfo(), Get-WindowsSummary(), Get-WindowsVersionValue(), Get-AboutElevationLabel(), Get-AboutHostLabel(), Get-AboutText(), Initialize-AboutMenu() (+9 more)

### Community 10 - "Cabecera de pagina y avisos"
Cohesion: 0.13
Nodes (15): Add-PageAction(), Add-PageActionFirst(), Add-PageActionLabel(), Clear-PageHeader(), New-SectionHeader(), Set-PageTitle(), Show-PageToast(), Start-EnterTransition() (+7 more)

### Community 11 - "Maximizar y ventana del log"
Cohesion: 0.13
Nodes (10): Enable-WorkAreaMaximize(), Initialize-WorkAreaMaximize(), Add-LogWindowDrag(), Clear-LogWindowState(), New-LogWindow(), Open-LogWindow(), Set-LogWindowState(), Show-LogWindowFront() (+2 more)

### Community 12 - "Reglas de core y seguridad (doc)"
Cohesion: 0.12
Nodes (19): Code execution prohibitions, Five registry write conditions, Diff security review order, core/ never throws upward, DWord arrives as signed Int32 (Format-RegistryValue), Mica and custom gradient are mutually exclusive, Computed registry status (optimized/factory/custom/unknown), Test suite (tests/Run-Tests.ps1 -BothHosts, no Pester) (+11 more)

### Community 13 - "Resumen de categorias y busqueda"
Cohesion: 0.16
Nodes (14): Get-SettingStatusNames(), Get-SearchTestKey(), Get-SearchTestSetting(), Add-StatusPills(), Add-TagPills(), New-CategorySummary(), New-SummaryPill(), Update-CategorySummary() (+6 more)

### Community 14 - "Arquitectura y equipo de agentes"
Cohesion: 0.14
Nodes (18): Agente arquitecto (solo lectura), Arquitectura de siete capas (Design, Engine, Index, core, Data, Components, Views), Optimizacion fuera del registro = mecanismo nuevo en core/, Orden de carga de capas, Plan de cambio (formato de entrega del arquitecto), Programa/OptimizadorPC.ps1 como referencia de Apply/Revert, Parte de trabajo (dev delivery format), Los agentes arrancan en frio (no ven la conversacion) (+10 more)

### Community 15 - "Auditoria y CI de seguridad"
Cohesion: 0.22
Nodes (18): security-reviewer skill, Threat model of elevated portable exe, actions/checkout pinned by SHA, Push trigger without paths filter, Semgrep CI workflow, Security and quality audit 2026-09-07, New-ChipMenu / New-ViewMenu deliberate duplication, Audit history convention (+10 more)

### Community 16 - "Log de actividad (core)"
Cohesion: 0.17
Nodes (12): Export-AppLog(), Format-AppLogLine(), Format-AppLogText(), Get-AppLogFileName(), Get-AppLogFolder(), Write-AppLog(), Format-LogValue(), Format-RegistryValue() (+4 more)

### Community 17 - "Material de ventana"
Cohesion: 0.16
Nodes (12): Initialize-SystemBackdrop(), Set-WindowBackdrop(), Test-SystemBackdropSupport(), Get-WindowMaterial(), Set-MaterialSurfaces(), Set-WindowMaterialChoice(), Sync-WindowMaterial(), Get-AppTheme() (+4 more)

### Community 18 - "Aserciones del TestKit"
Cohesion: 0.22
Nodes (12): Assert-Contains(), Assert-Equal(), Assert-False(), Assert-Match(), Assert-NotEqual(), Assert-NoThrow(), Assert-NotNull(), Assert-Null() (+4 more)

### Community 19 - "Riesgos y contrato de escritura"
Cohesion: 0.17
Nodes (16): Audit recommendations (sign exe, persist rollback, Windows CI, narrow prefix), Always RegistryView::Registry64, DWord read as signed Int32, Pending work (persistent rollback, restore point, -Registry elsewhere), ps2exe, Accepted and pending risks table, Five conditions of each write, NetworkThrottlingIndex setting (Regedit) (+8 more)

### Community 20 - "Versionado, tester y build (doc)"
Cohesion: 0.20
Nodes (14): Tester agent, estado.ps1 status script, One commit by default policy, versionado skill, Test in both hosts (5.1 and pwsh 7), Build pipeline (build.ps1 -> _combined.ps1 -> ps2exe), Pending roadmap, AppHost harness (loads app without window) (+6 more)

### Community 21 - "Tema, traduccion y capas (doc)"
Cohesion: 0.15
Nodes (15): Frozen brushes (Set-AppTheme, Resources.Add), Get-Palette and $GradientTokens (two color families), graphify graph: uses and limits, Layered architecture (7 layer folders), Optimizador PC (CLAUDE.md), Computed setting status (optimized/factory/custom/unknown), All visible text passes through T, Colors only via theme resources (+7 more)

### Community 22 - "Navegacion, idioma y ajustes (doc)"
Cohesion: 0.17
Nodes (13): Activity log (log drawer and window), Set-AppSetting / settings.json in %APPDATA%, Glyph catalog (Segoe Fluent Icons), Router / Show-View, Sidebar built by code (Build-Sidebar, Set-NavSelection, Sync-NavSelection), Translation via T (source-text keyed), Languages (Register-Language, Get-MissingTranslations), Navigation flow (OptimizationsList -> CategoryDetail -> Settings) (+5 more)

### Community 23 - "Agente dev y trampas (doc)"
Cohesion: 0.31
Nodes (11): Dev agent, Agent delegation policy, @@EMBED_DIR@@ / @@EMBED_XAML@@ build markers, Normalize-PsEncoding PostToolUse hook, Global search flat index, graphify graph limitations, @() over List[object] pitfall (use .ToArray()), No .GetNewClosure() in event handlers (+3 more)

### Community 24 - "Enlaces externos y referencia"
Cohesion: 0.38
Nodes (8): Invoke-ExternalLink(), Test-ExternalLinkAllowed(), New-FactBlock(), New-GamingFactBlock(), New-GamingTag(), New-LinkFactBlock(), New-ReferenceBody(), New-SettingReference()

### Community 26 - "Barra de progreso"
Cohesion: 0.60
Nodes (4): Set-ProgressFill(), Set-ProgressStrip(), Show-ProgressStrip(), Update-UiNow()

### Community 29 - "Animaciones y fondo (doc)"
Cohesion: 0.67
Nodes (4): Live backdrop at 20 fps without BlurEffect, Add-HoverLift static wrapper (RenderTransform hit-test loop), Start-StaggeredEnter / Get-EnterTarget, Effects and transitions table

### Community 32 - "Contrato de ajustes con registro"
Cohesion: 0.67
Nodes (3): core/Registry/CategoryState.ps1 (rellena el Current al entrar en la seccion), Declaracion New-Setting con -Registry, Recommended y Default, Sin valor de restauracion real no se puede aplicar un ajuste

## Knowledge Gaps
- **29 isolated node(s):** `Programa/OptimizadorPC.ps1 como referencia de Apply/Revert`, `Skill security-reviewer`, `Skill windows-desktop-architect`, `Scripts sueltos: #requires y StrictMode`, `core/Registry/CategoryState.ps1 (rellena el Current al entrar en la seccion)` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 150 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Set-TextFg()` connect `Tarjetas y piezas de interfaz` to `Fondo vivo y menu lateral`, `Cajon del log`, `Buscador global`, `Cabecera de pagina y avisos`, `Resumen de categorias y busqueda`, `Enlaces externos y referencia`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `Invoke-SettingToggle()` connect `Estado de categoria y desplegables` to `Tarjetas y piezas de interfaz`, `Escritura y estado del registro`, `Cajon del log`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Why does `versionado skill` connect `Versionado, tester y build (doc)` to `Skills de exploracion y buenas practicas`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Are the 51 inferred relationships involving `Set-TextFg()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`Set-TextFg()` has 51 INFERRED edges - model-reasoned connections that need verification._
- **Are the 25 inferred relationships involving `Set-BoxBg()` (e.g. with `New-DisclosureSection()` and `New-SearchResultRow()`) actually correct?**
  _`Set-BoxBg()` has 25 INFERRED edges - model-reasoned connections that need verification._
- **Are the 16 inferred relationships involving `New-Icon()` (e.g. with `New-CategoryCard()` and `New-CategoryTile()`) actually correct?**
  _`New-Icon()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Programa/OptimizadorPC.ps1 como referencia de Apply/Revert`, `Skill security-reviewer`, `Skill windows-desktop-architect` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._