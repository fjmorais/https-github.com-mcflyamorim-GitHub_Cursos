Clear-Host

Write-Output "Iniciando execução do desafio 1"
$VerbosePreference = 'SilentlyContinue'


. "$PSScriptRoot\Invoke-SQLCmd2.ps1"

$computername = $env:computername
$ServerInstance = "$computername\SQL2017"

$user = "sa"
$password = '@bc123456789'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepararDesafio5.sql" -QueryTimeout 600 | Out-Null

$tsql = 'SELECT TOP 10 * FROM Desafio5.dbo.ProductsBig ORDER BY ProductName DESC OPTION (MAXDOP 1, MIN_GRANT_PERCENT = 100);'

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P@bc123456789 -dDesafio5 -S$ServerInstance -n100 -r10 -Q""$tsql"" -q" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command

pause