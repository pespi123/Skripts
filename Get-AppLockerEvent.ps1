Function Get-AppLockerEvent {
    <#
        .Synopsis
         Retrieve AppLocker events from one or more computers.

        .Description
         Retrieve AppLocker events from one or more computers. AppLocker events can be queried by either EventType (a plain-english explanation of the general type of event) or EventID. 

        .Parameter ComputerName
         The name of the computer whose eventlogs will be queried for AppLocker events. If no ComputerName is specified, the function will default to the localhost.

        .Parameter EventType
         The plain english name of the AppLocker event or events being queried for. 
         The "Allowed" prefix indicates that the action is allowed as per the AppLocker policy. 
         The "Audited" prefix indicates that the action was allowed because the AppLocker policy is in Auditing mode, but would have been blocked if the policy was enforced.
         The "Blocked" prefix indicates that the action was blocked as per the AppLocker policy.

        .Parameter EventID
         The Event ID of the AppLocker event or events being queried for.

        .Example
         Get-AppLockerEvent -ComputerName Server1
         This command will return all of the AppLocker events from Server1.

        .Example
         Get-AppLockerEvent -ComputerName Server1 -EventID 8003,8006
         This command will return all of the AppLocker events from Server1 whose ID is either 8003 or 8006.

        .Example
         Get-AppLockerEvent -ComputerName Server1 -EventType AuditedFileExecution,AuditedMSIOrScriptExecution
         This command will return all of the AppLocker events from Server1 where a file, MSI, or script was allowed to execute but would have been blocked if AppLocker was enforcing policies.

        .Example
         "Server1","Server2" | Get-AppLockerEvent -EventId 8003,8006
         This command will return all of the AppLocker events from Server1 and Server 2 whose ID is either 8003 or 8006.

        .Example
         Get-ADComputer -Filter {OperatingSystem -Like "Windows 7*"} | Select-Object -ExpandProperty Name | Get-AppLockerEvent -EventType PolicyApplicationFailure,PolicyApplicationSuccess
         This command will query all Windows 7 computers in the domain and return all AppLocker Events for policy application success and failure.

        .Note
         If neither EventType nor EventID are specified, the function will return all AppLocker events from the targeted computer or computers.

    #>
    [cmdletbinding(DefaultParameterSetName="ByEventID")]
    Param (
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias("CN","Name")]
            [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName="ByEventType")]
        [Alias("Type")]
        [ValidateSet("PolicyApplicationFailure","PolicyApplicationSuccess",
                     "AllowedFileExecution","AuditedFileExecution","BlockedFileExecution",
                     "AllowedScriptOrMSIExecution","AuditedScriptOrMSIExecution","BlockedScriptOrMSIExecution",
                     "AllowedPackagedApp","AuditedPackagedApp","DisabledPackagedApp",
                     "AllowedPackagedAppInstallation","AuditedPackagedAppInstallation","DisabledPackagedAppInstallation",
                     "NoPackagedAppRule"
                     )]
            [string[]]$EventType,
        [Parameter(ParameterSetName="ByEventID")]
        [Alias("ID")]
        [ValidateSet(8000,8001,8002,8003,8004,8005,8006,8007,8020,8021,8022,8023,8024,8025,8027)]
        [int32[]]$EventID
    )
    Begin {
        If($EventType){
            # Map the EventType to the appropriate EventID
            ForEach ($Type in $EventType){
                Switch ($Type) {
                    "PolicyApplicationFailure"         {$EventID += 8000}
                    "PolicyApplicationSuccess"         {$EventID += 8001}
                     "AllowedFileExecution"            {$EventID += 8002}
                     "AuditedFileExecution"            {$EventID += 8003}
                     "BlockedFileExecution"            {$EventID += 8004}
                     "AllowedScriptOrMSIExecution"     {$EventID += 8005}
                     "AuditedScriptOrMSIExecution"     {$EventID += 8006}
                     "BlockedScriptOrMSIExecution"     {$EventID += 8007}
                     "AllowedPackagedApp"              {$EventID += 8020}
                     "AuditedPackagedApp"              {$EventID += 8021}
                     "DisabledPackagedApp"             {$EventID += 8022}
                     "AllowedPackagedAppInstallation"  {$EventID += 8023}
                     "AuditedPackagedAppInstallation"  {$EventID += 8024}
                     "DisabledPackagedAppInstallation" {$EventID += 8025}
                     "NoPackagedAppRule"               {$EventID += 8027}
                }
            }
        } ElseIf (-not $EventID) {
            # Ensure that all of the AppLocker Event Logs are returned if no Event ID is specified.
            [int32[]]$EventID = ((8000..8007) + (8020..8025) + 8027)
        }
        
    }
    Process {
        ForEach ($Computer in $ComputerName){
            $Events = @()
            # Collect all of the logs on the 
            # MSI and Script events are kept in a different log file for some reason.
            If($EventID -contains ("8005" -or "8006" -or "8007")){
                $Events += Get-WinEvent -LogName "Microsoft-Windows-AppLocker/MSI and Script" -ComputerName $Computer | 
                    Where-Object -FilterScript {$EventID -contains $_.Id}
            }
            $Events += Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -ComputerName $Computer | 
                    Where-Object -FilterScript {$EventID -contains $_.Id}
            # Return the datacalls as custom objects dropping the additional unneeded metadata and adding the computername.
            ForEach ($Event in $Events){
                $Properties = @{
                    "ComputerName" = $Computer
                    "TimeCreated"  = $Event.TimeCreated
                    "Id"           = $Event.Id
                    "Message"      = $Event.Message
                }
                New-Object -TypeName PSCustomObject -Property $Properties | Select-Object -Property ComputerName,TimeCreated,ID,Message
            }
        }
    }
}

New-Alias -Name gale -Value Get-AppLockerEvent