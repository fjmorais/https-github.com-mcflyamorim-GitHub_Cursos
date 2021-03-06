----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
/*
  Treinamento SQL Server Internals Parte 4 - Disk I/O
  Fabiano Neves Amorim - fabianonevesamorim@hotmail.com
  http://blogfabiano.com
*/
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

-- Preparando demo 
USE master
GO

-- Apenas 1GB de memória... quero fazer I/O... não quero ler do disco :-) 
sp_configure 'show advanced options', 1;  
RECONFIGURE;
GO 
EXEC sys.sp_configure N'max server memory (MB)', N'1024'
GO
RECONFIGURE WITH OVERRIDE
GO

if exists (select * from sysdatabases where name='Test_Fabiano_Rampup')
BEGIN
  ALTER DATABASE Test_Fabiano_Rampup SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Test_Fabiano_Rampup
end
GO
CREATE DATABASE Test_Fabiano_Rampup
 ON  PRIMARY 
( NAME = N'Test_Fabiano_Rampup', FILENAME = N'C:\DBs\Test_Fabiano_Rampup.mdf' , SIZE = 5GB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Test_Fabiano_Rampup_log', FILENAME = N'C:\DBs\Test_Fabiano_Rampup_log.ldf' , SIZE = 100MB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO
USE Test_Fabiano_Rampup
GO
-- Criar 1 tabela com +- 80MB
-- 30 segundos pra rodar o script...
DROP TABLE IF EXISTS Products1
GO
SELECT TOP 10000 IDENTITY(Int, 1,1) AS ProductID, 
       SubString(CONVERT(VarChar(250),NEWID()),1,8) AS ProductName, 
       CONVERT(VarChar(250), NEWID()) AS Col1,
       CONVERT(Char(4000), NEWID()) AS Col2
  INTO Products1
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
ALTER TABLE Products1 ADD CONSTRAINT xpk_Products1 PRIMARY KEY(ProductID)
GO
-- Criar 1 tabela com +- 1GB
-- 30 segundos pra rodar o script...
DROP TABLE IF EXISTS Products2
GO
SELECT TOP 130000 IDENTITY(Int, 1,1) AS ProductID, 
       SubString(CONVERT(VarChar(250),NEWID()),1,8) AS ProductName, 
       CONVERT(VarChar(250), NEWID()) AS Col1,
       CONVERT(Char(4000), NEWID()) AS Col2
  INTO Products2
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
ALTER TABLE Products2 ADD CONSTRAINT xpk_Products2 PRIMARY KEY(ProductID)
GO

-- Começando com um boot no SQL
-- Pra ter um "cold cache"...
EXEC xp_cmdShell 'net stop MSSQL$SQL2019 && net start MSSQL$SQL2019'
GO
SELECT 1
GO
-- Lendo alguma coisa só pra fazer SQL colocar as páginas de sistema no cache
SELECT * FROM Products2 WHERE ProductID = 1
GO


-- Como está o uso de memória?
SELECT object_name,
       counter_name,
       cntr_value / 1024. AS MBs
  FROM sys.dm_os_performance_counters
 WHERE counter_name IN('Target Server Memory (KB)', 'Total Server Memory (KB)')
GO

-- Vai ter que fazer leitura física na página com o ProductID = 5000... 
SET STATISTICS IO ON
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, 
       *
  FROM Products1
 WHERE ProductID = 5000
SET STATISTICS IO OFF
GO
-- Physical_RID = (1:35731:0)
-- Table 'Products2'. Scan count 0, logical reads 3, physical reads 3, read-ahead reads 0


-- E se eu ler uma ProductID = 4998, vai ter que fazer 
-- leitura física?
SET STATISTICS IO ON
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, 
       *
  FROM Products1
 WHERE ProductID = 4998
SET STATISTICS IO OFF
-- Physical_RID = (1:35654:0)
GO

-- E o ProductID = 5005 ?
SET STATISTICS IO ON
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, 
       *
  FROM Products1
 WHERE ProductID = 5003
SET STATISTICS IO OFF
-- Physical_RID = (1:35736:0)
GO

-- Pergunta... como eu faria pra ver o I/O gerado? 
-- quais páginas foram lidas no I/O?

-- O que foi pro BP data cache?
SELECT b.* FROM sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
 INNER JOIN sys.allocation_units AS a WITH (NOLOCK)
    ON a.allocation_unit_id = b.allocation_unit_id
 INNER JOIN sys.partitions AS p WITH (NOLOCK)
    ON a.container_id = p.hobt_id
 WHERE b.database_id = DB_ID('Test_Fabiano_Rampup')
   AND p.[object_id] = object_id('Products1')
   AND page_type = 'DATA_PAGE'
 ORDER BY page_id
GO

-- Vamos ler a tabela de 1GB pra encher o cache... 
SELECT COUNT(*) FROM Products2


-- Depois que o target é atingido... SQL para de fazer o rampup...
SELECT object_name,
       counter_name,
       cntr_value / 1024. AS MBs
  FROM sys.dm_os_performance_counters
 WHERE counter_name IN('Target Server Memory (KB)', 'Total Server Memory (KB)')
GO

-- Vai ter que fazer leitura física na página com o ProductID = 9000... 
SET STATISTICS IO ON
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, 
       *
  FROM Products1
 WHERE ProductID = 9000
SET STATISTICS IO OFF
-- Physical_RID = (1:34530:0)
GO

-- Vai ter que fazer leitura física na páginas... 
SET STATISTICS IO ON
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * FROM Products1 WHERE ProductID = 8995
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * FROM Products1 WHERE ProductID = 8996
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * FROM Products1 WHERE ProductID = 8997
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * FROM Products1 WHERE ProductID = 8998
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * FROM Products1 WHERE ProductID = 8999
SET STATISTICS IO OFF
GO


-- O que foi pro BP data cache?
SELECT b.* FROM sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
 INNER JOIN sys.allocation_units AS a WITH (NOLOCK)
    ON a.allocation_unit_id = b.allocation_unit_id
 INNER JOIN sys.partitions AS p WITH (NOLOCK)
    ON a.container_id = p.hobt_id
 WHERE b.database_id = DB_ID('Test_Fabiano_Rampup')
   AND p.[object_id] = object_id('Products1')
   AND page_type = 'DATA_PAGE'
 ORDER BY page_id
GO

-- Cleanup
sp_configure 'show advanced options', 1;  
RECONFIGURE;
GO 
-- Set BP to 10GB
EXEC sys.sp_configure N'max server memory (MB)', N'10240'
GO
RECONFIGURE WITH OVERRIDE
GO
