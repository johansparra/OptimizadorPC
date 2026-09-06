# Graph Report - OptimizadorPC  (2026-09-05)

## Corpus Check
- 87 files · ~87,829 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 673 nodes · 1355 edges · 52 communities (29 shown, 1 thin omitted)
- Extraction: 64% EXTRACTED · 35% INFERRED · 0% AMBIGUOUS · INFERRED: 480 edges (avg confidence: 0.85)
- Token cost: 235,269 input · 0 output

## Community Hubs (Navigation)
- Kit visual y tarjetas
- Registro de actividad
- Agentes y arnes de pruebas
- XAML de la ventana
- Tema, menu lateral y fondo
- Arnes y pruebas de interfaz
- Vistas y cabecera de pagina
- Buscador global
- Skills de exploracion y versionado
- Resumen de categorias
- Aserciones del TestKit
- Estado del registro documentado
- Capa visual: color y movimiento
- Arquitectura de siete capas
- Ajustes y material de ventana
- Lectura real del registro
- Skill de interfaz WPF
- Traduccion y preferencias
- Trampas de PowerShell documentadas
- Skill de PowerShell
- Skill de seguridad
- Buenas practicas de PowerShell
- Dos hosts y flujos de salida
- Donde va cada cosa
- Navegacion y menu lateral
- Buscador y log documentados
- Empaquetado y arranque
- Como se trabaja aqui
- Pruebas del registro de actividad
- Opciones de vista

## God Nodes (most connected - your core abstractions)
1. `T()` - 61 edges
2. `Set-TextFg()` - 47 edges
3. `Window` - 42 edges
4. `Set-BoxBg()` - 24 edges
5. `New-Icon()` - 21 edges
6. `Show-CategoryDetailView()` - 21 edges
7. `Update-LogList()` - 16 edges
8. `Get-AppWindow()` - 15 edges
9. `Skill: windows-desktop-architect` - 15 edges
10. `New-CategoryCard()` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Marcadores @@EMBED_DIR@@ / @@EMBED_XAML@@` --semantically_similar_to--> `build.ps1 (empaquetado + ps2exe)`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Menu lateral construido por codigo` --semantically_similar_to--> `ui/Index/NavigationIndex.ps1`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Las vistas se muestran con Show-View` --semantically_similar_to--> `ui/Engine/Router.ps1`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Indicadores deslizantes sin medidas` --semantically_similar_to--> `Efectos y transiciones`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md
- `Registro de actividad (cajon del log)` --semantically_similar_to--> `core/Diagnostics/Log.ps1`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Circuito de entregas: cada rol produce un documento de formato fijo que el siguiente lee** — _claude_agents_arquitecto_arquitecto, _claude_agents_dev_dev, _claude_agents_tester_tester, _claude_agents_arquitecto_plan_de_cambio, _claude_agents_dev_parte_de_trabajo, _claude_agents_tester_informe_de_verificacion [EXTRACTED 1.00]
- **El arnes de pruebas: lanzador y tres archivos de Harness que no prueban nada** — tests_readme_run_tests, tests_readme_testkit, tests_readme_apphost, tests_readme_fixtures, tests_readme_sin_pester [EXTRACTED 1.00]
- **Reglas de CLAUDE.md que se vigilan leyendo el codigo o ejecutando main.ps1** — _claude_agents_dev_utf8_con_bom, _claude_agents_dev_prohibicion_getnewclosure, _claude_agents_dev_marcadores_embed, _claude_agents_dev_regla_traduccion_t, tests_readme_rules_tests, tests_readme_wiring_tests, _claude_agents_tester_comprobaciones_fuera_de_la_suite [INFERRED 0.85]
- **Disciplina de los dos hosts (5.1 del .exe y pwsh 7 de main.ps1)** — _claude_skills_powershell_engineer_skill_contrato_de_los_dos_hosts, _claude_skills_powershell_engineer_skill_utf8_con_bom, _claude_skills_refactoring_agent_skill_ciclo_de_refactor, _claude_skills_versionado_skill_cuando_verificar, _claude_skills_powershell_best_practices_skill_checklist, _claude_skills_windows_desktop_architect_skill_checklist_interfaz [EXTRACTED 1.00]
- **Contrato para escribir en el sistema elevado (el primer SetValue)** — _claude_skills_powershell_best_practices_skill_supports_should_process, _claude_skills_powershell_best_practices_skill_idempotencia, _claude_skills_powershell_best_practices_skill_reversibilidad, _claude_skills_security_reviewer_skill_condiciones_de_escritura_al_registro, _claude_skills_security_reviewer_skill_ajustes_que_degradan_la_seguridad, _claude_skills_security_reviewer_skill_modelo_de_amenaza [INFERRED 0.85]
- **Trampas de WPF por recurso compartido o árbol mal colgado** — _claude_skills_windows_desktop_architect_skill_pinceles_congelados, _claude_skills_windows_desktop_architect_skill_freezable_en_setter, _claude_skills_windows_desktop_architect_skill_popup_arbol_logico, _claude_skills_windows_desktop_architect_skill_colores_por_recurso_de_tema [EXTRACTED 1.00]
- **Las siete capas y el orden que decide main.ps1** — claude_ui_design, claude_ui_engine, claude_ui_index, claude_core, claude_ui_data, claude_ui_components, claude_ui_views, readme_main_ps1 [EXTRACTED 1.00]
- **Contrato de empaquetado: mismo marcador y mismo orden en los tres sitios** — claude_embed_dir_marker, readme_main_ps1, readme_ps2exe_build, readme_combined_ps1, claude_test_harness, readme_mainwindow_xaml [EXTRACTED 1.00]
- **Flujo del buscador global** — claude_global_search, claude_search_index, claude_search_box_tag_trap, claude_search_body_repaint, claude_setting_status, claude_translation_t [EXTRACTED 1.00]

