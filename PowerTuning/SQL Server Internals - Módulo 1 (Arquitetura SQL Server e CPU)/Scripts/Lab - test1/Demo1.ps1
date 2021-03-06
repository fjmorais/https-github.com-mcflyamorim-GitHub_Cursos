Clear-Host

# Starting demo... 
Write-Output "Preparing demo..."

$VerbosePreference = 'SilentlyContinue'
. "$PSScriptRoot\Invoke-SQLCmd2.ps1"

$computername = 'VM1' #$env:computername
$ServerInstance = "$computername\SQL2017"

$user = "sa"
$password = '@bc12345'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Command -Computername $computername -ScriptBlock { while ($true){} } -AsJob | Out-Null
Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepareDemo1.sql" -Database Northwind -QueryTimeout 600 | Out-Null
Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepareDemo2.sql" -Database Northwind -QueryTimeout 600 | Out-Null

$tsql = 'EXEC st_TestCPU'

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P$password -S$ServerInstance -n1 -r2 -dNorthwind -Q""$tsql"" -q" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command
