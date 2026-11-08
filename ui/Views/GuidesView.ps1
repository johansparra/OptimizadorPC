# ============================================================
# Vistas: sección Guías
#
#   Show-GuidesView   la lista: una tarjeta por guía (los .md de
#                     ui/Data/Guides, ver ui/Engine/GuideRegistry.ps1)
#   Show-GuideView    una guía abierta, para leer y copiar
#
# Solo ensamblan: las piezas están en ui/Components/Cards/GuideCard.ps1
# y el documento en ui/Components/Layout/MarkdownDocument.ps1.
# ============================================================

function Show-GuidesView {
    param($Window)

    Clear-PageHeader $Window
    Set-PageTitle -Window $Window `
        -Title (T 'Guides') `
        -Subtitle (T 'Your reference notes: open one to read it and copy what you need')

    $guides = @(Get-Guides)
    $list = New-Object System.Windows.Controls.StackPanel
    if ($guides.Count -eq 0) { $list.Children.Add((New-GuideEmptyState)) | Out-Null }
    foreach ($guide in $guides) {
        $list.Children.Add((New-GuideCard -Window $Window -Guide $guide)) | Out-Null
    }

    $Window.FindName('MainContent').Content = $list
    Start-StaggeredEnter $list
}

function Show-GuideView {
    param($Window, $Guide)

    Clear-PageHeader $Window

    # El icono y el color de la miga son los de la tarjeta; el título,
    # el de la guía tal cual (es texto del usuario: sin T).
    $look = [PSCustomObject]@{ Icon = 'Article'; Accent = 'Accent'; AccentSoft = 'AccentSoft'; Name = $Guide.Title }
    Set-PageBreadcrumb -Window $Window -Category $look -RootLabel 'Guides' `
        -BackView 'Show-GuidesView' -RawTitle $Guide.Title
    $doc = New-GuideDocument -Window $Window -Guide $Guide
    Add-PageAction $Window (New-GuideFindBox -Window $Window -DocumentBox $doc.Child)
    Add-PageAction $Window (New-GuideCopyButton -Window $Window -Guide $Guide)

    $Window.FindName('MainContent').Content = $doc
    Start-EnterTransition $doc 200 8
}
