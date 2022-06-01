/*
  SQL25 - SQL Server Performance with nowait
  http://www.srnimbus.com.br
*/


USE Northwind
GO

-- Preparando o ambiente
-- DROP INDEX ixCityID on CustomersBig 
CREATE INDEX ixCityID on CustomersBig (CityID)
GO



/*
  QO estima que 8.9 linhas ser�o retornadas da tabela cidades.
  -- 7 linhas s�o retornadas
*/
SELECT CustomersBig.ContactName, 
       Cities.Description 
  FROM CustomersBig
 INNER JOIN Cities
    ON CustomersBig.CityID = Cities.CityID
 WHERE Cities.State = 'SP'
   AND Cities.Description LIKE 'Mar%'
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO

-- F�rmula utilizada para fazer a estimativa
-- https://www.simple-talk.com/sql/sql-training/questions-about-sql-server-distribution-statistics/
Estimativa = QtdeLinhasNaTabela * ( "seletividade 1" * "seletividade 2"...N )


/*
  Novo CE estima que 26.3136 linhas ser�o retornadas da tabela cidades.
  -- 7 linhas s�o retornadas
  Consequ�ncia, Join ir� retornar mais linhas e lookup n�o vale a pena.
  Plano bem diferente.
*/
SELECT CustomersBig.ContactName, 
       Cities.Description
  FROM CustomersBig
 INNER JOIN Cities
    ON CustomersBig.CityID = Cities.CityID
 WHERE Cities.State = 'SP'
   AND Cities.Description LIKE 'Mar%'
OPTION(RECOMPILE)
GO

-- F�rmula utilizada para fazer a estimativa
-- http://www.sqlperformance.com/2014/01/sql-plan/cardinality-estimation-for-multiple-predicates

Estimativa = Cardinalidade * Seletividade1 * SQRT(Seletividade2) * SQRT(SQRT(Seletividade3)) * SQRT(SQRT(SQRT(Seletividade4)))...


-- Planos podem mudar para bom e para ruim -- 
   -- ... testar testar testar ... -- 

-- Para melhorar a estimativa das consultas acima estat�sticas 
-- filtradas podem ser criadas para cada estado