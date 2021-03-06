Clear-Host

Write-Output "Iniciando execução do desafio 1"
$VerbosePreference = 'SilentlyContinue'


$computername = $env:computername
$ServerInstance = "$computername\SQL2017"

$user = "sa"
$password = '@bc123456789'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepararDesafio3.sql" -QueryTimeout 600 | Out-Null

$tsql = 'SELECT OrderDate, Value, Col1 FROM Desafio3.dbo.OrdersBig WHERE Value < 100 ORDER BY OrderDate DESC, Col1 DESC OPTION (MAXDOP 1);'

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P@bc123456789 -S$ServerInstance -n100 -r50 -Q""$tsql"" -q" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command

pause