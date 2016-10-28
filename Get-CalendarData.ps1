 
## EWS Managed API Connect Script
## Requires the EWS Managed API and Powershell V2.0 or greator  
  
## Load Managed API dll  
Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.0\Microsoft.Exchange.WebServices.dll"
  
## Set Exchange Version 
$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2007_SP1
  
## Create Exchange Service Object 
$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)  
  
## Set Credentials to use two options are availible Option1 to use explict credentials or Option 2 use the Default (logged On) credentials  
  
#Credentials Option 1 using UPN for the windows Account  
# Tech Support Kalender: Tech.Support@alpha-solutions.ch
$creds = New-Object System.Net.NetworkCredential("Tech.Support@alpha-solutions.ch","Sup4Alp15$!")   
$service.Credentials = $creds      
  
#Credentials Option 2  
#service.UseDefaultCredentials = $true  
  
## Choose to ignore any SSL Warning issues caused by Self Signed Certificates  
  
## Code From http://poshcode.org/624
## Create a compilation environment
$Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
$Compiler=$Provider.CreateCompiler()
$Params=New-Object System.CodeDom.Compiler.CompilerParameters
$Params.GenerateExecutable=$False
$Params.GenerateInMemory=$True
$Params.IncludeDebugInformation=$False
$Params.ReferencedAssemblies.Add("System.DLL") | Out-Null

$TASource=@'
  namespace Local.ToolkitExtensions.Net.CertificatePolicy{
    public class TrustAll : System.Net.ICertificatePolicy {
      public TrustAll() { 
      }
      public bool CheckValidationResult(System.Net.ServicePoint sp,
        System.Security.Cryptography.X509Certificates.X509Certificate cert, 
        System.Net.WebRequest req, int problem) {
        return true;
      }
    }
  }
'@ 
$TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
$TAAssembly=$TAResults.CompiledAssembly

## We now create an instance of the TrustAll and attach it to the ServicePointManager
$TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
[System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

## end code from http://poshcode.org/624
  
## Set the URL of the CAS (Client Access Server) to use two options are availbe to use Autodiscover to find the CAS URL or Hardcode the CAS to use  
  
#CAS URL Option 1 Autodiscover  
#$service.AutodiscoverUrl("Tech.Support@alpha-solutions.ch",{$true})  
#"Using CAS Server : " + $Service.url   
   
#CAS URL Option 2 Hardcoded  
  
  
$service.Url = "https://outlook.office365.com/EWS/Exchange.asmx"   
  
  
# Bind to the Calendar Folder
$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar,"Tech.Support@alpha-solutions.ch")   # $MailboxName war hier !!!!!!!!!!!!!
$Calendar = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
$Recurring = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition([Microsoft.Exchange.WebServices.Data.DefaultExtendedPropertySet]::Appointment, 0x8223,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Boolean); 
$psPropset= new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)  
$psPropset.Add($Recurring)
$psPropset.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text;

$AppointmentState = @{0 = "None" ; 1 = "Meeting" ; 2 = "Received" ;4 = "Canceled" ; }

#Define Date to Query 
$StartDate = (Get-Date)
$EndDate = (Get-Date).AddDays(0)  

