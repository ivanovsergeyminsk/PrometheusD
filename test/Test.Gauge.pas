unit Test.Gauge;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TGaugeTest = class
  private
    FRegistry: ICollectorRegistry;
    FMetrics: IMetricFactory;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure IncTo_IncrementsButDoesNotDecrement;
    [Test]
    procedure DecTo_DecrementsButDoesNotIncrement;
  end;

implementation

{ TGaugeTest }

procedure TGaugeTest.DecTo_DecrementsButDoesNotIncrement;
begin
  var Gauge := FMetrics.CreateGauge('xxx', 'xxx');
  Gauge.&Set(999);

  Gauge.DecTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.DecTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

   Gauge.DecTo(500);
  Assert.AreEqual<double>(100, Gauge.Value);
end;

procedure TGaugeTest.IncTo_IncrementsButDoesNotDecrement;
begin
  var Gauge := FMetrics.CreateGauge('xxx', 'xxx');

  Gauge.IncTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

  Gauge.IncTo(100);
  Assert.AreEqual<double>(100, Gauge.Value);

   Gauge.IncTo(10);
  Assert.AreEqual<double>(100, Gauge.Value);
end;

procedure TGaugeTest.Setup;
begin
  FRegistry := TMetrics.NewCustomRegistry;
  FMetrics  := TMetrics.WithCustomRegistry(FRegistry);
end;

procedure TGaugeTest.TearDown;
begin
  FRegistry := nil;
  FMetrics  := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TGaugeTest);

end.

