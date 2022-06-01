USE NorthWind
GO

/*
  Hypothetical Indexes
*/

-- Criando um �ndice comum
CREATE INDEX ix_OrderDate_Comum ON OrdersBig(OrderDate)
GO
DROP INDEX OrdersBig.ix_OrderDate_Comum
GO

-- Criando um �ndice hipot�tico
-- DROP INDEX OrdersBig.ix_OrderDate_Hipotetico
CREATE INDEX ix_OrderDate_Hipotetico ON OrdersBig(OrderDate) WITH STATISTICS_ONLY = -1
GO

-- Visualizando o �ndice
sp_HelpIndex OrdersBig
GO

-- Visualizando as estat�sticas do �ndice
DBCC SHOW_STATISTICS(OrdersBig, ix_OrderDate_Hipotetico)
GO


-- Tentando usar o �ndice
SELECT * 
  FROM OrdersBig WITH(index=ix_OrderDate_Hipotetico)
 WHERE OrderDate = '20100101'
GO

-- Usando o indexid
SELECT * 
  FROM OrdersBig WITH(index=3)
 WHERE OrderDate = '20100101'
GO


-- Custo da consulta sem o �ndice alto
-- Clustered Index Scan na pk
SELECT * 
  FROM OrdersBig
 WHERE OrderDate = '20100101'
GO

-- Pergunta: Como simular o uso do �ndice hipot�tico?




-- Lendo dados necess�rios para rodar o comando DBCC AUTOPILOT
SELECT name, id, Indid, Dpages, rowcnt 
  FROM sysindexes
 WHERE id = object_id('OrdersBig')
GO

-- Visualizando a sintaxe do comando
DBCC TRACEON (2588)
DBCC HELP ('AUTOPILOT')
GO
/*
  dbcc AUTOPILOT (typeid [, dbid [, {maxQueryCost | tabid [, indid [, pages [, flag [, rowcounts]]]]} ]])
*/
SELECT DB_ID('NorthWind')
GO


DBCC AUTOPILOT (0, 5, 1330103779, 1) -- �ndice cluster
DBCC AUTOPILOT (0, 5, 1330103779, 5) -- �ndice ix_OrderDate_Hipotetico
GO
SET AUTOPILOT ON
GO
SELECT *
  FROM OrdersBig
 WHERE OrderDate = '20120315'
GO
SET AUTOPILOT OFF
GO



-- Que tal usar a proc st_TestHipotheticalIndexes ?

-- Exemplo 1
EXEC dbo.st_TestHipotheticalIndexes @SQLIndex = 'CREATE INDEX ix_12 ON Products (Unitprice, CategoryID, SupplierID) INCLUDE(ProductName);CREATE INDEX ix_Quantity ON Order_Details (Quantity);', 
                                    @Query = 'SELECT p.ProductName, p.UnitPrice, s.CompanyName, s.Country, od.quantity
                                                FROM Products as P
                                               INNER JOIN Suppliers as S
                                                  ON P.SupplierID = S.SupplierID
                                               INNER JOIN order_details as od
                                                  ON p.productID = od.productid
                                               WHERE P.CategoryID in (1,2,3) 
	                                                AND P.Unitprice < 20
	                                                AND S.Country = ''uk'' 
	                                                AND od.Quantity < 90'

-- Exemplo 2
EXEC dbo.st_TestHipotheticalIndexes @SQLIndex = 'CREATE INDEX ix ON ProductsBig (ProductName);',
                                    @Query = 'SELECT * FROM ProductsBig WHERE ProductName = ''Mishi Kobe Niku 1A11B764'''