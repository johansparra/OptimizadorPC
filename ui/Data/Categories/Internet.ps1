# ============================================================
# Categoría: Internet
#
# NO es una sección de ajustes: es una lista de COMANDOS que se
# ejecutan. Sale de Reiniciar_Red_v3.cmd, un comando por paso y en
# el mismo orden. El usuario marca los que quiere y los corre con un
# botón; la pantalla es ui/Views/CategoryStepsView.ps1.
#
# EL ORDEN DE ESTA LISTA ES EL ORDEN DE EJECUCIÓN. Da igual lo que
# se marque: los pasos marcados corren siempre de arriba abajo. Así
# lo pedía el .cmd -primero se limpia la pila, después se ajusta TCP,
# al final DNS y servicios- y así se queda.
#
# AÑADIR UN COMANDO = añadir un New-CommandStep en su sitio de la
# lista (ver la ayuda en ui/Engine/CategoryRegistry.ps1). Si usa un
# ejecutable o un servicio nuevo, hay que darlo de alta también en la
# lista blanca de core/Network/CommandRunner.ps1: eso es una decisión
# de seguridad (SECURITY.md §12), no un detalle.
#
# Lo que tiene efectos que conviene decidir a conciencia -borrar las
# reglas del firewall, fijar DNS de Google- viene DESMARCADO y con
# aviso. Los reset de la pila piden reiniciar el equipo.
# ============================================================

$InternetPhase1 = 'Phase 1 · Clean up and reset the network stack'
$InternetPhase2 = 'Phase 2 · Tune TCP'
$InternetPhase3 = 'Phase 3 · Adapter, DNS and services'

