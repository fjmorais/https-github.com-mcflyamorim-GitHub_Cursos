/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/

USE NorthWind
GO

IF OBJECT_ID('HeapProducts', 'u') IS NOT NULL
  DROP TABLE HeapProducts
GO
-- Heap � uma tabela sem �ndice Cluster
CREATE TABLE HeapProducts (ProductID   Integer      NOT NULL,
                           ProductName VarChar(200) NOT NULL, 
                           Col1        VarChar(6000) NOT NULL)
GO

/*
  Insert de 1 milh�o de linhas com minimal log
*/

sp_helpindex HeapProducts
GO

INSERT INTO HeapProducts WITH(TABLOCK)
SELECT ProductID, ProductName, NEWID() FROM ProductsBig
GO

IF OBJECT_ID('ClusterProducts', 'u') IS NOT NULL
  DROP TABLE ClusterProducts
GO
-- Heap � uma tabela sem �ndice Cluster
CREATE TABLE ClusterProducts (ProductID   Integer      NOT NULL PRIMARY KEY,
                              ProductName VarChar(200) NOT NULL, 
                              Col1        VarChar(6000) NOT NULL)
GO

INSERT INTO ClusterProducts WITH(TABLOCK)
SELECT * FROM ProductsBig
GO


-- ANTES DE PROSSEGUIR EXPLICAR �NDICE CLUSTER --







/*
  A estrutura de uma heap � composta apenas por p�ginas de dados
  sem nenhuma ordem espec�fica.
  IAM (Index Allocation Map) contem as p�ginas utilizadas por uma heap.
  Todos os �ndices nonclustered contem o RID(FileID, PageID e SlotID)
  que � um ponteiro para a linha onde est�o os dados de todas as 
  colunas da tabela.
  
  DBCC IND para identificar o ID da p�gina IAM
  e a primeira p�gina de dados
*/
DBCC TRACEON (3604)
DBCC IND (NorthWind, HeapProducts, 1)
DBCC PAGE(NorthWind, 1, 417, 3)
GO

/*
  Consulta sem NonClustered:
  Qualquer consulta em uma HEAP sem um �ndice nonclustered ir� gerar um TableScan
  ou seja, o SQL ir� varrer a tabela toda com base nas p�ginas especificadas no IAM
  para procurar o valor desejado.  
*/
SELECT * FROM HeapProducts
WHERE ProductID = 10

/*
  Caso exista um �ndice nonclustered o SQL ir� utilizar este �ndice para
  localizar o registro, e depois ir� fazer um lookup para a p�gina heap
  utilizando o RID para ler os dados da tabela
  
  Vamos ver um exemplo de uma leitura NonClusterd + Heap:
*/
CREATE NONCLUSTERED INDEX ix_ProductID ON HeapProducts(ProductID)
GO

-- Vamos habilitar o STATISTICS IO para verificar quantas p�ginas 
-- s�o lidas para retornar o ProductID = 10
SET STATISTICS IO ON
SELECT * FROM HeapProducts
WHERE ProductID = 10
SET STATISTICS IO OFF

/*
  4 IOs foram realizados, vamos simular estas leituras utilizando DBCC PAGE
*/

-- Vamos identificar a p�gina Root do �ndice ix_ProductID
SELECT dbo.fn_HexaToDBCCPAGE(Root)
  FROM sys.sysindexes
 WHERE name = 'ix_ProductID'

-- Vamos navegar pelo �ndice a partir da p�gina Raiz procurando pelo valor ProductID = 10
DBCC TRACEON (3604)
DBCC PAGE (Northwind,1,51322,3) -- 1 Leitura
DBCC PAGE (Northwind,1,51320,3) -- 2 Leitura
DBCC PAGE (Northwind,1,51184,3) -- 3 Leitura Encontramos o ProductID 10
/* 
  Agora precisamos fazer o Lookup utilizando o RID na p�gina HEAP, 
  antes precisamos converter o hexa que contem o RIP
  0xC89C000001000900
  0xC89C 0000 0100 0900
  0x9CC8 0000 0001 0009
  SELECT CONVERT(Int, 0x9CC8) -- P�gina 40136
  SELECT CONVERT(Int, 0x0001) -- Arquivo 1
  SELECT CONVERT(Int, 0x0009) -- Slot 9
*/
DBCC PAGE (Northwind,1,40136,3) -- 4 Leitura
/*
  Com a 4 leitura simulamos exatamente o que o SQL Server fez para ler o 
  registro na p�gina.
*/


-- Forwarded Records --

/*
  Como nenhuma ordem � mantida, n�o ocorrem page splits nos inserts.
  Caso ocorra um UPDATE que atualiza um valor de uma p�g. para
  um valor maior do que o dispon�vel na p�gina, o SQL implementa o
  que chamamos de "Forwarded Records".
  O SQL Server move a linha para uma nova p�gina e deixa
  um ponteiro na p�gina atual apontando para onde o registro foi 
  incluido.
  
  Isso evita com que o SQL tenha que manter o RID nos �ndices 
  nonclustered atualizados.
  Mas tamb�m faz com que uma nova leitura seja efetuada para 
  ler os dados da linha.
  Por ex:
  No nosso "SELECT * FROM HeapProducts WHERE ProductID = 10"
  fizemos a leitura de 4 p�ginas, mas se eu atualizar a coluna Col1
  com um valor que far� com que o registro n�o caiba mais na p�gina
  o SQL ir� mover o registro para uma nova p�gina e deixar o ponteiro
  para a p�gina atual.
  Quando eu navegar pelo �ndice nonclustered e chegar no RID l� 
  especificado, eu irei para a p�g, e l� ter� um novo ponteiro 
  dizendo onde o registro esta. Isso gera o overread.
*/

