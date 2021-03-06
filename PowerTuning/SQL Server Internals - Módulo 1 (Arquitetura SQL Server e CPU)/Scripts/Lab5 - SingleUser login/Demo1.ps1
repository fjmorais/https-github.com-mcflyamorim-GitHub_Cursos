Clear-Host

# Starting demo... 

$VerbosePreference = 'SilentlyContinue'
$computername = $env:computername
$ServerInstance = "$computername\SQL2017"

Write-Output "Starting demo..."

$LoginOK = $false
while (-not $LoginOK) 
{
	try 
	{
		#Perform command to retry, passing -ErrorAction Stop
		Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Query "SELECT @@Version" -Database Northwind -ConnectionTimeOut 1 -QueryTimeout 1 -ErrorAction Stop | Out-Null
		$vGetDate = Get-Date -Format G
		Write-Output "$vGetDate : Connection OK..."

	#$LoginOK = $true  # An exception will skip this
	} 
	catch 
	{
		$ErrorMessage = $_.Exception.Message
		$FailedItem = $_.Exception.ItemName
		$vGetDate = Get-Date -Format G
		Write-Output "$vGetDate : Connection Failed "$ErrorMessage"... retrying..."
	}
}

Write-Output "Finished demo..."
