unit View.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,

  System.Threading,
  Prometheus.Metrics,
  Prometheus.Server,
  Prometheus.DelphiStats, FMX.Edit
  ;

type
  TFormMain = class(TForm)
    ButtonStart: TButton;
    ButtonStop: TButton;
    Button1: TButton;
    Edit1: TEdit;
    Button2: TButton;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonStopClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    Buffer: TArray<byte>;
    FServer: IMetricServer;

    FTest: ITask;

    Stat: TDelphiStats;
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

uses
    Prometheus.Server.Exporter
  ;

{$R *.fmx}

function RandomRangeF(min, max: single): single;
begin
  result := min + Random * (max - min);
end;

procedure TFormMain.Button1Click(Sender: TObject);
begin
  if not assigned(FTest) then exit;
  FTest.Cancel;
end;

procedure TFormMain.Button2Click(Sender: TObject);
begin
  SetLength(Buffer, 1024*1024*Edit1.Text.ToInteger);
end;

procedure TFormMain.Button3Click(Sender: TObject);
begin
  Buffer := [];
end;

procedure TFormMain.ButtonStartClick(Sender: TObject);
begin
  FServer.Start;
end;

procedure TFormMain.ButtonStopClick(Sender: TObject);
begin
  if assigned(FTest) then exit;

  FTest := TTask.Run(procedure begin
    while true do begin
      sleep(5);
      try
        TTask.CurrentTask.CheckCanceled;
        Stat.TestCounter.Inc;
        Stat.TestGauge.&Set(RandomRangeF(100, 10000));
        Stat.TestSummary.Observe(RandomRangeF(1, 100));
        Stat.TestHitogram.Observe(RandomRangeF(0,10), Random(10));
      except
        on E: Exception do begin
          FTest := nil;
          exit;
        end;
      end;
    end;

  end);
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  Stat := TDelphiStats.Create(TMetrics.DefaultRegistry);
  FServer := TMetricServer.Create(5678);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  Stat.Free;
  FServer.Stop;
  FServer := nil;
end;

end.
