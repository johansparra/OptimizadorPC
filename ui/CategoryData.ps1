# ============================================================
# CategoryData.ps1
# Datos de las categorías del menú principal y de sus ítems de
# detalle. Solo datos: la UI se construye en ui/Views/*.
# El icono de cada categoría NO vive aquí: lo asigna $CategoryLook
# en ui/Views/OptimizationsListView.ps1 (fuente Segoe Fluent Icons).
# ============================================================

function Get-OptimizationCategories {

    @(
        [PSCustomObject]@{
            Id = 'privacy'; Name = 'Privacy & Security'
            Badge = 'NEW 45'
            Description = 'Security, Content Delivery & Advertising, Lock Screen, General, ...'
            Recommended = 29; Default = 59; Custom = 0; Total = 88
            Items = @(
                [PSCustomObject]@{ Name='User Account Control Level'; Description='Controls UAC notification level and secure desktop behavior'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('Always notify','Notify when apps try to make changes','Notify me only (no dim)','Never notify'); Value='Notify when apps try to make changes' }
                [PSCustomObject]@{ Name='Workplace Join Message Prompts'; Description="Show 'Allow my organization to manage my device' prompts throughout Windows"; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='BitLocker Auto Encryption'; Description='Controls whether Windows can automatically encrypt drives with BitLocker. Has no effect if BitLocker encryption is already active on your device'; Tags=@('Preference','Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='WiFi-Sense'; Description='Allow sharing WiFi passwords with contacts and automatically connecting to suggested open hotspots'; Tags=@('Recommended','Custom'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='Automatic Maintenance'; Description='Choose if Windows should run automatic system maintenance tasks during idle time'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Windows Error Reporting'; Description='Choose if Windows should collect and send crash reports and error information to Microsoft'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'power'; Name = 'Power'
            Badge = $null
            Description = 'Display, Hard Disk, Internet Explorer, Desktop Background Settings, ...'
            Recommended = 18; Default = 23; Custom = 2; Total = 34
            Items = @(
                [PSCustomObject]@{ Name='High Performance Power Plan'; Description='Switch to the High Performance / Ultimate Performance power scheme'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='USB Selective Suspend'; Description='Allow Windows to power down idle USB devices to save energy'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Hibernation'; Description='Enable or disable hibernate mode and the hiberfil.sys reserved space'; Tags=@('Preference','Default'); Type='Toggle'; Value=$true }
            )
        }
        [PSCustomObject]@{
            Id = 'gaming'; Name = 'Gaming & Performance'
            Badge = 'NEW 16'
            Description = 'Processor, Graphics, Network, Security, ...'
            Recommended = 65; Default = 47; Custom = 2; Total = 112
            Items = @(
                [PSCustomObject]@{ Name='Game Mode'; Description='Optimize your PC for play by turning things off in the background'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$true }
                [PSCustomObject]@{ Name='Enhance Pointer Precision'; Description='Adjust cursor speed based on movement velocity (mouse acceleration). Most competitive gamers disable this for consistent aiming in FPS games'; Tags=@('Preference','Recommended'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Mouse Hover Time'; Description='Controls how long you must hover over an element before it activates (in milliseconds). Lower values make tooltips, menus, and hover effects appear faster. Default is 400ms'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('100ms','200ms','400ms (Default)','600ms'); Value='400ms (Default)'; Badge='NEW' }
                [PSCustomObject]@{ Name='Startup Delay for Apps'; Description='Delay startup applications by 10 seconds after boot to improve initial system responsiveness. Windows becomes usable faster, but your startup apps take longer to load'; Tags=@('Preference','Recommended','Default','Custom'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Background App Permissions'; Description='Control whether apps can run in the background via Group Policy. Force Deny removes per-app background settings from Windows Settings. Use User in Control if you need apps like Teams, Zoom, or WhatsApp'; Tags=@('Preference','Recommended','Default','Custom'); Type='Dropdown'; Options=@('User in Control','Force Allow','Force Deny'); Value='Force Deny'; Badge='NEW' }
            )
        }
        [PSCustomObject]@{
            Id = 'update'; Name = 'Update'
            Badge = 'NEW 1'
            Description = 'Update Policy, Delivery & Store, Update Behavior'
            Recommended = 5; Default = 8; Custom = 1; Total = 12
            Items = @(
                [PSCustomObject]@{ Name='Delivery Optimization (P2P)'; Description='Allow Windows to download/upload updates to and from other PCs on the internet'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Auto-Restart With Active Sessions'; Description='Allow Windows Update to restart the PC automatically while you are logged in'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'notifications'; Name = 'Notifications'
            Badge = $null
            Description = 'Additional Settings, System Notifications, Privacy Notifications, Security Notifications'
            Recommended = 7; Default = 9; Custom = 0; Total = 15
            Items = @(
                [PSCustomObject]@{ Name='Windows Tips & Suggestions'; Description='Show occasional tips, tricks, and suggestions as you use Windows'; Tags=@('Recommended','Default'); Type='Toggle'; Value=$false }
                [PSCustomObject]@{ Name='Lock Screen Suggestions'; Description='Show fun facts, tips, and other suggestions on the lock screen'; Tags=@('Recommended','Default','Custom'); Type='Toggle'; Value=$false }
            )
        }
        [PSCustomObject]@{
            Id = 'sound'; Name = 'Sound'
            Badge = $null
            Description = 'System Sounds'
            Recommended = 0; Default = 7; Custom = 0; Total = 7
            Items = @(
                [PSCustomObject]@{ Name='Startup Sound'; Description='Play the Windows startup sound when signing in'; Tags=@('Default'); Type='Toggle'; Value=$true }
            )
        }
    )
}
