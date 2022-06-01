USE Northwind
GO

-- Quantas linhas tem na tabela OrdersBig?
SELECT COUNT(*) FROM OrdersBig
GO

SELECT Rowcnt
  FROM sysindexes
 WHERE id = OBJECT_ID('OrdersBig') 
   AND indid <= 1
   AND rowcnt > 0
GO

-- Verificando valores atuais...
DBCC SHOW_STATISTICS (OrdersBig) WITH STATS_STREAM
GO
-- Atualizando com n�meros maiores
UPDATE STATISTICS OrdersBig WITH ROWCOUNT = 1000005, PAGECOUNT = 3589
GO

-- Reset ROWCOUNT e PAGECOUNT com n�meros originais...
DBCC UPDATEUSAGE (Northwind,'OrdersBig') WITH COUNT_ROWS;
GO

-- Cuidado com migra��es/upgrades de vers�o pois esses valores podem ficar desatualizados... 
-- Por isso � importante fazer um DBCC UPDATEUSAGE depois de uma migra��o