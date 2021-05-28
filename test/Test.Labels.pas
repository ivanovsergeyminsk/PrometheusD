unit Test.Labels;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TPrometheusTest = class
  public
    [Test]
    procedure CollectorRegistry_ExportAsText_ExportsExpectedData;

    [Test]
    procedure Counter_IncTo_IncrementsButDoesNotDecrement;

    [Test]
    procedure Gauge_IncTo_IncrementsButDoesNotDecrement;
    [Test]
    procedure Gauge_DecTo_DecrementsButDoesNotIncrement;

    [Test]
    procedure NewLabels;
    [Test]
    procedure Counter;

    [Test]
    procedure Def;
  end;

implementation
uses
  System.SysUtils,
  System.Classes,
  System.Threading
  ;

{ TPrometheusTest }

procedure TPrometheusTest.CollectorRegistry_ExportAsText_ExportsExpectedData;
begin
  var Registry := TMetrics.NewCustomRegistry;
  var Factory  := TMetrics.WithCustomRegistry(Registry);

  const Canary: string = 'sb64v77';
  const CanaryValue: double = 64835.83;

  var Gauge := Factory.CreateGauge(Canary, '');
  Gauge.&Set(CanaryValue);

  var Text: string := '';
  var Stream := TStringStream.Create;
  try
    TTask.WaitForAny(Registry.CollectAndExportAsTextAsync(Stream));
    Text := Stream.DataString;
  finally
    Stream.Free;
  end;

  Assert.Contains(Text, Canary);
  Assert.Contains(Text, CanaryValue.ToString);
end;

procedure TPrometheusTest.Counter;
begin
  var FRegistry := TMetrics.NewCustomRegistry;
  var FMetrics  := TMetrics.WithCustomRegistry(FRegistry);
  var Counter := FMetrics.CreateCounter('xxx', 'x x x', ['Label1', 'Label2', 'Label3']);

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(10);
  Assert.AreEqual<double>(100, Counter.Value);

  var Stream := TStringStream.Create;
  TTask.WaitForAny(FRegistry.CollectAndExportAsTextAsync(Stream));

  var Text := Stream.DataString;
  Stream.Free;
  text := '';

  Counter   := nil;
  FMetrics  := nil;
  FRegistry := nil;
end;

procedure TPrometheusTest.Counter_IncTo_IncrementsButDoesNotDecrement;
begin
  var FRegistry := TMetrics.NewCustomRegistry;
  var FMetrics  := TMetrics.WithCustomRegistry(FRegistry);

  var Counter := TMetrics.CreateCounter('xxx', 'xxx');

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(10);
  Assert.AreEqual<double>(100, Counter.Value);
end;

procedure TPrometheusTest.Def;
begin
  var Registry := TMetrics.DefaultRegistry;

  var Stream := TStringStream.Create('', TEncoding.UTF8);
  TTask.WaitForAny(Registry.CollectAndExportAsTextAsync(Stream));

  var Text := Stream.DataString;
  Stream.Free;
  text := '';

end;

procedure TPrometheusTest.Gauge_DecTo_DecrementsButDoesNotIncrement;
begin
  var FRegistry := TMetrics.NewCustomRegistry;
  var FMetrics  := TMetrics.WithCustomRegistry(FRegistry);

  var Gauge := FMetrics.CreateGauge('xxx', 'xxx');

  Gauge.&Set(999);

  Gauge.DecTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.DecTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.DecTo(500);
  Assert.AreEqual<double>(100, Gauge.Value);
end;

procedure TPrometheusTest.Gauge_IncTo_IncrementsButDoesNotDecrement;
begin
  var FRegistry := TMetrics.NewCustomRegistry;
  var FMetrics  := TMetrics.WithCustomRegistry(FRegistry);

  var Gauge := FMetrics.CreateGauge('xxx', 'xxx');

  Gauge.IncTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.IncTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.IncTo(10);
  Assert.AreEqual<double>(100, Gauge.Value);
end;

procedure TPrometheusTest.NewLabels;
begin
  Assert.WillRaiseAny(procedure begin
    var Labels := TLabels.New(['Name1', 'Name2'], []);
  end);

  Assert.WillNotRaiseAny(procedure begin
    var Labels := TLabels.New([], []);
  end);

  var ExNames  := ['Name1', 'Name2'];
  var ExValues := ['Val1', 'Val2'];
  var Labels := TLabels.New(['Name1', 'Name2'], ['Val1', 'Val2']);
  Assert.AreEqual(ExNames[0],  Labels.Names[0],  'Labels.Names[0]');
  Assert.AreEqual(ExNames[1],  Labels.Names[1],  'Labels.Names[1]');
  Assert.AreEqual(ExValues[0], Labels.Values[0], 'Labels.Values[0]');
  Assert.AreEqual(ExValues[1], Labels.Values[1], 'Labels.Values[1]');

  Assert.AreEqual(2, Labels.Count, 'Labels.Count');
  Labels := Labels.Concat([TStringPair.Create('Name3', 'Val3')]);
  Assert.AreEqual('Name3', Labels.Names[2], 'Labels.Names[3]');

  var OtherLabels := TLabels.New(['Name4', 'Name5'], ['Val4', 'Val5']);
  Labels := Labels.Concat(OtherLabels);
  Assert.AreEqual('Val5', Labels.Values[4], 'Labels.Values[4]');

  var LabelSerialized := 'Name1="Val1",Name2="Val2",Name3="Val3",Name4="Val4",Name5="Val5"';
  Assert.AreEqual(LabelSerialized, Labels.Serialize, 'Labels.Serialize');
end;

initialization
  TDUnitX.RegisterTestFixture(TPrometheusTest);

end.
