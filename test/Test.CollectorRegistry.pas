unit Test.CollectorRegistry;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TCollectorRegistryTest = class
  public
    [Test]
    procedure ExportAsText_ExportsExpectedData;
  end;

implementation
uses
  System.Classes,
  System.SysUtils,
  System.Threading
  ;

{ TCollectorRegistryTest }

procedure TCollectorRegistryTest.ExportAsText_ExportsExpectedData;
begin
  var Registry  := TMetrics.NewCustomRegistry;
  var Factory   := TMetrics.WithCustomRegistry(Registry);

  const Canary = 'sb64v77';
  const CanaryValue = 64835.83;

  var Gauge := Factory.CreateGauge(Canary, '');
  Gauge.&Set(CanaryValue);

  var text: string;
  var Stream := TStringStream.Create;
  try
    TTask.WaitForAny(Registry.CollectAndExportAsTextAsync(Stream));
    text := Stream.DataString;
  finally
    Stream.Free;
  end;

  Assert.Contains(text, Canary);
  Assert.Contains(text, CanaryValue.ToString);
end;

initialization
  TDUnitX.RegisterTestFixture(TCollectorRegistryTest);

end.
