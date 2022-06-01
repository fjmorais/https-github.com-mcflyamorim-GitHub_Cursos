----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
/*
  Treinamento SQL Server Internals Parte 4 - Disk I/O
  Fabiano Neves Amorim - fabianonevesamorim@hotmail.com
  http://blogfabiano.com
*/
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

USE [master]
GO
if exists (select * from sysdatabases where name='Fabiano_Test_CheckSum')
BEGIN
  ALTER DATABASE Fabiano_Test_CheckSum SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Fabiano_Test_CheckSum
end
GO

-- Criando banco pra testes
CREATE DATABASE Fabiano_Test_CheckSum
 ON  PRIMARY 
( NAME = N'Fabiano_Test_CheckSum_1', FILENAME = N'E:\Fabiano_Test_CheckSum_1.mdf' , SIZE = 100MB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'Fabiano_Test_CheckSum_log', FILENAME = N'C:\DBs\Fabiano_Test_CheckSum_log.ldf' , SIZE = 10MB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
-- Desligando CheckSum
ALTER DATABASE Fabiano_Test_CheckSum SET PAGE_VERIFY NONE 
GO

-- 20 segundos pra rodar
USE Fabiano_Test_CheckSum
GO
DROP TABLE IF EXISTS Table1
SELECT TOP 100  
       IDENTITY(Int, 1, 1) AS Col1, 
       ISNULL(CONVERT(Char(7500), ''), '') AS Col2,
       ISNULL(CONVERT(Char(150), ''), '') AS Col3
  INTO Table1
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
SET IDENTITY_INSERT Table1 ON
INSERT INTO Table1(Col1, Col2, Col3)
VALUES(999, '', 'Fabiano Neves Amorim')
SET IDENTITY_INSERT Table1 OFF
GO
CHECKPOINT; DBCC DROPCLEANBUFFERS
GO

-- Qual a p�gina com o "Fabiano Neves Amorim" ?
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, * 
  FROM Table1
 WHERE Col1 = 999
GO
-- Physical_RID = (1:8204:0)


-- CheckSum est� desabilitado, 
-- como est�o os campos m_tornBits e m_flagBits no cabe�alho da p�gina? 
DBCC TRACEON(3604)
DBCC PAGE (Fabiano_Test_CheckSum, 1, 8204, 1)
DBCC TRACEOFF(3604)
GO
/*
PAGE HEADER:
Page @0x000001890B682000

m_pageId = (1:8204)                 m_headerVersion = 1                 m_type = 1
m_typeFlagBits = 0x0                m_level = 0                         m_flagBits = 0x8000
m_objId (AllocUnitId.idObj) = 179   m_indexId (AllocUnitId.idInd) = 256 
Metadata: AllocUnitId = 72057594049658880                                
Metadata: PartitionId = 72057594043170816                                Metadata: IndexId = 0
Metadata: ObjectId = 581577110      m_prevPage = (0:0)                  m_nextPage = (0:0)
pminlen = 7508                      m_slotCnt = 1                       m_freeCnt = 559
m_freeData = 7631                   m_reservedCnt = 0                   m_lsn = (38:256:7)
m_xactReserved = 0                  m_xdesId = (0:0)                    m_ghostRecCnt = 0
m_tornBits = 0                      DB Frag ID = 1                                                        
*/

-- Ligando o CHECKSUM
ALTER DATABASE Fabiano_Test_CheckSum SET PAGE_VERIFY CHECKSUM 
GO

-- Pergunta:
-- Nesse momento o CHECKSUM j� est� valendo pra todas as p�ginas? 




















-- Gerando uma altera��o na tabela pra for�ar a reescrita da p�gina e 
-- calcular o checksum...
UPDATE Table1 SET Col3 = 'Fabiano Neves Amorim 2'
WHERE Col1 = 999
GO
-- For�ando checkpoint pra fazer o flush dessa dirty page...
CHECKPOINT; 
GO


-- E agora, m_tornBits e m_flagBits mudaram?
DBCC TRACEON(3604)
DBCC PAGE (Fabiano_Test_CheckSum, 1, 8204, 1)
DBCC TRACEOFF(3604)
GO
/*
PAGE HEADER:
Page @0x000001890B682000

m_pageId = (1:8204)                 m_headerVersion = 1                 m_type = 1
m_typeFlagBits = 0x0                m_level = 0                         m_flagBits = 0x8200
m_objId (AllocUnitId.idObj) = 179   m_indexId (AllocUnitId.idInd) = 256 
Metadata: AllocUnitId = 72057594049658880                                
Metadata: PartitionId = 72057594043170816                                Metadata: IndexId = 0
Metadata: ObjectId = 581577110      m_prevPage = (0:0)                  m_nextPage = (0:0)
pminlen = 7658                      m_slotCnt = 1                       m_freeCnt = 433
m_freeData = 7757                   m_reservedCnt = 0                   m_lsn = (38:400:2)
m_xactReserved = 0                  m_xdesId = (0:0)                    m_ghostRecCnt = 0
m_tornBits = 1220983596             DB Frag ID = 1                                   
*/

-- Qual valor de m_tornBits em hexa?
-- Guardar esse valor.. vamos precisar dele...
SELECT CONVERT(VARBINARY(MAX), 1220983596) -- 0x48C6BB2C
GO

-- Agora vamos mudar os dados na p�gina .... 
-- Como poderiamos fazer isso? Gerar a corrup��o, ou seja, alterar
-- os dados da p�gina 8204?






















-- Poderiamos mudar via XVI32.exe, bastaria ir no offset 
-- 67207168 (8204 * 8192) e alterar o texto da p�gina...

-- Mas vamos fazer isso via DBCC WRITEPAGE just because � mais legal :-) 
-- dbcc WRITEPAGE ({'dbname' | dbid}, fileid, pageid, {offset | 'fieldname'}, length, data [, directORbufferpool])

