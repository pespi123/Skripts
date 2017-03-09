<########################################################################################################################################

© Alpha Solutions AG | Stand: 05.01.2017 | History:
06.01.2017 - NBO: Logikfehler im Skript behoben(ForEachschleife)
        
Was macht das Skript?
1.  Kontrolliert ob die vDisk bereits genutzt wird, wenn nein dann weiter
2.  Kontrolliert ob die vDisk weniger als 20% frei hat, wenn ja dann weiter
2.1 Sicherheitsfrage, ob die vDisks erweitert werden sollen)
3.  Resized die VHDX Grösse auf 120% der ursprünglichen Grösse (also +20%)
4.  Mounted die VHDX ins Filesystem (diskmgmt) und erweitert dort die Partition um das verfügbare Maximum
5.  Dismount der VHDX und Output, welche Disks nicht bearbeitet werden konnten (Punkt 1.)

########################################################################################################################################>
#########################################################################################################################################
## Variabeln
# Es muss der vollständige Pfad zum Userprofile-Ordner angegeben sein (kein Netzlaufwerk!)
$inuse = New-Object System.Collections.ArrayList 
$change = New-Object System.Collections.ArrayList
$report = @()
$reportresize = @()
$path = "C:\temp\" # Das hier anpassen
$state = $true
$i = 0
$now=Get-Date -format "yyyymmmdd"
$childs = Get-ChildItem "$path"

#########################################################################################################################################
## Funktionen
# VHDs resizing (analog zu diskmgmt resizing)
function extendVHDX {
	Param ([string]$VHDPath)
    $partition = Mount-VHD -Path $VHDPath -NoDriveLetter -Passthru | Get-Disk | Get-Partition
    $partsize = $partition | Get-PartitionSupportedSize
    $partition | Resize-Partition -Size $partsize.SizeMax
}

# Übersetzung der SID (Filename) zum Username
function translateSID {
   	Param ([string]$VHDPath)
    $sid = $VHDPath -replace '.*?-(.*).*\.vhdx*','$1' # Entferne UVHD und .vhdx String um die SID zu haben)
    $objSID = New-Object System.Security.Principal.SecurityIdentifier("$sid")
    $objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
    Return $objUser
}


Get-ChildItem "$path" -Filter *.vhdx | Foreach-Object {
	$file = Get-Item $_	    # VHD Aktuelle max. Grösse Output

######################################################################################################################################### 
## Überprüfung jeder VHD ob sie gerade genutzt wird, wenn ja, dann wird zur nächsten gewechselt und es gibt einen Eintrag in $inuse
	try {
		Mount-VHD -Path $file -ErrorAction Stop
	}
	catch {
		$state = $false
		$inuse.Add("$_") > $null
	}

#########################################################################################################################################
## Erweiterungsvorgang, wird gestartet wenn die vDisk nicht genutzt wird (=$true)
	If($state -eq $true)
		{
		    # VHD aktuelle max. Grösse
		    $vhds = Get-VHD -Path $_

            #############################################################################################################################
		    ## Prüfen ob die Dateigrösse in den letzten 20% ist, wenn ja, wird die Datei zum $change-Array hinzugefügt und ausgegeben
		    $80perc = ($vhds.Size/1KB)*0.8

		    If($80perc -lt $file.length/1KB) {
			    $change.Add("$file") > $null
                $resize = $true
		    }
            else
            {
                $resize = $false

            }
	    }

    # Get User from SID
    $sid = translateSID -VHDPath $_

    # Zusammenstellen des Reportings    
    $free = ($vhds.Size/1KB)-($file.length/1KB)
	$report += New-Object psobject -Property @{"Disk"=$($file);"User"=$($sid);"Resize"=$($resize);"Frei (MB)"=$($free/1024);"Belegt (MB)"=$($file.length/1KB/1024);"Gesamt (MB)"=$($vhds.Size/1KB/1024)}


    Dismount-VHD -Path $file
    Write-Progress -Activity “Checking aller VHDs” -status “Kontrolliere Disk: $file” -percentComplete ($i / $childs.count*100)
    $i++
}

# Table mit allen VHDs in Konsole ausgeben
$report | select "Disk", "User", "Resize", "Frei (MB)", "Belegt (MB)", "Gesamt (MB)" | Format-Table –AutoSize
# Table mit allen VHDs in Log schreiben
$report | select "Disk", "User", "Resize", "Frei (MB)", "Belegt (MB)", "Gesamt (MB)" | Format-Table –AutoSize > ".\Diskreport_$now.log"
$i = 0

#########################################################################################################################################
## Wenn Disks gefunden wurden die keinen Platz haben, wird der Vorgang gestartet
If($change.count -gt 0) {
	
        #############################################################################################################################
        ## Wenn der Benutzer mit "y" Antwortet, werden alle Disks nacheinander um 1.2 vergrössert, sonst wird das Skript beendet
		if(($result = Read-Host "Sollen diese vDisks mit dem Status 'Resize = true' um weitere 20% (der Maximalgrösse) vergrössert werden? (y/n)") -eq 'y') {           
            foreach ($disk in $change) {
                    Write-Progress -Activity “Erweiterung der VHDs” -status “Erwetere vDisk: $disk” -percentComplete ($i / $change.count*100)
                    $i++
                    # Neue VHD Grösse (120%) und funktionsaufruf
                    $diskpath = Get-Item $disk
                    $vhds_temp = Get-VHD -Path $disk
                    $temp = ($vhds_temp.Size/1KB)/1024*1.2
                    
                    $new_size = $temp*1024
                    $old_size = ($diskpath.length/1KB)
                    Write-Host("alt " + $old_size + " KB")
		            # Dismount-VHD -Path $diskpath
                    # Resize der MaxVHDSize
                    Write-Host("Neu: " + $new_size + " KB")                    
                    $new_size = $new_size*1024

                    If($free/1024 -eq -4) {
                        Resize-VHD -Path $diskpath -SizeBytes $new_size
                    }

                    # Get User from SID
                    $sid = translateSID -VHDPath $disk

                    Resize-VHD -Path $diskpath -SizeBytes $new_size
                    # Resize der Partition (analog zu Diskmgmt > Partition erweitern)
                    extendVHDX -VHDPath $diskpath
		            Dismount-VHD -Path $diskpath
                    $reportresize += New-Object psobject -Property @{"Disk"=$($disk);"User"=$($sid);"Alt (GB)"=$($old_size/1024);"Neu (GB)"=$($new_size/1024/1024)}
                    Write-Host("VHDX vergrössert: " + $disk)
            }
        }
        Else
        {
            # Wenn der Benutzer mit alles anderem als "y" antwortet
            Write-Host("Skript wird geschlossen")
            Return 0
        }
}
Else
{

       Write-Host("Keine erweiterbaren Disks gefunden!")
}


# Table mit allen VHDs in Konsole ausgeben
$reportresize | select "Disk", "User", "Alt (GB)", "Neu (GB)" | Format-Table –AutoSize
# Table mit allen VHDs in Log schreiben
$reportresize | select "Disk", "User", "Alt (GB)", "Neu (GB)"| Format-Table –AutoSize >> ".\changes_$now.log"

#########################################################################################################################################
## Die nicht bearbeitetn werden am schluss noch ausgegeben

If($inuse.count -gt 0) {
	Write-Host("Folgende vDisks sind noch in Verwendung") -Foreground "Red"
	Write-Host($inuse) -Foreground "Red"
}


