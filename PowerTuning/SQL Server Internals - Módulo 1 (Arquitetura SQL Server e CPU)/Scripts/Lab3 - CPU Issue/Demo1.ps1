Clear-Host

# Starting demo... 
Write-Output "Preparing demo..."

$VerbosePreference = 'SilentlyContinue'
$computername = $env:computername
$ServerInstance = "$computername\SQL2008R2"

$user = "sa"
$password = '@bc12345'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepareDemo1.sql" -Database Northwind -QueryTimeout 600 | Out-Null

$tsql = 'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; DECLARE @i INT = 0; WHILE @i < = 2000 BEGIN IF EXISTS(SELECT * FROM Orders WHERE OrderID = 10) AND EXISTS(SELECT * FROM Customers WHERE CustomerID = 10) AND EXISTS(SELECT * FROM Shippers WHERE ShipperID = 10)AND EXISTS(SELECT * FROM Cities WHERE CityID = 10) AND EXISTS(SELECT * FROM Employees WHERE EmployeeID = 10) AND EXISTS(SELECT * FROM Products WHERE ProductID = 10) BEGIN SELECT 1 END SET @i += 1 END';

Write-Output "Starting demo..."

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P$password -S$ServerInstance -n10 -r500 -dNorthwind -Q""$tsql"" -q -l60" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command
