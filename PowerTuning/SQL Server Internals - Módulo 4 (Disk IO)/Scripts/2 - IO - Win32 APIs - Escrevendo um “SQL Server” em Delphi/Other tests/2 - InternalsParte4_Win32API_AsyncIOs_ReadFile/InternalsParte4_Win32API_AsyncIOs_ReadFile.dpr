program InternalsParte4_Win32API_AsyncIOs_ReadFile;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'InternalsParte4_Win32API_AsyncIOs_ReadFile';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
