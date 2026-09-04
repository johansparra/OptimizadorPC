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
   powershell -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1
   pwsh       -ExecutionPolicy Bypass -File ./tests/Run-Tests.ps1
   ```
4. **Un agente que se queda sin contexto no vuelve a empezar.** Pídele el documento de
   entrega y pásaselo al siguiente.
5. **Los agentes no ven esta conversación.** Arrancan en frío: dales el objetivo
   completo, no una referencia a algo que dijiste antes.

## Cuándo NO usar un agente

Un agente arranca sin contexto y tiene que redescubrir el proyecto. Para un cambio de
dos líneas cuesta más de lo que ahorra. Úsalos cuando haya **varios archivos y varias
capas** de por medio, o cuando quieras el trabajo aislado de la conversación principal.

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

Si cambias una regla del proyecto, cámbiala en el **skill**, no en los tres agentes.
