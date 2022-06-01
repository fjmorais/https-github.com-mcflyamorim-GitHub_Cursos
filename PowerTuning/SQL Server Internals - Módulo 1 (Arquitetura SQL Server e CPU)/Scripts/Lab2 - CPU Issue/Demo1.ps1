Clear-Host

# Starting demo... 
Write-Output "Preparing demo..."

$VerbosePreference = 'SilentlyContinue'
$computername = $env:computername
$ServerInstance = "$computername\SQL2017"

$user = "sa"
$password = '@bc12345'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword) 

Invoke-Sqlcmd2 -ServerInstance $ServerInstance -Credential $cred -InputFile "$PSScriptRoot\PrepareDemo1.sql" -Database Northwind -QueryTimeout 600 | Out-Null

$tsql = 'DECLARE @Var VarChar(250) = NEWID(), @SQL NVarChar(MAX); SET @SQL = ''SELECT Orders.OrderID, COUNT(DISTINCT Orders.CustomerID), SUM(Orders.Value) FROM Orders INNER JOIN Customers ON Customers.CustomerID = Orders.CustomerID INNER JOIN Order_Details ON Order_Details.OrderID = Orders.OrderID INNER JOIN Products ON Products.ProductID = Order_Details.ProductID WHERE Products.ProductName = '' + '''''''' + @Var + '''''' GROUP BY Orders.OrderID''; EXEC sp_executesql @SQL';

Write-Output "Starting demo..."

$tmpCommand = "cmd.exe /C C:\RMLUtils\ostress.exe -Usa -P$password -S$ServerInstance -n200 -r200 -dNorthwind -Q""$tsql"" -q" 
$command = @"
$tmpCommand
"@

Invoke-Expression -Command:$command
