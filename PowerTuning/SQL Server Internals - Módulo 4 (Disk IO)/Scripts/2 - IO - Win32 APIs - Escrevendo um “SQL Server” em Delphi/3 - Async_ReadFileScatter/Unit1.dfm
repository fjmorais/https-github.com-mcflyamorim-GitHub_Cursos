object Form1: TForm1
  Left = 234
  Top = 188
  Width = 1075
  Height = 490
  Caption = 'InternalsParte4_Win32API_AsyncIOs_ReadFileScatter'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 152
    Width = 124
    Height = 13
    Caption = 'Tamanho do I/O em bytes'
  end
  object Label2: TLabel
    Left = 16
    Top = 80
    Width = 45
    Height = 13
    Caption = 'Arquivo...'
  end
  object Label3: TLabel
    Left = 16
    Top = 104
    Width = 45
    Height = 13
    Caption = 'Arquivo...'
  end
  object Label4: TLabel
    Left = 336
    Top = 400
    Width = 625
    Height = 25
    Caption = 'Nota: Abrir o ProcessMonitor pra ver o tamanho do I/O enviado...'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clRed
    Font.Height = -20
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Memo3: TMemo
    Left = 8
    Top = 176
    Width = 321
    Height = 265
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Button4: TButton
    Left = 16
    Top = 16
    Width = 457
    Height = 25
    Caption = 
      'Chama ReadFileScatter com  FILE_FLAG_OVERLAPPED + FILE_FLAG_NO_B' +
      'UFFERING'
    TabOrder = 1
    OnClick = Button4Click
  end
  object ProgressBar1: TProgressBar
    Left = 16
    Top = 48
    Width = 977
    Height = 17
    Min = 0
    Max = 100
    TabOrder = 2
  end
  object Edit1: TEdit
    Left = 144
    Top = 149
    Width = 97
    Height = 21
    TabOrder = 3
    Text = '65536'
  end
  object edtfPath: TEdit
    Left = 64
    Top = 77
    Width = 977
    Height = 21
    TabOrder = 4
    Text = 'C:\temp\Test3.txt'
  end
  object Edit2: TEdit
    Left = 248
    Top = 149
    Width = 97
    Height = 21
    TabOrder = 5
    Text = '1048576 --1MB'
  end
  object Edit3: TEdit
    Left = 64
    Top = 101
    Width = 977
    Height = 21
    TabOrder = 6
    Text = 'C:\temp\TabelaTeste1.csv'
  end
end
