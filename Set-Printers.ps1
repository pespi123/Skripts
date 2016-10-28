# Active Directory OU mit den Druckergruppen
$adsearch = "OU=PrinterMapping,OU=Security Groups,OU=Groups,OU=_Datacenter SG,DC=dixa,DC=ch"

# Active Directory OU mit den Standard-Druckergruppen
$adsearchdef = "OU=PrinterDefault,OU=Security Groups,OU=Groups,OU=_Datacenter SG,DC=dixa,DC=ch"

# Printserver
$psrv = "DIX-SVW-FS01"

# Löscht alle bereits verbunden Drucker vom angegebenen Printserver
remove-printer -Name "\\$($psrv)*"

# Speichert alle Gruppennamen in der OU in die Variable
# .name listet nur den Gruppennamen, ansonsten wäre es der DN
$pgrp = (Get-ADGroup -filter * -Searchbase $adsearch).name

foreach ($g in $pgrp) { # Geht jeden Gruppennamen einzeln durch
    # Speichert den samAccountName der Gruppenmitglieder in der Variablen. Auch kaskadierte Gruppen
    $groupmember = (Get-ADGroupMember $g -Recursive).samAccountName
    foreach ($i in $groupmember) { # Geht jeden einzelnes Gruppenmitglied durch
        if($i -eq $env:username){ # Wenn der angemeldete Benutzer Mitglied der Gruppe ist wird das nächste Statement ausgeführt
            # Liest die Beschreibung der aktuellen Gruppe aus
            $gdesc = (get-adgroup $g -Properties Description).Description

            # Speichert alle Drucker vom Printserver, welche der Gruppen-Beschreibung entsprechen, in der Variablen
            # In der Gruppenbeschreibung kann mit Wildcards * gearbeitet werden
	        $printer = get-printer -ComputerName $psrv -Name $gdesc

	        foreach ($p in $printer) { # Geht jeden einzelnen Drucker in der Variablen durch
                # Verbindet des Drucker
                Write-Host "\\$($psrv)\$($p.name)"
                add-printer -connectionname "\\$($psrv)\$($p.name)"
               }
        }
    }
}

# Sucht den bereits verbunden Drucker anhand der Beschreibung mittels WMI
$defprinter = Get-WmiObject -Query "Select * from Win32_Printer Where ShareName = '$gdesc'"

# Setzt den Drucker als Standard
$defprinter.SetDefaultPrinter()