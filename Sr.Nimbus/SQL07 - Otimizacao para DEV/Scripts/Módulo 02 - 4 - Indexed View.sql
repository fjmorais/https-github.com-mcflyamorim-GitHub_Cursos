/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/


USE NorthWind
GO

/*
  Limpar/Preparar o banco
  
  IF OBJECT_ID('vw_Test') IS NOT NULL 
    DROP VIEW vw_Test
  IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = 'ix_Value_CustomerID' AND Object_id = OBJECT_ID('OrdersBig'))
    DROP INDEX OrdersBig.ix_Value_CustomerID
  IF EXISTS(SELECT 1 FROM sys.indexes WHERE Name = 'ix_CustomerID_Value' AND Object_id = OBJECT_ID('OrdersBig'))
    DROP INDEX OrdersBig.ix_CustomerID_Value
*/

/*
  Consulta abaixo faz um Scan no �ndice cluster
*/
SET STATISTICS IO ON
SELECT CustomerID, SUM(Value)
  FROM OrdersBig
 GROUP BY CustomerID
 ORDER BY CustomerID
SET STATISTICS IO OFF
GO


CREATE INDEX ix_Value_CustomerID ON OrdersBig(Value, CustomerID)
GO
/*
  Ap�s criar o �ndice a consulta abaixo 
  passa a fazer um Scan no �ndice NonClustered
  Por�m continua usando o Hash Aggregate
*/
SET STATISTICS IO ON
SELECT CustomerID, SUM(Value)
  FROM OrdersBig
 GROUP BY CustomerID
 ORDER BY CustomerID
SET STATISTICS IO OFF
GO

/* 
  At� para criar um �ndice o SQL pode fazer proveito de outro �ndice
  O create index abaixo usa o indice ix_Value_CustomerID para criar 
  o ix_CustomerID_Value
*/
CREATE INDEX ix_CustomerID_Value ON OrdersBig(CustomerID) INCLUDE(Value)

-- N�o gera mais o HashAggregate e usa o �ndice para ler os dados
SET STATISTICS IO ON
SELECT CustomerID, SUM(Value)
  FROM OrdersBig
 GROUP BY CustomerID
 ORDER BY CustomerID
SET STATISTICS IO OFF
GO

IF OBJECT_ID('vw_Test') IS NOT NULL
BEGIN
  DROP VIEW vw_Test
END
GO
CREATE VIEW vw_Test
WITH SCHEMABINDING AS 
SELECT CustomerID, SUM(Value) AS Value, Count_Big(*) AS CountBig
  FROM dbo.OrdersBig
 GROUP BY CustomerID
GO
CREATE UNIQUE CLUSTERED INDEX ix_View ON vw_Test(CustomerID)
GO



SET STATISTICS IO ON
SELECT CustomerID, SUM(Value)
  FROM OrdersBig
 GROUP BY CustomerID
 ORDER BY CustomerID
SET STATISTICS IO OFF

-- NOTA: Rodar o arquivo Indexed View 2 (selects).sql para 
-- comparar os planos de execu��o

/*-- Limpar banco
DROP VIEW vw_Test
DROP INDEX OrdersBig.ix_Value_CustomerID
DROP INDEX OrdersBig.ix_CustomerID_Value
*/

/*
  Comentar sobre limita��es, e comportamento no SQL 2000
*/