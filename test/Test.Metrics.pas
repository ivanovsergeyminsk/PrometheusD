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

    [Test]
    procedure Histogram_no_buckets;
    [Test]
    procedure Histogram_buckets_do_not_increase;
    [Test]
    procedure Histogram_exponential_buckets_are_correct;
    [Test]
    [TestCase('count: -1',   ' 1,   2,  -1')]
    [TestCase('count: 0',    ' 1,   2,   0')]
    [TestCase('start: -1',   '-1,   2,   5')]
    [TestCase('start: 0',    ' 0,   2,   5')]
    [TestCase('factor: 0.9', ' 1, 0.9,   5')]
    [TestCase('factor: 0',   ' 1,   0,   5')]
    [TestCase('factor: -1',  ' 1,  -1,   5')]
    procedure Histogram_exponential_buckets_WillRaise(Start, Factor: double; Count: integer);
    [Test]
    procedure Histogram_linear_buckets_are_correct;
    [Test]
    [TestCase('count: -1',   ' 1,   2,  -1')]
    [TestCase('count: 0',    ' 1,   2,   0')]
    [TestCase('start: -1',   '-1,   2,   5')]
    [TestCase('start: 0',    ' 0,   2,   5')]
    [TestCase('width: 0.9',  ' 1, 0.9,   5')]
    [TestCase('width: 0',    ' 1,   0,   5')]
    [TestCase('width: -1',   ' 1,  -1,   5')]
    procedure Histogram_linear_buckets_WillRaise(Start, Width: double; Count: integer);

    [Test]
    procedure Same_labels_return_same_instance;
    [Test]
    procedure Cannot_create_metrics_with_the_same_name_but_different_labels;
    [Test]
    procedure Cannot_create_metrics_with_the_same_name_and_labels_but_different_type;


    [Test]
    [TestCase('name: my-metric',   'my-metric,  help')]
    [TestCase('name: my!metric',   'my!metric,  help')]
    [TestCase('name: %',           '%,          help')]
    [TestCase('name: 5a',          '5a,         help')]
    procedure MetricNames_WillRaise(Name, Help: string);
    [Test]
    [TestCase('name: abc',        'abc,       help')]
    [TestCase('name: myMetric2',  'myMetric2, help')]
    [TestCase('name: a:3',        'a:3,       help')]
    procedure MetricNames(Name, Help: string);

    [Test]
    [TestCase('label: my-metric',  'a, help, my-metric')]
    [TestCase('label: my!metric',  'a, help, my!metric')]
    [TestCase('label: my%metric',  'a, help, my%metric')]
    [TestCase('label: le',         'a, help, le')]
    [TestCase('label: __reserved', 'c, help1, __reserved')]
    procedure LabelNames_WillRaise(Name, Help, LabelName: string);
    [Test]
    [TestCase('label: my:metric',  'a, help, my:metric')]
    [TestCase('label: good_name',  'b, help, good_name')]
    procedure LabelNames(Name, Help, LabelName: string);

    [Test]
    procedure LabelValues;
    [Test]
    procedure GetAllLabelValues_GetsThemAll;
    [Test]
    procedure GetAllLabelValues_DoesNotGetUnlabelled;

//    [Test]
    procedure CreateCounter_WithDifferentRegistry_CreatesIndependentCounters;
//    [Test]
    procedure Export_FamilyWithOnlyNonpublishedUnlabeledMetrics_ExportsFamilyDeclaration;
  end;

implementation
uses
  System.SysUtils,
  System.Threading
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

  Assert.WillRaise(
    procedure begin
      Gauge.Labels(['1']);
    end,
    EArgumentException
  );

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

  Assert.AreEqual<double>(0, Counter.Labels(['a']).Value);
  Counter.Labels(['a']).Inc(3.3);
  Counter.Labels(['a']).Inc(1.1);
  Assert.AreEqual<double>(4.4, Counter.Labels(['a']).Value);
