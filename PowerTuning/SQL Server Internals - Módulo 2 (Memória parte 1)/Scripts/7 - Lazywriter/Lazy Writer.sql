/*

  Objetivo do Lazy Writer � garantir que teremos p�ginas de mem�ria
  livres no buffer pool.

*/

-- Qual � a thread rodando o Lazy Writer? 
select session_id, command, r.last_wait_type, os_thread_id, s.scheduler_id, s.cpu_id, s.current_workers_count, s.status
from sys.dm_exec_requests as r
join sys.dm_os_workers as w on r.task_address = w.task_address
join sys.dm_os_threads as t on t.thread_address = w.thread_address
JOIN sys.dm_os_schedulers AS s ON s.scheduler_id = r.scheduler_id
where r.command = 'LAZY WRITER'
GO

-- Vamos ver no Windbg? ... 
SELECT CONVERT(VARBINARY(MAX), 796) -- 0x00001AAC
GO

-- Abrir windbg

-- Analizar a threadstack
~~[31C]k



-- Quick internal info: 
-- User threads s�o din�micas, ou seja, elas podem ser criadas em qualquer scheduler online
-- Algumas (CheckPoint ou LazyWriter) system worker thredas s�o fixas, ou seja, uma vez que elas foram
-- criadas em um scheduler espec�fico eles permanecer�o l� at� morrer... se eu deixar o scheduler offline
-- posso isolar essa thread em uma CPU espec�fica... Affinity mask pode ser utilizado pra isso...
-- Ainda que o status de uma scheduler seja offline, isso significa que apenas NOVAS threads n�o ser�o 
-- criadas nele...


-- Lazy writes/sec = "Number of buffers written by buffer manager's lazy writer."
SELECT object_name, counter_name, cntr_value, cntr_type
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Buffer Manager%'
AND [counter_name] = 'Lazy writes/sec'
GO

-- Quantidade de vezes "lazy writer" realocou algo em 10 segundos...
DECLARE @LazyWrites1 bigint;
SELECT @LazyWrites1 = cntr_value
  FROM sys.dm_os_performance_counters
  WHERE counter_name = 'Lazy writes/sec';
 
WAITFOR DELAY '00:00:10';
 
SELECT(cntr_value - @LazyWrites1) / 10 AS 'LazyWrites/sec'
  FROM sys.dm_os_performance_counters
  WHERE counter_name = 'Lazy writes/sec';
GO


-- Outro contador interessante: 
-- Free List Stalls/sec = "Indicates the number of requests per second that had to wait for a free page."
SELECT object_name, counter_name, cntr_value, cntr_type
FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Buffer Manager%'
AND [counter_name] = 'Free List Stalls/sec'
GO


-- E de quanto em quanto tempo o LazyWriter faz o "check"? 

-- Abrir windbg
-- Adicionar bp em WakeupLazyWriter e escrever texto sempre que tiver um bp hit
bp sqlmin!BPool::WakeupLazyWriter ".echo Acordando LazyWriter; g"

-- Cleanup

-- remover o bp
bl
bc 0


-- sqlmin!BPool::HelpLazyWriter
-- Outras threads podem chamar um sqlmin!BPool::HelpLazyWriter e fazer o trabalho dele
-- ou seja, se uma thread alocando mem�ria percebe que a freelist est� baixa
-- ela pode chamar iniciar um LazyWriter e fazer come�ar a limpeza... 
-- Ou seja, podemos ter um cen�rio onde v�rias threads est�o fazendo um "lazywriter"...





-- T�, mas conseguimos ver ele em a��o? ... 

-- Vamos habilitar o comportamento "padr�o" (checkpoint) em vers�es < 2016 
USE [master]
GO
ALTER DATABASE DB_BPDisfavoring_4 SET TARGET_RECOVERY_TIME = 0 SECONDS WITH NO_WAIT
GO
-- Set BP to 10GB
EXEC sys.sp_configure N'max server memory (MB)', N'10240'
GO
RECONFIGURE WITH OVERRIDE
GO


-- Vamos primeiro popular um pouco do BP data cache... 

-- Vamos utilizar o DB DB_BPDisfavoring_4 que tem uma tabela de 4GB
USE DB_BPDisfavoring_4
GO

CHECKPOINT;DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE(); 
GO

-- Abrir o arquivo "...M�dulo 02 - Mem�ria parte 1\7 - LazywriterPerfmonMem.msc"
-- Ver os contadores de mem�ria, Lazy Writes/Sec, "Total Server Memory", "Free Memory (KB)" e etc...


-- Popular cache com 4GB
SET STATISTICS IO ON
SELECT COUNT(*) FROM DB_BPDisfavoring_4.dbo.Products4GB
SET STATISTICS IO OFF
GO

-- Como est� o data cache?
SELECT Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = CASE
                    WHEN database_id = 32767 THEN
                        'RESOURCEDB'
                    ELSE
                        DB_NAME(database_id)
                END,
       Pages = COUNT(1)
FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID('DB_BPDisfavoring_4') -- Comentar se necess�rio
GROUP BY database_id,
         is_modified
GO

-- Agora vamos sujar todas essas p�ginas... 
UPDATE DB_BPDisfavoring_4.dbo.Products4GB SET Col1 = NEWID(), Col2 = NEWID()
GO


-- Como ficaram as p�ginas no cache?
SELECT Page_Status = CASE
                         WHEN is_modified = 1 THEN
                             'Dirty'
                         ELSE
                             'Clean'
                     END,
       DBName = CASE
                    WHEN database_id = 32767 THEN
                        'RESOURCEDB'
                    ELSE
                        DB_NAME(database_id)
                END,
       Pages = COUNT(1)
FROM sys.dm_os_buffer_descriptors
WHERE database_id = DB_ID('DB_BPDisfavoring_4') -- Comentar se necess�rio
GROUP BY database_id,
         is_modified
GO



-- Quanto estou usando de BP data cache? 
SELECT SUM(pages_kb) / 1024. SizeInMb 
  FROM sys.dm_os_memory_clerks
 WHERE type = 'MEMORYCLERK_SQLBUFFERPOOL'
GO


-- Mas e se eu mudar o BP para 1GB ? 
-- Lazy writer tem que entrar e remover algumas p�ginas dirty do cache para colocar na freelist
EXEC sys.sp_configure N'max server memory (MB)', N'1024'
GO
RECONFIGURE WITH OVERRIDE
GO

-- Ver contadores... LazyWriter vai entrar e remover as p�ginas 



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