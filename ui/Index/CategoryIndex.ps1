# ============================================================
# CategoryIndex.ps1
#
#   *** ESTE ES EL ARCHIVO PRINCIPAL DE LAS SECCIONES ***
#
# Manda sobre qué secciones se ven, en qué orden y cuáles están
# bloqueadas. El contenido de cada una sigue viviendo en su
# propio archivo dentro de ui/Data/Categories/.
#
#   ORDEN      El de esta lista, de arriba abajo.
#              Mover una sección = mover su línea.
#
#   Visible    $true  -> se muestra
#              $false -> se oculta por completo (sigue en el
#                        disco, no se pierde nada)
#
#   Locked     $false -> normal
#              $true  -> se muestra con un candado y se puede
#                        abrir, pero sus ajustes salen en gris
#                        y no se pueden tocar
#
# Quitar una sección de la lista NO borra su archivo: si la
# comentas con # deja de aparecer, y la recuperas quitando el #.
#
# Una sección que exista en ui/Data/Categories/ pero no esté aquí se
# añade al final, visible y desbloqueada.
# ============================================================

$CategoryIndex = @(

    #  Id                    Visible          Bloqueada
    @{ Id = 'regedit';       Visible = $true;  Locked = $false }
    @{ Id = 'power';         Visible = $true;  Locked = $false }
    @{ Id = 'gaming';        Visible = $true;  Locked = $false }
    @{ Id = 'update';        Visible = $true;  Locked = $false }
    @{ Id = 'notifications'; Visible = $true;  Locked = $false }
    @{ Id = 'sound';         Visible = $true;  Locked = $false }

)
