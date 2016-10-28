<#
	.SYNOPSIS
		Generate a report of upcoming certificates that will expire on servers located in AD.
	.DESCRIPTION
		Script queries AD for server names. Invokes *multithreading on the 'Get-Certificates.ps1' in order to speed up the processes.
		Script will email a HTML report if there is expiring certificates. 
		
		The script outputs a XML to the script's running path. This XML is used to compare expiring certificates to the next time the script is ran. (Keep spamming of emails down)
		If no certificate experations are less than $HighAlertDays or $lowAlertDays then a email will not be generated.
		
		When an certificate experation reaches $lowAlertDays only one email will be generated until $highAlertDays is reached.
		
		The script also produces a list of ComputerNames that it failed to get valid certificates from (stored in the directory the script was ran from).
		
		*Multithreading function credit goes to http://www.get-blog.com/?p=189
		
		Version 1.0
		
	.PARAMETER HighAlertDays
		Certificates with an experation less than HighAlertDays will trigger an email to be sent every day(as well as color coded red).
	.PARAMETER LowAlertDays
		Certificates with an experation less than LowAlertDays will trigger an email once (until HighAlertDays is met).
	.PARAMETER SendAlertTo
		User or Group that the HTML report will be sent to.
	.PARAMETER SendAlertFrom
		User or Group that the HTML report will be sent from.
	.PARAMETER SendErrorTo
		User or Group that any errors will be sent to.
	.PARAMETER SendErrorFrom
		User or Group that any errors will be sent from.
	.PARAMETER SMTPServer
		SMTP Server that will be used to generate the email alerts.
	.PARAMETER TranscriptPath
		Path that transcript will be exported to.
	.EXAMPLE
		$Params = @{
			HighAlertDays = '7'
			LowAlertDays = '30'
			SendAlertTo = 'username@contoso.com'
			SendAlertFrom = 'username@contoso.com'
			SendErrorTo = 'username@contoso.com'
			SendErrorFrom = 'username@contoso.com'
			SMTPServer = 'CONMAIL1.contoso.net'
			TranscriptPath = 'C:\temp'
			Verbose = $true

		}
		..\Find-ExpiringCertificates.ps1 @Params
	
#>
[CmdletBinding(SupportsShouldProcess=$True)]
param(
	[String]$HighAlertDays,
	[String]$LowAlertDays,
	[Array]$SendAlertTo,
	[String]$SendAlertFrom,
	[Array]$SendErrorTo,
	[String]$SendErrorFrom,
	[String]$SMTPServer,
	[String]$TranscriptPath
)

$Error.Clear()
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptName = $MyInvocation.MyCommand.Name

#region Start Transcript
	if($TranscriptPath){
		$transcriptPath = "$transcriptPath\transcript_$(get-date -f yyyy-MM-dd)_001.txt"
		if(!(Test-Path $transcriptPath)){
			New-Item $transcriptPath -ItemType File -Verbose
		}
		Start-Transcript -path $transcriptPath -Append
	}
#endRegion

#region Import Modules
Import-Module ActiveDirectory
#endregion Import Modules

