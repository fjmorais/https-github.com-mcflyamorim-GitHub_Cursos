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

-- 16 segundos pra rodar
if exists (select * from sysdatabases where name='Test1')
BEGIN
  ALTER DATABASE Test1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Test1
END
GO
DBCC TRACEON(1806) -- Habilitando TF1806 pra evitar IFI
GO
CREATE DATABASE [Test1]
 ON  PRIMARY 
( NAME = N'Test1', FILENAME = N'E:\Test1.mdf' , SIZE = 51200KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Test1_log', FILENAME = N'E:\Test1_log.ldf' , SIZE = 1MB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO
DBCC TRACEOFF(1806) -- Habilitando TF1806 pra evitar IFI
GO
-- 30 segundos pra rodar
USE [Test1]
GO
DROP TABLE IF EXISTS Table1
SELECT TOP 1000  
       IDENTITY(BigInt, 1, 1) AS Col1, 
       ISNULL(CONVERT(VarChar(250), NEWID()), '') AS Col2,
       ISNULL(CONVERT(VarChar(7000), REPLICATE('x', 5000)), '') AS Col3
  INTO Table1
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
SET IDENTITY_INSERT Table1 ON
INSERT INTO Table1(Col1, Col2, Col3)
VALUES(99999999999, 'Fabiano Neves Amorim', REPLICATE('x', 5000))
SET IDENTITY_INSERT Table1 OFF
GO
ALTER TABLE Table1 ADD CONSTRAINT xpkTable1 PRIMARY KEY(Col1)
GO


-- Começando demo...
CHECKPOINT; DBCC DROPCLEANBUFFERS
GO

-- Abrir Windows Performance Recorder e 
-- D:\Windows Kits\10\Windows Performance Toolkit\WPRUI.exe
-- Start recording...
-- Rodar a query...

-- Gerar o page read I/O... se ramp-up tiver "ON" 
-- provavelmente vai ler 64KB via ReadFileScatter...
SELECT COUNT(*) 
  FROM Test1.dbo.Table1
GO

-- Save recording...
-- Abrir arquivo .etl no Windows Performance Analyzer... 
-- D:\Windows Kits\10\Windows Performance Toolkit\wpa.exe
-- Filtrar pra mostrar apenas processo do sqlservr.exe -> Load Symbols
-- Ver stack...
