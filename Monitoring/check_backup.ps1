<#
Autor: Nemanja Bocokic
Datum: 06.10.2016
Funktion: Nimmt die neuste Datei aus dem Ordner ($path) und kontrolliert ob sie jünger als 24h ist.

Dieses Plugin wird durch den NSClient (NRPE) ausgeführt!
0 = OK
2 = Critical
#>

$path = "F:\SRVSQL01`$MSSQL12\NAV-LIVE\FULL"
$file=dir -path $path | sort LastWriteTime | select -last 1
$timespan = new-timespan -hours 24

if(((get-date) - $file.LastWriteTime) -lt $timespan) {
    $state = 0
    $statetext = "Age: $((get-date) - $file.LastWriteTime)"
}
else {
    $state = 2
    $statetext = "Kein aktuelles Backup in $path"
}

Write-Host "$state $statetext | 'Age'=$((get-date) - $file.LastWriteTime);24:00:00"
exit $state