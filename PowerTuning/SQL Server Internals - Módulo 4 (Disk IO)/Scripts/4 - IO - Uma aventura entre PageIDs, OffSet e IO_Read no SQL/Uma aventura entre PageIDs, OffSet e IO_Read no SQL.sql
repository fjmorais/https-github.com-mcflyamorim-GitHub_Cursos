----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
/*
  Treinamento SQL Server Internals Parte 4 - Disk I/O
  Fabiano Neves Amorim - fabianonevesamorim@hotmail.com
  http://blogfabiano.com
*/
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

-- Preparando demo 
USE master
GO

-- Apenas 1GB de memória... quero fazer I/O... não quero ler do disco :-) 
sp_configure 'show advanced options', 1;  
RECONFIGURE;
GO 
EXEC sys.sp_configure N'max server memory (MB)', N'1024'
GO
RECONFIGURE WITH OVERRIDE
GO


-- Rodar apenas se necessário (não tiver rodado ainda)
/*

-- 30 segundos pra rodar...
-- Criando um banco pra me ajudar a limpar o BP data cache de apenas 1 banco
if exists (select * from sysdatabases where name='Test2')
BEGIN
  ALTER DATABASE Test2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Test2
end
GO
CREATE DATABASE Test2
 ON  PRIMARY 
( NAME = N'Test2', FILENAME = N'C:\DBs\Test2.mdf' , SIZE = 5GB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Test2_log', FILENAME = N'C:\DBs\Test2_log.ldf' , SIZE = 100MB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO
USE Test2
GO
-- Criar 2 tabelas com +- 900MB
IF OBJECT_ID('Products1') IS NOT NULL
  DROP TABLE Products1
GO
SELECT TOP 115000 IDENTITY(Int, 1,1) AS ProductID, 
       SubString(CONVERT(VarChar(250),NEWID()),1,8) AS ProductName, 
       CONVERT(VarChar(250), NEWID()) AS Col1,
       CONVERT(Char(4000), NEWID()) AS Col2
  INTO Products1
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
ALTER TABLE Products1 ADD CONSTRAINT xpk_Products1 PRIMARY KEY(ProductID)
GO
SELECT * INTO Products2 FROM Products1
GO
ALTER TABLE Products2 ADD CONSTRAINT xpk_Products2 PRIMARY KEY(ProductID)
GO
-- Meter migué pro SQL pra evitar que ele faça disfavoring das minhas leituras...
-- Quando eu ler essas tabelas, quero que ele remove as tabelas do banco Test1 e 
-- Não que fique concorrendo com ele mesmo...
UPDATE STATISTICS Products1 WITH ROWCOUNT = 1, PAGECOUNT = 1
UPDATE STATISTICS Products2 WITH ROWCOUNT = 1, PAGECOUNT = 1
GO

DROP PROC IF EXISTS st_LimpaCache
GO
CREATE PROC st_LimpaCache
AS
BEGIN
  -- Lendo as tabelas (+- 1.8GB) pra forçar que o SQL limpe o cache 
  -- do banco Test1
  DECLARE @i Int
  SELECT @i = COUNT(*) FROM Test2.dbo.Products1
  SELECT @i = COUNT(*) FROM Test2.dbo.Products2
END
GO

-- 16 segundos pra rodar
if exists (select * from sysdatabases where name='Test1')
BEGIN
  ALTER DATABASE Test1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE Test1
END
GO

CREATE DATABASE [Test1]
 ON  PRIMARY 
( NAME = N'Test1', FILENAME = N'E:\Test1.mdf' , SIZE = 51200KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Test1_log', FILENAME = N'E:\Test1_log.ldf' , SIZE = 1MB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO

-- 30 segundos pra rodar
USE [Test1]
GO
DROP TABLE IF EXISTS Table1
SELECT TOP 1000  
       IDENTITY(BigInt, 1, 1) AS Col1, 
       ISNULL(CONVERT(VarChar(250), NEWID()), '') AS Col2,
       ISNULL(CONVERT(VarChar(7000), REPLICATE('x', 5000)), '') AS Col3
  INTO Table1
  FROM sysobjects A
 CROSS JOIN sysobjects B
 CROSS JOIN sysobjects C
 CROSS JOIN sysobjects D
GO
SET IDENTITY_INSERT Table1 ON
INSERT INTO Table1(Col1, Col2, Col3)
VALUES(99999999999, 'Fabiano Neves Amorim', REPLICATE('x', 5000))
SET IDENTITY_INSERT Table1 OFF
GO
SET IDENTITY_INSERT Table1 ON
INSERT INTO Table1(Col1, Col2, Col3)
VALUES(100000000000, 'Fabiano Neves Amorim 2', REPLICATE('x', 5000))
SET IDENTITY_INSERT Table1 OFF
GO
ALTER TABLE Table1 ADD CONSTRAINT xpkTable1 PRIMARY KEY(Col1)
GO
CHECKPOINT; DBCC DROPCLEANBUFFERS
GO

*/


-- Começando demo...
CHECKPOINT; DBCC DROPCLEANBUFFERS
GO


-- Qual o FileID e PageID com os dados do "Fabiano Neves Amorim"? 
SELECT sys.fn_PhysLocFormatter(%%physloc%%) AS Physical_RID, 
       * 
  FROM Test1.dbo.Table1
 WHERE Col1 = 99999999999
GO
-- Physical_RID = (1:2368:0)

-- Confirmando se os dados estão lá via DBCC PAGE
-- String "Fabiano Neves Amorim" deve estar no começo da página...
DBCC TRACEON(3604)
DBCC PAGE (Test1, 1, 2368, 1)
DBCC TRACEOFF(3604)
GO