Register-Category @{
    Id          = 'internet'
    Name        = 'Internet'
    Icon        = 'Globe'
    Accent      = 'Accent'
    AccentSoft  = 'AccentSoft'
    Description = 'Reset and tune the network: pick the commands and run them in order'
    Badge       = 'NEW'

    Steps = @(
        # ---- Fase 1: limpiar y resetear la pila de red ------------
        New-CommandStep -Id 'firewall-reset' -Group $InternetPhase1 `
            -Name 'Reset Windows Firewall' `
            -Description 'Restores the firewall to its factory policy.' `
            -Warning 'Deletes every custom rule and exception: apps you had allowed will ask again.' `
            -Checked $false `
            -Exe 'netsh.exe' -Arguments 'advfirewall', 'reset'

        New-CommandStep -Id 'branchcache-reset' -Group $InternetPhase1 `
            -Name 'Reset BranchCache' `
            -Description 'Empties the BranchCache content cache and its settings. Harmless if you do not use it.' `
            -Exe 'netsh.exe' -Arguments 'branchcache', 'reset'

        New-CommandStep -Id 'http-flush' -Group $InternetPhase1 `
            -Name 'Flush the HTTP log buffer' `
            -Description 'Writes out and empties the HTTP.sys log buffer.' `
            -PauseAfter 5 `
            -Exe 'netsh.exe' -Arguments 'http', 'flush', 'logbuffer'

        New-CommandStep -Id 'ipv4-reset' -Group $InternetPhase1 `
            -Name 'Reset IPv4' `
            -Description 'Rewrites the IPv4 configuration to its defaults.' `
            -RequiresRestart -PauseAfter 5 `
            -Exe 'netsh.exe' -Arguments 'int', 'ipv4', 'reset'

        New-CommandStep -Id 'dns-flush' -Group $InternetPhase1 `
            -RequiresAdmin $false `
            -Name 'Flush the DNS cache' `
            -Description 'Forgets the names already resolved, so they are looked up again.' `
            -Exe 'ipconfig.exe' -Arguments '/flushdns'

        New-CommandStep -Id 'netbios-purge' -Group $InternetPhase1 `
            -Name 'Purge the NetBIOS name cache' `
            -Description 'Empties the NetBIOS name table and reloads it.' `
            -Exe 'nbtstat.exe' -Arguments '-R'

        New-CommandStep -Id 'netbios-reregister' -Group $InternetPhase1 `
            -Name 'Re-register NetBIOS names' `
            -Description 'Releases and registers this PC''s NetBIOS names again on the network.' `
            -Exe 'nbtstat.exe' -Arguments '-RR'

        New-CommandStep -Id 'arp-clear' -Group $InternetPhase1 `
            -Name 'Clear the ARP cache' `
            -Description 'Forgets which hardware address belongs to each IP on the local network.' `
            -Exe 'arp.exe' -Arguments '-d', '*'

        New-CommandStep -Id 'winsock-reset' -Group $InternetPhase1 `
            -Name 'Reset Winsock' `
            -Description 'Restores the Windows sockets catalog: undoes what VPNs or network filters may have hooked in.' `
            -RequiresRestart `
            -Exe 'netsh.exe' -Arguments 'winsock', 'reset'

        New-CommandStep -Id 'ip-reset' -Group $InternetPhase1 `
            -Name 'Reset TCP/IP' `
            -Description 'Rewrites the TCP/IP stack settings to their defaults.' `
            -RequiresRestart `
            -Exe 'netsh.exe' -Arguments 'int', 'ip', 'reset'

        New-CommandStep -Id 'proxy-reset' -Group $InternetPhase1 `
            -Name 'Reset the WinHTTP proxy' `
            -Description 'Removes any system proxy for WinHTTP: direct connection.' `
            -Exe 'netsh.exe' -Arguments 'winhttp', 'reset', 'proxy'

        # ---- Fase 2: ajustar TCP (la pila ya está limpia) ---------
        New-CommandStep -Id 'tcp-heuristics' -Group $InternetPhase2 `
            -Name 'Turn off TCP window heuristics' `
            -Description 'Stops Windows from shrinking the receive window on its own.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'heuristics', 'disabled'

        New-CommandStep -Id 'tcp-autotuning' -Group $InternetPhase2 `
            -Name 'Receive window auto-tuning: normal' `
            -Description 'Lets the receive window grow with the connection speed.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'autotuninglevel=normal'

        New-CommandStep -Id 'tcp-rss' -Group $InternetPhase2 `
            -Name 'Turn on Receive Side Scaling' `
            -Description 'Spreads network processing across several CPU cores.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'rss=enabled'

        New-CommandStep -Id 'tcp-rsc' -Group $InternetPhase2 `
            -Name 'Turn off Receive Segment Coalescing' `
            -Description 'Delivers packets as they arrive instead of grouping them: less latency, a bit more CPU.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'rsc=disabled'

        New-CommandStep -Id 'tcp-ctcp' -Group $InternetPhase2 `
            -Name 'Congestion control: CTCP' `
            -Description 'Uses Compound TCP for Internet connections. Some Windows 11 builds reject it; then the step fails and nothing changes.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'supplemental', 'Internet', 'congestionprovider=ctcp'

        New-CommandStep -Id 'tcp-timestamps' -Group $InternetPhase2 `
            -Name 'Turn off TCP timestamps' `
            -Description 'Saves 12 bytes per packet. Windows has them off by default.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'timestamps=disabled'

        New-CommandStep -Id 'tcp-ecn' -Group $InternetPhase2 `
            -Name 'Turn off ECN' `
            -Description 'Disables Explicit Congestion Notification, which some routers handle badly.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'ecncapability=disabled'

        New-CommandStep -Id 'tcp-initialrto' -Group $InternetPhase2 `
            -Name 'Initial retransmission timeout: 2000 ms' `
            -Description 'How long TCP waits before resending the first packet of a connection.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'initialrto=2000'

        New-CommandStep -Id 'tcp-synretries' -Group $InternetPhase2 `
            -Name 'SYN retransmissions: 2' `
            -Description 'Gives up sooner on connections that do not answer.' `
            -Exe 'netsh.exe' -Arguments 'int', 'tcp', 'set', 'global', 'maxsynretransmissions=2'

        # ---- Fase 3: adaptador, DNS y servicios -------------------
        New-CommandStep -Id 'teredo-off' -Group $InternetPhase3 `
            -Name 'Turn off Teredo' `
            -Description 'Disables the IPv6-over-IPv4 tunnel. Some games and Xbox services use it for multiplayer.' `
            -Exe 'netsh.exe' -Arguments 'interface', 'teredo', 'set', 'state', 'disabled'

        New-CommandStep -Id 'dns-primary' -Group $InternetPhase3 `
            -Name 'DNS: Google 8.8.8.8 as primary' `
            -Description 'Sets a fixed DNS server on the adapter named "Ethernet".' `
            -Warning 'Only works if the adapter is called "Ethernet". Replaces the DNS your router provides.' `
            -Checked $false `
            -Exe 'netsh.exe' -Arguments 'interface', 'ip', 'set', 'dns', 'name=Ethernet', 'static', '8.8.8.8'

        New-CommandStep -Id 'dns-secondary' -Group $InternetPhase3 `
            -Name 'DNS: Google 8.8.4.4 as secondary' `
            -Description 'Adds the second Google DNS server to the adapter named "Ethernet".' `
            -Warning 'Run it together with the previous step: on its own it adds a server to whatever DNS is set.' `
            -Checked $false `
            -Exe 'netsh.exe' -Arguments 'interface', 'ip', 'add', 'dns', 'name=Ethernet', '8.8.4.4', 'index=2'

        New-CommandStep -Id 'service-dhcp' -Group $InternetPhase3 `
            -Name 'Make sure the DHCP Client service is running' `
            -Description 'Starts it if it is stopped. Without it the PC does not get an IP address.' `
            -Service 'Dhcp'

        New-CommandStep -Id 'service-dnscache' -Group $InternetPhase3 `
            -Name 'Make sure the DNS Client service is running' `
            -Description 'Starts it if it is stopped. Without it names are not resolved.' `
            -Service 'Dnscache'

        New-CommandStep -Id 'dns-flush-final' -Group $InternetPhase3 `
            -RequiresAdmin $false `
            -Name 'Flush the DNS cache again' `
            -Description 'One last cleanup with the final configuration in place.' `
            -Exe 'ipconfig.exe' -Arguments '/flushdns'

        New-CommandStep -Id 'show-interfaces' -Group $InternetPhase3 `
            -RequiresAdmin $false `
            -Name 'List the network adapters' `
            -Description 'Only reads: shows each adapter and whether it is connected, to check the result in the log.' `
            -Exe 'netsh.exe' -Arguments 'interface', 'show', 'interface'
    )
}
