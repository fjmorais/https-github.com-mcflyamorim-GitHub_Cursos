/*
  SQL25 - SQL Server Performance with nowait
  http://www.srnimbus.com.br
*/



----------------------------------------
--------- Qtde de dias sem vendas ------
----------------------------------------

/*
  Escreva uma consulta que retorne todos os pedidos
  e quantos dias se passaram desde a �ltima venda efetuada
  por cliente

  Banco: NorthWind
  Tabela: Orders

  Obs.: Pode ser utilizado recursos do SQL Server 2012
  Bonus: Escrever consulta que rode no SQL2005
*/

-- Resultado esperado:
/*
  CustomerID  orderdate               orderid     dias desde a �ltima compra
  ----------- ----------------------- ----------- ---------------------
  1           1997-08-25 00:00:00.000 10643       NULL
  1           1997-10-03 00:00:00.000 10692       39
  1           1997-10-13 00:00:00.000 10702       10
  1           1998-01-15 00:00:00.000 10835       94
*/
