USE Northwind
GO

-- 10 segundos para rodar...
IF OBJECT_ID('dbo.TabelaVARMAX', 'U') IS NOT NULL
	 DROP TABLE dbo.TabelaVARMAX
GO

CREATE TABLE dbo.TabelaVARMAX (
	ID INT IDENTITY NOT NULL CONSTRAINT PK_TabelaVARMAX PRIMARY KEY
	, Nome VARCHAR(100) NOT NULL DEFAULT NEWID()
	, DataRegistro DATETIME2 NOT NULL DEFAULT(SYSDATETIME())
	, Texto VARCHAR(MAX) NOT NULL DEFAULT (REPLICATE('A', 4000)) -- Preencher tabela com 4000 caracteres...
)
GO
CREATE INDEX ixNome ON TabelaVARMAX(Nome)-- INCLUDE(Texto)
GO

BEGIN TRAN
GO
INSERT INTO dbo.TabelaVARMAX DEFAULT VALUES
GO 10000
COMMIT
GO


SELECT ID, Nome 
  FROM TabelaVARMAX
 WHERE Nome LIKE 'F%'
GO
SELECT COUNT(*)
  FROM TabelaVARMAX
GO

SELECT ID, Nome 
  FROM TabelaVARMAX
 WHERE ID <= 1000
GO