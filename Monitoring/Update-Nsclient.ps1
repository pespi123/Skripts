# Wenn das nicht geht...
Get-content “.\hosts.txt” | foreach {
            New-PSSession -Computername $_
            Write-Host("NSCP gestoppt")
            If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
                        Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
                        Write-Host("Ini gelöscht")
            }
            Copy-Item "PATH_TO_WORKING_FILE\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"
            Write-Host("Ini kopiert")
            Restart-Service nscp -force
            Write-Host("NSCP gestartet")
            Exit-PSSession
}

#... das hier ausführen...
Get-content “.\hosts.txt” | foreach {
            If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
                        Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
                        Write-Host("Ini gelöscht")
            }
            Copy-Item "PATH_TO_WORKING_FILE\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"
            Get-Service -Name nscp -ComputerName $_ | Restart-Service
} 

#... oder am besten das hier
Get-content “.\hosts.txt” | foreach {
    Restart-Service -InputObject $(Get-Service -Computer $_ -Name nscp);
	If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
		Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
		Write-Host("Ini gelöscht")
	}
	Copy-Item "PATH_TO_WORKING_FILE\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"

	Write-Host("NSCP neugstartet auf $_")
}
