/*
         Sr.Nimbus
  http://www.srnimbus.com.br
*/

USE NorthWind
GO

/*
  Optimizer WhatIF
*/

 -- Habilita traceflag 2588 para mostrar a sintaxe de DBCCs n�o documentados
DBCC TRACEON (2588) WITH NO_INFOMSGS
GO
-- Visualiza sintaxe do OPTIMIZER_WHATIF
DBCC HELP ('OPTIMIZER_WHATIF') WITH NO_INFOMSGS
/*
  dbcc OPTIMIZER_WHATIF ({property/cost_number | property_name} [, {integer_value | string_value} ])
*/


/*
  Property
  1 CPUs = N�mero de CPUs
  2 MemoryMBs = Quantidade de Mem�ria f�sica em MBs
  3 Bits = 32 ou 64 Bits
*/

-- Desabilita TF 2588
DBCC TRACEOFF (2588) WITH NO_INFOMSGS
GO

-- Habililta 3604 para enviar resultado dos comandos para console
DBCC TRACEON(3604) WITH NO_INFOMSGS
GO
-- Visualiza o status do WHATIF, e os par�metros default
DBCC OPTIMIZER_WHATIF(0) WITH NO_INFOMSGS;
GO


-- Seta o n�mero de CPUs para 8
DBCC OPTIMIZER_WHATIF(1, 8);
GO
-- Seta a quantidade de mem�ria para 2GB
DBCC OPTIMIZER_WHATIF(2, 2048);
GO
-- Seta 32 bits
DBCC OPTIMIZER_WHATIF(3, 32);
GO

-- Volta n�mero de CPUs para default
DBCC OPTIMIZER_WHATIF(1, 0);
GO
-- Volta quantidade de mem�ria para default
DBCC OPTIMIZER_WHATIF(2, 0);
GO
-- Volta processador para default
DBCC OPTIMIZER_WHATIF(3, 0);
GO

USE Northwind
GO

-- Exemplo 1 - CPU
-- Gerando planos em paralelo para m�quinas com mais CPUs

-- Dados de teste ... 20 segundos para rodar...
IF OBJECT_ID('TestRunningTotals') IS NOT NULL
  DROP TABLE TestRunningTotals
GO
CREATE TABLE TestRunningTotals (ID         Integer IDENTITY(1,1) PRIMARY KEY,
                                ID_Account Integer, 
                                ColDate    Date,
                                ColValue   Float)
GO
INSERT INTO TestRunningTotals(ID_Account, ColDate, ColValue)
SELECT TOP 500000
       ABS((CHECKSUM(NEWID()) /10000000)), 
       CONVERT(Date, GetDate() - (CHECKSUM(NEWID()) /1000000)), 
       (CHECKSUM(NEWID()) /10000000.)
FROM master.sys.columns AS c,
     master.sys.columns AS c2,
     master.sys.columns AS c3
GO
;WITH CTE1
AS
(
  SELECT ColDate, ROW_NUMBER() OVER(PARTITION BY ID_Account, ColDate ORDER BY ColDate) rn
    FROM TestRunningTotals
)
-- Removendo dados duplicados...
DELETE FROM CTE1
WHERE rn > 1
GO
CREATE UNIQUE INDEX ix ON TestRunningTotals (ID_Account, ColDate) INCLUDE(ColValue)
GO

-- Com 2 CPUs QO gera plano serial
DBCC OPTIMIZER_WHATIF(1, 2);
GO
-- Demora 4 mins e 48 segundos para rodar
CHECKPOINT; DBCC DROPCLEANBUFFERS()
GO
SELECT ID_Account,
       ColDate,
       ColValue,
       (SELECT SUM(b.ColValue)
          FROM TestRunningTotals b
         WHERE b.ColDate <= a.ColDate) AS RunningTotal
  FROM TestRunningTotals a
 ORDER BY ID_Account, ColDate
OPTION (RECOMPILE)