## Communities (52 total, 1 thin omitted)

### Community 0 - "Kit visual y tarjetas"
Cohesion: 0.09
Nodes (66): New-CategoryCard(), New-CategoryStats(), New-CategoryTile(), New-PreferenceCard(), New-PreferenceControl(), Get-SearchResultTitle(), New-SearchMatchLine(), New-SearchResultCard() (+58 more)

### Community 1 - "Registro de actividad"
Cohesion: 0.07
Nodes (59): Clear-AppLog(), Export-AppLog(), Format-AppLogLine(), Format-AppLogText(), Get-AppLog(), Get-AppLogCount(), Get-AppLogDropped(), Get-AppLogFileName() (+51 more)

### Community 2 - "Agentes y arnes de pruebas"
Cohesion: 0.05
Nodes (59): Agente arquitecto (solo lectura), Arquitectura de siete capas (Design, Engine, Index, core, Data, Components, Views), core/Registry/CategoryState.ps1 (rellena el Current al entrar en la seccion), Declaracion New-Setting con -Registry, Recommended y Default, Optimizacion fuera del registro = mecanismo nuevo en core/, Orden de carga de capas, Plan de cambio (formato de entrega del arquitecto), Programa/OptimizadorPC.ps1 como referencia de Apply/Revert (+51 more)

### Community 3 - "XAML de la ventana"
Cohesion: 0.05
Nodes (55): IsDropDownOpen, SelectionBoxItem, Tag, Backdrop, bd, BtnClose, BtnHelp, BtnLog (+47 more)

### Community 4 - "Tema, menu lateral y fondo"
Cohesion: 0.08
Nodes (39): Set-ModeSelection(), Push-NavButton(), Build-Backdrop(), New-BlobAnim(), Set-BackdropLayout(), Start-BlobDrift(), Build-Sidebar(), Get-SidebarExpanded() (+31 more)

### Community 5 - "Arnes y pruebas de interfaz"
Cohesion: 0.07
Nodes (21): New-FakeSetting(), Find-Visuals(), Get-AppRoot(), Get-VisualText(), New-AppWindow(), Get-TestRegFullPath(), Get-TestRegPath(), New-TestCategory() (+13 more)

### Community 6 - "Vistas y cabecera de pagina"
Cohesion: 0.10
Nodes (24): Add-PageAction(), Add-PageActionFirst(), Add-PageActionLabel(), Clear-PageHeader(), New-SectionHeader(), Set-PageSummary(), Set-PageTitle(), Show-PageToast() (+16 more)

### Community 7 - "Buscador global"
Cohesion: 0.15
Nodes (24): Invoke-PendingSearch(), Invoke-SearchKey(), New-SearchBar(), Set-SearchFocus(), Start-SearchDebounce(), Stop-SearchDebounce(), Update-SearchPopup(), Get-OptimizationCategories() (+16 more)

### Community 8 - "Skills de exploracion y versionado"
Cohesion: 0.13
Nodes (22): Agrupar llamadas independientes en un turno, Recetas de búsqueda con grep, Skill: exploracion, Qué NO hace falta leer, Revisar cambios antes de confirmar, Trampas de esta máquina que cuestan turnos, Crear un archivo nuevo desde Bash (heredoc, sin BOM, sin python), Eliminar un concepto de todo el proyecto (+14 more)

### Community 9 - "Resumen de categorias"
Cohesion: 0.15
Nodes (15): Get-SettingStatusNames(), Get-SearchTestKey(), Get-SearchTestSetting(), Add-StatusPills(), Add-TagPills(), New-CategorySummary(), New-SummaryPill(), Update-CategorySummary() (+7 more)