$RptCollection = @()

  
#Define the calendar view  
$CalendarView = New-Object Microsoft.Exchange.WebServices.Data.CalendarView($StartDate,$EndDate,1000)    
$fiItems = $service.FindAppointments($Calendar.Id,$CalendarView)
if($fiItems.Items.Count -gt 0){
 [Void]$service.LoadPropertiesForItems($fiItems,$psPropset)  
}
foreach($Item in $fiItems.Items){      
 $rptObj = "" | Select StartTime,EndTime,Duration,Type,Subject,Location,Organizer,Attendees,Resources,AppointmentState,Notes,HasAttachments,IsReminderSet,ReminderDueBy
 $rptObj.StartTime = $Item.Start  
 $rptObj.EndTime = $Item.End  
 $rptObj.Duration = $Item.Duration
 $rptObj.Subject  = $Item.Subject   
 $rptObj.Type = $Item.AppointmentType
 $rptObj.Location = $Item.Location
 $rptObj.Organizer = $Item.Organizer.Address
 $rptObj.HasAttachments = $Item.HasAttachments
 $rptObj.IsReminderSet = $Item.IsReminderSet
 $rptObj.ReminderDueBy = $Item.ReminderDueBy
 $aptStat = "";
 $AppointmentState.Keys | where { $_ -band $Item.AppointmentState } | foreach { $aptStat += $AppointmentState.Get_Item($_) + " "}
 $rptObj.AppointmentState = $aptStat 
 $RptCollection += $rptObj
    foreach($attendee in $Item.RequiredAttendees){
  $atn = $attendee.Address + " Required "  
  if($attendee.ResponseType -ne $null){
   $atn += $attendee.ResponseType.ToString() + "; "
  }
  else{
   $atn += "; "
  }
  $rptObj.Attendees += $atn
 }
 foreach($attendee in $Item.OptionalAttendees){
  $atn = $attendee.Address + " Optional "  
  if($attendee.ResponseType -ne $null){
   $atn += $attendee.ResponseType.ToString() + "; "
  }
  else{
   $atn += "; "
  }
  $rptObj.Attendees += $atn
 }
 foreach($attendee in $Item.Resources){
  $atn = $attendee.Address + " Resource "  
  if($attendee.ResponseType -ne $null){
   $atn += $attendee.ResponseType.ToString() + "; "
  }
  else{
   $atn += "; "
  }
  $rptObj.Resources += $atn
 }
 
} 
$RptCollection > $null



$rptObj.Notes = $Item.Body.Text
$support = $Item.Subject
# $countobject = $support | measure-object -character | select -expandproperty characters


$support = $support.Remove(0,15)
$support = $support.Remove(7,1)

$backup = $support.Remove(0,4)
$support = $support.Remove(3,4)

    if ($Item.Subject -like "*Pikett*")
    {


            $alternative = "Support ist offline"
            $alternative > "C:\Scripts\Who's support\supportteam.txt"

    }
    else
    {
        switch -wildcard ($support)
            {
               "NBO" {$support = "Nemanja"}
               "EZU" {$support = "Etienne"}
               "DBU" {$support = "David"}
               "MST" {$support = "Marco"}
               "MBA" {$support = "Milan"}
               "SAC" {$support = "Sandro"}
               "FCI" {$support = "Fabio"}
               "GPI" {$support = "Gabriel"}
               "DOB" {$support = "Dominic"}
               "AAG" {$support = "Alessandro"}
               "GSC" {$support = "Gabi"}
               "TSC" {$support = "Tobias"}
               "STH" {$support = "Simon"}
               "FFO" {$support = "Felice"}
               "SBO" {$support = "Stefan"}
               "CBR" {$support = "Christian"}
               "ALA" {$support = "Adrian"}			   
            }

        switch -wildcard ($backup)
            {
               "NBO" {$backup = "Nemanja"}
               "EZU" {$backup = "Etienne"}
               "DBU" {$backup = "David"}
               "MST" {$backup = "Marco"}
               "MBA" {$backup = "Milan"}
               "SAC" {$backup = "Sandro"}
               "FCI" {$backup = "Fabio"}
               "GPI" {$backup = "Gabriel"}
               "DOB" {$backup = "Dominic"}
               "AAG" {$backup = "Alessandro"}
               "GSC" {$backup = "Gabi"}
               "TSC" {$backup = "Tobias"}
               "STH" {$backup = "Simon"}
               "FFO" {$backup = "Felice"}
               "SBO" {$backup = "Stefan"}
               "CBR" {$backup = "Christian"}
               "ALA" {$backup = "Adrian"}				   
            }

        $supportteam = $support + " und " + $backup
        #V1 NBO 1.4.2015, ersetzt von EZU next line 7.4.15
        #$supportteam > "\\alpha-solutions.ch\AlphaDaten\Daten\37 Hilfsmittel\Tech\Betrieb\Supporttafel\supportteam.txt"
        $supportteam > "C:\Scripts\Who's support\supportteam.txt"

    }
