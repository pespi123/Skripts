<#
Beispiel:
Bild holen:
Get-ADProfilePicture -User jsmith
Bild setzen:
Set-OutlookPicture -User jsmith -Path \\server\folder\pic.jpg

Notiz:
Bilder können nicht grösser als 96x96 sein!
#>

Function Get-ADProfilePicture() {
	Param(
	[Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[Microsoft.ActiveDirectory.Management.ADUser]$User
		
	)
	Get-ADUser $User -Properties thumbnailPhoto | Select @{Name="User";Expression={$_.Name}}, @{Name="Photo";Expression={$_.thumbnailPhoto}}
}

Function Set-ADProfilePicture() {
	Param(
	[Parameter(Mandatory=$true,Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[Microsoft.ActiveDirectory.Management.ADUser]$User,
		[Parameter(Mandatory=$true,Position=1)]
		[String]$Path
	)
	$Photo = ([Byte[]] $(Get-Content -Path $Path -Encoding Byte -ReadCount 0))
	Set-ADUser $User -Replace @{thumbnailPhoto=$photo}
}

Function Set-OutlookPicture() {
	Param(
	[Parameter(Mandatory=$true,Position=0,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[String]$User,
		[Parameter(Mandatory=$true,Position=1)]
		[String]$Path
	)
	Import-RecipientDataProperty -Identity $User -Picture -FileData ([Byte[]] $(Get-Content -Path $Path -Encoding Byte -ReadCount 0))
}