unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, DB, ADODB, StdCtrls, ExtCtrls, DBCtrls, Grids, DBGrids;

type
  TForm1 = class(TForm)
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Button1: TButton;
    ADOConnection1: TADOConnection;
    ADOQuery1: TADOQuery;
    Button2: TButton;
    ADOQuery1OrderID: TAutoIncField;
    ADOQuery1CustomerID: TIntegerField;
    ADOQuery1OrderDate: TWideStringField;
    procedure Button1Click(Sender: TObject);
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
  i : Int64;
  Tempo : TDateTime;
begin
  i := 0;
  Tempo := Now();
  if not ADOConnection1.Connected then
  begin
    ADOConnection1.Connected := True;
  end;
  ADOQuery1.Close;
  ADOQuery1.SQL.Text := 'DBCC DROPCLEANBUFFERS; SELECT OrderID, CustomerID, OrderDate FROM OrdersBig ORDER BY CustomerID, OrderID OPTION (MAXDOP 1)';
  ADOQuery1.Open;
  ShowMessage(FormatDateTime('hh:mm:ss.zzz', Tempo - Now()));
end;

procedure TForm1.Button2Click(Sender: TObject);
Var
  i : Int64;
  Tempo : TDateTime;
begin
  i := 0;
  Tempo := Now();
  if not ADOConnection1.Connected then
  begin
    ADOConnection1.Connected := True;
  end;
  ADOQuery1.Close;
  ADOQuery1.SQL.Text := 'DBCC DROPCLEANBUFFERS; SELECT OrderID, CustomerID, OrderDate FROM OrdersBig OPTION (MAXDOP 1)';
  ADOQuery1.Open;
  ShowMessage(FormatDateTime('hh:mm:ss.zzz', Tempo - Now()));
  Tempo := Now();
  ADOQuery1.Sort := 'CustomerID, OrderID';
  ShowMessage(FormatDateTime('hh:mm:ss.zzz', Tempo - Now()));
end;

end.
