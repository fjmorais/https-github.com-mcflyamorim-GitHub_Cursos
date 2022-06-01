USE master
GO
if exists (select * from sysdatabases where name='Desafio4')
BEGIN
  ALTER DATABASE Desafio4 SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Desafio4
END 
GO
DECLARE @device_directory VarChar(520)
SELECT @device_directory = SUBSTRING(filename, 1, CHARINDEX(N'master.mdf', LOWER(filename)) - 1)
FROM master.dbo.sysaltfiles WHERE dbid = 1 AND fileid = 1
EXECUTE (N'CREATE DATABASE Desafio4
  ON PRIMARY (NAME = N''Desafio4'', FILENAME = N''' + @device_directory + N'Desafio4.mdf'')
  LOG ON (NAME = N''Desafio4_log'',  FILENAME = N''' + @device_directory + N'Desafio4.ldf'')')
GO

ALTER DATABASE Desafio4 SET RECOVERY SIMPLE
GO
ALTER DATABASE Desafio4 SET COMPATIBILITY_LEVEL = 110 -- SQL2012
GO


USE Desafio4
GO
CREATE TABLE [dbo].[OrdersBig](
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerID] [int] NULL,
	[OrderDate] [date] NOT NULL,
	[Value] [numeric](18, 2) NOT NULL,
 [Col1] VarCHAR(250)
) ON [PRIMARY]

INSERT INTO [OrdersBig] WITH (TABLOCK) ([CustomerID], OrderDate, Value, Col1) 
SELECT TOP 1000000
       ABS(CHECKSUM(NEWID())) / 100000 AS CustomerID,
       ISNULL(CONVERT(Date, GETDATE() - (CheckSUM(NEWID()) / 1000000)), GetDate()) AS OrderDate,
       ISNULL(ABS(CONVERT(Numeric(18,2), (CheckSUM(NEWID()) / 100000000.5))),0) AS Value,
       CONVERT(TEXT, 'SomeFixedShit') AS Col1
  FROM Northwind.dbo.Orders A
 CROSS JOIN Northwind.dbo.Orders B
 CROSS JOIN Northwind.dbo.Orders C
 CROSS JOIN Northwind.dbo.Orders D

ALTER TABLE OrdersBig ADD CONSTRAINT xpk_OrdersBig PRIMARY KEY(OrderID)
GO
CREATE INDEX ixValue ON OrdersBig (Value) INCLUDE(OrderDate, Col1)
GO


IF OBJECT_ID('CustomersBig') IS NOT NULL
  DROP TABLE CustomersBig
GO
SELECT TOP 1000000
       IDENTITY(Int, 1,1) AS CustomerID,
       a.CityID,
       SUBSTRING(CONVERT(VarChar(250),NEWID()),1,8) AS CompanyName, 
       SubString(CONVERT(VarChar(250),NEWID()),1,8) AS ContactName, 
       CONVERT(VarChar(250), REPLICATE('ASD', 5)) AS Col1, 
       CONVERT(VarChar(250), REPLICATE('ASD', 5)) AS Col2
  INTO CustomersBig
  FROM Northwind.dbo.Customers A
 CROSS JOIN Northwind.dbo.Customers B
 CROSS JOIN Northwind.dbo.Customers C
 CROSS JOIN Northwind.dbo.Customers D
GO
ALTER TABLE CustomersBig ADD CONSTRAINT xpk_CustomersBig PRIMARY KEY(CustomerID) 
GO

CREATE INDEX ixCustomerID ON OrdersBig(CustomerID)
GO


-- CREATE OR ALTER NIIIICEEE!
-- Creating a Multi Statment Function
CREATE OR ALTER FUNCTION dbo.fn_ReturnCustomersWithOrders(@ContactName VarChar(200))
RETURNS @TabResult TABLE (CustomerID Int,
                          ContactName VarChar(200),
                          CompanyName VarChar(200))
AS
BEGIN
  IF @ContactName = ''
    SET @ContactName = '%%'

  INSERT INTO @TabResult
  SELECT CustomersBig.CustomerID, 
         CustomersBig.ContactName, 
         CustomersBig.CompanyName
    FROM CustomersBig
   WHERE CustomersBig.ContactName LIKE @ContactName
     AND EXISTS(SELECT 1 FROM OrdersBig
                 WHERE CustomersBig.CustomerID = OrdersBig.CustomerID)

  RETURN
END
GO


CREATE PROCEDURE sp_Test1
AS
SELECT * 
  FROM Desafio4.dbo.fn_ReturnCustomersWithOrders('') AS fn
 INNER HASH JOIN  Desafio4.dbo.OrdersBig
    ON OrdersBig.CustomerID = fn.CustomerID
OPTION (MAXDOP 1)
GO
