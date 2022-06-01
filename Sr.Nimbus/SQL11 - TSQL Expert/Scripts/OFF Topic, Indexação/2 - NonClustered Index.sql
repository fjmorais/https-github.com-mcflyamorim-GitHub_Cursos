/*
  Author: Fabiano Neves Amorim
  E-Mail: fabiano_amorim@bol.com.br
  http://blogfabiano.com
  http://www.simple-talk.com/author/fabiano-amorim/
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

/*
  Novamente, vamos simular os 6 IOs usando o DBCC PAGE
*/
-- Vamos identificar a p�gina Root do �ndice ix_CompanyName
SELECT dbo.fn_HexaToDBCCPAGE(Root) 
  FROM sys.sysindexes
 WHERE name = 'ix_CompanyName'
   AND id = OBJECT_ID ('CustomersBig')

-- Vamos navegar pelo �ndice a partir da p�gina Raiz procurando pelo Value
-- CustomerID = 80000
DBCC TRACEON (3604)
DBCC PAGE (Northwind,1,10594,3) -- 1 Leitura
DBCC PAGE (Northwind,1,10597,3) -- 2 Leitura
DBCC PAGE (Northwind,1,27829,3) -- 3 Leitura Encontramos o CompanyName = 'Centro comercial Moctezuma B6950DA3'

-- Com o CustomerID 74045, vamos navegar pelo �ndice cluster para 
-- achar o Value da coluna Col1, pois ela n�o pertence ao �ndice

SELECT dbo.fn_HexaToDBCCPAGE(Root)
  FROM sys.sysindexes
 WHERE name = 'xpk_CustomersBig'
   AND id = OBJECT_ID ('CustomersBig')

DBCC PAGE (Northwind,1,14730,3) -- 4 Leitura
DBCC PAGE (Northwind,1,14729,3)  -- 5 Leitura
DBCC PAGE (Northwind,1,21235,3) -- 6 Leitura Encontramos o CustomerID = 80000


-- Covered Index --

/*
  Para a consulta que utilizamos acima, poderiamos evitar este extra
  passo de buscar os dados da coluna Col1 e Col2 no �ndice criando um 
  covered index, ou seja, um �ndice que cobre toda minha consulta.
  No SQL Server 2000 a �nica forma de fazer isso era incluindo a
  coluna Col1 como chave do �ndice, mas isso n�o faz muito sentido.
  Pois neste caso n�o fazemos filtro na coluna Col1 e Col2. Ent�o s� precisamos
  que o Value esteja no �ltimo n�vel do �ndice, para o SQL n�o precisar
  do lookup.
  
  A partir do SQL Server 2005 podemos utilizar a clausula INCLUDE.
  Ex:
*/

CREATE INDEX ix_CompanyName_Col1_Col2 ON CustomersBig(CompanyName) INCLUDE(Col1, Col2)
GO

SET STATISTICS IO ON
SELECT CustomerID, CompanyName, Col1 
  FROM CustomersBig
 WHERE CompanyName = 'Centro comercial Moctezuma B6950DA3'
SET STATISTICS IO OFF
/*
  Como podemos observar a consulta acima s� necessita de 3 IOs
  O Value da Coluna Col1 e Col2 foi incluido no leaf level(nivel folha) 
  do �ndice.
*/

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
  Exclus�o �mplicita de NULLs
*/

CREATE INDEX ix_CityID ON CustomersBig(CityID) INCLUDE(CompanyName)
WHERE CityID IS NOT NULL

/*
  A consulta abaixo ja sabe que estou procurando um Value
  que n�o � NULL, ent�o ele pode usar o �ndice
*/
SELECT CustomerID, CityID, CompanyName
  FROM CustomersBig
 WHERE CityID = 2

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

-- Hash Index --

-- Preparando o banco
CREATE INDEX ix_ProductID ON Order_DetailsBig(ProductID)
/*
  Uma tentativa para minimizar os custos ocupados pelo espa�o de um �ndice
  � gerar um hash de um Value e criar o �ndice com base neste hash.
  
  Um exemplo classico � na busca de colunas muito grandes, C�digo de barras
  T�tulos, Descri��o de Produtos etc...
  Vejamos a �deia abaixo:
*/


