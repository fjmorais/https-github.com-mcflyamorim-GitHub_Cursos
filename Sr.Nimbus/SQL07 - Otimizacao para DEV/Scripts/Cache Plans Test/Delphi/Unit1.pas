unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Grids, DBGrids, DB, ADODB, ExtCtrls, DBCtrls;

type
  TFrm1 = class(TForm)
    ADOConnection1: TADOConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Label1: TLabel;
    Edit1: TEdit;
    Button1: TButton;
    Edit2: TEdit;
    Label2: TLabel;
    ListBox1: TListBox;
    Label3: TLabel;
    Button2: TButton;
    Label4: TLabel;
    DBNavigator1: TDBNavigator;
    Memo1: TMemo;
    ADOQuery1: TADOQuery;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Frm1: TFrm1;

implementation

{$R *.dfm}

procedure TFrm1.Button1Click(Sender: TObject);
begin
  ADOConnection1.Connected := False;
  ADOConnection1.ConnectionString := Edit2.Text;
  ADOConnection1.Connected := true;
  ADOQuery1.Close;
  ADOQuery1.SQL := Memo1.Lines;
  ADOQuery1.Parameters.ParamByName('Contact').Value := Edit1.Text;
  ADOQuery1.Open;
end;

procedure TFrm1.Button2Click(Sender: TObject);
  Var i : Integer;
begin
  ADOConnection1.Connected := False;
  ADOQuery1.Parameters.ParamByName('Contact').Value := Edit1.Text;
  ADOConnection1.ConnectionString := Edit2.Text;
  ADOConnection1.Connected := true;

  for i:= 0 to -1 + ListBox1.Count do
  begin
    ADOQuery1.Close;
    ADOQuery1.Parameters.ParamByName('Contact').Value := ListBox1.Items[i];
    ADOQuery1.Open;
  end;

  ShowMessage('OK');
end;

end.
