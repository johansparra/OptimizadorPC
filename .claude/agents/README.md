# Equipo de agentes — Optimizador PC

Tres roles con memoria propia y herramientas distintas. Se lanzan **solo cuando tú lo
pides**: Claude no los invoca por su cuenta.

| Agente | Herramientas | Para qué |
| --- | --- | --- |
| **`arquitecto`** | solo lectura | Decidir **dónde va** algo y con qué contrato. Entrega un *Plan de cambio*. |
| **`dev`** | lectura + escritura + shell | Implementar el plan. Entrega un *Parte de trabajo*. |
| **`tester`** | lectura + escritura + shell | Verificar y escribir pruebas. Entrega un *Informe de verificación*. |

## Cómo se lanzan

Pídelo en lenguaje normal, nombrando el agente:

```
usa el agente arquitecto para diseñar la sección de red (TCP, Nagle, DNS, adaptador)
usa el agente dev para implementar ese plan
usa el agente tester para verificar lo que acaba de hacer el dev
```

También en paralelo, cuando las tareas no chocan:

```
lanza en paralelo: el arquitecto que diseñe la sección de servicios,
y el tester que audite qué zonas de core/ están sin cubrir
```

## El circuito

```
      ┌──────────────┐   Plan de cambio    ┌─────┐   Parte de trabajo   ┌────────┐
 idea │  arquitecto  │ ──────────────────► │ dev │ ───────────────────► │ tester │
      └──────────────┘                     └─────┘                      └────────┘
             ▲                                                               │
             └───────────── Informe de verificación (si falla) ──────────────┘
```

Cada paso entrega un documento con formato fijo, definido en el archivo del agente.
El siguiente **empieza leyendo ese documento**, no volviendo a decidir desde cero.

## Reglas del equipo

1. **Secuencial sobre los mismos archivos.** `dev` y `tester` nunca escriben a la vez
   en la misma zona: se pisan. En paralelo solo tareas que no comparten archivos.
2. **El arquitecto no escribe código y el tester no lo arregla.** Si el tester
   encuentra un fallo, lo reproduce y lo describe; arreglarlo es del `dev`. Mezclar
   los roles es perder la ventaja de tenerlos separados.
3. **Nadie cierra una tarea sin las dos suites verdes.**
   ```
   pwsh -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1 -BothHosts   # 5.1 y 7 a la vez
   ```
4. **Un agente que se queda sin contexto no vuelve a empezar.** Pídele el documento de
   entrega y pásaselo al siguiente.
5. **Los agentes no ven esta conversación.** Arrancan en frío: dales el objetivo
   completo, no una referencia a algo que dijiste antes.

## Cuándo delegar, y cuándo no

Un agente arranca **en frío**: no ve esta conversación y tiene que releer `CLAUDE.md`,
los índices y el código antes de empezar. Eso cuesta tiempo y contexto, así que la
cuenta solo sale a favor cuando hay trabajo suficiente para amortizarlo.

| Situación | Qué sale más barato |
| --- | --- |
| Un archivo, una capa, un cambio localizado | Hacerlo en la conversación |
| Varios archivos y varias capas, pero un solo frente | Hacerlo en la conversación, leyendo en paralelo |
| **Dos o más frentes que no comparten archivos** | Un agente por frente, **lanzados a la vez** |
| Algo largo que ensuciaría el hilo (una auditoría, un barrido) | Un agente, aunque sea uno solo |

**Para que corran en paralelo hay que pedirlos en el MISMO mensaje.** Uno por mensaje
se ejecutan en fila: se paga el arranque en frío de los dos y encima se espera dos
veces.

Antes de delegar nada, lo que casi siempre sobra: **agrupar en un mismo turno las
llamadas que no dependen unas de otras**. Seis lecturas a la vez no necesitan agente,
y las dos suites ya van juntas con `-BothHosts`.

## Skills que cargan

Los agentes son **roles**; el conocimiento vive en `.claude/skills/` y lo cargan según
lo que toquen:

| Skill | Lo carga | Cubre |
| --- | --- | --- |
| `powershell-engineer` | dev, tester | Trampas del lenguaje y los dos hosts |
| `powershell-best-practices` | dev | Cómo se escribe una función bien; `ShouldProcess`, idempotencia |
| `windows-desktop-architect` | arquitecto, dev | Capas, recetas y trampas de WPF |
| `refactoring-agent` | dev | Mover, renombrar y eliminar sin dejar restos |
| `security-reviewer` | arquitecto, dev | Aplicación elevada, escrituras al registro, tweaks que bajan la seguridad |
| `versionado` | dev | Confirmar en el repositorio local: verificar, preparar y redactar el commit |

Si cambias una regla del proyecto, cámbiala en el **skill**, no en los tres agentes.

## Lo demás que hay en `.claude/`

| Ruta | Qué es |
| --- | --- |
| `agents/` | Los tres roles de arriba. |
| `skills/` | El conocimiento que cargan. Si cambia una regla del proyecto, cámbiala **aquí**, no en los tres agentes. |
| `hooks/Normalize-PsEncoding.ps1` | Deja todo `.ps1` y `.xaml` en UTF-8 con BOM y CRLF nada más escribirlo (regla 3 de `CLAUDE.md`). Enganchado como `PostToolUse` sobre las escrituras. |
| `settings.local.json` | Permisos y hooks. **Es el freno principal de la velocidad**: un comando que no esté en `allow` detiene la sesión hasta que alguien lo apruebe. Si algo de solo lectura se repite, su sitio es esa lista. |
