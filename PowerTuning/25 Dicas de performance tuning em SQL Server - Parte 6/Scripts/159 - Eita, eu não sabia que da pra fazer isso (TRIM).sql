-- Dicas do mestre Itzik em 
-- https://sqlperformance.com/2019/10/t-sql-queries/overlooked-t-sql-gems

USE Northwind
GO

-- TRIM no SQL2017, � muito mais que apenas remover espa�o em branco do come�o e do fim... 
-- :-) 

-- O uso b�sico, de fato � esse...
DECLARE @i AS VARCHAR(200) = '   Alguma coisa    ';
SELECT '[' + TRIM(@i) + ']'
GO


-- Por�m, � poss�vel, especificar o que voc� quer remover no come�o e fim...
-- Sintax = TRIM ( [ characters FROM ] string )

DECLARE @i AS VARCHAR(200) = '*****Alguma coisa*****';
SELECT '[' + TRIM('*' FROM @i) + ']'
GO