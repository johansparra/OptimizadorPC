# graphify-out/

**Todo lo que hay aquí lo genera [graphify](https://github.com/safishamsi/graphify) — no se
edita a mano** (salvo este README). Se rehace con `/graphify . --update` desde
`OptimizadorPC/`, así que borrar la carpeta no pierde nada salvo el tiempo de recálculo.

Qué es: un **grafo de conocimiento** del proyecto. Lee los 144 archivos de
`OptimizadorPC/` (código `.ps1` / `.xaml` / `.json` y documentación `.md`, guías
incluidas) y saca de ellos quién llama a quién, qué concepto vive en qué archivo y qué
grupos de cosas se mueven juntas. **Antes de usarlo, lee "El grafo de graphify" en
`../CLAUDE.md`**: dice para qué sirve y para qué no.

## Estado actual (2026-11-08, tras Limpieza, Energía, Guías y el detalle del log)

| | |
| --- | --- |
| Nodos | **1.036** — 717 del análisis sintáctico del código, 319 de la documentación |
| Aristas | **2.614** · 12 hiperaristas (grupos de 3+ nodos que participan en lo mismo) |
| Documentación ↔ código | **674 aristas** (antes, 0): los `.md` ya apuntan a las funciones y archivos que describen |
| Comunidades | **53**, etiquetadas a mano ("Comandos y limpieza (core)", "Guías y lector Markdown"...). Solo 6 de un nodo (antes 39) |
| Salud | 0 aristas colgantes, 0 perdidas, 0 colapsadas, 0 bucles |
| Pasadas | 5 (la primera completa, cuatro incrementales con `--update`) |

Los nodos más conectados (*god nodes*): `Set-TextFg()` (75), la suite de pruebas (43),
`Window` (42), `Set-BoxBg()` (36), `New-Icon()` (28), `Write-RegistryValue()` (22),
`Show-CategoryDetailView()` (20) y las secciones de comandos (20). El tema, la ventana y
las pruebas lo tocan todo; la escritura al registro sigue siendo el centro de `core/`, y
las secciones de comandos (Internet, Limpieza, Energía) ya son un eje propio.

La pasada del 2026-11-08 añadió 325 nodos y 1.342 aristas y quitó 110 nodos y 230
aristas: los de las secciones borradas (Gaming, Notifications, Sound), el
`core/Network/CommandRunner.ps1` que se movió a `core/Commands/`, y los nodos de
documentación duplicados de pasadas anteriores, que la reextracción sustituyó.

## Lo que se queda

| Archivo | Qué es |
| ------- | ------ |
| `graph.json` | **El grafo.** Formato *node-link* de NetworkX: `nodes` y `links` (ojo, no `edges`). De aquí comen `graphify query`, `path` y `explain`, y de aquí se derivan el HTML y el informe. |
| `GRAPH_REPORT.md` | **El archivo para leer.** Comunidades con sus miembros, *god nodes*, conexiones sorprendentes y las preguntas que este grafo puede responder. |
| `graph.html` | El grafo interactivo. Doble clic y se abre; no necesita servidor ni conexión. |
| `manifest.json` | Una fila por archivo (144) con su `mtime` y sus hashes. Es lo que hace posible `--update`. |
| `cost.json` | Tokens gastados, acumulados por pasada (1.341.585 en 5 pasadas; 733.642 en la última). |
| `cache/` | ~3,1 MB. `ast/` (una entrada por archivo de código) y `semantic/` (lo que el modelo sacó de los `.md`, que es lo que de verdad cuesta). Se invalida sola al cambiar el archivo, la versión de graphify o el prompt de extracción. |
| `.graphify_python` / `.graphify_root` | El intérprete con graphify y la carpeta escaneada. Llevan rutas de esta máquina. |
| `.graphify_labels.json` | El nombre de cada comunidad. |

### Cómo leer `graph.json`

Cada **nodo** lleva `id`, `label`, `file_type`, `source_file`, `source_location`, su
`community` con su `community_name`, y un `_origin`: `ast` (717, del árbol sintáctico,
determinista y sin coste) o `semantic` / vacío (319, lo leyó el modelo de la
documentación). Por tipo: 705 de código, 167 conceptos, 138 de **rationale** (el
*porqué* de una decisión) y 26 documentos.

Cada **arista** lleva `relation`, `weight`, el archivo de origen y su rastro de
auditoría: `EXTRACTED` (1.962, literal en el código o el texto), `INFERRED` (651, lo
dedujo el modelo, con `confidence_score`) y `AMBIGUOUS` (1, para revisar: el `README`
describe cómo se calcula el estado de un ajuste con varias claves, y `CLAUDE.md` prohíbe
agrupar claves en un ajuste). Relaciones más frecuentes: `references` (906), `calls`
(861), `contains` (585), `conceptually_related_to` (155), `implements` (38).

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

- **La extracción de documentos va en subagentes y gasta.** Sin clave de Gemini, los
  `.md` los lee el propio Claude, repartidos en trozos. La pasada del 2026-11-08 se cortó
  una vez por el límite de uso y hubo que retomar los trozos: si pasa, se reanudan y
  no hay que repetir el análisis del código.
- **Los archivos de datos salen casi sueltos.** `ui/Data/Categories/*.ps1`, `es.ps1` y las
  preferencias apenas tienen aristas: el análisis sintáctico no ve llamadas en una lista
  de `New-Setting`. Para buscar un ajuste o una clave, `grep`.
- **Las guías son contenido, no código.** `ui/Data/Guides/*.md` entra al grafo (comunidad
  "Contenido de las guías" y cinco de un solo nodo); sus conceptos son ajustes de Windows,
  no piezas del programa.
- **`cost.json` cuenta todo como entrada.** El host solo da un total por subagente, sin
  separar entrada de salida: las cifras son un suelo, no un total.
- **Esta carpeta está versionada a propósito.** La regla `graphify-out/` del
  `.gitignore` está comentada: se quiere el grafo en el repo.
- **OneDrive sincroniza esta ruta.** Unos 5,9 MB en muchos archivos pequeños.