-- Ler os dados da p�gina est�o ok...
-- Sem erros...
CHECKPOINT; DBCC DROPCLEANBUFFERS;
SELECT * 
  FROM Table1
 WHERE Col1 = 999
GO


-- Offset table do DBCC PAGE indica onde o registro est� na p�gina... 
-- Nesse caso como s� temos 1 registro por p�gina, nosso registro come�a na posi��o 
-- 0x60, SELECT CONVERT(int, 0x60), mais conhecido como 96...

OFFSET TABLE:
Row - Offset 
0 (0x0) - 96 (0x60)   

-- Cada linha tem 4 bytes do Col1 (Int) + 7500 do Col2 (Char(7500)) e a partir da� 
-- j� estamos no offset da coluna Col3
-- Lembrando dos 96 bytes do cabe�alho da p�gina... 
-- Ent�o, 96 + 7504 (7600), teriamos o temos o offset exato de onde come�a o Col3 que tem 
-- o texto "Fabiano Neves Amorim"...
-- Se a gente inserir alguma coisa no offset 7607 devemos estar 
-- bem no meio do "Fabiano Neves Amorim"
GO

-- Usando offset de 7607 pra incluir alguma coisa la no meio do texto "Fabiano Neves Amorim"
-- SELECT DATALENGTH ('XXXXX') -- 5
-- SELECT CONVERT(VARBINARY(5), 'XXXXX') -- 0x5858585858
ALTER DATABASE Fabiano_Test_CheckSum SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
DBCC WRITEPAGE (Fabiano_Test_CheckSum, 1, 8204, 7607, 5, 0x5858585858, 1);
GO
ALTER DATABASE Fabiano_Test_CheckSum SET MULTI_USER;
GO

-- O 'XXXXX' foi pra p�gina? 
-- Deve ta l� no meio do Fabiano, no final da p�gina...
DBCC TRACEON(3604)
DBCC PAGE (Fabiano_Test_CheckSum, 1, 8204, 1)
DBCC TRACEOFF(3604)
GO

-- E agora se eu tentar ler a p�gina? 
SELECT * 
  FROM Table1
 WHERE Col1 = 999
GO
/*
  Msg 824, Level 24, State 2, Line 145
  SQL Server detected a logical consistency-based I/O error: incorrect 
  checksum (expected: 0x48c6bb2c; actual: 0xdaa8d75e).
  It occurred during a read of page (1:8204) in database ID 10 at offset 0x00000004018000 in file 'E:\Fabiano_Test_CheckSum_1.mdf'.  
*/
-- 0x48c6bb2c bate com o que calculamos acima...
-- Lembra, o CONVERT do m_tornBits pra hexa...
-- SELECT CONVERT(VARBINARY(MAX), 1220983596) -- 0x48C6BB2C
-- Esse � o checksum que ele tava esperando obter ao ler a p�gina... 
-- Mas o valor retornado na leitura foi o 0xdaa8d75e

-- Confirmando o m_tornBits = 1216527148
DBCC TRACEON(3604)
DBCC PAGE (Fabiano_Test_CheckSum, 1, 8204, 1)
DBCC TRACEOFF(3604)


-- Vamos "corrigir" o problema "quebrando" o CheckSum...
-- ou seja, fazendo que ele pense que o CheckSum "errado" t� certo.
/*
  Primeiro vamos pegar o valor do hexa na mensagem de erro

  actual: 0xdaa8d75e

  Pra gravar esse valor m_tornBits precisamos converter esse hexa 
  pro formato "Little Endian"... DBCC WRITEPAGE espera receber nesse formato...

  basicamente precisamos inverter os dados do hexa... 

  De
  0xdaa8d75e
  Pra
  0x5ed7a8da

  Ao inves de fazer isso na m�o, melhor usar o SQL pra nos ajudar :-) ... 

  SELECT CAST(REVERSE(0xdaa8d75e) AS VarBinary(4))
*/


-- Vamos ent�o setar o 0X5ED7A8DA no campo m_tornBits do cabe�alho da p�gina
-- Repare que agora eu n�o precisei usar o offset, usei o "field"... 
ALTER DATABASE Fabiano_Test_CheckSum SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
DBCC WRITEPAGE (Fabiano_Test_CheckSum, 1, 8204, 'm_tornBits', 4, 0x5ed7a8da, 1);
GO
ALTER DATABASE Fabiano_Test_CheckSum SET MULTI_USER;
GO

-- Valor atual de m_tornBits = -626469026
DBCC TRACEON(3604)
DBCC PAGE (Fabiano_Test_CheckSum, 1, 8204, 1)
DBCC TRACEOFF(3604)

-- O valor gravado bate com o que o SQL estava esperando... 
-- o Hexa da msg de erro = actual: 0xdaa8d75e
SELECT CONVERT(INT, 0xdaa8d75e) -- -626469026
GO

-- Ent�o agora, na teoria, se eu ler os dados da p�gina, o SQL vai gerar o checksum, 
-- o valor vai ser -626469026, e vai bater com o que est� no cabe�alho, 
-- portanto n�o vou ter erro... 
-- Certo ? 
SELECT * 
  FROM Table1
 WHERE Col1 = 999
GO