-- Qual o Offset preciso ler pra achar o "Fabiano Neves Amorim" ? 
-- É só fazer o PageID * 8192 (que é o tamanho de uma página no SQL)...
SELECT 2368 * 8192 /*8KB page*/ -- 19398656
GO

-- 1 - Colocar o banco offline
-- 2 - Abrir no XVI32.exe
-- 3 - Ir pro offset 19398656 e procurar pelo "Fabiano Neves Amorim" 
USE master
GO
-- Pegar o path do arquivo
SELECT filename FROM Test1.dbo.sysfiles WHERE fileid = 1
GO
ALTER DATABASE Test1 SET OFFLINE WITH ROLLBACK IMMEDIATE
GO

-- Volta o banco pra online
ALTER DATABASE Test1 SET ONLINE
GO


/*

  Será que bate com o io_offset da sys.dm_io_pending_io_requests?
  No SQL ele vai começar o I/O por onde? direto na página 2368 que 
  tem os dados que eu quero ler?
  
  É um Clustered Index Seek... Então ele na verdade começa na 
  página Root né?... Depois navega pela b-tree até chegar na 2368

*/

-- Página está lá no BP data cache...
SELECT * FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID('Test1') 
AND file_id = 1
AND page_id = 2368
GO

-- Removendo dados da tabela Table1 do cache
EXEC Test2.dbo.st_LimpaCache
GO

-- Pressão no BP tirou a pág 2368...
SELECT * FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID('Test1') 
AND file_id = 1
AND page_id = 2368
GO

-- Confirmando se ramp-up já parou...
-- Quando target for atingido pela primeira vez, o SQL para de 
-- fazer o ramp-up (a cada 1 leitura, ao invés de enviar read de 8KB, manda 64KB... 
-- ou seja, 8 páginas)
-- Pra essa demo, o ramp-up não pode entrar, senão vai estragar o que quero fazer... 
-- :-)
SELECT object_name,
       counter_name,
       cntr_value / 1024. AS MBs
  FROM sys.dm_os_performance_counters
 WHERE counter_name IN('Target Server Memory (KB)', 'Total Server Memory (KB)')
GO


-- Qual é o ID da Root Page?
USE Test1
GO
SELECT p.object_id, au.allocation_unit_id, p.index_id, p.rows,
       au.type_desc, au.first_page, au.root_page, au.first_iam_page,
       master.dbo.fn_HexaToDBCCPAGE(first_page) AS dbcc_first_page, 
       master.dbo.fn_HexaToDBCCPAGE(root_page) AS dbcc_root_page, 
       master.dbo.fn_HexaToDBCCPAGE(first_iam_page) AS dbcc_first_iam_page
FROM sys.partitions P
INNER JOIN sys.system_internals_allocation_units AU ON AU.container_id = P.partition_id
WHERE P.object_id = OBJECT_ID('Table1')
AND index_id = INDEXPROPERTY(object_id,'xpkTable1','IndexId')
GO
-- dbcc_root_page = DBCC PAGE (Test1,1,1841,3)

-- Então o I/O vai começar por aqui...
-- Level 2
DBCC TRACEON(3604)
DBCC PAGE (Test1,1,1841,3)
DBCC TRACEOFF(3604)
GO
/*
FileId PageId      Row    Level  ChildFileId ChildPageId Col1 (key)           KeyHashValue     Row Size
------ ----------- ------ ------ ----------- ----------- -------------------- ---------------- --------
1      1841        0      2      1           1384        NULL                 NULL             15
1      1841        1      2      1           1840        477                  NULL             15
1      1841        2      2      1           1842        953                  NULL             15
*/

-- Depois vai pra 1842 pra achar o 99999999999
-- Level 1
DBCC TRACEON(3604)
DBCC PAGE (Test1,1,1842,3)
DBCC TRACEOFF(3604)
GO
/*
FileId PageId      Row    Level  ChildFileId ChildPageId Col1 (key)           KeyHashValue     Row Size
------ ----------- ------ ------ ----------- ----------- -------------------- ---------------- --------
1      1842        0      1      1           2320        953                  NULL             15
1      1842        1      1      1           2321        954                  NULL             15
1      1842        2      1      1           2322        955                  NULL             15
...
1      1842        46     1      1           2366        999                  NULL             15
1      1842        47     1      1           2367        1000                 NULL             15
1      1842        48     1      1           2368        99999999999          NULL             15
*/

-- Por fim vai pra 2368...
-- Level 0
DBCC TRACEON(3604)
DBCC PAGE (Test1,1,2368,3)
DBCC TRACEOFF(3604)
GO

/*
  Ok, entendido...Então o offset vai ser o da root page
  SELECT 1841 * 8192 -- 15081472

  Então 15081472 deve ser o io_offset que veremos na sys.dm_io_pending_io_requests... 
*/


-- Lendo as páginas com DBCC PAGE pra forçar o disfavoring
-- e aumentar a chance delas serem removidas da memória 
-- em uma pressão
DBCC PAGE (Test1,1,1841,3)
DBCC PAGE (Test1,1,1842,3)
DBCC PAGE (Test1,1,2368,3)
GO
-- Forçar pressão na memória pra remover 
-- os dados da tabela Table1 do cache
EXEC Test2.dbo.st_LimpaCache
GO
-- Confirmando se 1841 (level 2), 1842 (level 1) e 2368 (level 0)
-- saíram do bp data cache
SELECT * 
  FROM sys.dm_os_buffer_descriptors
 WHERE database_id = DB_ID('Test1')
 ORDER BY page_id
