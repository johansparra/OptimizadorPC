# ============================================================
# Componente: fondo vivo
#
# Las manchas de color que se mueven muy despacio detrás del
# contenido. Es lo que separa una interfaz "plana" de una que
# parece tener profundidad, y no cuesta ni un control más: son
# tres elipses en el Canvas llamado Backdrop de MainWindow.xaml.
#
# TRES DECISIONES QUE CONVIENE NO DESHACER
#
#   Sin BlurEffect. La mancha se difumina sola porque su relleno
#   es un degradado RADIAL que acaba en transparente (Glow1Brush
#   y compañía, en ui/Design/Theme.ps1). Un desenfoque de 150px
#   sobre media pantalla es de lo más caro que se le puede pedir
#   a WPF; un degradado es gratis.
#
#   A 20 fotogramas por segundo, no a 60. El recorrido dura medio
#   minuto: a esa velocidad nadie distingue 20 de 60, y la
#   diferencia es tener o no tener la máquina repintando la
#   ventana entera sin parar. En un programa que se llama
#   Optimizador PC eso no es un detalle.
#
#   El lienzo es sordo al ratón (IsHitTestVisible="False" en el
#   XAML). Si no, se comería los clics de las tarjetas.
#
# Las posiciones van en tanto por uno del lienzo, así que se
# recolocan solas al maximizar la ventana; el vaivén, en cambio,
# va en píxeles y no depende del tamaño.
# ============================================================

# Cada mancha: su pincel del tema, su tamaño, dónde vive (0..1 del
# lienzo) y cuánto se mueve. Las duraciones son números primos
# entre sí a ojo para que no vuelvan a coincidir nunca y el
# movimiento no se note repetido.
$BackdropBlobs = @(
    @{ Fill = 'Glow1Brush'; Size = 760; X = 0.74; Y = 0.02; DriftX =  70; DriftY =  55; Ms = 27000 }
    @{ Fill = 'Glow2Brush'; Size = 640; X = 0.06; Y = 0.62; DriftX =  60; DriftY = -75; Ms = 34000 }
    @{ Fill = 'Glow3Brush'; Size = 520; X = 0.46; Y = 0.95; DriftX = -80; DriftY =  50; Ms = 41000 }
)

$BackdropFrameRate = 20

function Build-Backdrop {
    param($Window)

    $canvas = $Window.FindName('Backdrop')
    if (-not $canvas) { return }

    $canvas.Children.Clear()

    foreach ($blob in $BackdropBlobs) {
        $ellipse = New-Object System.Windows.Shapes.Ellipse
        $ellipse.Width  = $blob.Size
        $ellipse.Height = $blob.Size
        $ellipse.IsHitTestVisible = $false

        # El relleno de una figura NO es la Background de un Border:
        # son propiedades distintas, de ahí Set-ShapeFill.
        Set-ShapeFill $ellipse $blob.Fill

        $drift = New-Object System.Windows.Media.TranslateTransform
        $ellipse.RenderTransform = $drift

        # La receta viaja en el Tag: la posición depende del tamaño
        # del lienzo, que todavía no se conoce (nada de closures,
        # regla 4).
        $ellipse.Tag = $blob
        $canvas.Children.Add($ellipse) | Out-Null

        Start-BlobDrift $drift $blob
    }

    Set-BackdropLayout $canvas

    # El lienzo no tiene tamaño hasta que WPF lo mide, y cambia al
    # maximizar. Se ata UNA vez: Build-Backdrop puede volver a
    # llamarse y un segundo manejador dejaría el trabajo hecho dos
    # veces por cada píxel de ancho.
    if ($canvas.Uid -ne 'wired') {
        $canvas.Uid = 'wired'
        $canvas.Add_SizeChanged({ param($s, $e) Set-BackdropLayout $s })
    }
}

# Coloca cada mancha en su sitio a partir del tamaño real del
# lienzo. Sin medidas todavía no hay nada que colocar: se sale y ya
# volverá el SizeChanged.
function Set-BackdropLayout {
    param($Canvas)

    $width  = $Canvas.ActualWidth
    $height = $Canvas.ActualHeight
    if ($width -le 0 -or $height -le 0) { return }

    foreach ($ellipse in $Canvas.Children) {
        $blob = $ellipse.Tag
        if (-not $blob) { continue }

        # Restar medio diámetro deja el CENTRO de la mancha en la
        # coordenada declarada, que es como se piensa en ellas.
        [System.Windows.Controls.Canvas]::SetLeft($ellipse, ($width  * $blob.X) - ($blob.Size / 2))
        [System.Windows.Controls.Canvas]::SetTop( $ellipse, ($height * $blob.Y) - ($blob.Size / 2))
    }
}

# El vaivén. X e Y tienen duraciones distintas a propósito: con la
# misma el recorrido sería una diagonal de ida y vuelta, y con
# duraciones dispares es una curva que tarda muchísimo en repetirse.
function Start-BlobDrift {
    param($Transform, $Blob)

    $Transform.BeginAnimation(
        [System.Windows.Media.TranslateTransform]::XProperty,
        (New-BlobAnim (-$Blob.DriftX) $Blob.DriftX $Blob.Ms))

    $Transform.BeginAnimation(
        [System.Windows.Media.TranslateTransform]::YProperty,
        (New-BlobAnim (-$Blob.DriftY) $Blob.DriftY ([int]($Blob.Ms * 1.37))))
}

function New-BlobAnim {
    param([double]$From, [double]$To, [int]$Ms)

    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
    $anim.From = $From
    $anim.To   = $To
    $anim.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
    $anim.AutoReverse = $true
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $anim.EasingFunction = New-Ease -Mode 'EaseInOut'

    # Ver la cabecera: 20 fps en vez de 60.
    [System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($anim, $BackdropFrameRate)

    $anim
}
