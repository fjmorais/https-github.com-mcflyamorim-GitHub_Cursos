/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/

USE AdventureWorks2008R2
GO

-- Query abaixo faz o scan e depois aplica um filtro
SELECT SalesOrderID, SalesOrderNumber
  FROM Sales.SalesOrderHeader
 WHERE OrderDate = '20010702'
GO

-- Query abaixo com o HINT para usar o mesmo �ndice da query acima
-- faz o filtro como predicate direto na leitura do �ndice
SELECT SalesOrderID, SalesOrderNumber
  FROM Sales.SalesOrderHeader WITH(INDEX([PK_SalesOrderHeader_SalesOrderID]))
 WHERE OrderDate = '20010702'
GO

/*
  O problema s� acontece com tabelas com ComputedColumns.
  As colunas calculadas est�o impedindo o uso da otimiza��o que
  joga o filtro dos dados para o Engine do SQL enquanto ele est�
  lendo os dados de mem�ria/disco.
  For�ando o �ndice o SQL usa esta regra chamada SelToTrivialFilter
*/

-- Connect Item: https://connect.microsoft.com/SQLServer/feedback/details/495862/query-optimizer-generates-incorrect-plan-with-a-deffered-filter-operator