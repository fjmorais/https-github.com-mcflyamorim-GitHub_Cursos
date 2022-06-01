/*

  Checkpoint... 

*/

-- Qual � a thread rodando o CheckPoint? 
-- CHECKPOINT = Recovery Interval
-- RECOVERY WRITER = Indirect checkpoint... Tamb�m conhecido como DPM (dirty page manager)
select session_id, command, r.last_wait_type, os_thread_id, s.scheduler_id, s.cpu_id, s.current_workers_count
from sys.dm_exec_requests as r
join sys.dm_os_workers as w on r.task_address = w.task_address
join sys.dm_os_threads as t on t.thread_address = w.thread_address
JOIN sys.dm_os_schedulers AS s ON s.scheduler_id = r.scheduler_id
where r.command IN ('CHECKPOINT', 'RECOVERY WRITER')
GO


-- Vamos ver no Windbg? ... 
SELECT CONVERT(VARBINARY(MAX), 8888) -- 0x000022B8
GO

-- Abrir windbg

-- Analizar a threadstack
~~[22B8]k


-- T�, mas conseguimos ver ele em a��o? ... 

-- Vamos habilitar o comportamento "padr�o" (checkpoint) em vers�es < 2016 
USE [master]
GO
ALTER DATABASE DB_BPDisfavoring_4 SET TARGET_RECOVERY_TIME = 0 SECONDS WITH NO_WAIT
GO

-- Set BP to 10GB e recovery interval para default (0)
EXEC sys.sp_configure N'max server memory (MB)', N'10240'
GO
EXEC sys.sp_configure N'recovery interval (min)', N'0'
GO
RECONFIGURE WITH OVERRIDE
GO


-- Vamos primeiro popular um pouco do BP data cache... 

-- Vamos utilizar o DB DB_BPDisfavoring_4 que tem uma tabela de 4GB
USE DB_BPDisfavoring_4
GO

CHECKPOINT;DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE(); 
GO

-- Abrir o arquivo "...Scripts\8 - Checkpoint\PerfmonMem.msc"
-- Ver os contadores de mem�ria, Lazy Writes/Sec, "Total Server Memory", "Free Memory (KB)" e etc...


-- Popular cache com 4GB
SET STATISTICS IO ON
SELECT COUNT(*) FROM DB_BPDisfavoring_4.dbo.Products4GB
SET STATISTICS IO OFF
GO

-- Como est� o data cache?
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO


-- Agora vamos sujar todas essas p�ginas... 
UPDATE DB_BPDisfavoring_4.dbo.Products4GB 
SET Col1 = NEWID(), Col2 = NEWID()
GO


-- Como ficaram as p�ginas no cache?
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO


-- E agora, quando que o checkpoint vai entrar? ... em 1 min? 

-- Ok, vamos esperar 1 min e ver a dm_os_buffer_descriptors novamente
-- Enquanto isso tbm podemos olhar o contador de checkpoint no perfmon
WAITFOR DELAY '00:01:00.000'
GO



-- Na verdade a conta n�o � essa n�... n�o � de 60 em 60 segundos...
-- � o calculo interno que o SQL faz pra conseguir TENTAR recuperar tudo que precisa 
-- em at� 60 segundos

-- Ent�o pode ser que tenhamos que esperar por um bom tempo pro checkpoint autom�tico rodar...



-- Como ficaram as p�ginas no cache? Continua com p�ginas sujas?  
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO


-- Vamos criar uma tabela e come�ar a inserir dados nela... 
--qdo ser� que o checkpoint vai entrar? 

USE DB_BPDisfavoring_4
GO

DROP TABLE IF EXISTS TabCheckPoint
GO

CREATE TABLE TabCheckPoint (Col1 CHAR(7500) DEFAULT NEWID())
GO

-- Inserindo algumas linhas (sujando mais p�ginas) na tabela o checkpoint � disparado?
SET NOCOUNT ON
GO
INSERT INTO TabCheckPoint DEFAULT VALUES
GO 10000


-- Checkpoint entrou ? 
-- Como ficaram os contadores de disco? 
---- Disk transfers/sec
---- Avg. Disk sec/Write
---- Current Disk Queue Length

-- Como ficou o cache? 
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO


-- Agora vamos fazer ficar mais divertido... 
USE DB_BPDisfavoring_4
GO

DECLARE @TabName VARCHAR(500) = 'Tab' + CONVERT(VARCHAR(250), NEWID()),
        @SQL VARCHAR(MAX) = ''

