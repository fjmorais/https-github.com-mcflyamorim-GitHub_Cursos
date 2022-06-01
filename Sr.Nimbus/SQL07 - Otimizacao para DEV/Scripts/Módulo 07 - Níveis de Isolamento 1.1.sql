-- O Isolation Level padr�o para novas transa��es do SQL Server � o READ COMMITTED

use Treinamento
GO
DBCC USEROPTIONS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

DROP TABLE Teste
CREATE TABLE Teste (ID Int Identity(1,1) Primary Key, 
                    Nome VarChar(80))

INSERT INTO Teste Values('Fabiano')
INSERT INTO Teste Values('Coragem') -- Nome cachorro
INSERT INTO Teste Values('Silvio')

SELECT * FROM Teste

-- 1 - Abir o arquivo READ COMMITTED 1 e efetuar um update na tabela Teste

-- 2 - Efetuar o select na tabela Teste, verificar que o SQL Gera um block pois a tabela est� com lock
-- exclusivo pela transa��o que est� efetuando o UPDATE
-- Abrir outra sess�o e mostrar o uso do SP_Who2/sys.dm_exec_connections para ver por qual sess�o estamos sendo bloqueados
-- mostrar o uso do DBCC InputBuffer/sys.dm_exec_sql_text para ver o ultimo comando SQL executado por uma determinada sess�o.

SELECT * FROM Teste

-- Efetuar consulta para verificar outro registro que n�o est� bloqueado pelo UPDATE(ID = 2)
SELECT * FROM Teste
WHERE ID = 2

-- Exemplo de como ler dados n�o comitados sem o uso de READ UNCOMMITTED
SELECT * FROM Teste WITH(NOLOCK)

-- 3 - Alterar o ISOLATION LEVEL para READ UNCOMMITTED

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DBCC USEROPTIONS

-- 4 - Verificar os dados da tabela Teste
 
-- 5 - Efetuar um rollback no UPDATE para mostrar que o READ UNCOMMITTED pode exibir dados Sujos.
-- pois o UPDATE n�o foi comitado no banco de dados.

-- 6 - Alterar o ISOLATION LEVEL para READ COMMITTED para exibir um efeito de leitura n�o Repetida
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

-- 7 - Efetuar select na tabela teste e Verificar os registros para poder comparar com o outro select depois.
BEGIN TRAN

SELECT * FROM Teste
GO
WAITFOR DELAY '00:00:25'
-- 8 - Abrir outra sess�o e Efetuar UPDATE e COMMIT na tabela Teste pela outra transa��o 
-- aberta e fazer select na tabela teste novamente
SELECT * FROM Teste

--SELECT @@TranCount
ROLLBACK TRAN

---------------------------------------------------------------------------

-- 9 - Alterar o ISOLATION LEVEL para REPEATABLE READ
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

DBCC USEROPTIONS
BEGIN TRAN

SELECT @@TranCount

SELECT * FROM Teste
-- 10 - Verificar com SP_Lock que a tabela Teste est� em lock Compartilhado(S), 
-- quando o registro est� em lock compartilhado outras transa��es podem ler est� informa��o
-- porem n�o podem alterar os dados enquanto a tabela estiver em lock
SP_Lock @@SPID

-- 11 - Abrir a outra sess�o e tentar efetuar um UPDATE na tabela teste.
-- o Update n�o vai funcionar porque a tabela est� em Lock compartilhado devido ao meu Isolation Level.
ROLLBACK TRAN

BEGIN TRAN

SELECT * FROM Teste
GO
WAITFOR DELAY '00:00:25'
-- 12 - Abrir outra sess�o e incluir um registro na tabela teste.
-- Podemos verificar que utilizando o REPEATABLE READ evitamos o problema de leitura 
-- n�o repetida porem podem aparecer o que chamamos de dados Fantasmas, pois na
-- primeira leitura o registro n�o existia e agora j� existe, para evitar este problema podemos utilizar 
-- o isolation level SERIALIZABLE
SELECT * FROM Teste
ROLLBACK TRAN

-- 13 - Voltar o isolation level para o nivel padr�o SQL Server que � o READ COMMITTED
-- para poder exibir o uso do HINT XLock, TabLock
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

-- 14 - Iniciar uma transa��o e executar um select na tabela teste usando os Hints XLock, TabLock
BEGIN TRAN

SELECT * FROM Teste WITH(xLock, TabLock)
-- Falar sobre o PagLock, RowLock e ReadPast(L� apenas os registros comitados pulandos os n�o comitados)

-- 15 - Verifique que o SQL gerou um Lock Exclusivo na tabela Teste, 
SP_Lock @@SPID
-- 16 - Ao abrir outra sess�o e tentar efetuar um UPDATE, INSERT, DELETE e SELECT
-- veremos que n�o � possivel efetuar nenhuma destas opera��es pois a tabela est� em LOCK Exclusivo(X)

ROLLBACK TRAN

-- 16 - Alterar o isolation level para o SERIALIZABLE
-- para poder vermos como evitar fantasmas, uso parecido com o xLock TabLock que acabamos de ver
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
DBCC USEROPTIONS

BEGIN TRAN

-- 17 - Efetuar um select na tabela teste.
SELECT * FROM Teste

-- 18 - Verificar que o SQL gerou um Lock de um range dos dados lidos para evitar
-- que altera��s na tabela afim de previnir dados Sujos, Leituras n�o Repetidas ou Fantasmas.
SP_Lock @@SPID

-- 19 - Ao abrir outra sess�o e tentar efetuar um UPDATE, INSERT, DELETE e SELECT
ROLLBACK TRAN

-- 20 - Abrir outra transa��o efetuar um select na tabela teste limitando as colunas e 
-- verificar que o SQL gerou um lock apenas no range que foi lido.
BEGIN TRAN

SELECT * FROM Teste
WHERE ID BETWEEN 1 AND 2

SP_Lock @@SPID

-- 21 - Abrir outra sess�o e efetuar um UPDATE na tabela teste onde o ID seja igual a 2
-- podemos observar que n�o foi gerado lock neste registro pois o UPDATE roda normalmente
-- porem ao tentar efetuar um UPDATE no registro 1 o SQL fica esperando o 
-- registro ser liberado do LOCK.

ROLLBACK TRAN


/* Tabela de Isolation Levels
 -------------------------------------------------------------------------
|                 |"Registros Sujos" |"Leitura n�o Repetida" | "Fantasmas"|
|READ UNCOMMITED  | Sim              | Sim                   |  Sim       |
|READ COMMITED    | N�o              | Sim                   |  Sim       |
|REPEATABLE READ  | N�o              | N�o                   |  Sim       |
|SERIALIZABLE     | N�o              | N�o                   |  N�o       |
 -------------------------------------------------------------------------
*/