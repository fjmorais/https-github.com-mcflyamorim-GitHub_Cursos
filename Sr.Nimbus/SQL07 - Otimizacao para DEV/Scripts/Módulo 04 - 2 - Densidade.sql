/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/


USE NorthWind
GO

/*
  Densidade
*/

/*
  Criando base para testes
*/
IF OBJECT_ID('Test') IS NOT NULL
  DROP TABLE Test
GO
CREATE TABLE Test(Col1 INT)
GO
DECLARE @i INT
SET @I = 0

WHILE @i < 5000
BEGIN
  INSERT INTO Test VALUES(@i)
  INSERT INTO Test VALUES(@i)
  INSERT INTO Test VALUES(@i)
  INSERT INTO Test VALUES(@i)
  INSERT INTO Test VALUES(@i)
  SET @i = @i + 1
END
GO

CREATE STATISTICS Stat ON Test(Col1)
GO

-- Tabela com 25 mil linhas e 5 mil valores distintos
-- Cada valor repete 5 vezes
SELECT * FROM Test

/*
  Calculando a densidade da coluna
  1.0 / 5000 = 0.0002
*/ 
SELECT 1. / COUNT(DISTINCT Col1) 
  FROM Test
-- Resultado: 0.00020000000

/*
  Com este valor quais as informa��es podemos responder?
  
  1 - Quantos valores distintos temos na coluna Col1?
  R: F�cil. 1.0 / 0.0002 = 5000
  
  2 - Qual � a m�dia de valores duplicados na coluna Col1?
  R: F�cil. 0.0002 * 25000 = 5
  
  Onde o SQL utiliza isso?
*/

/*
  Caso eu utiize uma vari�vel o SQL N�o consegue utilizar o 
  histograma para estimar quantas linhas ser�o retornadas.
  Neste caso ele utiliza densidade para calcular a m�dia 
  de valores distintos como estimativa.
  O que neste caso foi perfeito.
*/
DECLARE @i Integer
SET @i = 2000
SELECT *
  FROM Test
 WHERE Col1 = @i


/*
  Quantas linhas existem para cada grupo?
  
  Abaixo o SQL usa a informa��o da densidade para estimar
  quantas linhas distintas ser�o retornadas para cada grupo
*/
SELECT Col1, COUNT(*)
  FROM Test
 GROUP BY Col1
 ORDER BY Col1
 
/*
  Abaixo em uma consulta mais simples o SQL tamb�m utiliza
  a densidade para analisar quantas linhas distintas ser�o 
  retornadas ap�s a agrega��o
*/
SELECT DISTINCT Col1
  FROM Test