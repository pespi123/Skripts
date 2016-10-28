# Install the Azure Resource Manager modules from the PowerShell Gallery
Install-Module AzureRM

# Install the Azure Service Management module from the PowerShell Gallery
Install-Module Azure

# Login
Login-AzureRmAccount

# Abos holen
Get-AzureRmSubscription

# Alle Ressourcen entfernen
$sub = "Kostenlose Testversion"

Select-AzureSubscription -SubscriptionName $sub  
Set-AzureSubscription -DefaultSubscription $sub

$websitesToSave = ""
$VMsToSave = ""
$storageAccountsToSave = ""

Get-AzureWebsite | Where {$_.Name -notin $websitesToSave} | Remove-AzureWebsite -Force
Get-AzureService | Where {$_.Label -notin $VMsToSave} | Remove-AzureService -Force
Get-AzureDisk | Where {$_.AttachedTo -eq $null} | Remove-AzureDisk -DeleteVHD
Get-AzureStorageAccount | Where {$_.Label -notin $storageAccountsToSave} | Remove-AzureStorageAccount
Get-AzureAffinityGroup | Remove-AzureAffinityGroup
Remove-AzureVNetConfig