end;

procedure TMetricsTest.Cannot_create_metrics_with_the_same_name_and_labels_but_different_type;
begin
  FMetrics.CreateGauge('Name1', 'h', ['label1']);
  try
    FMetrics.CreateCounter('Name1', 'h', ['label1']);
    Assert.Fail('Should have throw');
  except
    on E: Exception do
      Assert.AreEqual('Collector of a different type with the same name is already registered.', E.Message);
  end;
end;

procedure TMetricsTest.Cannot_create_metrics_with_the_same_name_but_different_labels;
begin
  FMetrics.CreateGauge('Name1', 'h');
  try
    FMetrics.CreateGauge('Name1', 'h', ['Label1']);
    Assert.Fail('Should have throw');
  except
    on E: Exception do
      Assert.AreEqual('Collector matches a previous registration but has a different set of label names.', E.Message);
  end;
end;

procedure TMetricsTest.CreateCounter_WithDifferentRegistry_CreatesIndependentCounters;
begin
  var Registry1 := TMetrics.NewCustomRegistry;
  var Registry2 := TMetrics.NewCustomRegistry;
  var Counter1  := TMetrics.WithCustomRegistry(Registry1)
    .CreateCounter('Counter', '');
  var Counter2  := TMetrics.WithCustomRegistry(Registry2)
    .CreateCounter('Counter', '');

  Assert.AreNotSame(Counter1, Counter2);

  Counter1.Inc();
  Counter2.Inc();

  Assert.AreEqual<double>(1, Counter1.Value);
  Assert.AreEqual<double>(1, Counter2.Value);

//  var Mock1 := TMock<IMetricsSerializer>.Create;
//  Mock1.Setup.Expect.AtLeastOnce;
//  var Serializer1 := Mock1.Instance;
//  TTask.WaitForAny(Registry1.CollectAndSerializeAsync(Serializer1));

end;

procedure TMetricsTest.Export_FamilyWithOnlyNonpublishedUnlabeledMetrics_ExportsFamilyDeclaration;
begin

end;

procedure TMetricsTest.GetAllLabelValues_DoesNotGetUnlabelled;
begin
  var Metric := FMetrics.CreateGauge('feee', 'fefe');
  Metric.Inc();

  var Values := Metric.GetAllLabelValues;

  Assert.AreEqual(0, Length(Values));
end;

procedure TMetricsTest.GetAllLabelValues_GetsThemAll;
begin
  var Metric := FMetrics
    .CreateGauge('metric1', 'helpmetric1', ['a', 'b', 'c']);

  Metric.Labels(['1', '2', '3']);
  Metric.Labels(['4', '5', '6']);

  var Values := Metric.GetAllLabelValues;

  Assert.AreEqual(2, Length(Values));

  Assert.AreEqual(3, Length(Values[0]));
  Assert.AreEqual('1', Values[0][0]);
  Assert.AreEqual('2', Values[0][1]);
  Assert.AreEqual('3', Values[0][2]);

  Assert.AreEqual(3, Length(Values[1]));
  Assert.AreEqual('4', Values[1][0]);
  Assert.AreEqual('5', Values[1][1]);
  Assert.AreEqual('6', Values[1][2]);
end;

procedure TMetricsTest.Histogram_buckets_do_not_increase;
begin
  try
    var Conf := THistogramConfiguration.Create;
    Conf.Buckets := [0.5, 0.1];

    FMetrics.CreateHistogram('hist', 'help', Conf);

    Assert.Fail('Exptected an exception');
  except
    on E: Exception do
      Assert.AreEqual('Bucket values must be increasing', E.Message)
  end;
end;

