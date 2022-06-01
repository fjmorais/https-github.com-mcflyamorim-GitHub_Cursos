/*
  SQL25 - SQL Server Performance with nowait
  http://www.srnimbus.com.br
*/

-----------------------------------------
-- Estat�sticas correlatas e densidade --
-----------------------------------------

USE Northwind
GO


-- Preparando o ambiente
SET NOCOUNT ON;
IF OBJECT_ID('AluguelCarros') IS NOT NULL
  DROP TABLE AluguelCarros
GO
CREATE TABLE AluguelCarros(ID Int NOT NULL IDENTITY(1,1) PRIMARY KEY,
                           TipoCarro VarChar(200),
                           Value Numeric(18,2),
                           Carro VarChar(200) NOT NULL DEFAULT NEWID())
GO

;WITH TipoCarros
AS
 (
  SELECT * FROM (VALUES(50, 70, 'Economico'), 
                       (71, 90, 'Intermediario'),
                       (91, 120, 'Executivo'),
                       (120, 200, 'Luxo')) AS Tab(MenorValue, MaiorValue, TipoCarro)
 )
INSERT INTO AluguelCarros(TipoCarro, Value)
SELECT TipoCarro, MenorValue+ ABS(CHECKSUM(NEWID())) % (MaiorValue-MenorValue)
  FROM TipoCarros
GO 1000


-- Consultando os dados da tabela
SELECT * 
  FROM AluguelCarros
OPTION (USE HINT ('FORCE_DEFAULT_CARDINALITY_ESTIMATION'))
GO

/*
  Veriricar todos os carros do tipo Luxo com valor menor que 110 reais
  
  QO estima que 128,5 linhas ser�o retornadas.  
*/
SELECT * 
  FROM AluguelCarros
 WHERE TipoCarro = 'Luxo'
   AND Value < 60
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO

-- Vamos criar um �ndice para ajudar o SQL na estimativa
-- DROP INDEX ix_TipoCarro_Value ON AluguelCarros 
CREATE INDEX ix_TipoCarro_Value ON AluguelCarros (TipoCarro, Value)
GO

-- E agora a estimativa?
-- Continua com 137,5 linhas, e n�o usou o �ndice
SELECT * 
  FROM AluguelCarros
 WHERE TipoCarro = 'Luxo'
   AND Value < 60
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO

-- Como ele chegou nestas 137,5 linhas?
/*
  Como o SQL n�o consegue entender a correla��o entre as colunas
  ele utiliza a densidade das colunas para poder fazer a estimativa.
  
  1 - Calcula a densidade da coluna TipoCarro
  2 - Cria uma estat�stica para a coluna Value
  3 - Calcula a densidade da coluna Value
  4 - Densidade do TipoCarro * Densidade do Value
  5 - Densidade da multiplica��o (passo 4)

  Vamos simular estes passos com o c�digo abaixo
*/

DBCC SHOW_STATISTICS(AluguelCarros, ix_TipoCarro_Value)
GO
SELECT 1000./4000. -- Densidade = 0.250000

-- Vericar se existe mais alguma estat�stica na tabela
sp_helpstats AluguelCarros
GO

-- Consultar a estat�stica da coluna Value
DBCC SHOW_STATISTICS(AluguelCarros, _WA_Sys_00000003_7D0E9093)
GO

SELECT 514./4000. -- Densidade = 0.128500
GO

SELECT 0.250000 * 0.128500 -- Densidade final = 0.034375000000
GO

SELECT 0.032125000000 * 4000.
GO


/*
  1 - Alternativa
  For�ar o uso do �ndice
*/

-- Corrige o problema de fazer o Scan, mas n�o corrige a estimativa
SELECT * 
  FROM AluguelCarros WITH(index=ix_TipoCarro_Value)
 WHERE TipoCarro = 'Luxo'
   AND Value < 60
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO

/*
  2 - Alternativa
  Criar um �ndice coberto
*/

CREATE INDEX ix_Covered_Index ON AluguelCarros(TipoCarro, Value) INCLUDE(Carro)
GO
-- Continua corrigindo o problema de fazer o Scan, mas sem corrigir a estimativa
SELECT * 
  FROM AluguelCarros
 WHERE TipoCarro = 'Luxo'
   AND Value < 60
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO

DROP INDEX ix_Covered_Index ON AluguelCarros
GO

/*
  3 - Alternativa
  Filtered Statistics
*/

CREATE STATISTICS ix_AluguelCarros_Economico ON AluguelCarros(Value) 
 WHERE TipoCarro = 'Economico'
GO
CREATE STATISTICS ix_AluguelCarros_Intermediario ON AluguelCarros(Value) 
 WHERE TipoCarro = 'Intermediario'
GO
CREATE STATISTICS ix_AluguelCarros_Executivo ON AluguelCarros(Value) 
 WHERE TipoCarro = 'Executivo'
GO
CREATE STATISTICS ix_AluguelCarros_Luxo ON AluguelCarros(Value) 
 WHERE TipoCarro = 'Luxo'
GO
-- Criar uma estat�sticas para cobrir novas categorias
CREATE STATISTICS ix_AluguelCarros_Outros ON AluguelCarros(Value) 
 WHERE TipoCarro <> 'Luxo' 
   AND TipoCarro <> 'Executivo' 
   AND TipoCarro <> 'Intermediario'
   AND TipoCarro <> 'Economico'
GO

-- Consulta utilizando o �ndice corretamente
SELECT * 
  FROM AluguelCarros
 WHERE TipoCarro = 'Luxo'
   AND Value < 60
OPTION(RECOMPILE, QueryTraceON 9481) -- TF 9481 desabilita o novo cardinatlity estimator
GO