-- A consulta abaixo faz um index scan pois n�o existe nenhum
-- �ndice nas colunas ProductName e col1
SELECT ProductsBig.ProductID, SUM(OrdersBig.Value)
  FROM ProductsBig
 INNER JOIN Order_DetailsBig
    ON ProductsBig.ProductID = Order_DetailsBig.ProductID
 INNER JOIN OrdersBig
    ON Order_DetailsBig.OrderID = OrdersBig.OrderID
 WHERE ProductsBig.ProductName = 'Camembert Pierrot 4809558D'
   AND ProductsBig.Col1 = 'FF9B8A91-0652-409B-A095-A5B8296FC239'
 GROUP BY ProductsBig.ProductID
GO

-- DROP INDEX ix_ProductName_Col1 ON ProductsBig
CREATE INDEX ix_ProductName_Col1 ON ProductsBig(ProductName, Col1)
GO

-- Agora conseguimos usar o �ndice ix_ProductName_Col1 
SELECT ProductsBig.ProductID, SUM(OrdersBig.Value)
  FROM ProductsBig
 INNER JOIN Order_DetailsBig
    ON ProductsBig.ProductID = Order_DetailsBig.ProductID
 INNER JOIN OrdersBig
    ON Order_DetailsBig.OrderID = OrdersBig.OrderID
 WHERE ProductsBig.ProductName = 'Camembert Pierrot 4809558D'
   AND ProductsBig.Col1 = 'FF9B8A91-0652-409B-A095-A5B8296FC239'
 GROUP BY ProductsBig.ProductID
GO

/*
  Mas qual o custo deste �ndice?... 
  J� que as colunas s�o bem grandes.
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

/*
  Resultado da consulta acima:
  Tabela        Indice                   Total_Pages  MB
  ------------- -------------------      ------------ -----------
  ProductsBig	  xpk_ProductsBig	         9869	        77.1015625
  ProductsBig	  ix_ProductName_Col1	     9590	        74.9218750
*/

/*
  Conforme podemos observar o tamanho do �ndice � praticamente
  o tamanho da tabela
*/


/*
  Vejamos se conseguimos melhor isso com o uso do HashIndex
*/

-- ALTER TABLE ProductsBig DROP COLUMN Hash_ProductName_Col1
ALTER TABLE ProductsBig ADD Hash_ProductName_Col1 AS BINARY_CHECKSUM(ProductName, Col1)
GO
-- DROP INDEX ix_Hash_ProductName_Col1 ON ProductsBig
-- DROP INDEX ix_ProductName_Col1 ON ProductsBig
CREATE INDEX ix_Hash_ProductName_Col1 ON ProductsBig(Hash_ProductName_Col1) 
GO

-- Cuidado pois o hash pode gerar colis�es
SELECT Hash_ProductName_Col1, Count(*)
  FROM ProductsBig
 GROUP BY Hash_ProductName_Col1
HAVING Count(*) > 1
 ORDER BY 2 DESC

-- O SQL utilizou o HashIndex
SELECT ProductsBig.ProductID, SUM(OrdersBig.Value)
  FROM ProductsBig WITH(index=ix_Hash_ProductName_Col1)
 INNER JOIN Order_DetailsBig
    ON ProductsBig.ProductID = Order_DetailsBig.ProductID
 INNER JOIN OrdersBig
    ON Order_DetailsBig.OrderID = OrdersBig.OrderID    
 WHERE ProductsBig.Hash_ProductName_Col1 = BINARY_CHECKSUM('Camembert Pierrot 4809558D', 'FF9B8A91-0652-409B-A095-A5B8296FC239')
   AND ProductsBig.ProductName = 'Camembert Pierrot 4809558D'
   AND ProductsBig.Col1 = 'FF9B8A91-0652-409B-A095-A5B8296FC239'
 GROUP BY ProductsBig.ProductID

-- Vejamos o tamanho dos �ndices
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

/*
  Resultado da consulta acima:
  Tabela        Indice                   Total_Pages  MB
  ------------- -------------------      ------------ -----------
  ProductsBig	  xpk_ProductsBig	         9869	        77.1015625
  ProductsBig	  ix_Hash_ProductName_Col1	1781	        13.9140625
  ProductsBig	  ix_ProductName_Col1	     9590	        74.9218750
*/

-- Porque o SQL Server n�o usa meu �ndice ? -- 
/*
  Vamos analisar um exemplo bem interessante em rela��o a esta velha d�vida.
*/

