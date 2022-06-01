/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/

USE NorthWind
GO
SET NOCOUNT ON;
GO

-- ****************************************************** --
-- Aten��o comandos n�o documentados devem ser utilizados --
-- com extrema precau��o e devem ser observados durante   --
-- atualiza��o de vers�es do SQL Server                   --
-- ****************************************************** --

-- DELETE FROM OrdersBig WHERE OrderDate > GetDate()
-- DROP INDEX OrdersBig.ix_OrderDate
CREATE INDEX ix_OrderDate on OrdersBig(OrderDate)
GO

/*
  DBCC TRACEON(2388)
  Muda o resultado do DBCC SHOW_STATISTICS para exibir 
  se a estat�stica � "ascendente"
  DBCC TRACEOFF(2388)
*/
DBCC SHOW_STATISTICS (OrdersBig, [ix_OrderDate])
GO

-- A partir do terceiro UPDATE com dados ascendentes a estat�stica � marcada como 
-- "Ascending" 

-- Inserir 10 linhas ascendentes
INSERT INTO OrdersBig (CustomerID, OrderDate, Value)
VALUES  (106,
         (SELECT DATEADD(d, 1, MAX(OrderDate)) FROM OrdersBig),
         ABS(CONVERT(Numeric(18,2), (CheckSUM(NEWID()) / 1000000.5))))
GO 10
-- Atualizar a estat�stica
UPDATE STATISTICS OrdersBig [ix_OrderDate] WITH FULLSCAN
GO
-- Verificar se a estat�stica � "ascendente"
DBCC SHOW_STATISTICS (OrdersBig, [ix_OrderDate])
GO

-- Exibindo o problema

-- Inserir 5 mil linhas ascendentes para testar o traceflag
INSERT INTO OrdersBig (CustomerID, OrderDate, Value)
SELECT ABS(CONVERT(Int, (CheckSUM(NEWID()) / 10000000))),
       GetDate(),
       ABS(CONVERT(Numeric(18,2), (CheckSUM(NEWID()) / 1000000.5)))
GO
INSERT INTO OrdersBig (CustomerID, OrderDate, Value)
VALUES  (ABS(CONVERT(Int, (CheckSUM(NEWID()) / 10000000))),
         (SELECT DateAdd(d, 1, MAX(OrderDate)) FROM OrdersBig),
         ABS(CONVERT(Numeric(18,2), (CheckSUM(NEWID()) / 1000000.5))))
GO 5000

-- Estimativa incorreta pois as estat�sticas est�o desatualizadas
-- e n�o atingiram o n�mero suficiente de altera��es para disparar 
-- o auto update
SET STATISTICS IO ON
SELECT * 
  FROM OrdersBig
 WHERE OrderDate > '20200101'
OPTION(RECOMPILE)
SET STATISTICS IO OFF
GO
-- O ideal seria fazer um Scan
SET STATISTICS IO ON
SELECT * 
  FROM OrdersBig WITH(index=0)
 WHERE OrderDate > '20200101'
OPTION(RECOMPILE)
SET STATISTICS IO OFF
GO


-- Utiizando os Trace Flags

/*
  DBCC TRACEON(2389)  
  Caso a estat�stica esteja marcada como ascendente adiciona 
  um novo passo no histograma com o maior Value da tabela.

  DBCC TRACEON(2390)
  Mesmo comportamento do trace flag 2389 por�m n�o requer que a 
  estat�stica esteja marcada como ascendente
  
  HINT QUERYTRACEON para usar o traceflag apenas para uma 
  determinada consulta
  https://connect.microsoft.com/SQLServer/feedback/ViewFeedback.aspx?FeedbackID=338129
  http://connect.microsoft.com/SQLServer/feedback/details/361334/the-querytraceon-option-is-not-documented
*/

SET STATISTICS IO ON
SELECT * 
  FROM OrdersBig
 WHERE OrderDate > '20200101'
OPTION(QUERYTRACEON 2390, QUERYTRACEON 2389, RECOMPILE)
SET STATISTICS IO OFF
GO

-- 2371 - Novo trace flag do SQL Server 2008 R2 SP1 
-- http://blogs.msdn.com/b/saponsqlserver/archive/2011/09/07/changes-to-automatic-update-statistics-in-sql-server-traceflag-2371.aspx