-- Vamos gerar o Forwarded Record para o ProductID 10
UPDATE HeapProducts SET Col1 = REPLICATE('x', 500)
 WHERE ProductID = 10

/*
  Para verificar quandos forwarded records existem em uma tabela
  podemos fazer o seguinte.
  No SQL Server 2000:
  DBCC SHOWCONTIG (HeapProducts) WITH TABLERESULTS
  Temos a coluna ForwardedRecords.
  No SQL Server 2005:
  SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(N'HeapProducts'), 0, NULL , 'DETAILED')
  Temos a coluna Forwarded_Record_Count
  
  Para a consulta abaixo, podemos observar que um novo IO foi efetuado:
*/

SET STATISTICS IO ON
SELECT * FROM HeapProducts
 WHERE ProductID = 10
SET STATISTICS IO OFF

/*
  Vamos copiar os DBCC PAGE que utilizamos para chegar na p�g da Heap
  para verificar como ficou a p�gina.
*/
DBCC PAGE (Northwind,1,40136,3) -- 4 Leitura
/*
Slot 9 Offset 0x1f04 Length 9

Record Type = FORWARDING_STUB        Record Attributes =                  Record Size = 9
Memory Dump @0x000000001064BF04
0000000000000000:   04a00100 00010000 00�����������������.�.......        
Forwarding to  =  file 1 page 416 slot 0    
*/

/*
  Podemos observar que o registro foi movido para o arquivo 1 
  p�g 416 slot 0.
  Maravilha!, Vamos olhar a p�g 416
*/

DBCC PAGE (Northwind,1,416,3) -- 5 Leitura

/*
  Pergunta, o que ir� acontecer se o Registro ProductID = 10
  for atualizado novamente, e novamente com um valor que n�o cabe
  na p�g. 416?
  
  Teremos um forwarded record de um forwarded record?
  Vamos ver o que acontece?
*/

/*
  Primeiro precisamos encher a P�g, para isso vamos
  atualizar os registros da p�g.
  Para saber at� onde devemos atualizar os registros precisamos
  saber quanto espa�o livre tem na p�g.
  Para isso � s� olhar o valor do m_freeCnt no cabe�alho da p�g.
  onde esta o registro ProductID = 10, que � a p�gina que queremos
  "encher"
*/
-- Consulta a coluna m_freeCnt
DBCC PAGE (NorthWind,1,416,3)
GO
/*
  Caso exista alguma registro na p�g. atualizamos ele para um 
  valor maior, caso n�o exista, vamos atualizar v�rios 
  registos da tabela para que v�rios Forward Records ocorram.
*/
UPDATE HeapProducts SET Col1 = REPLICATE('x', 5000)
 WHERE ProductID = <ID DE UM REGISTRO DA P�g>
GO
UPDATE HeapProducts SET Col1 = REPLICATE('x', 5000)
 WHERE ProductID BETWEEN 20 AND 50
GO

-- Consulta novamente a coluna m_freeCnt
DBCC PAGE (NorthWind,1,416,3)
GO
UPDATE HeapProducts SET Col1 = REPLICATE('x', 5000)
 WHERE ProductID = 10
GO


/*
  Agora o registro ProductID 10 n�o cabe mais na p�gina
  416 slot 0, vamos ver o que tem l� agora.
*/ 

DBCC PAGE (NorthWind,1,416,3)
GO
/*
  O Slot 0 n�o existe mais n� p�gina 416.
  Na verdade ele existe mas n�o esta mais sendo utilizado, 
  se rodarmos o DBCC Page com a op��o 2 de visualiza��o 
  vemos no slot array que o Slot 0 n�o esta mais sendo utilizado
*/
DBCC PAGE (NorthWind,1,416,2)
GO
/*
OFFSET TABLE:
Row - Offset                         
1 (0x1) - 818 (0x332)                
0 (0x0) - 0 (0x0)     
*/

/* 
  Mas se o registro n�o esta mais na p�gina 416 
  onde ele est�?
  Vamos olhar na p�g do original do registro.
*/
DBCC PAGE (Northwind,1,40136,3) -- 4 Leitura

/*
Opa, maravilha, agora o SQL foi na p�gina onde 
originalmente estava o registro e atualizou o valor da p�g
e slot atual.

Slot 9 Offset 0x1eb2 Length 9
Record Type = FORWARDING_STUB        Record Attributes =                  Record Size = 9
Memory Dump @0x000000001064BEB2
0000000000000000:   0453d300 00010000 00�����������������.S�......        
Forwarding to  =  file 1 page 54099 slot 0                               
*/
DBCC PAGE (NorthWind,1,54099,3)
/* 
  ProductID 10 l� esta ele. :-)
*/


/*
  Agora que j� brincamos bastante com os forwarded records, 
  como resolver este tipo de fragmenta��o?
  
  A maneira mais simples seria criar um �ndice cluster na tabela
  e depois excluir o �ndice.
*/


-- Vamos ver quantos forwarded records temos na tabela
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(N'HeapProducts'), 0, NULL , 'DETAILED')
GO
CREATE CLUSTERED INDEX TempIndex ON HeapProducts (ProductID)
GO
DROP INDEX TempIndex ON HeapProducts
GO
-- Vamos ver quantos forwarded records temos na tabela
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(N'HeapProducts'), 0, NULL , 'DETAILED')
GO


-- Script para localizar todoas heaps do banco de dados
SELECT so.Name, si.rowcnt
  FROM sys.sysindexes si
 INNER JOIN sys.objects so
    ON si.id = so.object_id
 WHERE indid = 0
   AND so.type = 'U'
 ORDER BY 2 DESC