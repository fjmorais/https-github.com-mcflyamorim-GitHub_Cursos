----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
/*
  Treinamento SQL Server Internals Parte 4 - Disk I/O
  Fabiano Neves Amorim - fabianonevesamorim@hotmail.com
  http://blogfabiano.com
*/
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

/*
  Advanced Scan (a.k.a. Merry-go-round scan)
*/

USE NorthWind
GO

IF OBJECT_ID('TMP_ProductsBig') IS NOT NULL
  DROP TABLE TMP_ProductsBig
GO
SELECT TOP 100 
       ISNULL(ROW_NUMBER() OVER(ORDER BY (SELECT 1)),0) AS ProductID, 
       CONVERT(Char(7000), NEWID()) AS Col2
  INTO TMP_ProductsBig
  FROM master.dbo.spt_values A
 CROSS JOIN master.dbo.spt_values B
GO
ALTER TABLE TMP_ProductsBig ADD CONSTRAINT xpkTMP_ProductsBig PRIMARY KEY (ProductID)
GO
CHECKPOINT
GO
SELECT * FROM TMP_ProductsBig WITH(NOLOCK)
GO
-- "Fingir" que a tabela � grande para gerar o advanced scanning
UPDATE STATISTICS TMP_ProductsBig WITH ROWCOUNT = 1000000, PAGECOUNT = 1000000
GO


-- Sem merry go round
SELECT ProductID,
       sys.fn_PhysLocFormatter (%%physloc%%) AS Physical_RID
  FROM TMP_ProductsBig WITH(NOLOCK)
GO
WAITFOR DELAY '00:00:01:000'
GO
SELECT ProductID,
       sys.fn_PhysLocFormatter (%%physloc%%) AS Physical_RID
  FROM TMP_ProductsBig WITH(NOLOCK)
GO

-- Com merry go round
SELECT ProductID,
       sys.fn_PhysLocFormatter (%%physloc%%) AS Physical_RID
  FROM TMP_ProductsBig WITH(NOLOCK)
GO
WAITFOR DELAY '00:00:00:500'
GO
SELECT ProductID,
       sys.fn_PhysLocFormatter (%%physloc%%) AS Physical_RID
  FROM TMP_ProductsBig WITH(NOLOCK)
GO