### Community 10 - "Aserciones del TestKit"
Cohesion: 0.22
Nodes (12): Assert-Contains(), Assert-Equal(), Assert-False(), Assert-Match(), Assert-NotEqual(), Assert-NoThrow(), Assert-NotNull(), Assert-Null() (+4 more)

### Community 11 - "Estado del registro documentado"
Cohesion: 0.17
Nodes (16): Registro de actividad (cajon del log), Close-LogOverlay colapsa el velo, Capa 4 Sistema (core/), DWord llega como Int32 con signo, Abrir siempre RegistryView::Registry64, core/ lee el registro y nunca lanza, Estado calculado del ajuste (optimized/factory/custom/unknown), Update-UiNow es un DoEvents (+8 more)

### Community 12 - "Capa visual: color y movimiento"
Cohesion: 0.15
Nodes (16): Fondo vivo a 20 fps y sin BlurEffect, Nunca declarar un Freezable animable en un Setter, Dos familias de color: paleta y $GradientTokens, Envoltorio quieto de Add-HoverLift, Mica y el degradado propio son excluyentes, Entrada en cascada y Get-EnterTarget, TextBlock no se puede seleccionar ni copiar, Colores por recurso de tema (+8 more)

### Community 13 - "Arquitectura de siete capas"
Cohesion: 0.17
Nodes (16): Pinceles congelados (Freezable), Catalogo de glifos Segoe Fluent Icons, La cuadricula no es una vista aparte, Arquitectura de siete capas, Locked no es decorativo, Capa 6 Piezas (ui/Components), Capa 5 Datos (ui/Data), Capa 1 Base (ui/Design) (+8 more)

### Community 14 - "Ajustes y material de ventana"
Cohesion: 0.17
Nodes (10): Initialize-SystemBackdrop(), Set-WindowBackdrop(), Test-SystemBackdropSupport(), Get-WindowMaterial(), Set-MaterialSurfaces(), Set-WindowMaterialChoice(), Sync-WindowMaterial(), Set-PanelBg() (+2 more)

### Community 15 - "Lectura real del registro"
Cohesion: 0.23
Nodes (13): Get-CategoryRegistryKeyCount(), Update-CategoryRegistryState(), Format-LogValue(), Format-RegistryValue(), New-RegistryResult(), Read-RegistryValue(), Read-RegistryValueRaw(), Write-RegistryLog() (+5 more)

### Community 16 - "Skill de interfaz WPF"
Cohesion: 0.22
Nodes (15): Qué NO refactorizar por tu cuenta (marcadores y excepciones conscientes), Datos del usuario: settings.json y el registro de actividad, Las animaciones no avanzan sin una ventana pintándose, Antes de dar la interfaz por terminada, Colores siempre por recurso de tema, Nunca un Freezable dentro de un Setter que vayas a animar, Iconos: Glyph del catálogo de Theme.ps1, nunca emoji, Todo texto visible pasa por T y hay que repintar al cambiar de idioma (+7 more)

### Community 17 - "Traduccion y preferencias"
Cohesion: 0.16
Nodes (15): Repintar al cambiar de idioma, Guardado del log partido en tres, Sync-NavSelection decide la marca del menu, Preferencias via Set-AppSetting, Las vistas se muestran con Show-View, Todo texto visible pasa por T, Capa 2 Mecanismo (ui/Engine), ui/Engine/AppSettings.ps1 (+7 more)

### Community 18 - "Trampas de PowerShell documentadas"
Cohesion: 0.18
Nodes (13): Probar siempre en los dos hosts, Hook PostToolUse Normalize-PsEncoding, La coma dentro de un metodo separa argumentos, @() sobre List[object] revienta, Prohibido .GetNewClosure() en handlers, El Tag de la caja es del desplegable, Patron Tag + GetWindow($s), Arnes de pruebas (tests/Harness) (+5 more)

### Community 19 - "Skill de PowerShell"
Cohesion: 0.24
Nodes (10): Rendimiento y legibilidad: nada de alias, nada de +=, @() sobre List[object] creada con New-Object revienta, Comparaciones: $null a la izquierda, cadenas siempre verdaderas, DWord llega como Int32 con signo, -f dentro de los paréntesis de un método, += sobre arrays es O(n²), No usar GetNewClosure: el dato viaja por el Tag, Skill: powershell-engineer (+2 more)

### Community 20 - "Skill de seguridad"
Cohesion: 0.24
Nodes (10): Scripts sueltos: #requires y StrictMode, Estilo del proyecto: comentarios en español, identificadores en inglés, Ajustes que degradan la seguridad del equipo, Cadena de suministro: ps2exe sin repositorio ni versión fijada, Caso vivo: BitLocker Auto Encryption (PreventDeviceEncryption = 1), Caso vivo: User Account Control Level (ConsentPromptBehaviorAdmin = 0), Cómo revisar un diff y cómo reportar hallazgos, Modelo de amenaza del .exe elevado y portable (+2 more)