GO

/* 
Abrir Windbg e colocar bp em "KERNELBASE!ReadFile"... 
Nesse caso, como nem rampup e nem read-ahead vão entrar
sql vai usar a ReadFile... 
Com read-ahead ou rampup, ele vai chamar a KERNELBASE!ReadFileScatter...

bp KERNELBASE!ReadFile
g

WinDbg deve parar na thread que esta rodando a query abaixo... 
procure por "sqllang!process_request" e "sqllang!CStmtPrepQuery::Init" 
pra confirmar que é a thread correta
*/

-- Rodar a query pra gerar os I/Os e disparar o bp no WinDbg...
SELECT * 
  FROM Test1.dbo.Table1
 WHERE Col1 = 99999999999
GO

-- Não necessáriamente a thread que rodou o comando, é a quer vai pegar o resultado do I/O...
-- Pode ser que outra thread faça o Switch e chame a CheckForIOCompletion... 

-- Stack trace ficou assim...
/*
  0:158> bp kernelbase!ReadFile
  breakpoint 1 redefined
  0:158> g
  Breakpoint 1 hit
  KERNELBASE!ReadFile:
  00007ffb`e1585110 48895c2410      mov     qword ptr [rsp+10h],rbx ss:000000b5`21a76b98=00007ffb97c2f58e
  0:145> k
   # Child-SP          RetAddr           Call Site
  00 000000b5`21a76b88 00007ffb`97c3eddf KERNELBASE!ReadFile
  01 000000b5`21a76b90 00007ffb`97c3ec6a sqlmin!DiskReadAsync+0x19d
  02 000000b5`21a76c70 00007ffb`97c3ebfc sqlmin!FCB::AsyncReadInternal+0x3a
  03 000000b5`21a76cc0 00007ffb`97c3e81c sqlmin!FCB::AsyncReadWithOptionalBuffer+0x8ee
  04 000000b5`21a76dd0 00007ffb`97d7a378 sqlmin!FCB::AsyncRead+0x5c
  05 000000b5`21a76e40 00007ffb`97c3151b sqlmin!RecoveryUnit::ScatterRead+0xf3
  06 000000b5`21a76ea0 00007ffb`97c31719 sqlmin!BPool::GetFromDisk+0xc25
  07 000000b5`21a76fb0 00007ffb`97c01ef0 sqlmin!BPool::Get+0x332
  08 000000b5`21a77050 00007ffb`97c01991 sqlmin!BTreeMgr::HandleRoot+0x59b
  09 000000b5`21a77730 00007ffb`97c01677 sqlmin!BTreeMgr::Seek+0x240
  0a 000000b5`21a78470 00007ffb`97c00f49 sqlmin!BTreeMgr::GetHPageIdWithKey+0x7ec
  0b 000000b5`21a78910 00007ffb`97c00ca7 sqlmin!IndexPageManager::GetPageWithKey+0x119
  0c 000000b5`21a791e0 00007ffb`97c12a11 sqlmin!GetRowForKeyValue+0x203
  0d 000000b5`21a79d40 00007ffb`97c13169 sqlmin!IndexDataSetSession::GetRowByKeyValue+0x141
  0e 000000b5`21a79f20 00007ffb`97c12ecb sqlmin!IndexDataSetSession::FetchRowByKeyValueInternal+0x230
  0f 000000b5`21a7a380 00007ffb`97c12fb3 sqlmin!RowsetNewSS::FetchRowByKeyValueInternal+0x437
  10 000000b5`21a7a4b0 00007ffb`97c23459 sqlmin!RowsetNewSS::FetchRowByKeyValue+0x96
  11 000000b5`21a7a500 00007ffb`94a72227 sqlmin!CValFetchByKey::ManipData+0x86
  12 000000b5`21a7a550 00007ffb`97c20671 sqlTsEs!CEsExec::GeneralEval4+0xe7
  13 000000b5`21a7a620 00007ffb`97c1e2d9 sqlmin!CQScanRangeNew::GetRow+0x130
  14 000000b5`21a7a680 00007ffb`97c2571e sqlmin!CQScanLightProfileNew::GetRow+0x19
  15 000000b5`21a7a6b0 00007ffb`95367c0d sqlmin!CQueryScan::GetRow+0x80
  16 000000b5`21a7a6e0 00007ffb`95367ddc sqllang!CXStmtQuery::ErsqExecuteQuery+0x3de
  17 000000b5`21a7a850 00007ffb`95ec37b2 sqllang!CXStmtSelect::XretExecute+0x373
  18 000000b5`21a7a920 00007ffb`95eb56e9 sqllang!CMsqlExecContext::ExecuteStmts<0,1>+0x812
  19 000000b5`21a7b4e0 00007ffb`95366513 sqllang!CMsqlExecContext::FExecute+0x95b
  1a 000000b5`21a7c4c0 00007ffb`95f986b1 sqllang!CSQLSource::Execute+0xb9c
  1b 000000b5`21a7c7c0 00007ffb`95367488 sqllang!CStmtPrepQuery::XretPrepQueryExecute+0x611
  1c 000000b5`21a7c8b0 00007ffb`95366ec8 sqllang!CMsqlExecContext::ExecuteStmts<1,1>+0x8f8
  1d 000000b5`21a7d450 00007ffb`95366513 sqllang!CMsqlExecContext::FExecute+0x946
  1e 000000b5`21a7e430 00007ffb`9537031d sqllang!CSQLSource::Execute+0xb9c
  1f 000000b5`21a7e730 00007ffb`95351a55 sqllang!process_request+0xcdd
  20 000000b5`21a7ee30 00007ffb`95351833 sqllang!process_commands_internal+0x4b7
  21 000000b5`21a7ef60 00007ffb`94549b33 sqllang!process_messages+0x1f3
  22 000000b5`21a7f140 00007ffb`9454a48d sqldk!SOS_Task::Param::Execute+0x232
  23 000000b5`21a7f740 00007ffb`9454a295 sqldk!SOS_Scheduler::RunTask+0xb5
  24 000000b5`21a7f7b0 00007ffb`94567020 sqldk!SOS_Scheduler::ProcessTasks+0x39d
  25 000000b5`21a7f8d0 00007ffb`94567b2b sqldk!SchedulerManager::WorkerEntryPoint+0x2a1
  26 000000b5`21a7f9a0 00007ffb`94567931 sqldk!SystemThreadDispatcher::ProcessWorker+0x402
  27 000000b5`21a7fca0 00007ffb`e2917bd4 sqldk!SchedulerManager::ThreadEntryPoint+0x3d8
  28 000000b5`21a7fd90 00007ffb`e37cce51 KERNEL32!BaseThreadInitThunk+0x14
  29 000000b5`21a7fdc0 00000000`00000000 ntdll!RtlUserThreadStart+0x21

  Agora vamos remover o bp de KERNELBASE!ReadFile e adicionar bp em kernelbase!GetOverlappedResult
  a ideia é pegar a thread que está validando se o I/O terminou... 

  bc * (pra remover o bp em KERNELBASE!ReadFile)
  bp kernelbase!GetOverlappedResult
  g

  Quando parar no bp, ver qual thread está rodando o GetOverlappedResult... 
  É provável que seja uma thread diferente da 145 (que iniciou a query e chamou o I/O...)

  0:145> bc *
  0:145> bp kernelbase!GetOverlappedResult
  0:145> g
  Breakpoint 3 hit
  KERNELBASE!GetOverlappedResult:
  00007ffb`e15853c0 48895c2408      mov     qword ptr [rsp+8],rbx ss:000000b5`12bfec60=0000000000001084
  0:005> k
   # Child-SP          RetAddr           Call Site
  00 000000b5`12bfec58 00007ffb`97c2f218 KERNELBASE!GetOverlappedResult
  01 000000b5`12bfec60 00007ffb`9455e0ec sqlmin!DBGetOverlappedResult+0x44
  02 000000b5`12bfeca0 00007ffb`94541cb1 sqldk!IOQueue::CheckForIOCompletion+0x2ce
  03 000000b5`12bfee40 00007ffb`9455a5c8 sqldk!SOS_Scheduler::SwitchContext+0x1e5
  04 000000b5`12bff1a0 00007ffb`94549b33 sqldk!SOS_Scheduler::Idle+0xc8
  05 000000b5`12bff1d0 00007ffb`9454a48d sqldk!SOS_Task::Param::Execute+0x232
  06 000000b5`12bff7d0 00007ffb`9454a295 sqldk!SOS_Scheduler::RunTask+0xb5
  07 000000b5`12bff840 00007ffb`94567020 sqldk!SOS_Scheduler::ProcessTasks+0x39d
  08 000000b5`12bff960 00007ffb`94567b2b sqldk!SchedulerManager::WorkerEntryPoint+0x2a1
  09 000000b5`12bffa30 00007ffb`94567931 sqldk!SystemThreadDispatcher::ProcessWorker+0x402
  0a 000000b5`12bffd30 00007ffb`e2917bd4 sqldk!SchedulerManager::ThreadEntryPoint+0x3d8
  0b 000000b5`12bffe20 00007ffb`e37cce51 KERNEL32!BaseThreadInitThunk+0x14
  0c 000000b5`12bffe50 00000000`00000000 ntdll!RtlUserThreadStart+0x21

  Repare que a thread que está validando o I/O na CheckForIOCompletion é diferente 
  da que disparou o comando de leitura (KERNELBASE!ReadFile)...

  E o que a thread 145 tava fazendo nessa hora? 
  Como eu já esperava, ela fez o switch (SOS_Scheduler::Switch) e agora 
  ta em KERNELBASE!SignalObjectAndWait esperando o evento de termino de I/O ser sinalizado 

  Vamos rodar um ~145k (~<IdDaThreadQueIniciouALeitura>k) pra ver o que ela ta fazendo...
  
  0:005> ~145k
  # Child-SP          RetAddr           Call Site
  00 000000b5`21a75ae8 00007ffb`e1657bef ntdll!NtSignalAndWaitForSingleObject+0x14
  01 000000b5`21a75af0 00007ffb`9454b685 KERNELBASE!SignalObjectAndWait+0xcf
  02 000000b5`21a75ba0 00007ffb`9454b590 sqldk!SOS_Scheduler::SwitchToThreadWorker+0x136
  03 000000b5`21a75e70 00007ffb`945421ba sqldk!SOS_Scheduler::Switch+0x8e
  04 000000b5`21a75eb0 00007ffb`94543804 sqldk!SOS_Scheduler::SuspendNonPreemptive+0xe3
  05 000000b5`21a75f20 00007ffb`97c24922 sqldk!WaitableBase::Wait+0x16a
  06 000000b5`21a75fa0 00007ffb`97c2447e sqlmin!LatchBase::Suspend+0x6e2
  07 000000b5`21a76d70 00007ffb`97bfd926 sqlmin!LatchBase::AcquireInternal+0x92d
  08 000000b5`21a76e40 00007ffb`97bfdb4f sqlmin!BUF::AcquireLatch+0x9d
  09 000000b5`21a76fb0 00007ffb`97c01ef0 sqlmin!BPool::Get+0x1f7
  0a 000000b5`21a77050 00007ffb`97c01991 sqlmin!BTreeMgr::HandleRoot+0x59b
  0b 000000b5`21a77730 00007ffb`97c01677 sqlmin!BTreeMgr::Seek+0x240
  0c 000000b5`21a78470 00007ffb`97c00f49 sqlmin!BTreeMgr::GetHPageIdWithKey+0x7ec
  0d 000000b5`21a78910 00007ffb`97c00ca7 sqlmin!IndexPageManager::GetPageWithKey+0x119
  0e 000000b5`21a791e0 00007ffb`97c12a11 sqlmin!GetRowForKeyValue+0x203
  0f 000000b5`21a79d40 00007ffb`97c13169 sqlmin!IndexDataSetSession::GetRowByKeyValue+0x141
  10 000000b5`21a79f20 00007ffb`97c12ecb sqlmin!IndexDataSetSession::FetchRowByKeyValueInternal+0x230
  11 000000b5`21a7a380 00007ffb`97c12fb3 sqlmin!RowsetNewSS::FetchRowByKeyValueInternal+0x437
  12 000000b5`21a7a4b0 00007ffb`97c23459 sqlmin!RowsetNewSS::FetchRowByKeyValue+0x96
  13 000000b5`21a7a500 00007ffb`94a72227 sqlmin!CValFetchByKey::ManipData+0x86
  14 000000b5`21a7a550 00007ffb`97c20671 sqlTsEs!CEsExec::GeneralEval4+0xe7
  15 000000b5`21a7a620 00007ffb`97c1e2d9 sqlmin!CQScanRangeNew::GetRow+0x130
  16 000000b5`21a7a680 00007ffb`97c2571e sqlmin!CQScanLightProfileNew::GetRow+0x19
  17 000000b5`21a7a6b0 00007ffb`95367c0d sqlmin!CQueryScan::GetRow+0x80
  18 000000b5`21a7a6e0 00007ffb`95367ddc sqllang!CXStmtQuery::ErsqExecuteQuery+0x3de
  19 000000b5`21a7a850 00007ffb`95ec37b2 sqllang!CXStmtSelect::XretExecute+0x373
  1a 000000b5`21a7a920 00007ffb`95eb56e9 sqllang!CMsqlExecContext::ExecuteStmts<0,1>+0x812
  1b 000000b5`21a7b4e0 00007ffb`95366513 sqllang!CMsqlExecContext::FExecute+0x95b
  1c 000000b5`21a7c4c0 00007ffb`95f986b1 sqllang!CSQLSource::Execute+0xb9c
  1d 000000b5`21a7c7c0 00007ffb`95367488 sqllang!CStmtPrepQuery::XretPrepQueryExecute+0x611
  1e 000000b5`21a7c8b0 00007ffb`95366ec8 sqllang!CMsqlExecContext::ExecuteStmts<1,1>+0x8f8
  1f 000000b5`21a7d450 00007ffb`95366513 sqllang!CMsqlExecContext::FExecute+0x946
  20 000000b5`21a7e430 00007ffb`9537031d sqllang!CSQLSource::Execute+0xb9c
  21 000000b5`21a7e730 00007ffb`95351a55 sqllang!process_request+0xcdd
  22 000000b5`21a7ee30 00007ffb`95351833 sqllang!process_commands_internal+0x4b7
  23 000000b5`21a7ef60 00007ffb`94549b33 sqllang!process_messages+0x1f3
  24 000000b5`21a7f140 00007ffb`9454a48d sqldk!SOS_Task::Param::Execute+0x232
  25 000000b5`21a7f740 00007ffb`9454a295 sqldk!SOS_Scheduler::RunTask+0xb5
  26 000000b5`21a7f7b0 00007ffb`94567020 sqldk!SOS_Scheduler::ProcessTasks+0x39d
  27 000000b5`21a7f8d0 00007ffb`94567b2b sqldk!SchedulerManager::WorkerEntryPoint+0x2a1
  28 000000b5`21a7f9a0 00007ffb`94567931 sqldk!SystemThreadDispatcher::ProcessWorker+0x402
  29 000000b5`21a7fca0 00007ffb`e2917bd4 sqldk!SchedulerManager::ThreadEntryPoint+0x3d8
  2a 000000b5`21a7fd90 00007ffb`e37cce51 KERNEL32!BaseThreadInitThunk+0x14
  2b 000000b5`21a7fdc0 00000000`00000000 ntdll!RtlUserThreadStart+0x21


  Vamos congelar a thread 5 que esta validando o I/O pra evitar que ela chame a CompletionRoutine
  que vai sinalizar pra thead 145 que o I/O terminou... 
  Vamos congelar tbm a thread 145 só pra garantir que ela não acorde por causa de outra thread 
  rodando a CheckForIOCompletion...
    
  Enquanto as threads estão congeladas vamos consultar a sys.dm_io_pending_io_requests
  pra ver o que está pendende e ver se o io_offset bate com o que calculamos 
  (página raiz 1841, offset 15081472)...

  0:005> ~5f
  0:005> ~145f
  0:005> bc *
  0:005> g

  Se tudo deu certo, agora estamos de volta com o SQL e a sessão que rodou o 
  select está "rodando"...
  Abrir outra sessão  conectar como DAC, ADMIN:dellfabiano\SQL2019 pra evitar cair no mesmo
  scheduler que estão "congelados"... Rodar as queries abaixo pra ver o resultado da 
  dm_os_waiting_tasks e dm_io_pending_io_requests


  SELECT * FROM sys.dm_io_pending_io_requests
  SELECT dm_os_waiting_tasks.* FROM sys.dm_os_waiting_tasks
  INNER JOIN sys.dm_exec_sessions
  ON dm_exec_sessions.session_id = dm_os_waiting_tasks.session_id 
  WHERE is_user_process = 1
  GO

  io_completion_request_address io_type   io_pending_ms_ticks  io_pending  io_completion_routine_address io_user_data_address scheduler_address  io_handle          io_offset            io_handle_path
  ----------------------------- --------- -------------------- ----------- ----------------------------- -------------------- ------------------ ------------------ -------------------- -------------------
  0x000001DBA38C84D0            disk      1096114              0           0x00007FFB97C2EE80            0x000001DBA3AFA800   0x000001DBA2320040 0x0000000000001084 15081472             \\?\E:\Test1.mdf

  waiting_task_address session_id exec_context_id wait_duration_ms     wait_type         resource_address   blocking_task_address blocking_session_id blocking_exec_context_id resource_description
  -------------------- ---------- --------------- -------------------- ----------------- ------------------ --------------------- ------------------- ------------------------ ----------------------
  0x000001DB91E0F468   67         0               1096115              PAGEIOLATCH_SH    0x000001DBA3AFA898 NULL                  NULL                NULL                     9:1:1841

  io_offset bate com o que calculamos :-) ...
  Outra coisa, olha a io_pending_ms_ticks

  Aproveitando que estamos aqui... sabe esse io_completion_request_address da sys.dm_io_pending_io_requests?
  Ele é aquela estrutura de CompletionRequest enviada pra fila de I/O no scheduler via sqlmin!SOS_Scheduler::AddIOCompletionRequest...
  nessa estrutura tem infos do I/O e do "caller" que precisa ser acordado qdo o I/O terminar... 

  Vamos dar um Break no WinDbg e fazer um dump dessa memória...

  0:104> dd 0x000001DBA38C84D0
  000001db`a38c84d0  00000000 00000000 00002000 00000000
  000001db`a38c84e0  00e62000 00000000 00000598 00000000
  000001db`a38c84f0  00000000 0089a3ca a23213c8 000001db
  000001db`a38c8500  a23213c8 000001db 00001084 00000000
  000001db`a38c8510  00000000 00000000 97c2ee80 00007ffb
  000001db`a38c8520  a3afa800 000001db 2e092d9a 0000005b
  000001db`a38c8530  9479b060 00007ffb 00000000 00000000
  000001db`a38c8540  00000000 00000000 9ba1aa70 000001db
  0:104> ? e62000
  Evaluate expression: 15081472 = 00000000`00e62000

  Viu ai? Se convertermos o hexa 0xe62000 em decimal, temos 15081472
  Olha nosso Offset ai denovo :-) ... Isso faz parte da estrutura Overlapped
  que vai no I/O né... Você já viu isso no app que fiz no Delphi... 

  Vamos descongelar as threads pq a essa altura o Scheduler Monitor já deve estar esperniando
  por causa das non-yielding threads :-) 
  No error log deve ter algo +- assim:

  Process 0:0:0 (0x53f8) Worker 0x000001DB91DEA160 appears to be non-yielding on Scheduler 1. Thread creation time: 13239402281453.
  Approx Thread CPU Used: kernel 0 ms, user 0 ms. Process Utilization 0%. System Idle 95%. Interval: 70107 ms.

  Descongelando as threads no WinDbg:
  0:104> ~5u
  0:104> ~145u
  0:104> g

  Agora veja uma coisa interessante... Na sys.dm_os_buffer_descriptors tem uma coluna chamada
  read_microsec... De acordo com o BOL, esse valor significa o seguinte:
  "The actual time (in microseconds) required to read the page into the buffer."

  Olha quanto tempo demorou pra ler a página 1841(root page) que ficamos um tempo com as threads 
  congeladas..

  SELECT database_id, file_id, page_id, page_type, read_microsec
    FROM sys.dm_os_buffer_descriptors
   WHERE database_id = DB_ID('Test1')
     AND page_id IN (1841, 1842, 2368)
  
  database_id file_id     page_id     page_type      read_microsec
  ----------- ----------- ----------- -------------- -------------
  9           1           2368        DATA_PAGE      4214
  9           1           1842        INDEX_PAGE     4587
  9           1           1841        INDEX_PAGE     1817712038

  Outro perigo aqui é ver os dados na sys.dm_io_virtual_file_stats.
  Se liga no valor da io_stall_read_ms ("latência") de leitura no banco Test1 

  SELECT num_of_reads, io_stall_read_ms FROM sys.dm_io_virtual_file_stats(DB_ID('Test1'), 1)

  num_of_reads         io_stall_read_ms
  -------------------- --------------------
  330                  2711523

  O I/O terminou rápido no Windows, mas quem atualiza essas DMVs é a CompletionRoutine
  como ela demorou pra entrar, os valores ficaram altos...

*/

  

