/**************************************************************************************************
	
	Sr. Nimbus Servi�os em Tecnolgia LTDA
	
	Curso: SQL07 - M�dulo 03
	
**************************************************************************************************/

USE MASTER
GO

IF EXISTS (SELECT * FROM SYSDATABASES WHERE [Name] = 'Inside')
BEGIN
	DROP DATABASE Inside
END
GO

CREATE DATABASE Inside
GO

USE Inside
GO

IF EXISTS (SELECT [ID] FROM Sysobjects WHERE [Name] = 'Aluno' AND XType = 'U')
	DROP TABLE Aluno
GO

CREATE TABLE Aluno
(
	Codigo INT NOT NULL PRIMARY KEY,
	Nome VARCHAR(255)
)
GO

INSERT INTO Aluno VALUES (1, 'Alexandre')
INSERT INTO Aluno VALUES (2, 'Juliana')
INSERT INTO Aluno VALUES (3, 'Luciano')
INSERT INTO Aluno VALUES (4, 'Patricia')
GO

SELECT * FROM Aluno
GO

/*
	Conex�o de an�lise
*/
select 
	TL.request_session_id,
	TL.request_type,
	TL.request_mode,
	TL.request_status,
	TL.resource_type,
	TL.resource_description,	
	TL.resource_database_id
from sys.dm_tran_locks AS TL
GO

SELECT * 
FROM sys.dm_tran_session_transactions AS ST
WHERE ST.is_user_transaction = 1

EXEC SP_LOCK
EXEC SP_WHO2

SELECT @@SPID

/*
	READ COMMITTED
*/

-- Conex�o 01
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

-- Conex�o 02
BEGIN TRANSACTION
	UPDATE Aluno SET Nome = 'Carla' WHERE Codigo = 2
	
-- Conex�o 01
SELECT * FROM Aluno
SELECT @@TRANCOUNT

-- Conex�o 02
ROLLBACK TRANSACTION

/*
	READ UNCOMMITTED
*/

-- Conex�o 01
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Conex�o 02
BEGIN TRANSACTION
	UPDATE Aluno SET Nome = 'Carla' WHERE Codigo = 2
	
-- Conex�o 01
-- Dirty read
SELECT * FROM Aluno

-- Conex�o 02
ROLLBACK TRANSACTION

/*
	REPETEABLE READ
*/

-- Conex�o 01
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

BEGIN TRANSACTION
	SELECT * FROM Aluno
	select @@TRANCOUNT

-- Conex�o 02
-- ANALISA LOCKS

BEGIN TRANSACTION
	UPDATE Aluno SET Nome = 'Carla' WHERE Codigo = 2
COMMIT TRANSACTION
	
-- Conex�o 01 (Ainda dentro da transa��o)
-- NON REPETEABLE READ
	SELECT * FROM Aluno
COMMIT TRANSACTION

-- Conex�o 01
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

SELECT @@TRANCOUNT

BEGIN TRANSACTION
	SELECT * FROM Aluno

-- Conex�o 02
-- ANALISA LOCKS

BEGIN TRANSACTION
	UPDATE Aluno SET Nome = 'Juliana' WHERE Codigo = 2
	-- STOP EXECUTION
ROLLBACK TRANSACTION

	SELECT * FROM Aluno

BEGIN TRANSACTION 
	INSERT INTO Aluno VALUES (5, 'Renata')
	-- Verificar LOCKs
COMMIT TRANSACTION

-- Conex�o 01
-- PHANTOMS (Registro 5)
	SELECT * FROM Aluno
COMMIT TRANSACTION

/*
	SERIALIZABLE
*/

-- Conex�o 01
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
select @@TRANCOUNT
BEGIN TRANSACTION
	SELECT * FROM Aluno

-- Conex�o 02
-- ANALISA LOCKS

BEGIN TRANSACTION 
	INSERT INTO Aluno VALUES (6, 'Sabrina')
	-- STOP EXECUTION
ROLLBACK TRANSACTION


-- COMO EVITAR ALGU�M DE COLOCAR UM SERIALIZABLE?