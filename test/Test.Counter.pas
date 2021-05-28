unit Test.Counter;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TCounterTest = class
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
  end;

implementation

{ TCounterTest }

procedure TCounterTest.IncTo_IncrementsButDoesNotDecrement;
begin
  var Counter := FMetrics.CreateCounter('xxx', 'xxx');

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(100);
  Assert.AreEqual<double>(100, Counter.Value);

  Counter.IncTo(10);
  Assert.AreEqual<double>(100, Counter.Value);
end;

procedure TCounterTest.Setup;
begin
  FRegistry := TMetrics.NewCustomRegistry;
  FMetrics  := TMetrics.WithCustomRegistry(FRegistry);
end;

procedure TCounterTest.TearDown;
begin
  FRegistry := nil;
  FMetrics  := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TCounterTest);

end.

