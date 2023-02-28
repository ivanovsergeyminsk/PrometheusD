unit Test.CollectorRegistry;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics,
  System.Threading
  ;

type
  [TestFixture]
  TCollectorRegistryTest = class
  private
    function FactoryTaskMetric(const num: int64): ITask;
  public
    [Test]
    procedure ExportAsText_ExportsExpectedData;

//    [Test]
    procedure ExportAsText_Multithreading;
  end;

implementation
uses
  System.Classes,
  System.SysUtils,
  System.DateUtils
  ;

{ TCollectorRegistryTest }

procedure TCollectorRegistryTest.ExportAsText_ExportsExpectedData;
begin
  var FRegistry := TMetrics.NewCustomRegistry;
  var FMetrics  := TMetrics.WithCustomRegistry(FRegistry);

  const Canary = 'sb64v77';
  const CanaryValue = 64835.83;

  var Gauge := FMetrics.CreateGauge(Canary, '');
  Gauge.&Set(CanaryValue);

  var text: string;
  var Stream := TStringStream.Create;
  try
    FRegistry.CollectAndExportAsText(Stream);
    text := Stream.DataString;
  finally
    Stream.Free;
  end;

  Assert.Contains(text, Canary);
  Assert.Contains(text, CanaryValue.ToString.Replace(',','.'));
end;

procedure TCollectorRegistryTest.ExportAsText_Multithreading;
begin
//  TThreadPool.Default.SetMaxWorkerThreads(100);
//  TThreadPool.Default.SetMinWorkerThreads(100);

  var MetricTasks: TArray<ITask>;
  for var I := 1 to 30 do
  begin
    MetricTasks := MetricTasks + [FactoryTaskMetric(I)];
    MetricTasks[Length(MetricTasks)-1].Start;
  end;


  var TaskCollect := TTask.Run(
    procedure
    begin
      TThread.Current.NameThreadForDebugging('Task Collector');
      var StopTime : TDateTime := Now + 6/MinsPerDay;
      while Now < StopTime do
      begin

        var text: string;
        var Stream := TStringStream.Create;
        try
          TMetrics.DefaultRegistry.CollectAndExportAsText(Stream);
          text := Stream.DataString;
          Stream.SaveToFile(format('C:\DEV\Delphi\PrometheusD\Win32\metrics_%s.txt',[Now.Format('hh_nn_ss_zzz')]));
        finally
          Stream.Free;
        end;
        sleep(1000);
      end;
    end);

  MetricTasks := MetricTasks + [TaskCollect];
  TTask.WaitForAll(MetricTasks);

//  Assert.Contains(text, Canary);
//  Assert.Contains(text, CanaryValue.ToString.Replace(',','.'));
end;

function TCollectorRegistryTest.FactoryTaskMetric(const num: int64): ITask;
var
  LNum: int64;
begin
  LNum := num;
  result := TTask.Create(
    procedure
    begin
      TThread.Current.NameThreadForDebugging('Metric task '+ LNum.ToString);
      var Counter := TMetrics.CreateCounter('Counter'+LNum.ToString, 'TestWorkThread'+LNum.ToString);

      var StopTime : TDateTime := Now + 5/MinsPerDay;
      while Now < StopTime do
      begin
        Counter.Inc;
        sleep(100+Random(300));
      end;
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TCollectorRegistryTest);

end.
