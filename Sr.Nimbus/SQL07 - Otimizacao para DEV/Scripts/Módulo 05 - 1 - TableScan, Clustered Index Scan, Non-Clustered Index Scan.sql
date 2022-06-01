/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/

USE NorthWind
GO
/*
  TableScan, Clustered Index Scan, Non-Clustered Index Scan
*/

/*
  TableScan � utilizado para ler os dados de uma Heap
*/

IF EXISTS(SELECT * FROM sysindexes WHERE name ='PK_Order_Details')
  ALTER TABLE Order_Details DROP CONSTRAINT PK_Order_Details
GO

-- Ex: TableScan
SELECT * FROM Order_Details

IF NOT EXISTS(SELECT * FROM sysindexes WHERE name ='PK_Order_Details')
  ALTER TABLE Order_Details ADD CONSTRAINT PK_Order_Details PRIMARY KEY(OrderID, ProductID)
GO

/*
  Clustered Index Scan le os dados no �ndice cluster.
  
  Ler os dados no �ndice cluster n�o significa que os dados
  sempre ser�o retornados na ordem do �ndice cluster.
  
  Allocation Order Scan: L� os dados com base na ordem de 
                         aloca��o das p�ginas

  Index Order Scan: L� os dados com base na ordem do �ndice
*/

-- Ex: Clustered Index Scan
SELECT * FROM Products

IF EXISTS(SELECT * FROM sysindexes WHERE name ='ix_ProductName')
  DROP INDEX ix_ProductName ON Products
GO
CREATE INDEX ix_ProductName ON Products(ProductName)
GO

-- Ex: Non-Clustered Index Scan
SELECT * FROM Products WITH(INDEX=ix_ProductName)


/*
  Nota: Voc� realmente conhece todos os efeitos do uso do 
  hint NOLOCK?
  Tem certeza?
  "NOLOCK, Bomba Rel�gio.sql"
*/


/*
  Exemplo problema com leitura na ordem de aloca��o das p�ginas (IAM)
*/
-- Preparando o ambiente
IF OBJECT_ID('Tab1', 'U') IS NOT NULL
  DROP TABLE Tab1;
GO
CREATE TABLE Tab1(Col1 VarChar(250) NOT NULL DEFAULT(NEWID()) PRIMARY KEY,
                  Col2 Char(2000) NOT NULL DEFAULT('Teste'));
GO

-- Deixar rodando esta consulta na Conex�o 1
TRUNCATE TABLE Tab1
GO
WHILE 1=1
  INSERT INTO Tab1 DEFAULT VALUES
GO


-- Opcional: Consulta Fragmenta��o da tabela
SELECT avg_fragmentation_in_percent 
  FROM sys.dm_db_index_physical_stats (DB_ID('NorthWind'),OBJECT_ID('Tab1'),1,NULL,NULL);
GO

-- Conex�o 2
IF OBJECT_ID('tempdb.dbo.#Tab1', 'U') IS NOT NULL
  DROP TABLE #Tab1;
GO
SET NOCOUNT ON;
WHILE 1 = 1
BEGIN
  -- Joga os dados da tabela Tab1 em uma tabela tempor�ria
  -- Aten��o no uso do NOLOCK para for�ar a leitura por ordem de aloca��o
  SELECT * 
    INTO #Tab1 
    FROM Tab1 WITH(NOLOCK)

  -- Agrupa os dados por Col1 (Coluna com NEWID() como Default)
  -- Se existir mais que uma linha para um �nico valor
  -- significa que os dados foram lidos mais de uma vez
  IF EXISTS(SELECT Col1
              FROM #Tab1 
             GROUP BY Col1 
            HAVING COUNT(*) > 1)
  BEGIN     
    BREAK
  END
  DROP TABLE #Tab1
END
-- Consulta os registros lidos em duplicidade
SELECT Col1, COUNT(*) AS cnt
  FROM #Tab1 
 GROUP BY Col1
HAVING COUNT(*) > 1;
GO

-- Procura o registro na tabela original
SELECT * 
  FROM Tab1
 WHERE Col1 = '81416138-CC2E-401D-982E-35F869CD9564'

-- Procura o registro na tabela tempor�ria
SELECT * 
  FROM #Tab1
 WHERE Col1 = '81416138-CC2E-401D-982E-35F869CD9564'


/*
  Exemplo problema com leitura na ordem do �ndice
*/

-- Conex�o 1
SET NOCOUNT ON
IF OBJECT_ID('Funcionarios') IS NOT NULL
  DROP TABLE Funcionarios
GO
CREATE TABLE Funcionarios(ID      Int IDENTITY(1,1) PRIMARY KEY,
                          ContactName    Char(7000),
                          Salario Numeric(18,2));
GO
-- Inserir 4 registros para alocar 4 p�ginas
INSERT INTO Funcionarios(ContactName, Salario)
VALUES('Fabiano', 1000),('Felipe',2000),('Nilton', 3000),('Diego', 4000)
GO
CREATE NONCLUSTERED INDEX ix_Salario ON Funcionarios(Salario) INCLUDE(ContactName)
GO

/*
  Fica mudando a p�gina do Fabiano para primeira p�gina e �ltima
  
  Na primeira execu��o do update o Fabiano vai da primeira p�gina 
  para a �ltima. 
  Ele ganha 1000, ou seja, 6000 - 1000 = 5000,
  No update o SQL precisa manter o �ndice ix_Salario atualizado
  na ordem correta, ou seja, o Fabiano vai para o final (maior sal�rio)
  
  Na segunda execu��o do update o Fabiano vai da �ltima p�gina
  para a primeira
  Ele ganha 5000, ou seja, 6000 - 5000 = 1000
  No update o SQL precisa manter o �ndice ix_Salario atualizado
  na ordem correta, ou seja, o Fabiano vai para o come�o (menor sal�rio)
  
  Nota: executar o update duas vezes, e mostrar os valores mudando
*/
-- Deixar rodando o update na Conex�o 1
WHILE 1 = 1
  UPDATE Funcionarios
     SET Salario = 6000 - Salario
   WHERE ContactName = 'Fabiano';

-- Conex�o 2:
SET NOCOUNT ON;
-- Pular linha
WHILE 1 = 1
BEGIN
  IF OBJECT_ID('tempdb.dbo.#TMPFuncionarios', 'U') IS NOT NULL
    DROP TABLE #TMPFuncionarios;

  SELECT * 
    INTO #TMPFuncionarios 
    FROM Funcionarios WITH(index=ix_Salario)
  IF @@ROWCOUNT < 4
    BREAK
END
SELECT * FROM #TMPFuncionarios
GO
-- Ler linha em duplicidade
WHILE 1 = 1
BEGIN
  IF OBJECT_ID('tempdb.dbo.#TMPFuncionarios', 'U') IS NOT NULL
    DROP TABLE #TMPFuncionarios;

  SELECT * 
    INTO #TMPFuncionarios 
    FROM Funcionarios WITH(index=ix_Salario)
  IF @@ROWCOUNT > 4
    BREAK
END
SELECT * FROM #TMPFuncionarios