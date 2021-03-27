unit Test.Metrics;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TMetricsTest = class
  private
    FRegistry: ICollectorRegistry;
    FMetrics: IMetricFactory;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ApiUsage;
  end;

implementation
uses
  System.SysUtils
  ;

procedure TMetricsTest.ApiUsage;
begin
  var Gauge := FMetrics.CreateGauge('Name1', 'Help1');
  Gauge.Inc;
  Assert.AreEqual<double>(1, Gauge.Value);
  Gauge.Inc(3.2);
  Assert.AreEqual<double>(4.2, Gauge.Value);
  Gauge.&Set(4);
  Assert.AreEqual<double>(4, Gauge.Value);
  Gauge.Dec(0.2);
  Assert.AreEqual<double>(3.8, Gauge.Value);

//  Assert.WillRaise(
//    procedure begin
//      ICollector<IGauge>(Gauge).Labels(['1']);
//    end,
//    EArgumentException
//  );

  var Counter := TMetrics.CreateCounter('Name2', 'Help2', ['Label1']);
  Counter.Inc;
  Counter.Inc(3.2);
  Counter.Inc(0);
  Assert.WillRaise(
    procedure begin
      Counter.Inc(-1);
    end,
    EArgumentOutOfRangeException
  );
  Assert.AreEqual<double>(4.2, Counter.Value);

//  Assert.AreEqual<double>(0, ICounter(ICollector<ICounter>(Counter).Labels(['a'])).Value);
//  Counter.
end;

procedure TMetricsTest.Setup;
begin
  FRegistry := TMetrics.NewCustomRegistry;
  FMetrics  := TMetrics.WithCustomRegistry(FRegistry);
end;

procedure TMetricsTest.TearDown;
begin
  FRegistry := nil;
  FMetrics  := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TMetricsTest);

end.
