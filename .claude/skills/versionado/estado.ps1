# estado.ps1 - todo lo necesario para decidir un commit, en UNA llamada.
#   pwsh -File .claude/skills/versionado/estado.ps1
#
# Sustituye a: status + diff --stat + diff + log + "-toca codigo?" + rama.
# No lo trocees en varias llamadas.

$ErrorActionPreference = 'Continue'

'== rama / upstream =='
git --no-pager status -sb | Select-Object -First 1
''
'== cambios (incluye archivos nuevos ??) =='
git --no-pager status --short
''
# Solo cuenta el codigo de la app: .claude/ y tests de skills no pasan por las suites.
$nuevos  = @(git --no-pager ls-files --others --exclude-standard -- '*.ps1' '*.xaml')
$tocados = @(git --no-pager diff --name-only HEAD -- '*.ps1' '*.xaml' '*.psm1' '*.psd1')
$codigo  = @($tocados + $nuevos | Where-Object { $_ -and $_ -notlike '.claude/*' } | Sort-Object -Unique)
if ($codigo.Count) {
    '== TOCA CODIGO -> pasa las suites -BothHosts si no lo hiciste tras el ultimo cambio =='
    $codigo
} else {
    '== no toca codigo (.ps1/.xaml): NO hace falta verificar =='
}
''
'== diff --stat (HEAD .. arbol) =='
git --no-pager diff --stat HEAD
''
'== diff COMPLETO -- leelo: archivos colados, restos de awk/sed, bloques repetidos =='
git --no-pager diff HEAD
''
'== ultimos commits =='
git --no-pager log --oneline -5
