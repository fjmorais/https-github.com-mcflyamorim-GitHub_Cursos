
-- Ver no profiler

-- EncryptByPassPhrase faz que o TSQL n�o fique dispon�vel...
SELECT 'Teste C�digo que ninguem pode ver pelo Profiler' 
WHERE EncryptByPassPhrase('','') <> ''
GO

 