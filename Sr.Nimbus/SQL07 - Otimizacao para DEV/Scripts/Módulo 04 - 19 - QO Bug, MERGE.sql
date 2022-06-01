/*
  Sr.Nimbus - SQL07 - Otimizacao para DEV
  http://www.srnimbus.com.br
*/


USE tempdb
GO

DECLARE @TabDestino TABLE (ID   Int PRIMARY KEY,
                           Col1 VarChar(80));
 
DECLARE @TabOrigem TABLE (ID   Int PRIMARY KEY,
                          Col1 VarChar(80));

INSERT @TabDestino(ID, Col1)
VALUES (1, 'Teste Value 1'), (3, 'Teste Value 3');

INSERT @TabOrigem (ID, Col1)
VALUES (1, 'Teste Value 1 Alterado'), -- Linha J� Existe  = Update
       (2, 'Teste Value 2 Insert'),   -- Linha N�o Existe = Insert
       (3, 'Teste Value 3 Alterado'), -- Linha J� Existe  = Update
       (4, 'Teste Value 5 Insert');   -- Linha N�o Existe = Insert

/* Merge
  Se o registro j� existe (WHEN MATCHED) ent�o atualiza a coluna @TabDestino.Col1
  Se o registro n�o existe (NOT MATCHED) ent�o insere a linha na tabela TabDestino
  Neste caso os IDs 2 e 4 ser�o inseridos e os IDs  1 e 3 ser�o atualizados
  
  A clausula OUTPUT retorna a a��o que ocorreu ($action), e os IDs inseridos 
  ou atualizados.
*/

 MERGE @TabDestino
 USING @TabOrigem
    ON [@TabOrigem].ID = [@TabDestino].ID
  WHEN MATCHED THEN
UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
  WHEN NOT MATCHED BY TARGET THEN 
INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
OUTPUT $action AS Acao,
       DELETED.Col1 AS Col1_Antigo,
       INSERTED.Col1 AS Col1_Novo,
       INSERTED.ID AS ID_Novo
OPTION(RECOMPILE);
/*
  Resultado:
  Acao       Col1_Antigo     Col1_Novo                ID_Novo
  ---------- --------------- ------------------------ -----------
  UPDATE     Teste Value 1   Teste Value 1 Alterado   1
  INSERT     NULL            Teste Value 1 Alterado   1
  UPDATE     Teste Value 3   Teste Value 3 Alterado   3
  INSERT     NULL            Teste Value 3 Alterado   3

  Conforme esperado, a resultado do MERGE diz que 2 linhas foram inseridas, os IDs 1 e 3 ?????
  O Value da coluna Col1_Novo tambem parece n�o estar correta.
*/

SELECT * FROM @TabDestino
/*
  Resultado:
  ID          Col1
  ----------- ------------------------
  1           Teste Value 1 Alterado
  2           Teste Value 2 Insert
  3           Teste Value 3 Alterado
  4           Teste Value 5 Insert

  Conforme podemos observar no select acima OUTPUT do MERGE retornou Valuees incorretos.
*/

-- Outro erro ainda mais grave
use tempdb
GO

DECLARE @TabDestino TABLE (ID   Int PRIMARY KEY,
                           Col1 VarChar(80));
 
DECLARE @TabOrigem TABLE (ID   Int PRIMARY KEY,
                          Col1 VarChar(80));

INSERT  @TabDestino(ID, Col1)
VALUES  (1, 'Teste Value 1'), (3, 'Teste Value 3');


INSERT  @TabOrigem (ID, Col1)
VALUES  (1, 'Teste Value 1 Alterado'), -- Linha j� Existe = Update
        (2, 'Teste Value 2 Insert'), -- N�o existe = Insert
        (3, 'Teste Value 3 Alterado'), -- Linha j� Existe = Update
        (4, 'Teste Value 5 Insert'); -- N�o existe = Insert

/*
  Na consulta abaixo irei apenas incluir uma nova clausula para quando encontrar uma 
  linha com o Value 'Teste Value 1' apaga o registro
*/

 MERGE @TabDestino
 USING @TabOrigem
    ON [@TabOrigem].ID = [@TabDestino].ID
  WHEN MATCHED                              -- Nova linha
   AND [@TabDestino].Col1 = 'Teste Value 1' -- Nova linha
  THEN DELETE                               -- Nova linha
  WHEN MATCHED THEN
UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
  WHEN NOT MATCHED BY TARGET THEN 
INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
OUTPUT $action AS Acao,
       DELETED.Col1 AS Col1_Antigo,
       INSERTED.Col1 AS Col1_Novo,
       INSERTED.ID AS ID_Novo;

/*
  Resultado:
  Msg 0, Level 11, State 0, Line 0
  Erro grave no comando atual. Os resultados, se houver algum, dever�o ser descartados.
*/

-- Entendendo o problema

