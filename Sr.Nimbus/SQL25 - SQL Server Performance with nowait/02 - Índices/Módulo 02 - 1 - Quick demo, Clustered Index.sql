/*
  SQL25 - SQL Server Performance with nowait
  http://www.srnimbus.com.br
*/


USE NorthWind
GO

-- Overview �ndice --
/*
  Dados desordenados
  ?-----------------------?
  D  B  I  A  F  E  G  H  C

  SELECT * FROM Tab WHERE Letra = 'H'
  
  Varre a lista de valores procurando o 'H'
  Total de letras lidas ser� o total de letras
  existentes. Ou seja, 9.

  Dados ordenados
  ------------------------>
  A  B  C  D  E  F  G  H  I
  
  SELECT * FROM Tab WHERE Letra = 'H'
  
  Varre a lista de valores procurando o 'H'
  at� achar a pr�xima ocorr�ncia maior que 'H'
  Total de letras lidas = 9

  Dados Indexados (�rvore b-tree)
  |-------------------------|
  |          | E |          |
  |-------------------------|
  |   | D |         | I |   |
  |-------------------------|
  ||A| |B| |C|   |F| |G| |H||
  |-------------------------|

  SELECT * FROM Tab WHERE Letra = 'H'
  
  Navega pela �rvore balanceada procurando pelo 'H'
  Algoritmo de busca mais ou menos assim.
  
  Iniciando do n�vel raiz e faz a seguinte valida��o
  1 - 'H' � menor ou igual a 'E' ? N�o.
  2 - 'H' � menor ou igual a 'I' ? Sim.
  3 - L� o pr�ximo valor ('F'). � igual a 'G'? N�o.
  4 - L� o pr�ximo valor ('G'). � igual a 'G'? Sim.
  5 - L� o pr�ximo valor ('H'). � igual a 'G'? N�o. Termina a leitura
  Total de letras lidas = 5
*/



-- Analogia �ndice cluster --
/*
  Quantos �ndices temos em um Livro?
  
  
  
  
  R: 3, o �ndice cluster do livro � o n�mero das p�ginas
*/


/*
  Dados da tabela s�o ordenados na ordem da chave.
  Por isso quando efetuamos um select sem ORDER BY
  os dados vem na ordem da chave do �ndice
*/
SELECT * FROM Products
ORDER BY ProductID
/*
  Portanto, podemos dizer que o ORDER BY ProductID � 
  redundante? Pois se os dados j� ser�o retornados na 
  ordem do �ndice n�o preciso de order by. Correto?
  
  
  
  
  R:N�o. Pode me citar alguns exemplos onde a leitura 
  n�o ser� retornada na ordem esperada?
  
  R: NOLOCK, TABLOCK, READPAST, Advanced Scan, Parallelismo
  
  Nota: Voc� conhece todos os efeitos do uso do NoLock?
  Tem certeza?
  
  Repare que no plano de execu��o abaixo o SQL fez um 
  index scan e a propriedade Ordered do Clustered Index Scan
  � igual a True
*/

-- Modo correto, � sempre especificar o Order By
SELECT *
  FROM Products
 ORDER BY ProductID



/*
  Consulta para ler o CustomerID = 80000
  Temos um �ndice cluster definido como primary key
  na coluna CustomerID, portanto o SQL consegue
  utilizar este �ndice para retornar os dados da consulta
*/
SET STATISTICS IO ON
SELECT *
  FROM CustomersBig WITH(FORCESCAN) -- Hint para for�ar o SCAN
 WHERE CustomerID = 80000
SET STATISTICS IO OFF

/*
  E utilizando o �ndice?
*/

SET STATISTICS IO ON
SELECT *
  FROM CustomersBig
 WHERE CustomerID = 80000
SET STATISTICS IO OFF