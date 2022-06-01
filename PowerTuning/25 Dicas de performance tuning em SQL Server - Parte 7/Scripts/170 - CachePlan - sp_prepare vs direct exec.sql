/*
  Demo - sp_prepare vs Direct Exec
*/

-- Abrir app
-- D:\Fabiano\Trabalho\FabricioLima\Cursos\25 Dicas de performance tuning em SQL Server - Parte 7\Outros\sp_prepare vs direct exec\

USE Northwind
GO
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

-- Usando o CROSS APPLY para ver o texto e o plano
SELECT *
FROM sys.dm_exec_cached_plans as ECP
CROSS APPLY sys.dm_exec_sql_text(ECP.plan_handle)
CROSS APPLY sys.dm_exec_query_plan(ECP.plan_handle)
ORDER BY usecounts DESC
GO


-- Conclus�o
-- O tempo � o basicamente o mesmo, por�m a visibilidade do c�digo executado no 
-- profiler � p�ssima com sp_prepare...
-- Talvez em um ambiente com baixa lat�ncia de rede, o sp_prepare ajude, j� que na 
-- teoria ir� reduzir o tamanho do pacote enviado pela rede... 
-- Azure com serv no Jap�o...?...
-- IMO, n�o use prepare... please...