/*
  Se eu reiniciar o SQL e voltar a ter um "cold" cache, ou seja, SQL ainda não 
  atingiu "memory target" vamos ver o kernelbase!ReadFileScatter ser chamado?
*/


-- Deatach Windbg e reinciar a instancia...


-- Ainda faltam alguns MBs pra atingir o target, portanto ramp-up tá na ativa...
SELECT object_name,
       counter_name,
       cntr_value / 1024. AS MBs
  FROM sys.dm_os_performance_counters
 WHERE counter_name IN('Target Server Memory (KB)', 'Total Server Memory (KB)')
GO

USE Test1
GO
-- O que já foi carregado pra memória? 
-- Várias páginas, mas repare que o page_id delas é baixo...
-- certeza que esses allocation_unit_id ai vão apontar pra tabelas de sistema...
SELECT * 
  FROM sys.dm_os_buffer_descriptors
 WHERE database_id = DB_ID('Test1')
 ORDER BY page_id
GO

-- As páginas lidas no select não estão no BP
SELECT database_id, file_id, page_id, page_type, read_microsec
  FROM sys.dm_os_buffer_descriptors
 WHERE database_id = DB_ID('Test1')
   AND page_id IN (1841, 1842, 2368)
GO

-- Como o SQL pode precisar ler do disco algumas páginas de sistema e de controle, 
-- vou rodar uma consulta que vai ler outro ID... 
-- Isso deve gerar leituras em 1841 (level 2) e 1842 (level 1) 
-- mas não vai gerar o I/O na 2368 que tem os dados do Col1 = 99999999999


