---
name: versionado
description: Confirmar cambios en el repositorio LOCAL de Optimizador PC. Úsalo cuando pidan guardar, versionar o confirmar el trabajo - revisa qué cambió de verdad, verifica que el proyecto sigue en pie, prepara solo lo que toca y redacta el commit a partir del diff, no de la intención. No hay remoto - nunca se hace push. Trigger words - commit, confirmar, versionar, guardar cambios, git, status, add, historial, rama, branch, "sube los cambios".
---

# Versionado — repositorio local

**Este repositorio no tiene remoto.** No existe `push`, ni `pull`, ni PRs, ni nada que
salga de la máquina. Si algo lo sugiere, es un error: dilo y para.

**Solo se confirma cuando el usuario lo pide.** Terminar una tarea no es motivo.

## La ruta rápida — tres turnos

Confirmar es una tarea pequeña y tiene que costar poco. Cuando **escribiste tú los
cambios en esta misma sesión**, que es el caso normal, son tres turnos:

```bash
# TURNO 1 — todo el estado de una vez
git status --short && git diff --stat && git diff
```

```bash
# TURNO 2 — verificar, SOLO si hace falta (ver abajo)
pwsh -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1 -BothHosts
```

```bash
# TURNO 3 — preparar y confirmar en la misma llamada, una por commit
git add <rutas> && git commit -F - <<'MSGEOF'
Asunto en imperativo, sin punto final

Cuerpo: por qué, no qué.

Co-Authored-By: ...
MSGEOF
```

Lo que **no** hay que hacer y alarga esto sin aportar nada:

- Preguntar el estado en tres llamadas (`status`, luego `diff --stat`, luego `diff`).
  Van encadenadas con `&&` en una.
- Separar `git add` de `git commit` en dos turnos.
- Comprobar ramas, divergencias o historial "por si acaso" antes de saber si hace
  falta. `git log --oneline -3` al final ya lo enseña.
- Releer archivos que acabas de escribir.

## Cuándo verificar, y cuándo no

Un commit rojo es peor que no tener commit. Pero repetir una verificación que ya
pasaste hace dos minutos tampoco vale nada. La pregunta es una sola:

> ¿He tocado código **después** de la última vez que las suites salieron verdes?

| Situación | Qué hacer |
| --- | --- |
| Las suites salieron verdes y no has tocado nada desde entonces | **Nada.** Confirma |
| Has tocado `.ps1` o `.xaml` desde entonces (aunque sea un comentario) | Las dos suites con `-BothHosts` |
| Solo has tocado `.md`, `.claude/` o documentación | **Nada.** No hay código que romper |
| Vienes de una sesión anterior o el árbol traía cambios ajenos | Las dos suites, y lee el diff entero |

Y una sola vez más: si tocaste **fuentes que entran al `.exe`**, regenera el paquete
antes de confirmar, o `build/_combined.ps1` se queda desfasado:

```bash
powershell -ExecutionPolicy Bypass -File ./build.ps1 -CombineOnly
```

El BOM ya no hay que comprobarlo a mano: lo deja puesto el hook
`.claude/hooks/Normalize-PsEncoding.ps1` al escribir, y hay una prueba que lo vigila.

**Si algo falla, no confirmes.** Arréglalo, o cuéntaselo al usuario para que decida si
quiere un punto intermedio — y entonces dilo en el propio mensaje.

## Leer el diff

**El mensaje sale de lo que el diff enseña, no de lo que creías haber hecho.**

Si escribiste tú los cambios, el `--stat` te dice si se ha colado un archivo que no
esperabas, y en el diff buscas sobre todo **restos de las ediciones automáticas**: un
`<#` duplicado, una línea en blanco que se comió un `awk`, un bloque insertado dos
veces. Es el fallo típico de editar con `awk`/`sed` y el diff es el único sitio donde
se ve.

Si el árbol **ya traía cambios sin confirmar al empezar la sesión**, eso léelo entero:
es trabajo ajeno y puede que no debas confirmarlo.

## Qué entra y qué no

```bash
git add -A                                    # todo
git add -A -- ':(exclude).claude'             # todo menos una carpeta
git add ui/Data/Categories/Regedit.ps1        # archivos concretos
```

