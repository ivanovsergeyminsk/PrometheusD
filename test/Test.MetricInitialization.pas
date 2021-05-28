unit Test.MetricInitialization;

interface

uses
  DUnitX.TestFramework,
  Prometheus.Metrics
  ;

type
  [TestFixture]
  TMetricInitializationTest = class
  private
    FRegistry: ICollectorRegistry;
    FMetrics: IMetricFactory;

//    class function NewHistogramConfiguration: THistogramConfiguration; static;
//    class function MewSummaryConfiguration: TSummaryConfiguration; static;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  end;

implementation

{ TMetricInitializationTest }


//class function TMetricInitializationTest.MewSummaryConfiguration: TSummaryConfiguration;
//begin
//  result := nil;
//end;

//class function TMetricInitializationTest.NewHistogramConfiguration: THistogramConfiguration;
//begin
//  result := nil;
//end;

procedure TMetricInitializationTest.Setup;
begin
  FRegistry := TMetrics.NewCustomRegistry;
  FMetrics  := TMetrics.WithCustomRegistry(FRegistry);
end;

procedure TMetricInitializationTest.TearDown;
begin
  FRegistry := nil;
  FMetrics  := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TMetricInitializationTest);

end.

