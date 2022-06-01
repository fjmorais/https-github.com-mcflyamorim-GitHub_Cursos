USE Northwind
GO

-- Preparando demo
DELETE FROM Order_DetailsBig
WHERE OrderID > 1000000
DELETE FROM OrdersBig
WHERE OrderID > 1000000
GO
INSERT INTO OrdersBig(CustomerID, OrderDate, Value )
VALUES  (1, GetDate(),999)
INSERT INTO Order_DetailsBig(OrderID, ProductID, Shipped_Date, Quantity)
VALUES  (@@Identity, 1, GetDate()-30, 9), 
        (@@Identity, 2, GetDate()-30, 9), 
        (@@Identity, 3, GetDate()-30, 9)
GO

------------------------------------------------
--- Pedidos com mesma qtde de itens vendidos ---
------------------------------------------------
/*
  Escreva uma consulta que retorne informa��es
  sobre pedidos onde a quantidade de itens vendidos
  � a mesma para todos os itens vendidos.

  Banco: NorthWind
  Tabelas: OrdersBig e Order_DetailsBig
  Retornar as informa��es de
  OrderID, ProductID, Quantity, OrderDate e b.Value
*/

-- Exemplo resultado esperado:
/*
  OrderID	ProductID	Quantity	OrderDate	  Value
  1000005	1	        9	       2013-05-10	 999.00
  1000005	2	        9	       2013-05-10	 999.00
  1000005	3	        9	       2013-05-10	 999.00
*/


-- Query 1
CHECKPOINT; DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE();
GO
SELECT DISTINCT a.OrderID, a.OrderDate, a.Value
  FROM OrdersBig a
 INNER JOIN Order_DetailsBig b
    ON a.OrderID = b.OrderID
 WHERE NOT EXISTS(SELECT 1 
                    FROM Order_DetailsBig c
                   WHERE c.OrderID = b.OrderID
                     AND c.Quantity <> b.Quantity)
OPTION (MAXDOP 1)
GO

-- Query 2
CHECKPOINT; DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE();
GO
SELECT a.OrderID, a.OrderDate, a.Value
  FROM OrdersBig a
 INNER JOIN Order_DetailsBig b
    ON a.OrderID = b.OrderID
 GROUP BY a.OrderID, a.OrderDate, a.Value
HAVING MIN(b.Quantity) = MAX(b.Quantity)
OPTION (MAXDOP 1)
GO