-- Rodar a query pra gerar os I/Os nas tabelas de sistema
-- e root/intermediárias do índice...
SELECT TOP 1 * 
  FROM Test1.dbo.Table1
 ORDER BY Col1 ASC
GO

-- As páginas 1841 e 1842 foram pro BP, mas 2368 não foi...
SELECT database_id, file_id, page_id, page_type, read_microsec
  FROM sys.dm_os_buffer_descriptors
 WHERE database_id = DB_ID('Test1')
   AND page_id IN (1841, 1842, 2368)
GO

/*
  Agora vamos disparar a consulta que precisa da página 2368
  Na teoria isso vai disparar um kernelbase!ReadFileScatter com 
  I/O de 64KB, ou seja, 8 páginas, começando pelo offset 19398656 (2368 * 8192)

  Antes de rodar a cosulta vamos abrir o WinDbg e colocar o bp
  em kernelbase!ReadFileScatter
*/

-- Gerar o I/O na página 2368...
SELECT * 
  FROM Test1.dbo.Table1
 WHERE Col1 = 99999999999
GO

-- Conforme esperado bp parou na chamada do kernelbase!ReadFileScatter
/*
0:129> bp kernelbase!ReadFileScatter
0:129> g
Breakpoint 0 hit
KERNELBASE!ReadFileScatter:
00007ffb`e15e04d0 4883ec58        sub     rsp,58h
0:067> k
 # Child-SP          RetAddr           Call Site
00 0000000a`913f4358 00007ffb`94940cde KERNELBASE!ReadFileScatter
01 0000000a`913f4360 00007ffb`94940b54 sqlmin!DiskScatterReadAsync+0x19c
02 0000000a`913f4440 00007ffb`94940a1a sqlmin!FCB::ScatterReadInternal+0x128
03 0000000a`913f84e0 00007ffb`94941682 sqlmin!FCB::ScatterRead+0x8ae
04 0000000a`913f8600 00007ffb`9494151b sqlmin!RecoveryUnit::ScatterRead+0x13d
05 0000000a`913f8660 00007ffb`94941719 sqlmin!BPool::GetFromDisk+0xc25
06 0000000a`913f8770 00007ffb`9491133c sqlmin!BPool::Get+0x332
07 0000000a`913f8810 00007ffb`94910ca7 sqlmin!IndexPageManager::GetPageWithKey+0x14d7
08 0000000a`913f90e0 00007ffb`94922a11 sqlmin!GetRowForKeyValue+0x203
09 0000000a`913f9c40 00007ffb`94923169 sqlmin!IndexDataSetSession::GetRowByKeyValue+0x141
0a 0000000a`913f9e20 00007ffb`94922ecb sqlmin!IndexDataSetSession::FetchRowByKeyValueInternal+0x230
0b 0000000a`913fa280 00007ffb`94922fb3 sqlmin!RowsetNewSS::FetchRowByKeyValueInternal+0x437
0c 0000000a`913fa3b0 00007ffb`94933459 sqlmin!RowsetNewSS::FetchRowByKeyValue+0x96
0d 0000000a`913fa400 00007ffb`97d62227 sqlmin!CValFetchByKey::ManipData+0x86
0e 0000000a`913fa450 00007ffb`94930671 sqlTsEs!CEsExec::GeneralEval4+0xe7
0f 0000000a`913fa520 00007ffb`9492e2d9 sqlmin!CQScanRangeNew::GetRow+0x130
10 0000000a`913fa580 00007ffb`9493571e sqlmin!CQScanLightProfileNew::GetRow+0x19
11 0000000a`913fa5b0 00007ffb`98657c0d sqlmin!CQueryScan::GetRow+0x80
12 0000000a`913fa5e0 00007ffb`98657ddc sqllang!CXStmtQuery::ErsqExecuteQuery+0x3de
13 0000000a`913fa750 00007ffb`991b37b2 sqllang!CXStmtSelect::XretExecute+0x373
14 0000000a`913fa820 00007ffb`991a56e9 sqllang!CMsqlExecContext::ExecuteStmts<0,1>+0x812
15 0000000a`913fb3e0 00007ffb`98656513 sqllang!CMsqlExecContext::FExecute+0x95b
16 0000000a`913fc3c0 00007ffb`992886b1 sqllang!CSQLSource::Execute+0xb9c
17 0000000a`913fc6c0 00007ffb`98657488 sqllang!CStmtPrepQuery::XretPrepQueryExecute+0x611
18 0000000a`913fc7b0 00007ffb`98656ec8 sqllang!CMsqlExecContext::ExecuteStmts<1,1>+0x8f8
19 0000000a`913fd350 00007ffb`98656513 sqllang!CMsqlExecContext::FExecute+0x946
1a 0000000a`913fe330 00007ffb`9866031d sqllang!CSQLSource::Execute+0xb9c
1b 0000000a`913fe630 00007ffb`98641a55 sqllang!process_request+0xcdd
1c 0000000a`913fed30 00007ffb`98641833 sqllang!process_commands_internal+0x4b7
1d 0000000a`913fee60 00007ffb`943d9b33 sqllang!process_messages+0x1f3
1e 0000000a`913ff040 00007ffb`943da48d sqldk!SOS_Task::Param::Execute+0x232
1f 0000000a`913ff640 00007ffb`943da295 sqldk!SOS_Scheduler::RunTask+0xb5
20 0000000a`913ff6b0 00007ffb`943f7020 sqldk!SOS_Scheduler::ProcessTasks+0x39d
21 0000000a`913ff7d0 00007ffb`943f7b2b sqldk!SchedulerManager::WorkerEntryPoint+0x2a1
22 0000000a`913ff8a0 00007ffb`943f7931 sqldk!SystemThreadDispatcher::ProcessWorker+0x402
23 0000000a`913ffba0 00007ffb`e2917bd4 sqldk!SchedulerManager::ThreadEntryPoint+0x3d8
24 0000000a`913ffc90 00007ffb`e37cce51 KERNEL32!BaseThreadInitThunk+0x14
25 0000000a`913ffcc0 00000000`00000000 ntdll!RtlUserThreadStart+0x21

*/

