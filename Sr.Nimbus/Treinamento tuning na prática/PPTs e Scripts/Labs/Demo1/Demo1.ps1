Clear-Host

# Starting demo... 
Write-Output "Preparing demo..."

$VerbosePreference = 'SilentlyContinue'
. "$PSScriptRoot\Invoke-SQLCmd2.ps1"

$computername = $env:computername
$ServerInstance = "$computername\SQL2017"

$user = "sa"
$password = '@bc12345'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepareDemo1.sql" -QueryTimeout 600 | Out-Null

$tsql = 'SELECT CustomersBig.ContactName, CustomersBig.Col1, CustomersBig.Col2, OrdersBig.Col1, SUM(OrdersBig.Value) FROM dbo.OrdersBig INNER JOIN dbo.CustomersBig ON CustomersBig.CustomerID = OrdersBig.CustomerID GROUP BY CustomersBig.ContactName, CustomersBig.Col1, CustomersBig.Col2, OrdersBig.Col1 ORDER BY CustomersBig.ContactName DESC OPTION (MAXDOP 1);'

Write-Output "Starting demo..."

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P@bc12345 -S$ServerInstance -n180 -r10 -dNorthwind -Q""$tsql"" -q" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command
