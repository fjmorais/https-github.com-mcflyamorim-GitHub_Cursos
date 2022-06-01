

IF OBJECT_ID('TestDebug', 'P') IS NOT NULL
  DROP PROC TestDebug
GO
CREATE PROCEDURE dbo.TestDebug @Texto VarChar(200)
AS
BEGIN
  DECLARE @i Int

  IF dbo.fn_SomenteTexto(@Texto, 'N') <> @Texto
  BEGIN
    RAISERROR ('Valor informado na vari�vel de entrada n�o � permitido!', 16, 0)
  END
  --...
END
GO