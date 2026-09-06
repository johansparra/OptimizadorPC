# graphify-out/

**Todo lo que hay aquí lo genera [graphify](https://github.com/safishamsi/graphify) — no se
edita a mano.** Se rehace entero con `/graphify .` desde la raíz del proyecto, así que
borrar la carpeta no pierde nada salvo el tiempo de recálculo.

Qué es: un **grafo de conocimiento** del proyecto. Leyó los 87 archivos de
`OptimizadorPC/` (73 de código —`.ps1`, `.xaml`, `.json`— y 14 de documentación) y sacó
de ellos quién llama a quién, qué concepto vive en qué archivo y qué grupos de cosas se
mueven juntas. Sirve para **preguntarle al repositorio en vez de leerlo entero**.

## Lo que salió de la primera pasada

| | |
| --- | --- |
| Nodos | **673** — 434 del análisis sintáctico del código, 239 de la lectura de la documentación |
| Aristas | **1.355** · 9 hiperaristas (grupos de 3+ nodos que participan en lo mismo) |
| Comunidades | **52**, etiquetadas a mano ("Buscador global", "Lectura real del registro"...) |
| Construido sobre | el commit `1292968` |

> **DESFASADO (2026-09-06).** El grafo se construyó sobre `1292968`, que a día de hoy
> está **17 commits por detrás de `master`**. No conoce la escritura real al registro
> (`core/Registry/Writer.ps1`, `SettingApply.ps1`), la CI de Semgrep, el `.gitignore`,
> `SECURITY.md` ni `tests/Source/Security.Tests.ps1`, y su informe cita ajustes de UAC
> y BitLocker que ya se retiraron de `Regedit.ps1`. Para ponerlo al día:
> `/graphify . --update` (incremental, usa `manifest.json`).

## Lo que se queda

| Archivo | Tamaño | Qué es |
| ------- | -----: | ------ |
| `graph.json` | 791 KB | **El grafo.** Formato *node-link* de NetworkX: `nodes` y `links` (ojo, no `edges`). Es de donde comen `graphify query`, `path` y `explain`, y de donde se derivan el HTML y el informe. Guarda además `built_at_commit`, así que el grafo sabe de qué commit salió. |
| `GRAPH_REPORT.md` | 17 KB | **El archivo para leer.** Las 52 comunidades con sus miembros, los *god nodes* (lo que toca todo), las conexiones sorprendentes, los ciclos de importación y las preguntas que este grafo está en posición de responder. |
| `graph.html` | 625 KB | El grafo interactivo. Doble clic y se abre; no necesita servidor ni conexión. |
| `manifest.json` | 19 KB | Una fila por archivo (87) con su `mtime`, su `ast_hash` y su `semantic_hash`. Es lo que hace posible `--update`: sin esto, cada pasada volvería a extraerlo todo. |
| `cost.json` | 226 B | Los tokens gastados, acumulados por ejecución. |
| `cache/` | 87 archivos · 0,7 MB | La caché de extracción: `ast/` (una entrada por archivo de código; recalcular es gratis pero lento) y `semantic/` (lo que el modelo sacó de los `.md`, que es lo que de verdad cuesta). Se invalida sola al cambiar el archivo de origen, al actualizar graphify o al cambiar el prompt de extracción. |
| `.graphify_python` | 68 B | Ruta del intérprete de Python que tiene graphify instalado, para que los pasos siguientes no vuelvan a buscarlo. |
| `.graphify_root` | 53 B | La carpeta que se escaneó, para que `graphify update` sin argumentos sepa dónde mirar. |
| `.graphify_labels.json` | 1,8 KB | Los nombres en cristiano de cada comunidad. Los pone el modelo al final; el export `--wiki` los reutiliza. |

### Cómo leer `graph.json`

Cada **nodo** lleva `id`, `label`, `file_type`, `source_file`, `source_location`, a qué
`community` pertenece con su `community_name`, y un `_origin` que dice **de dónde salió**:

| `_origin` | Cuántos | Qué significa |
| --------- | ------: | ------------- |
| `ast` | 434 | Lo sacó el árbol sintáctico (tree-sitter, con gramática de PowerShell). Determinista, sin modelo, sin coste. |
| *(vacío)* | 239 | Lo leyó el modelo de la documentación. |

Y por tipo: 438 de código, 135 de **rationale** (el *porqué* de una decisión), 81 conceptos
y 19 documentos.

Cada **arista** lleva `relation`, `weight`, de qué archivo salió — y sobre todo su
**rastro de auditoría**, que es lo que separa a graphify de un diagrama bonito:

| `confidence` | Cuántas | Qué quiere decir |
| ------------ | ------: | ---------------- |
| `EXTRACTED` | 872 | Está literalmente en el código o el texto: una llamada, una cita, un "ver §3". |
| `INFERRED` | 480 | Lo dedujo el modelo. Trae `confidence_score` (0,55 a 0,95) para saber cuánto fiarse. |
| `AMBIGUOUS` | 3 | El modelo dudó y **lo dejó marcado en vez de tirarlo**. Son las tres primeras preguntas del informe. |

Las relaciones más frecuentes: `calls` (594), `contains` (347), `references` (282),
`conceptually_related_to` (53), `semantically_similar_to` (39).

## Lo que debería haber desaparecido

Archivos de trabajo de una sola pasada. Se regeneran solos en la siguiente ejecución.
**Borrados el 2026-09-06** (`.graphify_detect.json`, `.graphify_ast.json`,
`.graphify_chunk_01..03.json`, `.graphify_uncached.txt`, `.graphify_semantic.json`,
`.graphify_semantic_new.json`, `.graphify_extract.json`, `.graphify_analysis.json`).
Si `/graphify` los vuelve a dejar, se pueden borrar a mano sin perder nada.

| Archivo | Para qué sirvió |
| ------- | --------------- |
| `.graphify_detect.json` | El inventario: qué archivos hay y de qué tipo. |
| `.graphify_ast.json` | Extracción **estructural** del código, la barata. |
| `.graphify_chunk_01..03.json` | Un archivo por subagente. La extracción **semántica** de los 14 `.md` se repartió en tres tandas que corrieron a la vez. |
| `.graphify_uncached.txt` | Qué hacía falta extraer y qué se pudo reaprovechar de `cache/`. |
| `.graphify_semantic.json` / `_new.json` | Las tres tandas ya juntas. |
| `.graphify_extract.json` | Estructural + semántico fundidos. Es la entrada del grafo. |
| `.graphify_analysis.json` | Comunidades, cohesión, *god nodes* y conexiones sorprendentes, antes de ponerles nombre. |

## Cómo se rehace

```powershell
/graphify .                 # todo de nuevo
/graphify . --update        # solo lo que haya cambiado (usa manifest.json)
/graphify . --cluster-only  # reagrupa sin volver a extraer
/graphify query "¿por qué T() conecta seis comunidades?"
/graphify path "LogPanel.ps1" "Reader.ps1"
/graphify explain "Update-LogList"
```

## Cuatro avisos

- **`cost.json` dice 235.269 tokens de entrada y 0 de salida, y no es verdad del todo.**
  El host solo publica un total combinado por subagente, sin separar entrada de salida,
  así que todo se anotó como entrada. Además el tercer subagente murió por el límite de
  sesión justo después de escribir su resultado, así que **sus tokens no están contados**.
  El trabajo sí está completo; la cifra es un suelo, no un total.
- **El informe trae un aviso de salud del grafo**: 1 arista colgante y 2 colapsadas. Son
  dos nodos unidos a la vez por `references` y `semantically_similar_to` —una duplicación
  real entre dos skills—, no una corrupción.
- **Esta carpeta está versionada a propósito.** El proyecto ya tiene `.gitignore`
  (desde el commit `6e5df0f`) y la regla `graphify-out/` está ahí **comentada**: se
  quiere el grafo en el repo. Se regenera con `/graphify . --update` tras tocar código.
- **OneDrive sincroniza esta ruta.** Son ~2,5 MB en muchos archivos pequeños (`cache/`
  incluido). Ignorarla en git no la saca de la sincronización.