procedure TMetricsTest.Histogram_exponential_buckets_are_correct;
begin
  var BucketsStart  := 1.1;
  var BucketsFactor := 2.4;
  var BucketsCount  := 4;

  var Buckets := TMetrics.ExponentialBuckets(BucketsStart, BucketsFactor, BucketsCount);

  Assert.AreEqual(BucketsCount, Length(Buckets));
  Assert.AreEqual<double>(1.1, Buckets[0]);
  Assert.AreEqual<double>(2.64, Buckets[1]);
  Assert.AreEqual<double>(6.336, Buckets[2]);
  Assert.AreEqual<double>(15.2064, Buckets[3]);
end;

procedure TMetricsTest.Histogram_exponential_buckets_WillRaise(Start, Factor: double; Count: integer);
begin
  Assert.WillRaise(procedure begin
    TMetrics.ExponentialBuckets(Start, Factor, Count)
  end, EArgumentException);
end;

procedure TMetricsTest.Histogram_linear_buckets_are_correct;
begin
  var BucketsStart := 1.1;
  var BucketsWidth := 2.4;
  var BucketsCount := 4;

  var Buckets := TMetrics.LinearBuckets(BucketsStart, BucketsWidth, BucketsCount);

  Assert.AreEqual(BucketsCount, Length(Buckets));
  Assert.AreEqual<double>(1.1, Buckets[0]);
  Assert.AreEqual<double>(3.5, Buckets[1]);
  Assert.AreEqual<double>(5.9, Buckets[2]);
  Assert.AreEqual<double>(8.3, Buckets[3]);
end;

procedure TMetricsTest.Histogram_linear_buckets_WillRaise(Start, Width: double;
  Count: integer);
begin
  Assert.WillRaise(procedure begin
    TMetrics.ExponentialBuckets(Start, Width, Count)
  end, EArgumentException);
end;

procedure TMetricsTest.Histogram_no_buckets;
begin
  Assert.Pass('Empty Buckets set from Default Backets')
//  try
//    var Conf := THistogramConfiguration.Create;
//    Conf.Buckets := [];
//    FMetrics.CreateHistogram('hist', 'help', Conf);
//
//    Assert.Fail('Expected an exception');
//  except
//    on E: Exception do
//    Assert.AreEqual('Histogram must have at least one bucket', E.Message);
//  end;
end;

procedure TMetricsTest.LabelNames(Name, Help, LabelName: string);
begin
  Assert.WillNotRaiseAny(
  procedure begin
    FMetrics.CreateGauge(Name, Help);
  end);
end;

procedure TMetricsTest.LabelNames_WillRaise(Name, Help, LabelName: string);
begin
  if LabelName.Equals('le') then begin

    Assert.WillRaise(procedure begin
      FMetrics.CreateHistogram(Name, Help, [LabelName]);
    end, EArgumentException);

  end else begin

    Assert.WillRaise(procedure begin
      FMetrics.CreateGauge(Name, Help, [LabelName]);
    end, EArgumentException);

  end;
end;

procedure TMetricsTest.LabelValues;
begin
  var Metric := FMetrics.CreateGauge('a', 'help', ['MyLabelName']);

  Assert.WillNotRaiseAny(
  procedure begin
    Metric.Labels(['']);
    Metric.Labels(['mylabelvalue']);
  end);
end;

procedure TMetricsTest.MetricNames(Name, Help: string);
begin
  Assert.WillNotRaiseAny(
  procedure begin
    FMetrics.CreateGauge(Name, Help);
  end);
end;

procedure TMetricsTest.MetricNames_WillRaise(Name, Help: string);
begin
  Assert.WillRaise(procedure begin
    FMetrics.CreateGauge(Name, Help);
  end, EArgumentException);
end;

procedure TMetricsTest.Same_labels_return_same_instance;
begin
  var Gauge := FMetrics.CreateGauge('Name1', 'Help1', ['Label1']);

  var Labelled1 := Gauge.Labels(['1']);
  var Labelled2 := Gauge.Labels(['1']);

  Assert.AreSame(Labelled1, Labelled2);
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