#region DefineFunctions
Function Invoke-Multithreading {
	#.Synopsis
	#    This is a quick and open-ended script multi-threader searcher
	#    
	#.Description
	#    This script will allow any general, external script to be multithreaded by providing a single
	#    argument to that script and opening it in a seperate thread.  It works as a filter in the 
	#    pipeline, or as a standalone script.  It will read the argument either from the pipeline
	#    or from a filename provided.  It will send the results of the child script down the pipeline,
	#    so it is best to use a script that returns some sort of object.
	#
	#    Authored by Ryan Witschger - http://www.Get-Blog.com
	#    
	#.PARAMETER Command
	#    This is where you provide the PowerShell Cmdlet / Script file that you want to multithread.  
	#    You can also choose a built in cmdlet.  Keep in mind that your script.  This script is read into 
	#    a scriptblock, so any unforeseen errors are likely caused by the conversion to a script block.
	#    
	#.PARAMETER ObjectList
	#    The objectlist represents the arguments that are provided to the child script.  This is an open ended
	#    argument and can take a single object from the pipeline, an array, a collection, or a file name.  The 
	#    multithreading script does it's best to find out which you have provided and handle it as such.  
	#    If you would like to provide a file, then the file is read with one object on each line and will 
	#    be provided as is to the script you are running as a string.  If this is not desired, then use an array.
	#    
	#.PARAMETER InputParam
	#    This allows you to specify the parameter for which your input objects are to be evaluated.  As an example, 
	#    if you were to provide a computer name to the Get-Process cmdlet as just an argument, it would attempt to 
	#    find all processes where the name was the provided computername and fail.  You need to specify that the 
	#    parameter that you are providing is the "ComputerName".
	#
	#.PARAMETER AddParam
	#    This allows you to specify additional parameters to the running command.  For instance, if you are trying
	#    to find the status of the "BITS" service on all servers in your list, you will need to specify the "Name"
	#    parameter.  This command takes a hash pair formatted as follows:  
	#
	#    @{"ParameterName" = "Value"}
	#    @{"ParameterName" = "Value" ; "ParameterTwo" = "Value2"}
	#
	#.PARAMETER AddSwitch
	#    This allows you to add additional switches to the command you are running.  For instance, you may want 
	#    to include "RequiredServices" to the "Get-Service" cmdlet.  This parameter will take a single string, or 
	#    an aray of strings as follows:
	#
	#    "RequiredServices"
	#    @("RequiredServices", "DependentServices")
	#
	#.PARAMETER MaxThreads
	#    This is the maximum number of threads to run at any given time.  If resources are too congested try lowering
	#    this number.  The default value is 20.
	#    
	#.PARAMETER SleepTimer
	#    This is the time between cycles of the child process detection cycle.  The default value is 200ms.  If CPU 
	#    utilization is high then you can consider increasing this delay.  If the child script takes a long time to
	#    run, then you might increase this value to around 1000 (or 1 second in the detection cycle).
	#
	#    
	#.EXAMPLE
	#    Both of these will execute the script named ServerInfo.ps1 and provide each of the server names in AllServers.txt
	#    while providing the results to the screen.  The results will be the output of the child script.
	#    
	#    gc AllServers.txt | .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1
	#    .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1 -ObjectList (gc .\AllServers.txt)
	#
	#.EXAMPLE
	#    The following demonstrates the use of the AddParam statement
	#    
	#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"}
	#    
	#.EXAMPLE
	#    The following demonstrates the use of the AddSwitch statement
	#    
	#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -AddSwitch @("RequiredServices", "DependentServices")
	#
	#.EXAMPLE
	#    The following demonstrates the use of the script in the pipeline
	#    
	#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"} | Select Status, MachineName
	#


	Param($Command = $(Read-Host "Enter the script file"), 
	    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$ObjectList,
	    $InputParam = $Null,
	    $MaxThreads = 20,
	    $SleepTimer = 200,
	    $MaxResultTime = 120,
	    [HashTable]$AddParam = @{},
	    [Array]$AddSwitch = @(),
		[array]$AddObjParam

	)

	Begin{
	    $ISS = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
	    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads, $ISS, $Host)
	    $RunspacePool.Open()
	        
	    If ($(Get-Command | Select-Object Name) -match ([regex]::Escape($Command))){
	        $Code = $Null
	    }
		ElseIf($Command -like "*.ps1"){
			$OFS = "`r`n"
	        $Code = [ScriptBlock]::Create($(Get-Content $Command))
	        Remove-Variable OFS
		}
		Else{
	        $OFS = "`r`n"
	        $Code = [ScriptBlock]::Create($Command)
	        Remove-Variable OFS
	    }
	    $Jobs = @()
	}

	Process{
	    Write-Progress -Activity "Preloading threads" -Status "Starting Job $($jobs.count)"
	    ForEach ($Object in $ObjectList){
	        If ($Code -eq $Null){
	            $PowershellThread = [powershell]::Create().AddCommand($Command)
	        }Else{
	            $PowershellThread = [powershell]::Create().AddScript($Code)
	        }
	        If ($InputParam -ne $Null){
	            $PowershellThread.AddParameter($InputParam, $Object.ToString()) | out-null
	        }Else{
	            $PowershellThread.AddArgument($Object.ToString()) | out-null
	        }
	        ForEach($Key in $AddParam.Keys){
	            $PowershellThread.AddParameter($Key, $AddParam.$key) | out-null
	        }
			If($AddObjParam){
				ForEach($Param in $AddObjParam){
		            $PowershellThread.AddParameter($Param, $Object.$($Param)) | out-null
		        }
			}
	        ForEach($Switch in $AddSwitch){
	            $Switch
	            $PowershellThread.AddParameter($Switch) | out-null
	        }
	        $PowershellThread.RunspacePool = $RunspacePool
	        $Handle = $PowershellThread.BeginInvoke()
	        $Job = "" | Select-Object Handle, Thread, object
	        $Job.Handle = $Handle
	        $Job.Thread = $PowershellThread
	        $Job.Object = $Object.ToString()
	        $Jobs += $Job
	    }
	        
	}

	End{
	    $ResultTimer = Get-Date
	    While (@($Jobs | Where-Object {$_.Handle -ne $Null}).count -gt 0)  {
	    
	        $Remaining = "$($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).object)"
	        If ($Remaining.Length -gt 60){
	            $Remaining = $Remaining.Substring(0,60) + "..."
	        }
	        Write-Progress `
	            -Activity "Waiting for Jobs - $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads running" `
	            -PercentComplete (($Jobs.count - $($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).count)) / $Jobs.Count * 100) `
	            -Status "$(@($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False})).count) remaining - $remaining" 

	        ForEach ($Job in $($Jobs | Where-Object {$_.Handle.IsCompleted -eq $True})){
	            $Job.Thread.EndInvoke($Job.Handle)
	            $Job.Thread.Dispose()
	            $Job.Thread = $Null
	            $Job.Handle = $Null
	            $ResultTimer = Get-Date
	        }
	        If (($(Get-Date) - $ResultTimer).totalseconds -gt $MaxResultTime){
	            Write-Error "Child script appears to be frozen, try increasing MaxResultTime"
	            Exit
	        }
	        Start-Sleep -Milliseconds $SleepTimer
	        
	    } 
	    $RunspacePool.Close() | Out-Null
	    $RunspacePool.Dispose() | Out-Null
	} 
}
#endregion DefineFunctions

#region GetCertificates
Write-Verbose "********************"
Write-Verbose "Begin Query for Certificates"
Write-Verbose "********************"
Measure-Command {
	$Servers = Get-ADComputer -Filter {OperatingSystem -Like "Windows Server*"} | Select -ExpandProperty Name
	Write-Verbose "Server Count: $($Servers.Count)" 
	$Certs = @()
	$Certs = $Servers | Invoke-Multithreading -InputParam 'Computer' -MaxThreads 50 -Command {
		param ($Computer = $env:ComputerName)
		$Error.Clear()
		$ro=[System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly"
		$lm = [System.Security.Cryptography.X509Certificates.StoreLocation]"LocalMachine"
		$store = new-object System.Security.Cryptography.X509Certificates.X509Store("\\$computer\my",$lm)
		$store.Open($ro)
		$Certificates = @()
		ForEach($cert in $store.Certificates){
			$TemopObj = New-Object System.Object
			$TemopObj | Add-Member -Type NoteProperty -Name ComputerName -Value $computer
			$TemopObj | Add-Member -Type NoteProperty -Name FriendlyName -Value $cert.FriendlyName 
			$TemopObj | Add-Member -Type NoteProperty -Name Issuer -Value $cert.Issuer
			$TemopObj | Add-Member -Type NoteProperty -Name Subject -Value $cert.Subject
			$TemopObj | Add-Member -Type NoteProperty -Name Thumbprint -Value $cert.Thumbprint
			$TemopObj | Add-Member -Type NoteProperty -Name NotAfter -Value $cert.NotAfter
			$template = $cert.Extensions | Where-Object {$_.Oid.Value -eq "1.3.6.1.4.1.311.20.2" }
			 if (!$template) {
		        $template = $cert.Extensions | Where-Object { $_.Oid.Value -eq "1.3.6.1.4.1.311.21.7" }
		 	}
			if($template){
				if($template.Format(0) -match "Template=([^*]+)\("){
					$template = $Matches[1]
				}
				else{
					$template = $template.Format(0)
				}
			}
		    $TemopObj | Add-Member -Type NoteProperty -Name Template -Value $template
			$TemopObj | Add-Member -Type NoteProperty -Name Error -Value $Null
			$Certificates += $TemopObj
		}
		if($error){
			foreach($obj in $error){
				$TemopObj = New-Object System.Object
				$TemopObj | Add-Member -Type NoteProperty -Name ComputerName -Value $computer
				$TemopObj | Add-Member -Type NoteProperty -Name FriendlyName -Value $Null
				$TemopObj | Add-Member -Type NoteProperty -Name Issuer -Value $Null
				$TemopObj | Add-Member -Type NoteProperty -Name Subject -Value $Null
				$TemopObj | Add-Member -Type NoteProperty -Name Thumbprint -Value $Null
				$TemopObj | Add-Member -Type NoteProperty -Name NotAfter -Value $Null
			    $TemopObj | Add-Member -Type NoteProperty -Name Template -Value $Null
				$TemopObj | Add-Member -Type NoteProperty -Name Error -Value $obj
				$Certificates += $TemopObj
			}
		}
		return $Certificates
	}
	Write-Verbose "Certificate Count: $($Certs.Count)" 
}
Write-Verbose "********************"
Write-Verbose "End Query for Certificates"
Write-Verbose "********************"
#endregion GetCertificates

#region FilterCerts

$SucessfulQueries = (($Certs | Where-Object {$_.Error -eq $null}).ComputerName | Select -Unique | Sort)
Write-Verbose "********************"
Write-Verbose "SuccessfulQueries"
Write-Verbose "********************"
Write-Verbose ($SucessfulQueries | Out-String) 
$UnsucessfulQueries = (($Certs | Where-Object {$_.Error -ne $null}).ComputerName | Select -Unique | Sort)
Write-Verbose "********************"
Write-Verbose "UnsuccessfulQueries"
Write-Verbose "********************"
Write-Verbose ($UnsucessfulQueries | Out-String) 

$ExpiringCerts = @()
$ExpiringCerts = $Certs | Where-Object{ ($_.NotAfter -gt (Get-Date)) -and  ($_.NotAfter -lt (Get-Date).AddDays($LowAlertDays)) } 
$ExpiringCerts | ForEach-Object {
	$daysLeft = (($_.NotAfter) - (Get-Date)).days
	$_ | Add-Member -Type NoteProperty -Name DaysLeft -Value $daysLeft
	$_.NotAfter = $(($_.NotAfter).ToString("dd/MM/yyyy"))
}

$ExpiringCerts = $ExpiringCerts | Sort-Object $_.DaysLeft -Descending

#endregion FilterCerts

#region ImportPreviousExpiringCertsXML
if(Test-Path $scriptPath\ExpiringCerts.xml){
	$previouslyExpiringCerts = Import-Clixml $scriptPath\ExpiringCerts.xml
}
else{
	$previouslyExpiringCerts = @()
}

#endregion ImportPreviousExpiringCertsXML

#region SendEmail
If($ExpiringCerts){
	if( (Compare-Object $previouslyExpiringCerts $ExpiringCerts -Property Thumbprint) -or ($ExpiringCerts | Where-Object { $_.DaysLeft -lt $HighAlertDays }) ){
		$ExpiringCerts = $ExpiringCerts | Sort-Object DaysLeft
		[string]$body = "
		<!DOCTYPE html>
		<html>
		<head>
		<style>
		table, th, td {
		    border: 1px solid black;
			padding: 5px;
		}
		</style>
		</head>
		<body>"
			$body += "
			<table>
				<tr>
					<th colspan = 7 ><font size= 8 ><b>Upcoming Certificate Expiration Report</font></b></th>
				</tr>
				<tr>
					<th align=Center >DaysLeft</th>
					<th align=Center >ComputerName</th>
					<th align=Center >Template</th>
					<th align=Center >FriendlyName</th>
					<th align=Center >Issuer</th>
					<th align=Center >ThumbPrint</th>
					<th align=Center >ExpirationDate(dd/MM/yyyy)</th>
				</tr>
			"
			foreach($ExpiringCert in $ExpiringCerts){
				if($ExpiringCert.DaysLeft -lt '7'){
					$body +="<tr bgcolor = red >"
				}else{
					$body +="<tr>"
				}
				$body +="
					<td align=right >$($ExpiringCert.DaysLeft)</th>
					<td align=right >$($ExpiringCert.ComputerName)</th>
					<td align=right >$($ExpiringCert.Template)</th>
					<td align=right >$($ExpiringCert.FriendlyName)</th>
					<td align=right >$($ExpiringCert.Issuer)</th>
					<td align=right >$($ExpiringCert.ThumbPrint)</th>
			     	<td align=right >$($ExpiringCert.NotAfter)</th>
			     </tr>"
		  }
		  $body += "
		  	</table>
			<br>Servers Queried: $($Servers.Count)
			<br>Successful Server Queried Count: $($SucessfulQueries.Count)
			<br>Unsuccessful Server Queried Count: $($UnsucessfulQueries.Count)
			<br>Certificate Count: $($Certs.Count)
			<br>Successful and Unsuccessful Querie Computernames can be found in the Transcript (if Verbose is enabled)
			</p>
			<p>Transcript can be found: <a href=$TranscriptPath>$TranscriptPath</a></p>
			<p>Script source can be found: <a href=$scriptPath>$scriptPath</a></p>
			<p><b>***This was an automatically generated email.***</b></p>
	  </body>
	  </html>"
		$Params = @{
			'To' = $SendAlertTo;
			'From' = $SendAlertFrom;
			'Subject' = "Upcoming Certificate Expiration Report";
			'Body' = $body
			'SMTPServer' = $SMTPServer;
			'BodyAsHtml' = $true;
		}
		Send-Mailmessage @Params
		$ExpiringCerts = $ExpiringCerts | Export-Clixml $scriptPath\ExpiringCerts.xml
	}
}
#endregion SendEmail

#region GenerateErrorReport
Function Generate-ErrorReport {
		Param(
		[Parameter(Mandatory = $True)][array]$To,
		[Parameter(Mandatory = $True)][string]$From,
		[Parameter(Mandatory = $True)][string]$SMTPServer,
		[Parameter(Mandatory = $False)][String]$TranscriptPath,
		[Parameter(Mandatory = $False)][String]$ScriptPath,
		[Parameter(Mandatory = $False)][String]$ScriptName,
		[Parameter(Mandatory = $False)][String]$ComputerName
	)
	if($Error){
		$Errors = @()
		for($i = 0; $i -lt $Error.Count; $i++){
			if($Error[$i].ScriptStackTrace){
				$Errors += "<br><b>Error [ $($Error[$i].ScriptStackTrace.ToString())]:</b>  $($Error[$i].ToString())</br>"
			}
			else{
				$Errors += "<br><b>Error [ ]:</b>  $($Error[$i].ToString())</br>"
			}
		}
	}
	$body = "An error was generated from $scriptName running on $Env:COMPUTERNAME.`r
		<br></br>
		<b>Error Information:`r</b>
		<br>$Errors`r</br>
		<p>Transcript can be found: $TranscriptPath</p>
		<p>Script source can be found: $scriptPath\$scriptName</p>
		<p><b>***This was an automatically generated email.***</b></p>"
	Send-MailMessage -from $From -to $To -subject "Error Report: $scriptName on $ComputerName (Running as Task)" -body $body -smtpServer $SMTPServer -BodyAsHtml
}
$ErrorReportParam = @{
	'To' = $SendErrorTo
	'From' = $SendErrorFrom
	'SMTPServer' = $SMTPServer;
	'TranscriptPath' = $transcriptPath;
	'ScriptPath' = $scriptPath;
	'ScriptName' = $scriptName;
	'ComputerName' = $Env:COMPUTERNAME;
}

if($Error){
	Generate-ErrorReport @ErrorReportParam
}
#endregion GenerateErrorReport
if($TranscriptPath){
	Stop-Transcript 
}
Exit