-- Criando os dados para o teste
USE Tempdb
GO
IF OBJECT_ID('TABTeste') IS NOT NULL
  DROP TABLE TABTeste
GO

CREATE TABLE TabTeste(ID    Int Identity(1,1) Primary Key,
                      CompanyName  VarChar(50) NOT NULL,
                      Value Int NOT NULL)
GO
DECLARE @i INT
SET @i = 0
WHILE (@i < 1000)
BEGIN
    INSERT INTO TabTeste(CompanyName, Value)
    VALUES('Fabiano', 0) 
    SET @i = @i + 1
END;

-- Analisando os dados da tabela
SELECT * FROM TabTeste

-- Criando um �ndice por CompanyName e Value
CREATE NONCLUSTERED INDEX ix_TesteSem_Include ON TabTeste(CompanyName, Value)
GO

/*
  Consulta os dados de todos os registros onde CompanyName seja
  igual a 'Fabiano' e o Value seja menor ou igual a 10, 
  ordenado por ID, ou seja com estes dados, a tabela toda.
  
  A consulta abaixo n�o usa o �ndice:
*/
SELECT ID
  FROM TabTeste
 WHERE CompanyName = 'Fabiano'
   AND Value <= 10
 ORDER BY ID
 
-- Re-Criando o �ndice, mas desta vez incluindo a coluna Value 
-- como INCLUDE ele passa a utilizar o �ndice, porque?
CREATE NONCLUSTERED INDEX ix_Teste_Include ON TabTeste(CompanyName) INCLUDE(Value)
GO

-- Usando o �ndice ix_Teste_Include
SELECT ID
  FROM TabTeste
 WHERE CompanyName = 'Fabiano'
   AND Value <= 10
 ORDER BY ID
 
-- Apagar o indice para continuar os testes...
DROP INDEX TabTeste.ix_Teste_Include 
GO

-- For�ando o uso do �ndice com o hint INDEX
-- temos um sort pesado (82% do custo da consulta)
SELECT ID
  FROM TabTeste WITH(INDEX = ix_TesteSem_Include)
 WHERE CompanyName = 'Fabiano'
   AND Value <= 10
 ORDER BY ID
GO

/*
  A pergunta �, porque o SQL n�o pode confiar no ID 
  que esta no �ndice noncluster? 
  Porque � necess�rio fazer o SORT?
  Se eu remover o ORDER BY, os dados j� vem na ordem de ID.
*/
SELECT ID
  FROM TabTeste WITH(INDEX = ix_TesteSem_Include)
 WHERE CompanyName = 'Fabiano'
   AND Value <= 10
GO

/*
  Vamos analisar como os dados est�o armazenados no �ndice
*/

-- Pega o hexadecimal da primeira p�gina do �ndice na coluna ROOT
SELECT id, name, root, dbo.fn_HexaToDBCCPAGE(Root) 
  FROM SysIndexes
 WHERE ID = OBJECT_ID('TabTeste')
   AND name = 'ix_TesteSem_Include'
   
-- Usando a fn_HexaToDBCCPAGE para gerar o DBCC PAGE
SELECT dbo.fn_HexaToDBCCPAGE(0xEE0000000100)

-- Vamos navegar pelo �ndice a partir da p�gina Raiz
DBCC TRACEON (3604)
DBCC PAGE (2,1,238,3)
-- Pegamos o Value de ChildPageId para ver os dados da pr�xima p�gina na �rvore balanceada do �ndice
DBCC PAGE(2,1,187,3)
GO
DBCC PAGE(2,1,249,3)

/* 
  Como podemos ver os dados est�o ordenados por ID no �ndice, 
  porque n�o confiar neste ordem? 
  
  E se eu fizer o seguinte insert?
*/

SET IDENTITY_INSERT TabTeste ON 
INSERT INTO TabTeste(ID, CompanyName, Value) VALUES(-1, 'Fabiano', 1) 
SET IDENTITY_INSERT TabTeste OFF 

-- Agora rodando novamente a consulta sem o order by para simular a leitura na ordem do indice
-- Esta ordenado?
SELECT ID
  FROM TabTeste
 WHERE CompanyName = 'Fabiano'
   AND Value <= 10
   
/*
  Lembre-se o �ndice esta ordenado por CompanyName e Value.
  A ordem do ID depende primeiro da ordena��o de CompanyName e Value.
*/