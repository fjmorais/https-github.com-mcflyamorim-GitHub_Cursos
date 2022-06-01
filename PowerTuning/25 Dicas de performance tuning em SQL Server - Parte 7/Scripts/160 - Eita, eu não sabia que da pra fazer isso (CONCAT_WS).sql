-- Dicas do mestre Itzik em 
-- https://sqlperformance.com/2019/10/t-sql-queries/overlooked-t-sql-gems

USE Northwind
GO

-- Digamos que eu queira retornar uma coluna com tudo concatenado...
SELECT FirstName, LastName, City, Region, Country 
  FROM Employees
GO


-- D� ruim por causa do NULL
SELECT FirstName, LastName, City, Region, Country, (FirstName + ',' + LastName + ',' + City + ',' + Region + ',' + Country )
  FROM Employees
GO

-- Nada que um ISNULL n�o resolva
SELECT FirstName, LastName, City, Region, Country, 
      ISNULL(FirstName, '') + ',' + ISNULL(LastName, '')  + ',' + ISNULL(City, '')  + ',' + ISNULL(Region, '')  + ',' + ISNULL(Country, '')  
  FROM Employees
GO
-- Mas da� ficou o ",," ai no meio... Ex: "Steven,Buchanan,London,,UK"

-- Aaa, mas da� taca um REPLACE e bla bla bla, j� viu onde vamos chegar n�... 


-- Ou, no SQL2017 podemos fazer assim: 
SELECT FirstName, LastName, City, Region, Country, 
      CONCAT_WS(',', FirstName, LastName, City, Region, Country)
  FROM Employees
GO
