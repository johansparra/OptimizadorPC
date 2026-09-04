---
name: versionado
description: Confirmar cambios en el repositorio LOCAL de Optimizador PC. Úsalo cuando pidan guardar, versionar o confirmar el trabajo - revisa qué cambió de verdad, verifica que el proyecto sigue en pie (pruebas en los dos hosts, BOM, empaquetado), prepara solo lo que toca y redacta el commit a partir del diff, no de la intención. No hay remoto - nunca se hace push. Trigger words - commit, confirmar, versionar, guardar cambios, git, status, add, historial, rama, branch, "sube los cambios".
---

# Versionado — repositorio local

**Este repositorio no tiene remoto.** No existe `push`, ni `pull`, ni PRs, ni nada que
salga de la máquina. Si algo lo sugiere, es un error: dilo y para.

Regla que manda sobre todo lo demás: **solo se confirma cuando el usuario lo pide.**
Terminar una tarea no es motivo para hacer un commit.

## El orden. No te lo saltes

```bash
# 1. QUÉ hay
git status --short
git diff --stat                    # sin preparar
git diff --cached --stat           # ya preparado, si lo hubiera

# 2. QUÉ dice ese cambio  (léelo de verdad, es de donde sale el mensaje)
git diff
```

**Antes de preparar nada, mira el diff completo.** El mensaje del commit se redacta a
partir de lo que el diff enseña, no de lo que creías haber hecho. Es habitual
encontrarse con más cosas de las que recordabas: un archivo tocado de paso, una
prueba que quedó a medias, un `.bak` que no pinta nada ahí.

### 3. Verificar que el proyecto sigue en pie

Un commit rojo es peor que no tener commit: enmascara dónde se rompió. Antes de
confirmar, **siempre**:

```bash
pwsh -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1 -BothHosts   # 5.1 y 7 a la vez
```

Y si el cambio toca archivos de código o el empaquetado:

```bash
# Ningún .ps1 sin BOM: en 5.1 el parser revienta (regla 3 de CLAUDE.md)
find ui core tests -name '*.ps1' -exec file {} \; | grep -v 'with BOM'   # debe salir vacío

# El paquete del .exe se arma y lleva todo dentro
powershell -ExecutionPolicy Bypass -File ./build.ps1 -CombineOnly
```

**Si algo falla, no confirmes.** Arréglalo o cuéntaselo al usuario; que decida él si
quiere guardar un punto intermedio, y entonces dilo en el propio mensaje.

### 4. Preparar solo lo que toca

```bash
git add -A                                    # todo
git add -A -- ':(exclude).claude'             # todo menos una carpeta
git add ui/Data/Categories/Regedit.ps1        # archivos concretos
```

Lo que **no** entra:

| No confirmar | Por qué |
| --- | --- |
| `*.bak`, `*.tmp`, copias de seguridad | Ruido; suelen ser la versión **rota** de algo |
| Archivos del scratchpad o de `%TEMP%` | No son del proyecto |
| Credenciales, tokens, rutas con datos personales | Nunca, aunque el repo sea local |
| `OptimizadorPC.exe` recién compilado | Solo si el usuario lo pide expresamente |

`build/_combined.ps1` **sí** va: es generado, pero ya está versionado y dejarlo atrás
haría que el árbol nunca estuviera limpio. Que no cuadre con las fuentes es señal de
que falta ejecutar `build.ps1`.

Comprueba lo preparado antes de escribir el mensaje:

```bash
git status --short          # las dos columnas: preparado | sin preparar
git diff --cached
```

### 5. Confirmar

`git commit -m "..."` vale para una línea. Para un mensaje con cuerpo —lo normal
aquí— usa un heredoc, que evita pelearse con las comillas:

```bash
git commit -F - <<'MSGEOF'
Asunto en imperativo, sin punto final

Cuerpo: por qué, no qué. El qué ya está en el diff.

Co-Authored-By: ...
MSGEOF
```

En PowerShell el equivalente es un aquí-string de comillas simples (`@'...'@`), con el
cierre pegado al margen izquierdo.

## Ramas

`master` es la rama por defecto y es la única que hay. **Si el trabajo es más que un
retoque, saca una rama antes de confirmar:**

```bash
git checkout -b refactor/lo-que-sea
```

Y al terminar dile al usuario cómo llevarlo a `master`, que al no haber divergido es
un avance rápido:

```bash
git checkout master && git merge --ff-only refactor/lo-que-sea
```

Si el usuario dice explícitamente que quiere confirmar directo sobre `master`, se
hace y ya está: es su repositorio.

## El mensaje

En **español**, como el resto del proyecto. Asunto en imperativo (*Reorganiza*,
*Añade*, *Corrige*), sin punto final, y que quepa en una línea de terminal.

El cuerpo explica **por qué** y qué se decidió; el *qué* ya lo cuenta el diff. Vale la
pena escribirlo cuando hay algo que el diff no puede decir:

- la razón del cambio, o el problema que resuelve;
- una alternativa que se descartó y por qué;
- lo que **no** cambia (*"sin cambios de comportamiento"*);
- lo que quedó a medias o pendiente;
- **trabajo ajeno que arrastra el commit.** Si el árbol ya tenía cambios sin confirmar
  que no son tuyos y no se pueden separar, dilo en el mensaje. Es la diferencia entre
  un historial honesto y uno que engaña.

Al final, **las líneas de atribución que indique la sesión actual** (`Co-Authored-By:`
y `Claude-Session:`). Cópialas de las instrucciones de esta sesión — cambian, no las
saques de un commit viejo.

**Varios cambios sin relación = varios commits.** Si el trabajo toca el código de la
aplicación y además la configuración de `.claude/`, son dos commits: se revisan y se
revierten por separado. Prepara y confirma uno, luego el otro.

## Al mover o renombrar archivos

Mueve con `mv` normal y luego `git add -A`: git detecta el renombrado al comparar, no
hace falta `git mv`. Compruébalo antes de dar el commit por bueno:

```bash
git show --stat --find-renames=40% HEAD | grep '=>'
```

Si salen como borrado + añadido en vez de `{ => Nueva }/Archivo.ps1`, es que el
contenido cambió demasiado en el mismo commit. **Separa el movimiento del cambio de
contenido en dos commits** y el historial de cada archivo se conserva.

## Cosas que no se hacen

- **Nada de `push`, `pull`, `fetch` ni remotos.** No hay ninguno.
- **Nada de `--no-verify`** ni de saltarse una comprobación porque estorba.
- **Nada de `git reset --hard`, `git checkout -- <archivo>` ni `git clean`** sobre
  trabajo del usuario. Son irreversibles y ahí suele haber cosas sin guardar. Si hace
  falta deshacer algo, pregunta primero.
- **Prefiere un commit nuevo a `--amend`.** Enmendar reescribe historia; solo si el
  usuario lo pide.
- **No inventes lo que hay en el diff.** Si no lo has leído, no lo resumas.

El aviso `LF will be replaced by CRLF` es normal en este repositorio (Windows con
`autocrlf`): no es un error y no hay que hacer nada.

## Al terminar

Enseña al usuario lo que quedó, en tres líneas:

```bash
git log --oneline -3
git status --short          # debería estar limpio, salvo lo que dejaste fuera a propósito
```

Y dile **qué dejaste sin confirmar y por qué** (ese `.bak`, ese `.exe`), más el
comando para llevar la rama a `master` si sacaste una.