/*
   Ao inves de continuar com o WinDbg, dessa vez vamos ver os I/Os via ExtendedEvents
   Fechar o Windbg, e reiniciar serviço do SQL...
*/

-- Criar xEvent capturando file_read_completed e physical_page_read
-- DROP EVENT SESSION CapturaIOs ON SERVER 

-- Ajustar o filtro pra pegar apenas dados dessa sessão...
SELECT @@SPID
GO
CREATE EVENT SESSION [CapturaIOs] ON SERVER 
ADD EVENT sqlserver.file_read_completed(
    ACTION(sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[session_id]=(57))),
ADD EVENT sqlserver.physical_page_read(
    ACTION(sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[session_id]=(57)))
ADD TARGET package0.ring_buffer
WITH(MAX_DISPATCH_LATENCY = 1 SECONDS)
GO

-- Rodar a query pra gerar os I/Os nas tabelas de sistema
-- e root/intermediárias do índice...
SELECT TOP 1 * 
  FROM Test1.dbo.Table1
 ORDER BY Col1 ASC
GO

-- As páginas 1841 e 1842 foram pro BP, mas 2368 não foi...
SELECT database_id, file_id, page_id, page_type, read_microsec
  FROM sys.dm_os_buffer_descriptors
 WHERE database_id = DB_ID('Test1')
   AND page_id IN (1841, 1842, 2368)
