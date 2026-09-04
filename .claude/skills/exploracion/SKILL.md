---
name: exploracion
description: Leer, buscar y revisar cambios en este repositorio sin gastar turnos de más. Úsalo al empezar cualquier tarea que necesite entender código existente, al buscar dónde vive algo, o al revisar un diff antes de confirmar. Dice qué se lee y qué no, cómo agrupar las llamadas para que vayan a la vez, y dónde está cada cosa para no tener que buscarla. Trigger words - leer, buscar, explorar, revisar, entender, diff, cambios, "dónde está", "cómo funciona", contexto.
---

# Leer y revisar sin perder el tiempo

El coste de una tarea aquí casi nunca es pensar: es **el número de turnos**. Cada
llamada a una herramienta es una espera, y si además necesita aprobación, una espera
larga. Este archivo va de gastar menos.

## 1. La regla que más ahorra: agrupar

**Las llamadas que no dependen unas de otras van en el MISMO turno.** Seis lecturas
para entender una zona son una tanda, no seis turnos.

```bash
# ✗ seis turnos: cada uno espera al anterior sin motivo
cat ui/Components/Shell/LogPanel.ps1
cat ui/Engine/Router.ps1
grep -rn "Show-LogPanel" ui/

# ✓ un turno: tres llamadas en paralelo, o una sola con todo dentro
for f in ui/Components/Shell/LogPanel.ps1 ui/Engine/Router.ps1; do echo "### $f"; cat "$f"; done
```

Solo se espera cuando **el resultado de una decide cuál es la siguiente**: leer un
archivo que te dijo un `grep`, editar algo que acabas de leer.

Regla práctica: antes de mandar una llamada, pregúntate qué más vas a necesitar sí o
sí. Si la respuesta es "también esto", va en la misma tanda.

## 2. Qué NO hace falta leer

| No leas | Por qué |
| --- | --- |
| `build/_combined.ps1` | Generado. Cualquier búsqueda debe excluirlo: `grep -rn "x" --include=*.ps1 . \| grep -v build/` |
| Un archivo que escribiste en esta sesión | Ya sabes lo que tiene. Releerlo para "confirmar" es un turno tirado |
| El árbol entero para un cambio de un archivo | `grep` con el nombre de la función basta |
| `CLAUDE.md` otra vez | Se carga solo en cada sesión, ya está en contexto |

Y al revés: **antes de crear un archivo nuevo, lee uno vecino**. Este proyecto tiene
un estilo muy marcado —cabecera que explica qué es y qué no, comentarios en español,
identificadores en inglés— y salir de él se nota más que cualquier otra cosa.

## 3. Dónde vive cada cosa

Esto está para **no tener que buscarlo**. Si lo que buscas encaja en una fila, ve
directo al archivo.

| Busco... | Está en |
| --- | --- |
| Colores, glifos, animaciones | `ui/Design/Theme.ps1` |
| Botones, píldoras, iconos genéricos | `ui/Design/UiKit.ps1` |
| Traducir, guardar preferencias, navegar | `ui/Engine/` |
| Qué secciones se ven y en qué orden | `ui/Index/CategoryIndex.ps1` |
| Qué hay en el menú lateral | `ui/Index/NavigationIndex.ps1` |
| Leer el registro de Windows | `core/Registry/` |
| El registro de actividad (el log) | `core/Diagnostics/Log.ps1` + `ui/Components/Shell/LogPanel.ps1` |
| Los textos en español | `ui/Data/Lang/es.ps1` |
| El marco de la ventana | `ui/Components/Shell/` |
| Las tarjetas | `ui/Components/Cards/` |
| Las pantallas | `ui/Views/` |
| Cómo se carga todo y en qué orden | `main.ps1` |

Las siete capas y sus reglas están en `CLAUDE.md`; el árbol completo, en `README.md`.

## 4. Buscar

```bash
# Dónde se usa algo (excluyendo siempre el generado)
grep -rn "Show-LogPanel" --include=*.ps1 --include=*.xaml . | grep -v build/

# Dónde se DEFINE
grep -rn "^function Show-LogPanel" --include=*.ps1 .

# Todas las funciones de un archivo, para hacerse el mapa sin leerlo entero
grep -n "^function " ui/Components/Shell/LogPanel.ps1
```

Ese último es el que más ahorra: en un archivo de 600 líneas te da el índice en una
línea por función y luego lees solo el trozo que importa con `sed -n '200,260p'`.

## 5. Revisar cambios antes de confirmar

Todo de una vez, en un turno:

```bash
git status --short && git diff --stat && git diff
```

Y luego **la parte que de verdad hay que leer con cuidado**: lo que tú no escribiste.

- **Lo que escribiste en esta sesión**: te basta el `--stat` para comprobar que no se
  ha colado nada raro, y una pasada rápida al diff buscando restos de las ediciones
  automáticas (un `<#` duplicado, una línea en blanco que se comió un `awk`, un
  bloque insertado dos veces). Esos restos son el fallo típico de editar con
  `awk`/`sed`, y el diff es el único sitio donde se ven.
- **Lo que ya estaba sin confirmar al empezar**: eso sí, entero. Es trabajo ajeno y
  puede que no debas confirmarlo.

Ver `versionado` para el resto del ciclo de confirmación.

## 6. Trampas de esta máquina que cuestan turnos

Aprendidas a base de perderlos:

- **No hay `python`.** El `python.exe` del PATH es el atajo de la Microsoft Store y
  falla. Para transformar archivos: `awk`, `sed`, `perl` o PowerShell.
- **Un heredoc de Bash colapsa `\\` a `\`**, y `sed` convierte `\t` en tabulador. Un
  JSON con rutas de Windows sale inválido y un `sed` con `.\tests\` mete un tabulador
  dentro del texto. Usa **barras normales**: PowerShell las acepta igual.
- **Si un heredoc falla al parsear**, no insistas cambiando comillas: escribe el
  archivo con la herramienta de escritura y sigue.
- **Un `awk` con anclas mal puestas borra en silencio.** Después de insertar o
  sustituir un bloque, comprueba el resultado en la misma llamada
  (`grep -n "^function " archivo`), no en la siguiente.
- **Editar `.claude/settings.local.json` está bloqueado** a propósito. No es una
  barrera que rodear: deja la versión corregida en el scratchpad y díselo al usuario.
