/*
  SQL25 - SQL Server Performance with nowait
  http://www.srnimbus.com.br
*/




USE NorthWind
GO

/*
  �ndices nonclustered s�o pequenas c�pias dos dados
  da tabela, com sua pr�pria �rvore balanceada.
  
  �ndices nonclustered podem existir em tabelas HEAP
  ou Cluster.
  
  Quando a tabela � uma HEAP o �ndice nonclustered cont�m
  um RID para a localiza��o da linha na HEAP.
  Quando a tabela tem um �ndice cluster, o �ndice 
  nonclustered cont�m a chave do �ndice cluster.
*/


-- Exemplo de falta de �ndice nonclustered
SET STATISTICS IO ON
SELECT CustomerID, CompanyName, Col1 
  FROM CustomersBig
 WHERE CompanyName = 'Folies gourmandes 15BB3518'
SET STATISTICS IO OFF

-- Na aus�ncia da palavra NONCLUSTERED
-- o �ndice � considerado NONCLUSTERED.
CREATE NONCLUSTERED INDEX ix_CompanyName ON CustomersBig(CompanyName)
GO

/*
  Agora a consulta pode fazer proveito do �ndice ix_CompanyName
*/
SET STATISTICS IO ON
SELECT CustomerID, CompanyName, Col1 
  FROM CustomersBig
 WHERE CompanyName = 'Centro comercial Moctezuma B6950DA3'
SET STATISTICS IO OFF


-- Filtered Index --

/*
  No SQL Server 2008 temos os �ndices filtrados.
  Existem v�rios cen�rios onde podemos e devemos utilizar
  �ndices filtrados, vejamos alguns:
*/

/*
  Tenho uma tabela onde s� consulto os dados mais recentes.
  No caso de minha tabela de Orders, digamos que eu sempre
  leio os dados maiores que 2017. 
  Porque ent�o guardar os dados dos outros anos no �ndice?
*/

CREATE INDEX ix_OrderDate_Greater_Than_2005 ON OrdersBig(OrderDate)
WHERE OrderDate > '20170201'
GO

SET STATISTICS IO ON
SELECT OrderID, OrderDate
  FROM OrdersBig
 WHERE OrderDate > '20170201'
SET STATISTICS IO OFF

/*
  Filtered Index em Procedures
*/

-- DROP PROC st_TestFilteredIndex 
CREATE PROC st_TestFilteredIndex @Dt DateTime
AS
BEGIN
  SELECT OrderID, OrderDate
    FROM OrdersBig
   WHERE OrderDate > @Dt
END
GO

-- SQL n�o usa o �ndice porque o filtro � um par�metro
EXEC st_TestFilteredIndex @Dt = '20170201'

-- Alternativa 1: Reescrever a proc com option recompile
DROP PROC st_TestFilteredIndex 
GO
CREATE PROC st_TestFilteredIndex @Dt DateTime
AS
BEGIN
  SELECT OrderID, OrderDate
    FROM OrdersBig
   WHERE OrderDate > @Dt
  OPTION (RECOMPILE)
END
GO
EXEC st_TestFilteredIndex @Dt = '20170201'

-- Alternativa 2: Reescrever a proc com o filtro fixo
DROP PROC st_TestFilteredIndex 
GO
CREATE PROC st_TestFilteredIndex @Dt DateTime
AS
BEGIN
  IF @Dt < '20170201'
  BEGIN
    SELECT OrderID, OrderDate
      FROM OrdersBig
     WHERE OrderDate > @Dt
  END
  ELSE
  BEGIN
    SELECT OrderID, OrderDate
      FROM OrdersBig
     WHERE OrderDate > @Dt
       AND OrderDate > '20170201'
  END
END
GO

-- Visualizar plano estimado (CTRL+L)
EXEC st_TestFilteredIndex @Dt = '20170201'

/*
  Plano que ser� inclu�do em cache cont�m o acesso a tabela 
  utilizando os dois �ndices
*/


/*
  Outro cen�rio complicado era � cria��o de �ndices �nicos
  mas que aceitavam NULL.
  Vamos ver o problema.
*/

IF OBJECT_ID('TMP_Unique') IS NOT NULL
  DROP TABLE TMP_Unique
GO
CREATE TABLE TMP_Unique (ID Int)
GO

/*
  Como n�o posso permitir que os Valuees dupliquem, ent�o crio um �ndice
  �nico com base na coluna ID
*/

CREATE UNIQUE INDEX ix_Unique ON TMP_Unique(ID)
GO

-- Vamos tentar inserir um o Value "1" duas vezes
INSERT INTO TMP_Unique (ID) VALUES(1) --  OK
INSERT INTO TMP_Unique (ID) VALUES(1) -- ERRO

INSERT INTO TMP_Unique (ID) VALUES(NULL) --  OK
INSERT INTO TMP_Unique (ID) VALUES(NULL) -- ERRO

/*
  At� ai ok, mas e se eu quiser aceitar Valuees NULL duplicados?
  A solu��o existente seria criar uma view indexada com o 
  WHERE IS NOT NULL
  Com o �ndice filtered ficou bem mais f�cil
*/
TRUNCATE TABLE TMP_Unique
GO
DROP INDEX ix_Unique ON TMP_Unique
GO
CREATE UNIQUE INDEX ix_Unique ON TMP_Unique(ID)
WHERE ID IS NOT NULL

INSERT INTO TMP_Unique (ID) VALUES(NULL) -- OK
INSERT INTO TMP_Unique (ID) VALUES(NULL) -- OK

INSERT INTO TMP_Unique (ID) VALUES(1) -- OK
INSERT INTO TMP_Unique (ID) VALUES(1) -- ERRO


-- Computed Index --
/*
  Podemos indexar colunas calculadas para obter melhor performance.
  Um exemplo classico � o seguinte:
*/

SELECT *
  FROM OrdersBig
 WHERE YEAR(OrderDate) = 2010
 
/*
  Mesmo que voc� criar um �ndice por OrderDate o SQL 
  n�o ir� utilizar o �ndice.
  Uma alternativa � criar uma coluna calculada e indexar a coluna.
*/

ALTER TABLE OrdersBig ADD Orders_Year AS YEAR(OrderDate)
GO

CREATE INDEX ix_Orders_Year ON OrdersBig(Orders_Year) INCLUDE(OrderDate, CustomerID, Value)
GO

SELECT * 
  FROM OrdersBig
 WHERE YEAR(OrderDate) = 2010

/*
  No oracle � bem mais f�cil, � s� criar o �ndice com base na express�o
  CREATE INDEX ix_Orders_Year ON OrdersBig(YEAR(OrderDate))
*/


-- Consulta o tamanho dos �ndices
SELECT Object_Name(p.Object_Id) As Tabela,
       I.Name As Indice, 
       Total_Pages,
       Total_Pages * 8 / 1024.00 As MB
  FROM sys.Partitions AS P
 INNER JOIN sys.Allocation_Units AS A 
    ON P.Hobt_Id = A.Container_Id
 INNER JOIN sys.Indexes AS I 
    ON P.object_id = I.object_id 
   AND P.index_id = I.index_id
 WHERE p.Object_Id = Object_Id('ProductsBig')
