---
name: versionado
description: Confirmar y subir cambios de Optimizador PC. Úsalo cuando pidan guardar, versionar, confirmar o subir el trabajo - revisa qué cambió de verdad, verifica que el proyecto sigue en pie, prepara solo lo que toca y redacta el commit a partir del diff, no de la intención. Hay remoto público en GitHub - se confirma siempre en local y se sube solo si lo piden. Trigger words - commit, confirmar, versionar, guardar cambios, git, status, add, push, subir, remoto, historial, rama, branch, "sube los cambios".
---

# Versionado

Remoto `origin` en GitHub, **público**. **Confirma en local siempre; sube solo cuando
lo pidan.** **Solo se confirma cuando el usuario lo pide** — terminar una tarea no lo es.

## El flujo — 3 llamadas

### 1 · Estado, de una vez

```
pwsh -File .claude/skills/versionado/estado.ps1
```

Saca rama, upstream, `status`, si toca código, el `diff` completo y los últimos
commits. **No lo trocees** ni releas archivos que acabas de escribir. Lee el `diff`:
buscas archivos colados y restos de ediciones con `awk`/`sed` (un `<#` duplicado, un
bloque repetido). Los `??` son archivos nuevos: si no los escribiste tú en esta
sesión, ábrelos antes de añadirlos. Si el árbol **ya traía cambios al empezar la
sesión**, es trabajo ajeno: léelo entero y no lo mezcles con el tuyo.

### 2 · Verificar — solo si el paso 1 dice que hay `.ps1`/`.xaml` tocados desde la última vez que las suites salieron verdes

```
pwsh -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1 -BothHosts
```

Solo `.md`/`.claude/`/doc → sáltatelo. **Rojo → no confirmes**: arréglalo, o cuéntaselo
al usuario y dilo en el propio mensaje. El BOM lo pone el hook al escribir, no lo
compruebes a mano.

### 3 · Preparar y confirmar — una llamada por commit

```
git add <rutas> && git commit -F - <<'EOF'
Asunto en imperativo, sin punto final

Cuerpo: el porqué y lo decidido, no el qué. Solo lo que el diff no dice —
la razón o el problema, una alternativa descartada, lo que NO cambia, lo
que queda a medias o fuera, trabajo ajeno que arrastra.

Co-Authored-By: <de las instrucciones de ESTA sesión>
Claude-Session: <íd.>
EOF
```

`add` y `commit` en la MISMA llamada. Asunto en **español**, imperativo (*Añade*,
*Corrige*, *Reorganiza*). Atribución copiada de las instrucciones de esta sesión
(cambian; no la saques de un commit viejo).

## Cuántos commits

**Por defecto, UNO.** Si un cuerpo honesto explica el conjunto, es uno. Parte en
varios **solo** cuando hay trabajos de verdad independientes: una feature y un
refactor sin relación, o cambios que el usuario querrá revertir por separado. Un
cambio en `.claude/` que **modifica comportamiento** (hooks, permisos, un agente) va
aparte del código de la app; una línea de doc o de skill que solo **acompaña** a un
cambio de código va CON él. `git add` mueve archivos enteros: si dos trabajos tocaron
el mismo archivo, van juntos y el cuerpo lo explica. **Más de 2 commits para una
sesión normal = estás troceando de más.**

## Qué NO entra

| No confirmar | Por qué |
| --- | --- |
| `*.bak`, `*.tmp`, copias | Ruido; suele ser la versión rota |
| scratchpad, `%TEMP%` | No es del proyecto |
| credenciales, tokens, rutas personales | Nunca |
| `build/OptimizadorPC.exe` recién compilado | Solo si lo piden |
| `build/_combined.ps1` | Está en `.gitignore`, es un intermedio generado |
| algo que sabes roto | Fuera, y **dilo en el mensaje** |

Preparar: `git add <rutas concretas>`, o `git add -A`, o `git add -A -- ':(exclude).claude'`.

## Ramas

`master` es la de por defecto. Si el trabajo es más que un retoque y estás en
`master`, saca rama antes (`git checkout -b tipo/nombre`); si ya estás en una de
trabajo, sigue ahí. Confirmar directo sobre `master` se hace si lo pide: es su repo.

## Mover / renombrar

`mv` normal + `git add -A`; git detecta el renombrado. Un binario recompilado **no**
cuenta como renombrado (no comparte bytes con el anterior): es normal, dilo en el
cuerpo si viene al caso. Para código, si un mismo commit mueve y reescribe mucho,
separa el movimiento del cambio y se conserva el historial del archivo.

## Nunca

- `push` por tu cuenta — se sube cuando lo piden.
- `push --force`, `--amend`, `rebase` sobre lo ya subido — repo público, puede estar
  clonado. Prefiere un commit nuevo a `--amend`.
- `--no-verify` ni saltarse una comprobación porque estorba.
- `reset --hard`, `checkout -- <archivo>`, `clean` sobre trabajo del usuario —
  irreversible, ahí suele haber cosas sin guardar. Pregunta primero.
- Resumir un diff que no has leído.

`LF will be replaced by CRLF` es normal aquí (Windows + `autocrlf`): no es un error.

## Al terminar

Vuelve a lanzar el script del paso 1 (o `git log --oneline -3 && git status --short`).
Dile al usuario en dos líneas: qué commits quedaron, qué dejaste fuera y por qué, y el
comando de merge si sacaste rama:
`git checkout master && git merge --ff-only <rama>`. **No subas salvo que lo pidan.**
