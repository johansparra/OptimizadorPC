# ============================================================
# ui/Data/AppInfo.ps1
# Quién es el programa: nombre, versión, descripción y dónde vive.
#
# ES LA ÚNICA FUENTE DE LA VERSIÓN. La leen:
#   - la insignia de la barra de título (Update-TitleBarTexts)
#   - el panel "Acerca de" del botón ? (ui/Components/Shell/AboutMenu.ps1)
#   - build.ps1, que la escribe en los metadatos del .exe
#     (Propiedades > Detalles en el Explorador)
#
# Subir de versión es cambiar Version aquí y recompilar. Se sigue
# versionado semántico: MAYOR.MENOR.PARCHE -cambio incompatible,
# función nueva, arreglo-. El .exe pide cuatro números; build.ps1
# añade el cuarto.
#
# Solo declaraciones: este archivo lo lee también build.ps1 con un
# punto, fuera de la aplicación, así que no puede llamar a nada.
# ============================================================

$AppInfo = @{
    Name        = 'Optimizador PC'
    Version     = '1.1.0'
    Description = 'Windows 11 tweaks for performance, gaming and privacy. Every change shows the registry key it touches and can be turned back off.'
    Repository  = 'https://github.com/johansparra/OptimizadorPC'
}

function Get-AppInfo { $AppInfo }