-- A partir de 12 CPUs QO come�a a gerar plano paralelo
DBCC OPTIMIZER_WHATIF(1, 12);
GO
-- Demora 2 mins e 40 segundos para rodar
-- Obs.: CPU fica a 100% de uso, 
-- entendeu porque o SQL s� gera o plano em paralelo quando tiver v�rios processadores?
CHECKPOINT; DBCC DROPCLEANBUFFERS()
GO
SELECT ID_Account,
       ColDate,
       ColValue,
       (SELECT SUM(b.ColValue)
          FROM TestRunningTotals b
         WHERE b.ColDate <= a.ColDate) AS RunningTotal
  FROM TestRunningTotals a
 ORDER BY ID_Account, ColDate
OPTION (RECOMPILE)
GO

-- Volta CPU para o normal
DBCC OPTIMIZER_WHATIF(1, 0);

-- Exemplo 2 - Mem�ria (Batch Sort)

-- REALIZAR TESTES NO SQL 2005 --
-- REALIZAR TESTES NO SQL 2005 --
-- REALIZAR TESTES NO SQL 2005 --
-- REALIZAR TESTES NO SQL 2005 --

/*
    ------------------------------------------------------
    ------------------------------------------------------
      At� SQL 2005 calculo utiliza 1% da mem�ria dispon�vel...

      Se a tabela for pequena QO n�o habilita batch sort
      Usa mem�ria dispon�vel para servidor para medir o
      que � uma "tabela pequena"
      "inner table" tem que ser 1% maior que a mem�ria 
      dispon�vel para o servidor.
    ------------------------------------------------------
    ------------------------------------------------------
*/
-- Digamos que o serivdor tenha 1GB de mem�ria dispon�vel
EXEC sp_configure 'show advanced options', 1
GO
RECONFIGURE
GO
EXEC sys.sp_configure N'max server memory (MB)', N'1024'
GO
RECONFIGURE WITH OVERRIDE
GO

-- Na nossa m�quininha com 1GB de mem�ria batch sort � habilitado...
-- Optimized = True
SELECT TOP 1000 *
  FROM OrdersBig
 INNER JOIN CustomersBig
    ON OrdersBig.CustomerID = CustomersBig.CustomerID
OPTION (MAXDOP 1, RECOMPILE)
GO

-- E no servidor com 512GB ?...
-- 512GB de mem�ria = 524288MB/536870912KB
DBCC OPTIMIZER_WHATIF(2, 524288);
GO
SELECT TOP 1000 *
  FROM OrdersBig
 INNER JOIN CustomersBig
    ON OrdersBig.CustomerID = CustomersBig.CustomerID
OPTION (MAXDOP 1, RECOMPILE)
GO

-- Para habilitar BatchSort em um serv com 512GB qu�o grande
-- a tabela Customers precisa ser?
-- 1% de 536870912KB (512GB) � igual a 5368709KB
-- Ou seja, apenas tabelas maiores que 5368709KB (5gb) ter�o planos Optimized = True (com BatchSort)
-- Em outras palavras, apenas tabelas com MAIS (maior que) de 671088 p�ginas de dados (SELECT ((536870912 * 1) / 100) / 8)

-- Retorna quantidade de p�ginas da tabela
DBCC SHOW_STATISTICS (CustomersBig) WITH STATS_STREAM
/*
  Stats_Stream	Rows	    Data Pages
  NULL	        1000000	 18012
*/

-- Vamos "enganar" o Otimizador
UPDATE STATISTICS CustomersBig WITH PAGECOUNT = 671088
GO

-- Ainda Optimized = false
SELECT TOP 1000 *
  FROM OrdersBig
 INNER JOIN CustomersBig
    ON OrdersBig.CustomerID = CustomersBig.CustomerID
OPTION (MAXDOP 1, RECOMPILE)
GO

-- Aumentando 1 p�gina para bater o threshold
UPDATE STATISTICS CustomersBig WITH PAGECOUNT = 671089
GO

-- Optimized = True :-)
SELECT TOP 1000 *
  FROM OrdersBig
 INNER JOIN CustomersBig
    ON OrdersBig.CustomerID = CustomersBig.CustomerID
OPTION (MAXDOP 1, RECOMPILE)
GO

-- OBERVA�AO --
/*
  Isso mudou a partir do SQL Server 2008...
  Ainda n�o descobri qual o calculo novo :-)... mas irei, um dia...
*/

-- CleanUp
UPDATE STATISTICS CustomersBig WITH PAGECOUNT = 18012