/*
  Plano de execu��o do Merge (simplificado):
  |--Clustered Index Merge(OBJECT:(@TabDestino), SET:([Col1] = [Expr1009]) ACTION:([Action1008]))
     |--Clustered Index Insert(OBJECT:(@TabDestino), SET:([Col1] = [Col1],[ID] = [ID]) DEFINE:([TrgPrb1006] = [PROBE VALUE]))
        |--Clustered Index Scan(OBJECT:(@TabOrigem))  

  Conforme podemos observar este � um plano um tanto quanto estranho, 
  era de esperar um Join entre as tabelas, mas n�o vemos o join.
  
  A otimiza��o LOJPrjGetToApply faz com que o Join seja evitado:
  O plano � otimizado para n�o fazer o Join, desta forma o SQL tenta fazer o insert, 
  caso ele receba um erro de viola��o de Constraint(neste caso a PK), ele faz o update.
  
  Se n�s mudarmos o MERGE incluindo um filtro qualquer no Join (ID >= 0) esta otimiza��o passa a n�o ser
  poss�vel, e o SQL Gera um plano diferente, desta vez com o Loop Join, por exemplo:

   MERGE @TabDestino
   USING @TabOrigem
      ON [@TabOrigem].ID = [@TabDestino].ID
     AND [@TabOrigem].ID >= 0
    WHEN MATCHED THEN
  UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
    WHEN NOT MATCHED BY TARGET THEN 
  INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
  OUTPUT $action AS Acao,
         DELETED.Col1 AS Col1_Antigo,
         INSERTED.Col1 AS Col1_Novo,
         INSERTED.ID AS ID_Novo
  OPTION(RECOMPILE);

  Plano de execu��o do Merge (simplificado):
  |--Clustered Index Merge(OBJECT:(@TabDestino), SET:(Insert, [Col1] = [Expr1009],[ID] = [Expr1010]), SET:(Update, [Col1] = [Expr1009]) ACTION:([Action1008]))
     |--Nested Loops(Left Outer Join, OUTER REFERENCES:([ID]))
        |--Clustered Index Scan(OBJECT:(@TabOrigem))
        |--Compute Scalar(DEFINE:([TrgPrb1006]=(1)))
           |--Filter(WHERE:(STARTUP EXPR([ID]>=(0))))
              |--Clustered Index Seek(OBJECT:(@TabDestino), SEEK:([ID]=[ID]) ORDERED FORWARD)

*/

SELECT * FROM sys.dm_exec_query_transformation_stats
WHERE Name = 'LOJPrjGetToApply'

/*
  Guardar o resultado da dm_exec_query_transformation_stats, rodar a consulta
  novamente com OPTION(RECOMPILE) e verificar que a coluna succeeded aumenta.
*/

-- Alternativas para resolu��o do problema

-- Alternativa 1: N�o deixar que o SQL utilize a regra for�ando o uso de
-- outros algor�tmos para o join
 MERGE @TabDestino
 USING @TabOrigem
    ON [@TabOrigem].ID = [@TabDestino].ID
   AND [@TabOrigem].ID >= 0
  WHEN MATCHED THEN
UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
  WHEN NOT MATCHED BY TARGET THEN 
INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
OUTPUT $action AS Acao,
       DELETED.Col1 AS Col1_Antigo,
       INSERTED.Col1 AS Col1_Novo,
       INSERTED.ID AS ID_Novo
OPTION (RECOMPILE, MERGE JOIN, HASH JOIN);

-- Alternativa 2: Incluir uma regra "segura" para evitar o uso da otimiza��o. 
-- Por exemplo, for�ando um filtro em que confiamos "ID <> -1"
 MERGE @TabDestino
 USING @TabOrigem
    ON [@TabOrigem].ID = [@TabDestino].ID
   AND [@TabOrigem].ID <> -1
  WHEN MATCHED THEN
UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
  WHEN NOT MATCHED BY TARGET THEN 
INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
OUTPUT $action AS Acao,
       DELETED.Col1 AS Col1_Antigo,
       INSERTED.Col1 AS Col1_Novo,
       INSERTED.ID AS ID_Novo
OPTION (RECOMPILE);

-- Alternativa 3: Desabilitar a otimiza��o LOJPrjGetToApply
DBCC RULEOFF('LOJPrjGetToApply');
 MERGE @TabDestino
 USING @TabOrigem
    ON [@TabOrigem].ID = [@TabDestino].ID
  WHEN MATCHED THEN
UPDATE SET [@TabDestino].Col1 = [@TabOrigem].Col1
  WHEN NOT MATCHED BY TARGET THEN 
INSERT VALUES ([@TabOrigem].ID, [@TabOrigem].Col1)
OUTPUT $action AS Acao,
       DELETED.Col1 AS Col1_Antigo,
       INSERTED.Col1 AS Col1_Novo,
       INSERTED.ID AS ID_Novo
OPTION (RECOMPILE);
DBCC RULEON('LOJPrjGetToApply');

-- Alternativa 4: Habilitar o TraceFlag 8758, n�o recomendado

-- Connect Item - https://connect.microsoft.com/SQLServer/feedback/details/581548/sql2008-r2-merge-statement-with-only-table-variables-fails