### Autor: Nemanja Bocokic
### Datum: 05.07.2016
### Funktion: Installation und Konfiguration eines AD Standardserver + Wartungstools (MUSS AUF HV-HOST AUSGEFÜHRT WERDEN)

## Variabeleingabe
# Standardeinstellungen
$vmname = "TestNBO" # Der Ziel-VM-Name
$ipaddress = "192.168.1.2" # Welche IP?
$ipprefix = "24" # Subnetz
$ipgw = "192.168.1.1" # Gateway
$ipdns = "192.168.1.2" # DNS
$newname = "SRVDC01" # Hostname

# AD Einstellungen
$domainname = "alpha.local"
$netbiosName = "alpha" # NetBIOS Name
$adminpw = "Test" # PW des Admins

## Start der Konfiguration
# VM auswählen
Enter-PSSession -VMName $vmname
Invoke-Command -VMName $vmname -ScriptBlock {

# Powershell Execute-Richtlinie
Set-ExecutionPolicy Unrestricted

# Setzten einer statischen IP Adresse
$ipif = Get-NetIPInterface
New-NetIPAddress -IPAddress $ipaddress -PrefixLength $ipprefix -InterfaceIndex $ipif[0].ifIndex -DefaultGateway $ipgw
Set-DnsClientServerAddress -InterfaceIndex $ipif[0].ifIndex -ServerAddresses $ipaddress

# Umbenennung des Computers

Rename-Computer -NewName $newname –force

#Installieren von AD DS, DNS und GPMC
start-job -Name addFeature -ScriptBlock {
Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools }
Wait-Job -Name addFeature
Get-WindowsFeature

# Neuer AD Forest
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false `
-SafeModeAdministratorPassword $adminpw `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2012" `
-DomainName $domainname `
-DomainNetbiosName $netbiosName `
-ForestMode "Win2012" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

# Deaktvierung der IE Enhanced Security
Disable-IEEnhancedSecurityConfiguration

# Installiere Chocolatey Packet Manager
If (!Test-Path "C:\ProgramData\Chocolatey\choco.exe") {
	iwr "https://chocolatey.org/install.ps1" -UseBasicParsing | iex
}

# Installiere/Upgrade nützliche Tools
choco upgrade "notepadplusplus.install" -y
choco upgrade "dotnet4.5" -y
choco upgrade "sysinternals" -y
choco upgrade "treesizefree" -y

# Neustart um alles sauber abzuschliessen
Restart-Computer
}
