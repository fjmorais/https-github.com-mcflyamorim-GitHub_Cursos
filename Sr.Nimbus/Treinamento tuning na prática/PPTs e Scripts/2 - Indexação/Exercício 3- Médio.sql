USE Northwind
GO

INSERT INTO ProductsBig(ProductName)
VALUES('Tourti�re')
GO

SELECT *
  FROM ProductsBig
 WHERE ProductsBig.ProductName COLLATE Latin1_General_CI_AI LIKE 'Tourtiere%'
GO

