# Wenn das nicht geht...
Get-content �.\hosts.txt� | foreach {
            New-PSSession -Computername $_
            Write-Host("NSCP gestoppt")
            If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
                        Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
                        Write-Host("Ini gel�scht")
            }
            Copy-Item "\\HLNT02\c$\Users\Administrator.HOEGGER\Desktop\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"
            Write-Host("Ini kopiert")
            Restart-Service nscp -force
            Write-Host("NSCP gestartet")
            Exit-PSSession
}

#... das hier ausf�hren...
Get-content �.\hosts.txt� | foreach {
            If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
                        Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
                        Write-Host("Ini gel�scht")
            }
            Copy-Item "\\HLNT02\c$\Users\Administrator.HOEGGER\Desktop\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"
            Get-Service -Name nscp -ComputerName $_ | Restart-Service
} 

#... oder am besten das hier
Get-content �.\hosts.txt� | foreach {
    Restart-Service -InputObject $(Get-Service -Computer $_ -Name nscp);
	If (test-path "\\$_\c$\Program Files\NSClient++\nsclient.ini") {
		Remove-Item "\\$_\c$\Program Files\NSClient++\nsclient.ini"
		Write-Host("Ini gel�scht")
	}
	Copy-Item "\\SRVFM002\c$\Users\administrator.SCHNIDER-AG\Desktop\nsclient.ini" "\\$_\c$\Program Files\NSClient++\nsclient.ini"

	Write-Host("NSCP neugstartet auf $_")
}
