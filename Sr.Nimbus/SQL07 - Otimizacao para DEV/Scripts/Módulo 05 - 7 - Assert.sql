/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/


USE NorthWind
GO

/*
  Assert
*/

/*
  Check Constraints
*/
IF OBJECT_ID('Tab1') IS NOT NULL
  DROP TABLE Tab1
GO
CREATE TABLE Tab1(ID Integer, Sexo CHAR(1)) 
GO 
ALTER TABLE TAB1 ADD CONSTRAINT ck_Sexo_M_F CHECK(Sexo IN('M','F')) 
GO

/*
  Se o Value retornado pela express�o do Assert
  CASE 
    WHEN [NorthWind].[dbo].[Tab1].[Sexo]<>'F' AND [NorthWind].[dbo].[Tab1].[Sexo]<>'M' THEN (0) 
    ELSE NULL
  END
*/
-- Assert validando Check Constraints
INSERT INTO Tab1(ID, Sexo) VALUES(1,'X')
GO


/*
  Foreign Keys Constraints
*/
ALTER TABLE Tab1 ADD ID_Sexos INT
ALTER TABLE Tab1 DROP CONSTRAINT ck_Sexo_M_F
ALTER TABLE Tab1 DROP COLUMN Sexo
GO 
IF OBJECT_ID('Tab2') IS NOT NULL
  DROP TABLE Tab2
GO
CREATE TABLE Tab2(ID Integer PRIMARY KEY, Sexo CHAR(1)) 
GO 
INSERT INTO Tab2(ID, Sexo) VALUES(1, 'F')
INSERT INTO Tab2(ID, Sexo) VALUES(2, 'M')
INSERT INTO Tab2(ID, Sexo) VALUES(3, 'N')
GO 
ALTER TABLE Tab1 ADD CONSTRAINT fk_Tab2 FOREIGN KEY (ID_Sexos) REFERENCES Tab2(ID)
GO

/*
  Assert valida a express�o [Expr1007] que � retornado
  como Probe column do "Left Semi Join"
  No loop join se o Value passado no insert fizer join com 
  a tabela Tab2 ent�o o Value do join ser� retornado,
  caso contrario ele ir� retornar NULL
  Se ele for NULL � porque o Value n�o existe,
  neste caso a express�o do assert ir� retornar "0"
  o que faz com que a exce��o seja gerada.
  
  CASE 
    WHEN NOT [Pass1008] AND [Expr1007] IS NULL THEN (0) 
    ELSE NULL 
  END
*/
-- Assert validando Foreign Keys Constraints
INSERT INTO Tab1(ID, ID_Sexos) VALUES(1, 4)

-- Quando n�o utilizada a coluna com a foreign key o SQL 
-- n�o utiliza o Assert
INSERT INTO Tab1(ID) VALUES(1)

-- Quando especificado NULL o SQL n�o utiliza o Assert
INSERT INTO Tab1(ID, ID_Sexos) VALUES(1, NULL)

-- Por�m quando passada uma vari�vel o SQL n�o
-- sabe que o Value � NULL ele usa o Assert e faz
-- o join com a tabela relacionada
DECLARE @i Int
INSERT INTO Tab1(ID, ID_Sexos) VALUES(1, @i)
GO

/*
  Nota: Pergunta: Compensa fazer uma valida��o e passar somente 
  a coluna que ser� utiliza no insert?
  Resposta: Depende, na maioria dos casos n�o compensa.
  
  Teste com o SQLQuery Stress(Adam Machanic)
  N�mero de Itera��es: 500
  N�mero de Threads: 40
  
  -- M�dia 19.7 segundos
  INSERT INTO NorthWind.dbo.OrdersBig(CustomerID, OrderDate, Value)
  VALUES (1, GetDate(), 0)

  -- M�dia 15.1 segundos
  DECLARE @CustomerID Int
  IF @CustomerID IS NOT NULL
  BEGIN
    INSERT INTO NorthWind.dbo.OrdersBig(CustomerID, OrderDate, Value)
    VALUES (@CustomerID, GetDate(), 0)
  END
  ELSE 
  BEGIN
    INSERT INTO NorthWind.dbo.OrdersBig(CustomerID, OrderDate, Value)
    VALUES (NULL, GetDate(), 0)
  END  
*/

/*
  Operador de StreamAggregate faz o count e caso o
  resultador for maior que 1 ent�o o assert retorna zero,
  ou seja, erro.
  
  CASE 
    WHEN [Expr1008]>(1) THEN (0) 
    ELSE NULL 
  END
*/
-- Assert validando Foreign Keys Constraints
SELECT (SELECT ContactName FROM Customers),
       *
  FROM Customers
/*
  Casos onde o QO identifica que n�o � necess�rio o Assert+StreamAggregate
*/
SELECT (SELECT TOP 1 ContactName FROM Customers),
       *
  FROM Customers
GO

SELECT (SELECT ContactName FROM Customers WHERE CustomerID = 1),
       *
  FROM Customers