SET @SQL = 'SET NOCOUNT ON; DROP TABLE IF EXISTS "' + @TabName + '"; CREATE TABLE "' + @TabName + '" (Col1 CHAR(7500) DEFAULT NEWID()); '
SET @SQL += 'DECLARE @i Int = 0; WHILE @i < 1000 BEGIN INSERT INTO "' + @TabName + '" DEFAULT VALUES; DELETE FROM "' + @TabName + '" SET @i += 1 END' 


-- Inserindo algumas linhas (sujando mais p�ginas) na tabela o checkpoint � disparado?
-- +- checkpoint entrando gostoso...
-- Rodar no SQLQueryStress, 100 threads 5 iterations utilizando o DB DB_BPDisfavoring_4
--PRINT @SQL
EXEC (@SQL)


-- Ver os contadores... CheckPoint, transactions/sec e avg disk sec/write

-- E se eu meter o loco e estressar o C:\ ? como fica? 
-- c:\sqlio\sqlio.exe -kW -t32 -dE -s99999 -b1024

-- Repare que o intervalo de tempo que em que o Checkpoint entra aumenta... 
-- Lembra do PPT? 
/*
  Frequ�ncia de um automatic cpk pode variar devido ao ajuste de outstanding I/Os enviados.
  I/O pode ser throttled (diminuido) caso a lat�ncia das escritas forem > 20ms (<SQL2016) e 50ms (SQL2016+). 
  Se a lat�ncia for alta, o n�mero de I/Os enviados ser� reduzido a fim de dimunir a fila de I/O e obter uma lat�ncia melhor.
*/

-- Repare que de fato o avg disk sec/write ficou maior que 50ms
-- Repare tbm que o disk transfer (I/Os gerados pelo checkpoint) diminuiu consideravelmente quando a 
-- lat�ncia estava alta... isso � o checkpoint tentando causar menos problema...


-- E como ficaria com indirect checkpoint? 
USE [master]
GO
-- Utilizando indirect padr�o... 
ALTER DATABASE DB_BPDisfavoring_4 SET TARGET_RECOVERY_TIME = 60 SECONDS WITH NO_WAIT
GO

-- 1 - Agora quem escreve � o DPM (dirty page manager)

-- Vamos popular um pouco do BP data cache... 
USE DB_BPDisfavoring_4
GO
CHECKPOINT;DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE(); 
GO

-- Popular cache com 4GB
SET STATISTICS IO ON
SELECT COUNT(*) FROM DB_BPDisfavoring_4.dbo.Products4GB
SET STATISTICS IO OFF
GO

-- Como est� o data cache?
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO


-- Agora vamos sujar todas essas p�ginas... 
UPDATE DB_BPDisfavoring_4.dbo.Products4GB SET Col1 = NEWID(), Col2 = NEWID()
GO


-- Como ficaram as p�ginas no cache?
SELECT obj.name,
       Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = DB_NAME(database_id),
       Pages = COUNT(1)
  FROM sys.dm_os_buffer_descriptors as bd
 INNER JOIN (SELECT object_id as objectid,
                    object_name(object_id) as name,
                    index_id,
                    allocation_unit_id,
                    p.data_compression_desc,
                    (au.total_pages * 8) / 1024. ActualSizeMB
               FROM sys.allocation_units as au
              INNER JOIN sys.partitions as p
                 ON au.container_id = p.hobt_id
                AND (au.type = 1 OR au.type = 3)) as obj
    ON bd.allocation_unit_id = obj.allocation_unit_id
 WHERE bd.database_id = DB_ID('DB_BPDisfavoring_4')
   AND obj.name NOT LIKE 'sys%'
GROUP BY obj.name, is_modified, database_id
GO

-- WOW Recovery Writer (outro nome para o dirty page manager) j� rodou e limpou v�rias p�ginas...
-- Lembra do slide? 
-- O DPM tem a lista de p�ginas sujas, como ele n�o precisa ficar varrendo o BP para limpar essas p�ginas
-- ele roda com uma frequ�ncia muito maior... a tendencia � que quanto mais ele rodar
-- menos p�ginas ele vai precisar limpar, gerando I/Os bem menores... causando menos impacto



-- Cleanup
-- Habilita Indirect checkpoint... 
USE [master]
GO
ALTER DATABASE DB_BPDisfavoring_4 SET TARGET_RECOVERY_TIME = 60 SECONDS WITH NO_WAIT
GO
-- Set BP to 10GB
EXEC sys.sp_configure N'max server memory (MB)', N'10240'
GO
RECONFIGURE WITH OVERRIDE
GO