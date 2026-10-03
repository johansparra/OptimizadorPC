# graphify-out/

**Todo lo que hay aquí lo genera [graphify](https://github.com/safishamsi/graphify) — no se
edita a mano** (salvo este README). Se rehace con `/graphify . --update` desde
`OptimizadorPC/`, así que borrar la carpeta no pierde nada salvo el tiempo de recálculo.

Qué es: un **grafo de conocimiento** del proyecto. Lee los 127 archivos de
`OptimizadorPC/` (código `.ps1` / `.xaml` / `.json` y documentación `.md`) y saca de
ellos quién llama a quién, qué concepto vive en qué archivo y qué grupos de cosas se
mueven juntas. **Antes de usarlo, lee "El grafo de graphify" en `../CLAUDE.md`**: dice
para qué sirve y, sobre todo, para qué no.

## Estado actual (2026-10-03, tras la sección Internet)

| | |
| --- | --- |
| Nodos | **821** — 670 del análisis sintáctico del código, 151 de la documentación |
| Aristas | **1.502** · 7 hiperaristas (grupos de 3+ nodos que participan en lo mismo) |
| Comunidades | **80**, etiquetadas a mano ("Ejecución de comandos de red", "Buscador global"...). 39 son de un solo nodo: archivos sueltos |
| Salud | 0 aristas colgantes, 0 perdidas, 0 colapsadas |
| Pasadas | 4 (la primera completa, tres incrementales con `--update`) |

Los nodos más conectados (*god nodes*): `Set-TextFg()` (61), `Window` (41),
`Set-BoxBg()` (31), `New-Icon()` (18), `Write-RegistryValue()` (18), `T()` (16),
`Sync-StepRunPanel()` (15). Dicen lo mismo que el código: el tema, la ventana y la
traducción lo tocan todo, la escritura al registro es el centro de `core/`, y el marco
de ejecución de Internet es quien más piezas mueve de lo nuevo.

## Lo que se queda

| Archivo | Qué es |
| ------- | ------ |
| `graph.json` | **El grafo.** Formato *node-link* de NetworkX: `nodes` y `links` (ojo, no `edges`). De aquí comen `graphify query`, `path` y `explain`, y de aquí se derivan el HTML y el informe. |
| `GRAPH_REPORT.md` | **El archivo para leer.** Comunidades con sus miembros, *god nodes*, conexiones sorprendentes, ciclos de importación y las preguntas que este grafo puede responder. |
| `graph.html` | El grafo interactivo. Doble clic y se abre; no necesita servidor ni conexión. |
| `manifest.json` | Una fila por archivo (127) con su `mtime`, su `ast_hash` y su `semantic_hash`. Es lo que hace posible `--update`. |
| `cost.json` | Tokens gastados, acumulados por pasada (607.943 en 4 pasadas). |
| `cache/` | ~203 archivos, ~1,6 MB. `ast/` (una entrada por archivo de código) y `semantic/` (lo que el modelo sacó de los `.md`, que es lo que de verdad cuesta). Se invalida sola al cambiar el archivo, la versión de graphify o el prompt de extracción. |
| `.graphify_python` / `.graphify_root` | El intérprete con graphify y la carpeta escaneada. Llevan rutas de esta máquina. |
| `.graphify_labels.json` | El nombre de cada comunidad. |

### Cómo leer `graph.json`

Cada **nodo** lleva `id`, `label`, `file_type`, `source_file`, `source_location`, su
`community` con su `community_name`, y un `_origin`:

| `_origin` | Cuántos | Qué significa |
| --------- | ------: | ------------- |
| `ast` | 670 | Del árbol sintáctico (tree-sitter, gramática de PowerShell). Determinista, sin modelo, sin coste. |
| `semantic` / *(vacío)* | 151 | Lo leyó el modelo de la documentación (el vacío es de la primera pasada). |

Por tipo: 620 de código, 103 conceptos, 75 de **rationale** (el *porqué* de una decisión)
y 23 documentos.

Cada **arista** lleva `relation`, `weight`, el archivo de origen y su **rastro de
auditoría**:

| `confidence` | Cuántas | Qué quiere decir |
| ------------ | ------: | ---------------- |
| `EXTRACTED` | 1.095 | Está literalmente en el código o el texto: una llamada, una cita, un "ver §3". |
| `INFERRED` | 407 | Lo dedujo el modelo. Trae `confidence_score` (0,55 a 0,95) para saber cuánto fiarse. |

Relaciones más frecuentes: `calls` (686), `contains` (507), `references` (206),
`conceptually_related_to` (44), `implements` (18), `semantically_similar_to` (17).

## Cómo se rehace

```powershell
/graphify . --update        # solo lo que haya cambiado (usa manifest.json)
/graphify .                 # todo de nuevo
/graphify . --cluster-only  # reagrupa sin volver a extraer
/graphify path "LogPanel.ps1" "Reader.ps1"
/graphify explain "Write-RegistryValue"
```

Ejecútalo **desde `OptimizadorPC/`**: desde la carpeta padre crearía otro grafo que
mezcla los scripts sueltos de `Temp/` y la versión antigua de `Programa/`.

## Avisos

- **Los archivos de datos salen sueltos.** `ui/Data/Categories/*.ps1`, `es.ps1` y las
  preferencias son nodos de un solo elemento, sin aristas: el análisis sintáctico no ve
  llamadas en una lista de `New-Setting`. Para buscar un ajuste o una clave, `grep`.
- **La documentación y el código no están enlazados.** Ninguna arista va de un `.md` a
  una función. Por eso `graphify query` en lenguaje natural da malos resultados aquí.
- **`cost.json` cuenta todo como entrada.** El host solo da un total por subagente, sin
  separar entrada de salida. La primera pasada además perdió los tokens de un subagente:
  las cifras son un suelo, no un total.
- **Etiquetas duplicadas al actualizar.** Los nodos de documentación de la primera pasada
  guardaban la ruta relativa (`CLAUDE.md`) y los de `--update` la absoluta. En la pasada
  del 2026-10-03 graphify avisó de unos 20 nodos con el mismo id y conservó una de las
  dos etiquetas de cada uno: el concepto está, solo se pierde la redacción alternativa.
  Un `/graphify .` completo lo dejaría limpio.
- **Esta carpeta está versionada a propósito.** La regla `graphify-out/` del
  `.gitignore` está comentada: se quiere el grafo en el repo.
- **OneDrive sincroniza esta ruta.** Unos 2,7 MB en muchos archivos pequeños.