| No confirmar | Por qué |
| --- | --- |
| `*.bak`, `*.tmp`, copias de seguridad | Ruido; suelen ser la versión **rota** de algo |
| Archivos del scratchpad o de `%TEMP%` | No son del proyecto |
| Credenciales, tokens, rutas con datos personales | Nunca, aunque el repo sea local |
| `OptimizadorPC.exe` recién compilado | Solo si el usuario lo pide |
| Un archivo que sabes que está roto | Déjalo fuera y **dilo en el mensaje** |

`build/_combined.ps1` **sí** va: es generado, pero ya está versionado y dejarlo atrás
haría que el árbol nunca estuviera limpio.

## Cuántos commits

**Varios cambios sin relación = varios commits.** El código de la aplicación y la
configuración de `.claude/` son siempre dos: se revisan y se revierten por separado.

Pero hay un límite práctico: `git add` prepara **archivos enteros**, no trozos. Si dos
trabajos distintos tocaron el mismo archivo —el diccionario de idiomas, la sonda de
cableado, `CLAUDE.md`— separarlos dejaría commits intermedios en rojo, y eso enmascara
dónde se rompió algo. En ese caso **van juntos, y el cuerpo del mensaje explica por
qué**. Un commit honesto que agrupa dos cosas es mejor que dos que mienten.

## Ramas

`master` es la rama por defecto. **Si el trabajo es más que un retoque, saca una rama
antes de confirmar**, salvo que ya estés en una de trabajo:

```bash
git checkout -b refactor/lo-que-sea
```

Al terminar, dile al usuario cómo llevarlo a `master` — sin divergencia es avance
rápido:

```bash
git checkout master && git merge --ff-only refactor/lo-que-sea
```

Si pide confirmar directo sobre `master`, se hace: es su repositorio.

## El mensaje

En **español**. Asunto en imperativo (*Reorganiza*, *Añade*, *Corrige*), sin punto
final, que quepa en una línea de terminal.

El cuerpo explica **por qué** y qué se decidió; el *qué* ya lo cuenta el diff. Escríbelo
cuando haya algo que el diff no puede decir:

- la razón del cambio o el problema que resuelve;
- una alternativa descartada y por qué;
- lo que **no** cambia (*"sin cambios de comportamiento"*);
- lo que quedó a medias, pendiente o fuera del commit;
- **trabajo ajeno que arrastra el commit**, si no se podía separar.

Al final, **las líneas de atribución que indique la sesión actual** (`Co-Authored-By:`
y `Claude-Session:`). Cópialas de las instrucciones de esta sesión — cambian, no las
saques de un commit viejo.

## Al mover o renombrar archivos

Mueve con `mv` normal y luego `git add -A`: git detecta el renombrado solo.
Compruébalo antes de dar el commit por bueno:

```bash
git show --stat --find-renames=40% HEAD | grep '=>'
```

Si sale como borrado + añadido en vez de `{ => Nueva }/Archivo.ps1`, el contenido
cambió demasiado en el mismo commit: **separa el movimiento del cambio de contenido**
y el historial de cada archivo se conserva.

## Cosas que no se hacen

- **Nada de `push`, `pull`, `fetch` ni remotos.** No hay ninguno.
- **Nada de `--no-verify`** ni de saltarse una comprobación porque estorba.
- **Nada de `git reset --hard`, `git checkout -- <archivo>` ni `git clean`** sobre
  trabajo del usuario. Son irreversibles y ahí suele haber cosas sin guardar. Si hace
  falta deshacer algo, pregunta primero.
- **Prefiere un commit nuevo a `--amend`.** Enmendar reescribe historia.
- **No inventes lo que hay en el diff.** Si no lo has leído, no lo resumas.

El aviso `LF will be replaced by CRLF` es normal aquí (Windows con `autocrlf`): no es
un error.

## Al terminar

```bash
git log --oneline -3 && git status --short
```

Y dile al usuario, en dos líneas: qué commits quedaron, **qué dejaste fuera y por
qué**, y el comando para llevar la rama a `master` si sacaste una.