GO
-- Iniciar o xEvent
ALTER EVENT SESSION CapturaIOs ON SERVER STATE = START;
GO
-- Gerar o I/O na página 2368...
SELECT * 
  FROM Test1.dbo.Table1
 WHERE Col1 = 99999999999
GO

-- Em uma nova sessão rodar a query abaixo pra ver o que gerou de I/O
;WITH CTE1
AS
(
  SELECT CONVERT(XML, xst.target_data) AS Target_Data
    FROM sys.dm_xe_session_targets xst
   INNER JOIN sys.dm_xe_sessions xs 
      ON xs.address = xst.event_session_address
   WHERE xs.name = 'CapturaIOs'
),
CTE2
AS
(
  SELECT name     = XEvent.value('(@name)[1]','varchar(max)'),
         time     = XEvent.value('(@timestamp)[1]','datetime'),
         file_id  = XEvent.value('(data[@name=''file_id'']/value)[1]','int'),
         page_id  = XEvent.value('(data[@name=''page_id'']/value)[1]','int'),
         mode     = XEvent.value('(data[@name=''mode'']/text)[1]','VarChar(max)'),
         duration = XEvent.value('(data[@name=''duration'']/value)[1]','int'),
         offset   = XEvent.value('(data[@name=''offset'']/value)[1]','VarChar(max)'),
         size     = XEvent.value('(data[@name=''size'']/value)[1]','VarChar(max)')
    FROM CTE1
   CROSS APPLY CTE1.target_data.nodes('/RingBufferTarget/event') AS EventNodes(XEvent)
)
SELECT * FROM CTE2
ORDER BY time ASC
GO

/*
  name                 time                    file_id     page_id     mode                 duration    offset               size
  -------------------- ----------------------- ----------- ----------- -------------------- ----------- -------------------- --------------------
  file_read_completed  2020-07-17 01:25:41.093 1           NULL        Scatter/Gather       4           19398656             65536
  physical_page_read   2020-07-17 01:25:41.093 1           2368        NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
  physical_page_read   2020-07-17 01:25:41.093 0           0           NULL                 NULL        NULL                 NULL
*/

-- Repare que ainda que o SQL tenha tentado fazer a leitura de outras páginas
-- pra ajudar a "esquentar" o cache mais rápido... 65536 bytes(64KB) começando do offset 19398656
-- ele só conseguiu ler 1 página "útil", a 2369 pq não existem mais páginas depois do pageid 2368...


-- Parar o xEvent
ALTER EVENT SESSION CapturaIOs ON SERVER STATE = STOP;
GO

-- Cleanup
sp_configure 'show advanced options', 1;  
RECONFIGURE;
GO 
-- Set BP to 10GB
EXEC sys.sp_configure N'max server memory (MB)', N'10240'
GO
RECONFIGURE WITH OVERRIDE
GO
