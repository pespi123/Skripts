<#
Nemanja Bocokic
Alpha Solutions AG, 11.11.2016

Skript noch nicht abgeschlossen!
Tasks des Skripts:
- Backup der Nav-Live und Nav-Test-
- Löschen der Nav-Test DB
- Stoppen des Nav-Test Services
- Restore der Nav-Test mit Nav-Live Files
- Setzen des Restore Models auf 'Simple'
- Starten des Nav-Test Services
#>

declare @strDate varchar(30)
set @strDate = CONVERT(varchar, getdate(),112)
set @strDate = @strDate + Left(CONVERT(varchar, getdate(),108),2)
set @strDate = @strDate + SubString(CONVERT(varchar,getdate(),108),4,2)
set @strDate = @strDate + SubString(CONVERT(varchar,getdate(),108),7,2)

$dt = Get-Date -Format yyyyMMdd

declare @BackupDirectory nvarchar(512)
exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupDirectory OUTPUT

$svr = New-Object 'Microsoft.SqlServer.Management.SMO.Server' $inst
$bdir = $svr.Settings.BackupDirectory

Write-output "Backupordner: $bdir ausgewählt"

## -------------------------------- Backupstart 1 --------------------------------
# SQL Backup Optionen
$db = $svr.Databases['NAV-TEST']
$dbname = $db.Name
$dbbk = new-object ('Microsoft.SqlServer.Management.Smo.Backup')
$dbbk.Action = 'Database'
$dbbk.BackupSetDescription = "Full backup of " + $dbname
$dbbk.BackupSetName = $dbname + " Backup"
$dbbk.Database = $dbname
$dbbk.MediaDescription = "Disk"
$dbbk.Devices.AddDevice($bdir + "\" + $dt + $dbname + ".bak", 'File')
$dbbk.SqlBackup($svr)

## -------------------------------- Backupstart 2 --------------------------------
# SQL Backup Optionen
$db = $svr.Databases['NAV-LIVE']
$dbname = $db.Name
$dbbk = new-object ('Microsoft.SqlServer.Management.Smo.Backup')
$dbbk.Action = 'Database'
$dbbk.BackupSetDescription = "Full backup of " + $dbname
$dbbk.BackupSetName = $dbname + " Backup"
$dbbk.Database = $dbname
$dbbk.MediaDescription = "Disk"
$dbbk.Devices.AddDevice($bdir + "\" + $dt + $dbname + ".bak", 'File')
$dbbk.SqlBackup($svr)

# Get ready for restore
$restorefile = $bdir + "\" + $dt + $dbname + ".bak"


## -------------------------------- Restore --------------------------------


# Set Recovery Model Option
if ($db.IsSystemObject -ne $True -and $db.RecoveryModel -ne 'Simple') {
write-output "Ändere DB $dbname auf Recovery Model: Simple"
$db.RecoveryModel = 'Simple'
$db.Alter()
}
write-output "Anpassungen an $dbname abgeschlossen"