### Community 21 - "Buenas practicas de PowerShell"
Cohesion: 0.33
Nodes (9): Anatomía de una función PowerShell, Checklist de buenas prácticas, Idempotencia: leer antes de escribir, Parámetros tipados y validados en la firma, Skill: powershell-best-practices, Reversibilidad: capturar el valor previo antes de tocar, SupportsShouldProcess: -WhatIf y -Confirm gratis, Verbo aprobado y sustantivo singular (+1 more)

### Community 22 - "Dos hosts y flujos de salida"
Cohesion: 0.48
Nodes (7): Los cinco flujos de salida de PowerShell, Devolver objetos, no texto, El contrato de los dos hosts (5.1 del .exe y pwsh 7 de main.ps1), Todo lo que no se consume se devuelve (Out-Null), UTF-8 con BOM siempre, El ciclo de refactor (verde, paso pequeño, BOM, verde), Cuándo verificar y cuándo no antes de confirmar

### Community 23 - "Donde va cada cosa"
Cohesion: 0.40
Nodes (6): Mapa de dónde vive cada cosa, Errores: fallar pronto, no usar throw para el flujo normal, core/ nunca lanza hacia arriba: devuelve estado, Mover código entre capas, Recetas: dónde va cada cosa, Las siete capas, de datos a pantalla

### Community 24 - "Navegacion y menu lateral"
Cohesion: 0.40
Nodes (6): Start-CountUp sin ventana viva, Menu lateral construido por codigo, Plegado: animar el ancho del Border, Indicadores deslizantes sin medidas, Flujo de navegacion, ui/Index/NavigationIndex.ps1

### Community 25 - "Buscador y log documentados"
Cohesion: 0.33
Nodes (6): Marcadores @@EMBED_DIR@@ / @@EMBED_XAML@@, Buscador global (caja de la cabecera), LogWindow: el log en ventana aparte, Al escribir se repinta el cuerpo, nunca la cabecera, Indice plano de busqueda, Sync-LogView avisa a la interfaz

### Community 26 - "Empaquetado y arranque"
Cohesion: 0.47
Nodes (6): Contenedores nombrados de la cabecera, main.ps1 (arranque y orden de capas), MainWindow.xaml (esqueleto y estilos), Diagrama de modulos, Optimizador PC, build.ps1 (empaquetado + ps2exe)

### Community 28 - "Como se trabaja aqui"
Cohesion: 0.67
Nodes (3): Delegar por frentes independientes, Llamadas independientes en el mismo turno, Skills cargadas al empezar

### Community 29 - "Pruebas del registro de actividad"
Cohesion: 0.67
Nodes (3): tests/Core/Log.Tests.ps1, tests/Ui/LogPanel.Tests.ps1, tests/Ui/LogWindow.Tests.ps1

## Ambiguous Edges - Review These
- `Comparaciones: $null a la izquierda, cadenas siempre verdaderas` → `Caso vivo: Automatic Maintenance (Recommended y Default iguales)`  [AMBIGUOUS]
  .claude/skills/security-reviewer/SKILL.md · relation: conceptually_related_to
- `Estado calculado del ajuste (optimized/factory/custom/unknown)` → `Pendiente (escritura al registro y rollback)`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Buscador global (caja de la cabecera)` → `Pendiente (escritura al registro y rollback)`  [AMBIGUOUS]
  CLAUDE.md · relation: conceptually_related_to

## Knowledge Gaps
- **34 isolated node(s):** `Track`, `Tag`, `ToggleButton`, `IsDropDownOpen`, `SelectionBoxItem` (+29 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 101 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Comparaciones: $null a la izquierda, cadenas siempre verdaderas` and `Caso vivo: Automatic Maintenance (Recommended y Default iguales)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Estado calculado del ajuste (optimized/factory/custom/unknown)` and `Pendiente (escritura al registro y rollback)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Buscador global (caja de la cabecera)` and `Pendiente (escritura al registro y rollback)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `T()` connect `Kit visual y tarjetas` to `Registro de actividad`, `Tema, menu lateral y fondo`, `Arnes y pruebas de interfaz`, `Vistas y cabecera de pagina`, `Buscador global`, `Resumen de categorias`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **Why does `Show-CategoryDetailView()` connect `Vistas y cabecera de pagina` to `Kit visual y tarjetas`, `Registro de actividad`, `Tema, menu lateral y fondo`, `Buscador global`, `Lectura real del registro`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `Set-TextFg()` connect `Kit visual y tarjetas` to `Resumen de categorias`, `Tema, menu lateral y fondo`, `Vistas y cabecera de pagina`, `Registro de actividad`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 60 inferred relationships involving `T()` (e.g. with `New-CategoryCard()` and `New-CategoryStats()`) actually correct?**
  _`T()` has 60 INFERRED edges - model-reasoned connections that need verification._