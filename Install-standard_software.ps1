### Autor: Nemanja Bocokic
### Datum: 05.07.2016
### Funktion: Installiert / Upgraded Tools
param([switch]$Elevated)

function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) 
    {
        # Starten als Administrator funktionierte nicht
    } 
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}

exit
}


# Installiere Chocolatey Packet Manager
iwr "https://chocolatey.org/install.ps1" -UseBasicParsing | iex


# Installiere/Upgrade nützliche Tools
choco upgrade "dotnet4.5" -y
choco upgrade "sysinternals" -y
choco upgrade "treesizefree" -y
choco upgrade "7zip.install" -y
choco upgrade "paint.net" -y
choco upgrade "teamviewer" -y
choco upgrade "wireshark" -y
choco upgrade "filezilla" -y
choco upgrade "7zip" -y
choco upgrade "notepadplusplus" -y
choco upgrade "spotify" -y
choco upgrade "toastify" -y
choco upgrade "putty" -y
choco upgrade "nmap" -y
choco upgrade "googlechrome" -y
choco upgrade "vlc" -y