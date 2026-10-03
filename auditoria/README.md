# auditoría/

Registro de las auditorías de **seguridad y calidad** de Optimizador PC. Cada pasada
deja aquí su informe fechado, para que quede constancia de qué se revisó, qué se
encontró y qué se arregló.

## Convención

- Un archivo por auditoría: `AAAA-MM-DD-<tema>.html` (informe autónomo, se abre con
  doble clic).
- Una fila nueva en la tabla de abajo, de la más reciente a la más antigua.
- El **modelo de amenaza y el contrato de escritura** completos NO se duplican aquí:
  viven en `../SECURITY.md`, que se actualiza en la misma pasada. Estos informes son
  la *foto* de cada revisión; `SECURITY.md` es el documento vivo.
- La guía de cómo revisar un cambio está en
  `../.claude/skills/security-reviewer/SKILL.md`.

## Historial

| Fecha | Base | Alcance | Resumen | Informe |
| --- | --- | --- | --- | --- |
| 2026-09-07 | `bd2f12a` | Repaso | 2 brechas de CI de Semgrep corregidas (`actions/checkout` fijado por SHA; quitado el filtro `paths` del `push`). Pase estricto de PSScriptAnalyzer sobre `core/` sin la exclusión de `ShouldProcess`: 6 falsos positivos por verbo, `Write-RegistryValue` ya lo adopta. Funcionalidades nuevas (menús Expandir/Contraer, «Formato de hora») sin superficie nueva. Suite 438/438 en los dos hosts. | [2026-09-07-seguridad-calidad.html](2026-09-07-seguridad-calidad.html) |
| 2026-09-06 | `464ea1c` | Completa | Primera auditoría formal: contrato de escritura al registro (`core/Registry/Writer.ps1`), invariantes fijadas en `tests/Source/Security.Tests.ps1`, riesgos aceptados y pendientes documentados. | Prosa completa en [`../SECURITY.md`](../SECURITY.md) |
