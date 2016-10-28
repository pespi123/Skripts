### Autor: Nemanja Bocokic
### Datum: 05.07.2016
### Funktion: Konfig Cleanserver + Wartungstools (MUSS AUF HV-HOST AUSGEF�HRT WERDEN)

## Variabeleingabe
# Standardeinstellungen
$vmname = "TestNBO" # Der Ziel-VM-Name
$ipaddress = "192.168.1.2" # Welche IP?
$ipprefix = "24" # Subnetz
$ipgw = "192.168.1.1" # Gateway
$ipdns = "192.168.1.2" # DNS
$newname = "SRVDC01" # Hostname

## Start der Konfiguration
# VM ausw�hlen
Enter-PSSession -VMName $vmname
Invoke-Command -VMName $vmname -ScriptBlock {

# Powershell Execute-Richtlinie
Set-ExecutionPolicy Unrestricted

# Setzten einer statischen IP Adresse
$ipif = Get-NetIPInterface
New-NetIPAddress -IPAddress $ipaddress -PrefixLength $ipprefix -InterfaceIndex $ipif[0].ifIndex -DefaultGateway $ipgw
Set-DnsClientServerAddress -InterfaceIndex $ipif[0].ifIndex -ServerAddresses $ipaddress

# Umbenennung des Computers
Rename-Computer -NewName $newname �force

# Deaktvierung der IE Enhanced Security
Disable-IEEnhancedSecurityConfiguration

# Installiere Chocolatey Packet Manager
If (!Test-Path "C:\ProgramData\Chocolatey\choco.exe") {
	iwr "https://chocolatey.org/install.ps1" -UseBasicParsing | iex
}

# Installiere/Upgrade n�tzliche Tools
choco upgrade "notepadplusplus" -y
choco upgrade "dotnet4.5" -y
choco upgrade "sysinternals" -y
choco upgrade "treesizefree" -y

# Neustart um alles sauber abzuschliessen
Restart-Computer
}