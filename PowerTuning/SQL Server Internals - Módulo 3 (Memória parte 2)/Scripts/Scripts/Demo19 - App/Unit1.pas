unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DB, ADODB, Grids, DBGrids ;

type
  TForm1 = class(TForm)
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    ADOConnection1: TADOConnection;
    ADOQuery1: TADOQuery;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ADOStoredProc1: TADOStoredProc;
    Label1: TLabel;
    Label2: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
Var
  Tempo : TDateTime;
begin
  Label1.Caption := 'Running';
  Application.ProcessMessages;
  self.Refresh;//Refresh the form.

  ADOConnection1.Connected := True;
  ADOQuery1.Close;
  Tempo := Now();
  ADOQuery1.Parameters.ParamByName('PageNumber').Value := 1;
  ADOQuery1.Parameters.ParamByName('RowsPerPage').Value := 20;
  ADOQuery1.Open;
  Label1.Caption := 'Time to run query: ' + FormatDateTime('hh:mm:ss.zzz', Tempo - Now());
  Label2.Caption := 'Page ' + floattostr(ADOQuery1.Parameters.ParamByName('PageNumber').Value);
end;

procedure TForm1.Button3Click(Sender: TObject);
Var
  Tempo : TDateTime;
begin
  Label1.Caption := 'Running';
  Application.ProcessMessages;
  self.Refresh;//Refresh the form.
  
  ADOConnection1.Connected := True;
  ADOQuery1.Close;
  Tempo := Now();
  ADOQuery1.Parameters.ParamByName('PageNumber').Value := StrToInt(ADOQuery1.Parameters.ParamByName('PageNumber').Value) + 1;
  ADOQuery1.Parameters.ParamByName('RowsPerPage').Value := 20;
  ADOQuery1.Open;
  Label1.Caption := 'Time to run query: ' + FormatDateTime('hh:mm:ss.zzz', Tempo - Now());
  Label2.Caption := 'Page ' + floattostr(ADOQuery1.Parameters.ParamByName('PageNumber').Value);
end;

procedure TForm1.Button2Click(Sender: TObject);
Var
  Tempo : TDateTime;
begin
  Label1.Caption := 'Running';
  Application.ProcessMessages;
  self.Refresh;//Refresh the form.
  
  ADOConnection1.Connected := True;
  ADOQuery1.Close;
  Tempo := Now();
  ADOQuery1.Parameters.ParamByName('PageNumber').Value := StrToInt(ADOQuery1.Parameters.ParamByName('PageNumber').Value) - 1;
  ADOQuery1.Parameters.ParamByName('RowsPerPage').Value := 20;
  ADOQuery1.Open;
  Label1.Caption := 'Time to run query: ' + FormatDateTime('hh:mm:ss.zzz', Tempo - Now());
  Label2.Caption := 'Page ' + floattostr(ADOQuery1.Parameters.ParamByName('PageNumber').Value);
end;

end.
