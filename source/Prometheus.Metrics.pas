unit Prometheus.Metrics;

interface
uses
  System.Classes,
  System.SysUtils,
  System.Threading,
  System.Generics.Collections,
  System.TimeSpan
  ;

type

  TDebugInterfacedObject = class abstract(TInterfacedObject)
  protected
    function QueryInterface(const IID: TGUID; out Obj): HResult; reintroduce; stdcall;
    function _AddRef: Integer; reintroduce; stdcall;
    function _Release: Integer; reintroduce; stdcall;
  end;

{$REGION 'Pre-declaring'}
  IMetricsSerializer = interface;
  ICollectorRegistry = interface;
  IMetricFactory = interface;

  ICollectorChild = interface;
  ICounter = interface;
  IGauge = interface;
  ISummary = interface;
  IHistogram = interface;

  ICounterConfiguration = interface;
  IGaugeConfiguration = interface;
  ISummaryConfiguration = interface;
  IHistogramConfiguration = interface;
{$ENDREGION}

{$REGION 'TMetrics. Static API-class for easy creation of metrics'}

  /// <summary>
  /// Static class for easy creation of metrics. Acts as the entry point to the prometheus-net metrics recording API.
  ///
  /// Some built-in metrics are registered by default in the default collector registry. This is mainly to ensure that
  /// the library exports some metrics when installed. If these default metrics are not desired, call
  /// <see cref="SuppressDefaultMetrics"/> to remove them before registering your own.
  /// </summary>
  TMetrics = class
  strict private
    class var FDefaultFactory: IMetricFactory;
    class function GetDefaultRegistry: ICollectorRegistry; static;
    class constructor Create;
    class destructor Destroy;
  protected
    class function NewSerializer(const StreamFactory: TFunc<TStream>): IMetricsSerializer;
  public
    /// <summary>
    /// The default registry where all metrics are registered by default.
    /// </summary>
    class property DefaultRegistry: ICollectorRegistry read GetDefaultRegistry;
    /// <summary>
    /// Creates a new registry. You may want to use multiple registries if you want to
    /// export different sets of metrics via different exporters (e.g. on different URLs).
    /// </summary>
    class function NewCustomRegistry: ICollectorRegistry; static;
    /// <summary>
    /// Returns an instance of <see cref="MetricFactory" /> that you can use to register metrics in a custom registry.
    /// </summary>
    class function WithCustomRegistry(Registry: ICollectorRegistry): IMetricFactory; static;
    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    class function CreateCounter(Name, Help: string; Configuration: ICounterConfiguration = nil): ICounter; overload; static;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    class function CreateGauge(Name, Help: string; Configuration: IGaugeConfiguration = nil): IGauge; overload; static;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    class function CreateSummary(Name, Help: string; Configuration: ISummaryConfiguration = nil): ISummary; overload; static;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    class function CreateHistogram(Name, Help: string; Configuration: IHistogramConfiguration = nil): IHistogram; overload;  static;

    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    class function CreateCounter(Name, Help: string; LabelNames: TArray<string>): ICounter; overload; static;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    class function CreateGauge(Name, Help: string; LabelNames: TArray<string>): IGauge; overload; static;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    class function CreateSummary(Name, Help: string; LabelNames: TArray<string>): ISummary; overload; static;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    class function CreateHistogram(Name, Help: string; LabelNames: TArray<string>): IHistogram; overload; static;
    /// <summary>
    /// Suppresses the registration of the default sample metrics from the default registry.
    /// Has no effect if not called on startup (it will not remove metrics from a registry already in use).
    /// </summary>
    class procedure SuppressDefaultMetrics; static;
  end;

{$ENDREGION}

{$REGION 'Interfaces'}

  /// <summary>
  /// Maintains references to a set of collectors, from which data for metrics is collected at data export time.
  ///
  /// Use methods on the <see cref="Metrics"/> class to add metrics to a collector registry.
  /// </summary>
  /// <remarks>
  /// To encourage good concurrency practices, registries are append-only. You can add things to them but not remove.
  /// If you wish to remove things from the registry, create a new registry with only the things you wish to keep.
  /// </remarks>
  ICollectorRegistry = interface
    function GetStaticLabels: TArray<TPair<string, string>>;
    /// <summary>
    /// Registers an action to be called before metrics are collected.
    /// This enables you to do last-minute updates to metric values very near the time of collection.
    /// Callbacks will delay the metric collection, so do not make them too long or it may time out.
    ///
    /// The callback will be executed synchronously and should not take more than a few milliseconds.
    /// To execute longer-duration callbacks, register an asynchronous callback (Func&lt;Task&gt;).
    ///
    /// If the callback throws <see cref="ScrapeFailedException"/> then the entire metric collection will fail.
    /// This will result in an appropriate HTTP error code or a skipped push, depending on type of exporter.
    ///
    /// If multiple concurrent collections occur, the callback may be called multiple times concurrently.
    /// </summary>
    procedure AddBeforeCollectorCallback(Callback: TProc); overload;
    /// <summary>
    /// Registers an action to be called before metrics are collected.
    /// This enables you to do last-minute updates to metric values very near the time of collection.
    /// Callbacks will delay the metric collection, so do not make them too long or it may time out.
    ///
    /// Asynchronous callbacks will be executed concurrently and may last longer than a few milliseconds.
    ///
    /// If the callback throws <see cref="ScrapeFailedException"/> then the entire metric collection will fail.
    /// This will result in an appropriate HTTP error code or a skipped push, depending on type of exporter.
    ///
    /// If multiple concurrent collections occur, the callback may be called multiple times concurrently.
    /// </summary>
    procedure AddBeforeCollectorCallback(Callback: TFunc<ITask>); overload;

    /// <summary>
    /// The set of static labels that are applied to all metrics in this registry.
    /// Enumeration of the returned collection is thread-safe.
    /// </summary>
    property StaticLabels: TArray<TPair<string, string>> read GetStaticLabels;
    /// <summary>
    /// Defines the set of static labels to apply to all metrics in this registry.
    /// The static labels can only be set once on startup, before adding or publishing any metrics.
    /// </summary>
    procedure SetStaticLabels(Labels: TDictionary<string, string>);
    /// <summary>
    /// Collects all metrics and exports them in text document format to the provided stream.
    ///
    /// This method is designed to be used with custom output mechanisms that do not use an IMetricServer.
    /// </summary>
    function CollectAndExportAsTextAsync(Dest: TStream): ITask;
    /// <summary>
    /// Collects metrics from all the registered collectors and sends them to the specified serializer.
    /// </summary>
    function CollectAndSerializeAsync(Serializer: IMetricsSerializer): ITask;
  end;

  /// <summary>
  /// Adds metrics to a registry.
  /// </summary>
  IMetricFactory = interface
    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    function CreateCounter(Name, Help: string; Configuration: ICounterConfiguration = nil): ICounter; overload;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    function CreateGauge(Name, Help: string; Configuration: IGaugeConfiguration = nil): IGauge; overload;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    function CreateSummary(Name, Help: string; Configuration: ISummaryConfiguration = nil): ISummary; overload;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    function CreateHistogram(Name, Help: string; Configuration: IHistogramConfiguration = nil): IHistogram; overload;

    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    function CreateCounter(Name, Help: string; LabelNames: TArray<string>): ICounter; overload;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    function CreateGauge(Name, Help: string; LabelNames: TArray<string>): IGauge; overload;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    function CreateSummary(Name, Help: string; LabelNames: TArray<string>): ISummary; overload;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    function CreateHistogram(Name, Help: string; LabelNames: TArray<string>): IHistogram; overload;
  end;

  /// <summary>
  /// Base class for metrics, defining the basic informative API and the internal API.
  /// </summary>
  ICollector = interface
    function GetHelp(): String;
    function GetLabelNames(): TArray<string>;
    function GetName(): String;
    /// <summary>
    /// The metric name, e.g. http_requests_total.
    /// </summary>
    property Name: String read GetName;
    /// <summary>
    /// The help text describing the metric for a human audience.
    /// </summary>
    property Help: String read GetHelp;
    /// <summary>
    /// Names of the instance-specific labels (name-value pairs) that apply to this metric.
    /// When the values are added to the names, you get a <see cref="ChildBase"/> instance.
    /// </summary>
    property LabelNames: TArray<string> read GetLabelNames;
  end;

  ICollector<TChild> = interface(ICollector)
    function GetUnlabelled(): ICollectorChild;
    // This servers a slightly silly but useful purpose: by default if you start typing .La... and trigger Intellisense
    // it will often for whatever reason focus on LabelNames instead of Labels, leading to tiny but persistent frustration.
    // Having WithLabels() instead eliminates the other candidate and allows for a frustration-free typing experience.
    function WithLabels(LabelValues: TArray<string>): ICollectorChild;
    /// <summary>
    /// Gets the child instance that has no labels.
    /// </summary>
    property Unlabelled: ICollectorChild read GetUnlabelled;
  end;

  /// <summary>
  /// Base class for labeled instances of metrics (with all label names and label values defined).
  /// </summary>
  ICollectorChild = interface
  end;

  ICounter = interface(ICollectorChild)
    procedure IncTo(TargetValue: double);
    procedure Inc(Increment: double = 1);
    function GetValue(): double;
    property Value: double read GetValue;
  end;

  IGauge = interface(ICollectorChild)
    procedure &Set(Val: double);
    procedure IncTo(TargetValue: double);
    procedure Inc(Increment: double = 1);
    procedure DecTo(TargetValue: double);
    procedure Dec(Decrement: double = 1);
    function GetValue(): double;
    property Value: double read GetValue;
  end;

  IObserver = interface(ICollectorChild)
    procedure Observe(Val: double);
  end;

  ISummary = interface(IObserver)
  end;

  IHistogram = interface(IObserver)
    function GetSum(): double;
    property Sum: double read GetSum;
    function GetCount(): Int64;
    property Count: Int64 read GetCount;
    procedure Observe(Val: double; Count: Int64);
  end;

  IMetricsSerializer = interface
    function WriteMetricAsync(Identifier: TArray<byte>; Value: double): ITask;
    function WriteFamilyDeclarationAsync(HeaderLines: TArray < TArray < byte >> ): ITask;
  end;

{$ENDREGION}

{$REGION 'Others types'}

  TMetricType = (
    Counter,
    Gauge,
    Summary,
    Histogram
  );

  TMetricTypeHelper = record helper for TMetricType
  public
    function ToString: string;
  end;

  TStringPair = TPair<string, string>;

  TQuantileEpsilonPair = record
  strict private
    FQuantile: double;
    FEpsilon: double;
  public
    constructor New(Quantile, Epsilon: double);
    property Quantile: double read FQuantile;
    property Epsilon: double read FEpsilon;
  end;

  TThreadSafeDouble = record
  private
    FValue: Int64;

    function GetValue: double;
    procedure SetValue(AValue: double);
  public
    constructor New(AValue: double);

    property Value: double read GetValue write SetValue;

    procedure Add(AValue: double);
    /// <summary>
    /// Sets the value to this, unless the existing value is already greater.
    /// </summary>
    procedure IncrementTo(AValue: double);
    /// <summary>
    /// Sets the value to this, unless the existing value is already smaller.
    /// </summary>
    procedure DecrementTo(AValue: double);
  end;

  TThreadSafeInt64 = record
  private
    FValue: Int64;

    function GetValue: Int64;
    procedure SetValue(AValue: Int64);
  public
    constructor New(AValue: Int64);
    property Value: Int64 read GetValue write SetValue;
    procedure Add(Increment: Int64);
  end;


  /// <summary>
  /// The set of labels and label values associated with a metric. Used both for export and as keys.
  /// </summary>
  /// <remarks>
  /// Only the values are considered for equality purposes - the caller must ensure that
  /// LabelValues objects with different sets of names are never compared to each other.
  ///
  /// Always use the explicit constructor when creating an instance. This is a struct in order
  /// to reduce heap allocations when dealing with labelled metrics, which has the consequence of
  /// adding a default parameterless constructor. It should not be used.
  /// </remarks>
  TLabels = record
  strict private
    class var FEmpty: TLabels;
    class constructor Create;

    class function EscapeLabelValue(Value: string): string; static;
    class function CalculateHashCode(Values: TArray<string>): integer; static;
  private
    FValues: TArray<string>;
    FNames: TArray<string>;
    FHashCode: integer;

    function GetCount: integer;
    class function IsMultipleCopiesName(Names: TArray<string>): boolean; static;
  public
    constructor New(Names, Values: TArray<string>);

    property Values: TArray<string> read FValues;
    property Names: TArray<string> read FNames;
    property Count: integer read GetCount;
    class property Empty: TLabels read FEmpty;

    function Concat(More: TArray<TStringPair>): TLabels; overload;
    function Concat(More: TLabels): TLabels; overload;

    /// <summary>
    /// Serializes to the labelkey1="labelvalue1",labelkey2="labelvalue2" label string.
    /// </summary>
    function Serialize: string;
  end;

  TPrometheusConstants = class
  strict private
    class var FEncoding: TEncoding;
    class constructor Create;
  public const
    ExporterContentType = 'text/plain; version=0.0.4; charset=utf-8';
    // ASP.NET does not want to accept the parameters in PushStreamContent for whatever reason...
    ExporterContentTypeMinimal = 'text/plain';
  public
    // Use UTF-8 encoding, but provide the flag to ensure the Unicode Byte Order Mark is never
    // pre-pended to the output stream.
    class property ExportEncoding: TEncoding read FEncoding;
  end;

{$ENDREGION}

{$REGION 'Configurations'}

  IMetricConfiguration = interface
    function GetLabelNames: TArray<string>;
    procedure SetLabelNames(Value: TArray<string>);

    function GetStaticLabels: TDictionary<string, string>;
    procedure SetStaticLabels(Value: TDictionary<string, string>);

    function GetSuppressInitialValue: boolean;
    procedure SetSuppressInitialValue(Value: boolean);
    /// <summary>
    /// Names of all the label fields that are defined for each instance of the metric.
    /// If null, the metric will be created without any instance-specific labels.
    ///
    /// Before using a metric that uses instance-specific labels, .WithLabels() must be called to provide values for the labels.
    /// </summary>
    property LabelNames: TArray<string> read GetLabelNames write SetLabelNames;
    /// <summary>
    /// The static labels to apply to all instances of this metric. These labels cannot be later overwritten.
    /// </summary>
    property StaticLabels: TDictionary<string, string> read GetStaticLabels write SetStaticLabels;
    /// <summary>
    /// If true, the metric will not be published until its value is first modified (regardless of the specific value).
    /// This is useful to delay publishing gauges that get their initial values delay-loaded.
    ///
    /// By default, metrics are published as soon as possible - if they do not use labels then they are published on
    /// creation and if they use labels then as soon as the label values are assigned.
    /// </summary>
    property SuppressInitialValue: boolean read GetSuppressInitialValue write SetSuppressInitialValue;
  end;

  ICounterConfiguration = interface(IMetricConfiguration)
  end;

  IGaugeConfiguration = interface(IMetricConfiguration)
  end;

  ISummaryConfiguration = interface(IMetricConfiguration)
    function GetObjectives: TList<TQuantileEpsilonPair>;
    procedure SetObjectives(Value: TList<TQuantileEpsilonPair>);

    function GetMaxAge: TTimeSpan;
    procedure SetMaxAge(Value: TTimeSpan);

    function GetAgeBuckets: integer;
    procedure SetAgeBuckets(Value: integer);

    function GetBufferSize: integer;
    procedure SetBufferSize(Value: integer);

    /// <summary>
    /// Pairs of quantiles and allowed error values (epsilon).
    ///
    /// For example, a quantile of 0.95 with an epsilon of 0.01 means the calculated value
    /// will be between the 94th and 96th quantile.
    ///
    /// If null, no quantiles will be calculated!
    /// </summary>
    property Objectives: TList<TQuantileEpsilonPair> read GetObjectives write SetObjectives;
    /// <summary>
    /// Time span over which to calculate the summary.
    /// </summary>
    property MaxAge: TTimeSpan read GetMaxAge write SetMaxAge;
    /// <summary>
    /// Number of buckets used to control measurement expiration.
    /// </summary>
    property AgeBuckets: integer read GetAgeBuckets write SetAgeBuckets;
    /// <summary>
    /// Buffer size limit. Use multiples of 500 to avoid waste, as internal buffers use that size.
    /// </summary>
    property BufferSize: integer read GetBufferSize write SetBufferSize;
  end;

  IHistogramConfiguration = interface(IMetricConfiguration)
    function GetBuckets: TArray<double>;
    procedure SetBuckets(Value: TArray<double>);

    /// <summary>
    /// Custom histogram buckets to use. If null, will use Histogram.DefaultBuckets.
    /// </summary>
    property Buckets: TArray<double> read GetBuckets write SetBuckets;
  end;

  /// <summary>
  /// This class packages the options for creating metrics into a single class (with subclasses per metric type)
  /// for easy extensibility of the API without adding numerous method overloads whenever new options are added.
  /// </summary>
  TMetricConfiguration = class abstract(TDebugInterfacedObject, IMetricConfiguration)
  strict private
    FLabelNames: TArray<string>;
    FStaticLabels: TDictionary<string, string>;
    FSuppressInitialValue: boolean;

    function GetLabelNames: TArray<string>;
    procedure SetLabelNames(Value: TArray<string>);

    function GetStaticLabels: TDictionary<string, string>;
    procedure SetStaticLabels(Value: TDictionary<string, string>);

    function GetSuppressInitialValue: boolean;
    procedure SetSuppressInitialValue(Value: boolean);
  public
    /// <summary>
    /// Names of all the label fields that are defined for each instance of the metric.
    /// If null, the metric will be created without any instance-specific labels.
    ///
    /// Before using a metric that uses instance-specific labels, .WithLabels() must be called to provide values for the labels.
    /// </summary>
    property LabelNames: TArray<string> read GetLabelNames write SetLabelNames;
    /// <summary>
    /// The static labels to apply to all instances of this metric. These labels cannot be later overwritten.
    /// </summary>
    property StaticLabels: TDictionary<string, string> read GetStaticLabels write SetStaticLabels;
    /// <summary>
    /// If true, the metric will not be published until its value is first modified (regardless of the specific value).
    /// This is useful to delay publishing gauges that get their initial values delay-loaded.
    ///
    /// By default, metrics are published as soon as possible - if they do not use labels then they are published on
    /// creation and if they use labels then as soon as the label values are assigned.
    /// </summary>
    property SuppressInitialValue: boolean read GetSuppressInitialValue write SetSuppressInitialValue;
  end;

  TCounterConfiguration = class sealed(TMetricConfiguration, ICounterConfiguration)
  protected
    class function Default: ICounterConfiguration;
  end;

  TGaugeConfiguration = class sealed(TMetricConfiguration, IGaugeConfiguration)
  protected
    class function Default: IGaugeConfiguration;
  end;

  TSummaryConfiguration = class sealed(TMetricConfiguration, ISummaryConfiguration)
  strict private
    FBufferSize: integer;
    FAgeBuckets: integer;
    FMaxAge: TTimeSpan;
    FObjectives: TList<TQuantileEpsilonPair>;

    function GetObjectives: TList<TQuantileEpsilonPair>;
    procedure SetObjectives(Value: TList<TQuantileEpsilonPair>);

    function GetMaxAge: TTimeSpan;
    procedure SetMaxAge(Value: TTimeSpan);

    function GetAgeBuckets: integer;
    procedure SetAgeBuckets(Value: integer);

    function GetBufferSize: integer;
    procedure SetBufferSize(Value: integer);
  protected
    class function Default: ISummaryConfiguration;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Pairs of quantiles and allowed error values (epsilon).
    ///
    /// For example, a quantile of 0.95 with an epsilon of 0.01 means the calculated value
    /// will be between the 94th and 96th quantile.
    ///
    /// If null, no quantiles will be calculated!
    /// </summary>
    property Objectives: TList<TQuantileEpsilonPair> read GetObjectives write SetObjectives;
    /// <summary>
    /// Time span over which to calculate the summary.
    /// </summary>
    property MaxAge: TTimeSpan read GetMaxAge write SetMaxAge;
    /// <summary>
    /// Number of buckets used to control measurement expiration.
    /// </summary>
    property AgeBuckets: integer read GetAgeBuckets write SetAgeBuckets;
    /// <summary>
    /// Buffer size limit. Use multiples of 500 to avoid waste, as internal buffers use that size.
    /// </summary>
    property BufferSize: integer read GetBufferSize write SetBufferSize;
  end;

  THistogramConfiguration = class sealed(TMetricConfiguration, IHistogramConfiguration)
  strict private
    FBuckets: TArray<double>;

    function GetBuckets: TArray<double>;
    procedure SetBuckets(Value: TArray<double>);
  protected
    class function Default: IHistogramConfiguration;
  public
    /// <summary>
    /// Custom histogram buckets to use. If null, will use Histogram.DefaultBuckets.
    /// </summary>
    property Buckets: TArray<double> read GetBuckets write SetBuckets;
  end;

  {$ENDREGION}

implementation
uses
  System.Generics.Defaults,
  System.RegularExpressions,
  System.StrUtils,
  System.DateUtils,
  System.Rtti,
  System.SyncObjs,
  System.Math,
  Winapi.Windows,
  Common.BitConverter,
  Common.Debug,
  Common.DateTime.Helper
  ;

type
{$REGION 'Pre-declaring'}
  TMetricFactory = class;
  TCollectorRegistry = class;
  TChildBase = class;
  TCounter = class;
  TGauge = class;
  TSummary = class;
  THistogram = class;
{$ENDREGION}

{$REGION 'Collector. Base classes for metrics.'}

  /// <summary>
  /// Base class for metrics, defining the basic informative API and the internal API.
  /// </summary>
  TCollector = class abstract(TDebugInterfacedObject, ICollector)
  private const
    ValidMetricNameExpression: string   = '^[a-zA-Z_:][a-zA-Z0-9_:]*$';
    ValidLabelNameExpression: string    = '^[a-zA-Z_:][a-zA-Z0-9_:]*$';
    ReservedLabelNameExpression: string = '^__.*$';
  private
    class var LabelNameRegEx: TRegEx;
    class var MetricNameRegex: TRegEx;
    class var ReservedLabelRegex: TRegEx;
    class var EmptyLabelNames: TArray<string>;
    class constructor Create;
  private
    FName: String;
    FHelp: String;
    FLabelNames: TArray<string>;
    function GetHelp: String;
    function GetLabelNames: TArray<string>;
    function GetName: String;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>);
    /// <directed>True</directed>
    function CollectAndSerializeAsync(Serializer: IMetricsSerializer): ITask;
      virtual; abstract;
    // Used by ChildBase.Remove()
    procedure RemoveLabelled(Lables: TLabels); virtual; abstract;
    class procedure ValidateLabelName(LabelName: string);
  public
    /// <summary>
    /// The metric name, e.g. http_requests_total.
    /// </summary>
    property Name: String read GetName;
    /// <summary>
    /// The help text describing the metric for a human audience.
    /// </summary>
    property Help: String read GetHelp;
    /// <summary>
    /// Names of the instance-specific labels (name-value pairs) that apply to this metric.
    /// When the values are added to the names, you get a <see cref="ChildBase"/> instance.
    /// </summary>
    property LabelNames: TArray<string> read GetLabelNames;
  end;

  TCollector<TChild: TChildBase> = class abstract(TCollector, ICollector<TChild>)
  private
    /// <summary>
    /// Set of static labels obtained from any hierarchy level (either defined in metric configuration or in registry).
    /// </summary>
    FStaticLabels: TLabels;
    FSuppressInitialValue: boolean;
    FLabelledMetrics: TDictionary<TLabels, ICollectorChild>; //Concurrent
    FFamilyHeaderLines: TArray<TArray<byte>>;
    // Lazy-initialized since not every collector will use a child with no labels.
    FUnlabelled: ICollectorChild;
    FUnlabelledLazy: TFunc<ICollectorChild>;
    function GetUnlabelled: ICollectorChild;
    function GetOrAddLabelled(Key: TLabels): ICollectorChild;
    procedure EnsureUnlabelledMetricCreatedIfNoLabels;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>; StaticLabels: TLabels; SuppressInitialValue: boolean);
    /// <summary>
    /// Gets the child instance that has no labels.
    /// </summary>
    property Unlabelled: ICollectorChild read GetUnlabelled;
    procedure RemoveLabelled(Labels: TLabels); overload; override;
    /// <summary>
    /// For tests that want to see what label values were used when metrics were created.
    /// </summary>
    function GetAllLabels: TArray<TLabels>;
    /// <summary>
    /// Creates a new instance of the child collector type.
    /// </summary>
    function NewChild(Labels, FlattenedLabels: TLabels; Publish: boolean): ICollectorChild; virtual; abstract;
    function GetType: TMetricType; virtual; abstract;
    property &Type: TMetricType read GetType;

    function CollectAndSerializeAsync(Serializer: IMetricsSerializer): ITask; override;
  public
    destructor Destroy; override;
    function Labels(LabelValues: TArray<string>): ICollectorChild;
    procedure RemoveLabelled(LabelValues: TArray<string>); reintroduce; overload;
    /// <summary>
    /// Gets the instance-specific label values of all labelled instances of the collector.
    /// Values of any inherited static labels are not returned in the result.
    ///
    /// Note that during concurrent operation, the set of values returned here
    /// may diverge from the latest set of values used by the collector.
    /// </summary>
    function GetAllLabelValues: TArray<TArray<string>>;
    // This servers a slightly silly but useful purpose: by default if you start typing .La... and trigger Intellisense
    // it will often for whatever reason focus on LabelNames instead of Labels, leading to tiny but persistent frustration.
    // Having WithLabels() instead eliminates the other candidate and allows for a frustration-free typing experience.
    function WithLabels(LabelValues: TArray<string>): ICollectorChild;
  end;

{$ENDREGION}

{$REGION 'CollectorRegistry and MetricFactory'}

  /// <summary>
  /// Maintains references to a set of collectors, from which data for metrics is collected at data export time.
  ///
  /// Use methods on the <see cref="Metrics"/> class to add metrics to a collector registry.
  /// </summary>
  /// <remarks>
  /// To encourage good concurrency practices, registries are append-only. You can add things to them but not remove.
  /// If you wish to remove things from the registry, create a new registry with only the things you wish to keep.
  /// </remarks>
  TCollectorRegistry = class sealed(TDebugInterfacedObject, ICollectorRegistry)
  private
    FCollectors: TDictionary<string, ICollector>; //Concurrent
    FStaticLabels: TArray<TPair<string, string>>;
    FStaticLabelsLock: TObject;
    FFirstCollectLock: TObject;

    FBeforeCollectCallbacks: TList<TProc>; //Concurrent
    FBeforeCollectAsyncCallbacks: TList<TFunc<ITask>>; //Concurrent

    /// <summary>
    /// Allows us to initialize (or not) the registry with the default metrics before the first collection.
    /// </summary>
    FBeforeFirstCollectCallback: TProc;
    FHasPerformedFirstCollect: boolean;


    function GetStaticLabels: TArray<TPair<string, string>>;
  protected type
    // We pass this thing to GetOrAdd to avoid allocating a collector or a closure.
    // This reduces memory usage in situations where the collector is already registered.
    TCollectorInitializer<TCollectorType: TCollector; TConfigurationType: IMetricConfiguration> = record
    strict private
      FCreateInstance: TFunc<string, string, TConfigurationType, TCollectorType>;
      FName: string;
      FHelp: string;
      FConfiguration: TConfigurationType;
    public
      constructor New(Name, Help: string; Configuration: TConfigurationType; CreateInstance: TFunc<string, string, TConfigurationType, TCollectorType>);
      property Name: string read FName;
      property Help: string read FHelp;
      property Configuration: TConfigurationType read FConfiguration;
      function CreateInstance: TCollectorType;
    end;

  protected
    constructor Create;
    /// <summary>
    /// Executes an action while holding a read lock on the set of static labels (provided as parameter).
    /// </summary>
    function WhileReadingStaticLabels<TReturn>(Action: TFunc<TLabels, TReturn>): TReturn;
    /// <summary>
    /// Adds a collector to the registry, returning an existing instance if one with a matching name was already registered.
    /// </summary>
    function GetOrAdd<TCollectorType: TCollector; TConfigurationType: IMetricConfiguration>(Initializer: TCollectorInitializer<TCollectorType, TConfigurationType>): TCollectorType;

    procedure SetBeforeFirstCollectCallback(Action: TProc);
    /// <summary>
    /// Collects metrics from all the registered collectors and sends them to the specified serializer.
    /// </summary>
    function CollectAndSerializeAsync(Serializer: IMetricsSerializer): ITask;
  public
    destructor Destroy; override;
    /// <summary>
    /// Registers an action to be called before metrics are collected.
    /// This enables you to do last-minute updates to metric values very near the time of collection.
    /// Callbacks will delay the metric collection, so do not make them too long or it may time out.
    ///
    /// The callback will be executed synchronously and should not take more than a few milliseconds.
    /// To execute longer-duration callbacks, register an asynchronous callback (Func&lt;Task&gt;).
    ///
    /// If the callback throws <see cref="ScrapeFailedException"/> then the entire metric collection will fail.
    /// This will result in an appropriate HTTP error code or a skipped push, depending on type of exporter.
    ///
    /// If multiple concurrent collections occur, the callback may be called multiple times concurrently.
    /// </summary>
    procedure AddBeforeCollectorCallback(Callback: TProc); overload;
    /// <summary>
    /// Registers an action to be called before metrics are collected.
    /// This enables you to do last-minute updates to metric values very near the time of collection.
    /// Callbacks will delay the metric collection, so do not make them too long or it may time out.
    ///
    /// Asynchronous callbacks will be executed concurrently and may last longer than a few milliseconds.
    ///
    /// If the callback throws <see cref="ScrapeFailedException"/> then the entire metric collection will fail.
    /// This will result in an appropriate HTTP error code or a skipped push, depending on type of exporter.
    ///
    /// If multiple concurrent collections occur, the callback may be called multiple times concurrently.
    /// </summary>
    procedure AddBeforeCollectorCallback(Callback: TFunc<ITask>); overload;

    /// <summary>
    /// The set of static labels that are applied to all metrics in this registry.
    /// Enumeration of the returned collection is thread-safe.
    /// </summary>
    property StaticLabels: TArray<TPair<string, string>> read GetStaticLabels;
    /// <summary>
    /// Defines the set of static labels to apply to all metrics in this registry.
    /// The static labels can only be set once on startup, before adding or publishing any metrics.
    /// </summary>
    procedure SetStaticLabels(Labels: TDictionary<string, string>);

    /// <summary>
    /// Collects all metrics and exports them in text document format to the provided stream.
    ///
    /// This method is designed to be used with custom output mechanisms that do not use an IMetricServer.
    /// </summary>
    function CollectAndExportAsTextAsync(Dest: TStream): ITask;
  end;

  /// <summary>
  /// Adds metrics to a registry.
  /// </summary>
  TMetricFactory = class sealed(TDebugInterfacedObject, IMetricFactory)
  private
    FRegistry: ICollectorRegistry;

    function CreateStaticLabels(MetricConfiguration: IMetricConfiguration): TLabels;
  protected
    constructor Create(Registry: ICollectorRegistry);
  public
    destructor Destroy; override;
    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    function CreateCounter(Name, Help: string; Configuration: ICounterConfiguration = nil): ICounter; overload;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    function CreateGauge(Name, Help: string; Configuration: IGaugeConfiguration = nil): IGauge; overload;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    function CreateSummary(Name, Help: string; Configuration: ISummaryConfiguration = nil): ISummary; overload;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    function CreateHistogram(Name, Help: string; Configuration: IHistogramConfiguration = nil): IHistogram; overload;

    /// <summary>
    /// Counters only increase in value and reset to zero when the process restarts.
    /// </summary>
    function CreateCounter(Name, Help: string; LabelNames: TArray<string>): ICounter; overload;
    /// <summary>
    /// Gauges can have any numeric value and change arbitrarily.
    /// </summary>
    function CreateGauge(Name, Help: string; LabelNames: TArray<string>): IGauge; overload;
    /// <summary>
    /// Summaries track the trends in events over time (10 minutes by default).
    /// </summary>
    function CreateSummary(Name, Help: string; LabelNames: TArray<string>): ISummary; overload;
    /// <summary>
    /// Histograms track the size and number of events in buckets.
    /// </summary>
    function CreateHistogram(Name, Help: string; LabelNames: TArray<string>): IHistogram; overload;
  end;

{$ENDREGION}

{$REGION 'Metrics implementaions'}

  /// <summary>
  /// Base class for labeled instances of metrics (with all label names and label values defined).
  /// </summary>
  TChildBase = class abstract(TDebugInterfacedObject, ICollectorChild)
  private
    [weak] FParent: ICollector;
    FLabels: TLabels;
    FFlattenedLabels: TLabels;
    [Volatile]
    FPublish: boolean;
  protected
    constructor Create(Parent: ICollector; Labels, FlattenedLabels: TLabels; Publish: boolean);
    /// <summary>
    /// Labels specific to this metric instance, without any inherited static labels.
    /// Internal for testing purposes only.
    /// </summary>
    property Labels: TLabels read FLabels;
    /// <summary>
    /// All labels that materialize on this metric instance, including inherited static labels.
    /// Internal for testing purposes only.
    /// </summary>
    property FlattenedLabels: TLabels read FLabels;
    /// <summary>
    /// Collects all the metric data rows from this collector and serializes it using the given serializer.
    /// </summary>
    /// <remarks>
    /// Subclass must check _publish and suppress output if it is false.
    /// </remarks>
    function CollectAndSerializeAsync(Serializer: IMetricsSerializer): ITask;
    // Same as above, just only called if we really need to serialize this metric (if publish is true).
    function CollectAndSerializeImplAsync(Serializer: IMetricsSerializer): ITask; virtual; abstract;
    /// <summary>
    /// Creates a metric identifier, with an optional name postfix and optional extra labels.
    /// familyname_postfix{labelkey1="labelvalue1",labelkey2="labelvalue2"}
    /// </summary>
    function CreateIdentifier(Postfix: string = ''; ExtraLabels: TArray<TStringPair> = []): TArray<byte>;
  public
    destructor Destroy; override;
    /// <summary>
    /// Marks the metric as one to be published, even if it might otherwise be suppressed.
    ///
    /// This is useful for publishing zero-valued metrics once you have loaded data on startup and determined
    /// that there is no need to increment the value of the metric.
    /// </summary>
    /// <remarks>
    /// Subclasses must call this when their value is first set, to mark the metric as published.
    /// </remarks>
    procedure Publish;
    /// <summary>
    /// Marks the metric as one to not be published.
    ///
    /// The metric will be published when Publish() is called or the value is updated.
    /// </summary>
    procedure Unpublish;
    /// <summary>
    /// Removes this labeled instance from metrics.
    /// It will no longer be published and any existing measurements/buckets will be discarded.
    /// </summary>
    procedure Remove;
  end;

  {$REGION 'Counter'}
  TCounterChild = class sealed(TChildBase, ICounter)
  private
    FIdentifier: TArray<byte>;
    FValue: TThreadSafeDouble;

    function GetValue: double;
  protected
    constructor Create(Parent: TCollector; Labels, FlattenedLabels: TLabels; Publish: boolean);
    function CollectAndSerializeImplAsync(Serializer: IMetricsSerializer): ITask; override;
  public
    procedure Inc(Increment: double = 1.0);
    procedure IncTo(TargetValue: double);
    property Value: double read GetValue;
  end;

  TCounter = class sealed(TCollector<TCounterChild>, ICounter)
  private
    function GetValue: double;
    function NewChild(Labels, FlattenedLabels: TLabels;
      Publish: boolean): ICollectorChild; override;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>; StaticLabels: TLabels; SuppressInitialValue: boolean);
    function GetType: TMetricType; override;
  public
    procedure Inc(Increment: double = 1);
    procedure IncTo(TargetValue: double);
    property Value: double read GetValue;

    procedure Publish;
    procedure Unpublish;
  end;
  {$ENDREGION}

  {$REGION 'Gauge'}
  TGaugeChild = class sealed(TChildBase, IGauge)
  private
    FIdentifier: TArray<byte>;
    FValue: TThreadSafeDouble;
    function GetValue: double;
  protected
    constructor Create(Parent: TCollector; Labels, FlattenedLabels: TLabels; Publish: boolean);
    function CollectAndSerializeImplAsync(Serializer: IMetricsSerializer): ITask; override;
  public
    procedure &Set(Val: double);
    procedure IncTo(TargetValue: double);
    procedure Inc(Increment: double = 1);
    procedure DecTo(TargetValue: double);
    procedure Dec(Decrement: double = 1);
    property Value: double read GetValue;
  end;

  TGauge = class sealed(TCollector<TGaugeChild>, IGauge)
  private
    function GetValue: double;
    function NewChild(Labels, FlattenedLabels: TLabels;
      Publish: boolean): ICollectorChild; override;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>; StaticLabels: TLabels; SuppressInitialValue: boolean);
    function GetType: TMetricType; override;
  public
    procedure &Set(Val: double);
    procedure IncTo(TargetValue: double);
    procedure Inc(Increment: double = 1);
    procedure DecTo(TargetValue: double);
    procedure Dec(Decrement: double = 1);
    property Value: double read GetValue;
  end;
  {$ENDREGION}

  {$REGION 'Summary'}

  TSummaryChild = class sealed(TChildBase, ISummary)
  strict private type
    TSampleBuffer = class
    private
      FBuffer: TArray<double>;
      FPosition: integer;
      function GetValue(Idx: integer): double;
    public
      constructor Create(Capacity: integer);
      procedure Append(Value: double);
      procedure Reset;
      property Value[Idx: integer]: double read GetValue; default;
      property Position: integer read FPosition;
      function Capacity: integer;
      function IsFull: boolean;
      function IsEmpty: boolean;
    end;

    /// Sample holds an observed value and meta information for compression.
    TSample = record
      Value: double;
      Width: double;
      Delta: double;
      constructor New(AValue, AWidth, ADelta: double);
    end;

    TSampleStream = class;
    TInvariant = reference to function(Stream: TSampleStream; R: double): double;

    TSampleStream = class
    strict private
      FSamples: TList<TSample>;
      FInvariant: TInvariant;
      procedure Compress;
    public
      N: double;
      constructor Create(Invariant: TInvariant);
      procedure Merge(Samples: TList<TSample>);
      procedure Reset;
      function Count: integer;
      function Query(q: double): double;
      function SampleCount: integer;
    end;
    // Ported from https://github.com/beorn7/perks/blob/master/quantile/stream.go

    // Package quantile computes approximate quantiles over an unbounded data
    // stream within low memory and CPU bounds.
    //
    // A small amount of accuracy is traded to achieve the above properties.
    //
    // Multiple streams can be merged before calling Query to generate a single set
    // of results. This is meaningful when the streams represent the same type of
    // data. See Merge and Samples.
    //
    // For more detailed information about the algorithm used, see:
    //
    // Effective Computation of Biased Quantiles over Data Streams
    //
    // http://www.cs.rutgers.edu/~muthu/bquant.pdf
    TQuantileStream = class
    strict private
      FSampleStream: TSampleStream;
      FSamples: TList<TSample>;
      FSorted: boolean;

      constructor Create(SampleStream: TSampleStream; Samples: TList<TSample>; Sorted: boolean);
      procedure Insert(Sample: TSample); overload;
      procedure Flush;
      procedure MaybeSort;
      class function SampleComparison(const Lhs, Rhs: TSample): integer; static;
    public
      class function NewStream(Invariant: TInvariant): TQuantileStream; static;
      // NewLowBiased returns an initialized Stream for low-biased quantiles
      // (e.g. 0.01, 0.1, 0.5) where the needed quantiles are not known a priori, but
      // error guarantees can still be given even for the lower ranks of the data
      // distribution.
      //
      // The provided epsilon is a relative error, i.e. the true quantile of a value
      // returned by a query is guaranteed to be within (1±Epsilon)*Quantile.
      //
      // See http://www.cs.rutgers.edu/~muthu/bquant.pdf for time, space, and error
      // properties.
      class function NewLowBiased(Epsilon: double): TQuantileStream; static;
      // NewHighBiased returns an initialized Stream for high-biased quantiles
      // (e.g. 0.01, 0.1, 0.5) where the needed quantiles are not known a priori, but
      // error guarantees can still be given even for the higher ranks of the data
      // distribution.
      //
      // The provided epsilon is a relative error, i.e. the true quantile of a value
      // returned by a query is guaranteed to be within 1-(1±Epsilon)*(1-Quantile).
      //
      // See http://www.cs.rutgers.edu/~muthu/bquant.pdf for time, space, and error
      // properties.
      class function NewHighBiased(Epsilon: double): TQuantileStream; static;
      // NewTargeted returns an initialized Stream concerned with a particular set of
      // quantile values that are supplied a priori. Knowing these a priori reduces
      // space and computation time. The targets map maps the desired quantiles to
      // their absolute errors, i.e. the true quantile of a value returned by a query
      // is guaranteed to be within (Quantile±Epsilon).
      //
      // See http://www.cs.rutgers.edu/~muthu/bquant.pdf for time, space, and error properties.
      class function NewTargeted(Targets: TList<TQuantileEpsilonPair>): TQuantileStream; static;

      procedure Insert(Value: double); overload;
      procedure Reset;
      // Count returns the total number of samples observed in the stream since initialization.
      function Count: integer;
      function SamplesCount: integer;
      function Flushed: boolean;
      // Query returns the computed qth percentiles value. If s was created with
      // NewTargeted, and q is not in the set of quantiles provided a priori, Query
      // will return an unspecified result.
      function Query(q: double): double;

    end;
  private
    FSumIdentifier: TArray<byte>;
    FCountIdentifier: TArray<byte>;
    FQuantileIdentifiers: TArray<TArray<byte>>;

    // Objectives defines the quantile rank estimates with their respective
    // absolute error. If Objectives[q] = e, then the value reported
    // for q will be the φ-quantile value for some φ between q-e and q+e.
    // The default value is DefObjectives.
    FObjectives: TList<TQuantileEpsilonPair>;
    FSortedObjectives: TArray<double>;
    FSum: double;
    FCount: UInt64;
    FHotBuf: TSampleBuffer;
    FColdBuf: TSampleBuffer;
    FStreams: TArray<TQuantileStream>;
    FStreamDuration: TTimeSpan;
    FHeadStream: TQuantileStream;
    FHeadStreamIdx: integer;
    FHeadStreamExpTime: TDateTime;
    FHotBufExpTime: TDateTime;
    // MaxAge defines the duration for which an observation stays relevant
    // for the summary. Must be positive. The default value is DefMaxAge.
    FMaxAge: TTimeSpan;
    // AgeBuckets is the number of buckets used to exclude observations that
    // are older than MaxAge from the summary. A higher number has a
    // resource penalty, so only increase it if the higher resolution is
    // really required. For very high observation rates, you might want to
    // reduce the number of age buckets. With only one age bucket, you will
    // effectively see a complete reset of the summary each time MaxAge has
    // passed. The default value is DefAgeBuckets.
    FAgeBuckets: integer;
    // BufCap defines the default sample stream buffer size.  The default
    // value of DefBufCap should suffice for most uses. If there is a need
    // to increase the value, a multiple of 500 is recommended (because that
    // is the internal buffer size of the underlying package
    // "github.com/bmizerany/perks/quantile").
    FBufCap: integer;

    // Flush needs bufMtx locked.
    procedure Flush(ANow: TDateTime);
    // SwapBufs needs mtx AND bufMtx locked, coldBuf must be empty.
    procedure SwapBufs(ANow: TDateTime);
    // FlushColdBuf needs mtx locked.
    procedure FlushColdBuf;
    // MaybeRotateStreams needs mtx AND bufMtx locked.
    procedure MaybeRotateStreams;
  private
    // Protects hotBuf and hotBufExpTime.
    FBufLock: TObject;
    // Protects every other moving part.
    // Lock bufMtx before mtx if both are needed.
    FLock: TObject;
  protected
    constructor Create(Parent: TCollector; Labels, FlattenedLabels: TLabels; Publish: boolean);
    function CollectAndSerializeImplAsync(Serializer: IMetricsSerializer): ITask; override;
    /// <summary>
    /// For unit tests only
    /// </summary>
    procedure Observe(Value: double; ANow: TDateTime); overload;
  public
    procedure Observe(Value: double); overload;
  end;

  TSummary = class sealed(TCollector<TSummaryChild>, ISummary)
  private
    // Label that defines the quantile in a summary.
    const QuantileLabel = 'quantile';
    // Default duration for which observations stay relevant
    // class property DefMaxAge: TTimeSpan read FDefMaxAge;
    // Default number of buckets used to calculate the age of observations
    const DefAgeBuckets: integer = 5;
    // Standard buffer size for collecting Summary observations
    const DefBufCap: integer = 500;
  strict private
    class var FDefObjectiveArray: TArray<TQuantileEpsilonPair>;
    class var FDefObjectives: TList<TQuantileEpsilonPair>;
    class var FDefMaxAge: TTimeSpan;
  private
    FObjectives: TList<TQuantileEpsilonPair>;
    FMaxAge: TTimeSpan;
    FAgeBuckets: integer;
    FBufCap: integer;

    function NewChild(Labels, FlattenedLabels: TLabels;
      Publish: boolean): ICollectorChild; override;
  protected
    /// <summary>
    /// Client library guidelines say that the summary should default to not measuring quantiles.
    /// https://prometheus.io/docs/instrumenting/writing_clientlibs/#summary
    /// </summary>
    class property DefObjectiveArray: TArray<TQuantileEpsilonPair> read FDefObjectiveArray;
    // Default Summary quantile values.
    class property DefObjectives: TList<TQuantileEpsilonPair> read FDefObjectives;
    class property DefMaxAge: TTimeSpan read FDefMaxAge;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>; StaticLabels: TLabels;
      MaxAge: TTimeSpan; AgeBuckets: integer = 0; BufCap: integer = 0;
     SuppressInitialValue: boolean = false; Objectives: TList<TQuantileEpsilonPair> = nil);

    function GetType: TMetricType; override;
  public
    procedure Observe(Val: double);
  end;

  {$ENDREGION}

  {$REGION 'Histogram'}
  THistogramChild = class sealed(TChildBase, IHistogram)
  private
    FSum: TThreadSafeDouble;
    FBucketCounts: TArray<TThreadSafeInt64>;
    FUpperBounds: TArray<double>;
    FSumIdentifier: TArray<byte>;
    FCountIdentifier: TArray<byte>;
    FBucketIdentifiers: TArray<TArray<byte>>;

    function GetSum: double;
    function GetCount: int64;
  protected
    constructor Create(Parent: TCollector; Labels, FlattenedLabels: TLabels; Publish: boolean);
    function CollectAndSerializeImplAsync(Serializer: IMetricsSerializer): ITask; override;
  public
    property Sum: double read GetSum;
    property Count: int64 read GetCount;

    procedure Observe(Value: double); overload;
    procedure Observe(Value: double; Count: Int64); overload;
  end;

  THistogram = class sealed(TCollector<THistogramChild>, IHistogram)
  private const
    DefaultBuckets: TArray<double> = [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10];
  private
    FBuckets: TArray<double>;

    function GetCount: Int64;
    function GetSum: double;

    function NewChild(Labels, FlattenedLabels: TLabels;
    Publish: boolean): ICollectorChild; override;
  protected
    constructor Create(Name, Help: string; LabelNames: TArray<string>; StaticLabels: TLabels; SuppressInitialValue: boolean; Buckets: TArray<double> = []);
    function GetType: TMetricType; override;
  public
    property Sum: double read GetSum;
    property Count: Int64 read GetCount;
    procedure Observe(Val: double); overload;
    procedure Observe(Val: double; Count: Int64); overload;

    // From https://github.com/prometheus/client_golang/blob/master/prometheus/histogram.go
    /// <summary>
    ///  Creates '<paramref name="count"/>' buckets, where the lowest bucket has an
    ///  upper bound of '<paramref name="start"/>' and each following bucket's upper bound is '<paramref name="factor"/>'
    ///  times the previous bucket's upper bound.
    ///
    ///  The function throws if '<paramref name="count"/>' is 0 or negative, if '<paramref name="start"/>' is 0 or negative,
    ///  or if '<paramref name="factor"/>' is less than or equal 1.
    /// </summary>
    /// <param name="start">The upper bound of the lowest bucket. Must be positive.</param>
    /// <param name="factor">The factor to increase the upper bound of subsequent buckets. Must be greater than 1.</param>
    /// <param name="count">The number of buckets to create. Must be positive.</param>
    class function ExponetialBuckets(Start, Factor: double; Count: integer): TArray<double>; static;

    // From https://github.com/prometheus/client_golang/blob/master/prometheus/histogram.go
    /// <summary>
    ///  Creates '<paramref name="count"/>' buckets, where the lowest bucket has an
    ///  upper bound of '<paramref name="start"/>' and each following bucket's upper bound is the upper bound of the
    ///  previous bucket, incremented by '<paramref name="width"/>'
    ///
    ///  The function throws if '<paramref name="count"/>' is 0 or negative.
    /// </summary>
    /// <param name="start">The upper bound of the lowest bucket.</param>
    /// <param name="width">The width of each bucket (distance between lower and upper bound).</param>
    /// <param name="count">The number of buckets to create. Must be positive.</param>
    class function LinearBuckets(Start, Width: double; Count: integer): TArray<double>; static;
  end;

  {$ENDREGION}


  TCounterExtensions = class helper for TCounter
    /// <summary>
    /// Executes the provided operation and increments the counter if an exception occurs. The exception is re-thrown.
    /// If an exception filter is specified, only counts exceptions for which the filter returns true.
    /// </summary>
    procedure CountExceptions(Wrapped: TProc; ExceptionFilter: TFunc<Exception, boolean> = nil); overload;
    /// <summary>
    /// Executes the provided operation and increments the counter if an exception occurs. The exception is re-thrown.
    /// If an exception filter is specified, only counts exceptions for which the filter returns true.
    /// </summary>
    function CountExceptions<TResult>(Wrapped: TFunc<TResult>; ExceptionFilter: TFunc<Exception, boolean> = nil): TResult; overload;
    /// <summary>
    /// Executes the provided async operation and increments the counter if an exception occurs. The exception is re-thrown.
    /// If an exception filter is specified, only counts exceptions for which the filter returns true.
    /// </summary>
    function CountExceptionsAsync(Wrapped: TFunc<ITask>; ExceptionFilter: TFunc<Exception, boolean> = nil): ITask; overload;
    /// <summary>
    /// Executes the provided async operation and increments the counter if an exception occurs. The exception is re-thrown.
    /// If an exception filter is specified, only counts exceptions for which the filter returns true.
    /// </summary>
    function CountExceptionsAsync<TResult>(Wrapped: TFunc<IFuture<TResult>>; ExceptionFilter: TFunc<Exception, boolean> = nil): IFuture<TResult>; overload;
  end;
{$ENDREGION}

{$REGION 'MetricsSerializer'}

  /// <remarks>
  /// Does NOT take ownership of the stream - caller remains the boss.
  /// </remarks>
  TTextSerializer = class(TDebugInterfacedObject, IMetricsSerializer)
  strict private const
    NewLine: TArray<byte> = [ord(#13)];
    Space: TArray<byte>   = [ord(' ')];
  strict private
    // Reuse a buffer to do the UTF-8 encoding.
    // Maybe one day also ValueStringBuilder but that would be .NET Core only.
    // https://github.com/dotnet/corefx/issues/28379
    // Size limit guided by https://stackoverflow.com/questions/21146544/what-is-the-maximum-length-of-double-tostringd
    FStringBytesBuffer: TArray<byte>;

    FStreamLazy: TStream; //Lazy<TChild>
    FGetStreamLazy: TFunc<TStream>;

    function FStream: TStream;
  public
    constructor Create(Dest: TStream); overload;
    // Enables delay-loading of the stream, because touching stream in HTTP handler triggers some behavior.
    constructor Create(const StreamFactory: TFunc<TStream>); overload;

    // # HELP name help
    // # TYPE name type
    function WriteFamilyDeclarationAsync(HeaderLines: TArray<TArray<byte>>): ITask;
    // name{labelkey1="labelvalue1",labelkey2="labelvalue2"} 123.456
    function WriteMetricAsync(Identifier: TArray<byte>; value: double): ITask;
  end;

{$ENDREGION}

{$REGION 'Other types'}

  TIf = class
    class function IfThen<T>(Expression: boolean; IsTrue: T; IsFalse: T): T;
  end;

{$ENDREGION}


{Base classes}

{$REGION 'TCollector'}
constructor TCollector.Create(Name, Help: string; LabelNames: TArray<string>);
begin
  inherited Create;

  if not MetricNameRegex.IsMatch(Name) then
    raise EArgumentException.Create(format('Metric name "%s" does not match regex "%s".', [Name, ValidMetricNameExpression]));

  for var LabelName: string in LabelNames do
    ValidateLabelName(LabelName);

  FName     := Name;
  FHelp     := Help;

  if Length(LabelNames) = 0
    then FLabelNames := EmptyLabelNames
    else FLabelNames := LabelNames;
end;

class constructor TCollector.Create;
begin
  EmptyLabelNames     := [];
  MetricNameRegex     := TRegEx.Create(ValidMetricNameExpression,   [TRegExOption.roCompiled]);
  LabelNameRegex      := TRegEx.Create(ValidLabelNameExpression,    [TRegExOption.roCompiled]);
  ReservedLabelRegex  := TRegEx.Create(ReservedLabelNameExpression, [TRegExOption.roCompiled]);
end;

function TCollector.GetHelp: String;
begin
  result := FHelp;
end;

function TCollector.GetLabelNames: TArray<string>;
begin
  result := FLabelNames;
end;

function TCollector.GetName: String;
begin
  result := FName;
end;

class procedure TCollector.ValidateLabelName(LabelName: string);
begin
  if not LabelNameRegEx.IsMatch(LabelName) then
    raise EArgumentException.Create(format('Label name "%s" does not match regex "%s".', [LabelName, ValidLabelNameExpression]));

  if ReservedLabelRegex.IsMatch(LabelName) then
    raise EArgumentException.Create(format('Label name "%s" is not valid - labels starting with double underscore are reserved!', [LabelName]));
end;

{$ENDREGION}

{$REGION 'TCollector<TChild>'}

function TCollector<TChild>.CollectAndSerializeAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := TTask.Run(
    procedure begin
      EnsureUnlabelledMetricCreatedIfNoLabels;

      TTask.WaitForAny(Serializer.WriteFamilyDeclarationAsync(FFamilyHeaderLines));
      TMonitor.Enter(FLabelledMetrics);
      try
        for var Child: ICollectorChild in FLabelledMetrics.Values do
          TTask.WaitForAny(TChild(Child).CollectAndSerializeAsync(Serializer));
      finally
        TMonitor.Exit(FLabelledMetrics);
      end;
    end);
end;

constructor TCollector<TChild>.Create(Name, Help: string;
  LabelNames: TArray<string>; StaticLabels: TLabels;
  SuppressInitialValue: boolean);
begin
  inherited Create(Name, Help, LabelNames);

  FStaticLabels         := StaticLabels;
  FSuppressInitialValue := SuppressInitialValue;

  FUnlabelled := nil;
  FUnlabelledLazy := (
    function: ICollectorChild
    begin
      result := GetOrAddLabelled(TLabels.Empty);
    end);

  // Check for label name collisions.
  var AllLabelNames: TArray<string>;
  if Length(LabelNames) > 0
    then AllLabelNames := TArray.Concat<string>([LabelNames, StaticLabels.Names])
    else AllLabelNames := StaticLabels.Names;
  if TLabels.IsMultipleCopiesName(AllLabelNames) then
    raise EInvalidOpException.Create('The set of label names includes duplicates: '+string.Join(', ', AllLabelNames));


  FFamilyHeaderLines :=
    [TPrometheusConstants.ExportEncoding.GetBytes(format('# HELP %s %s', [Name, Help])),
     TPrometheusConstants.ExportEncoding.GetBytes(format('# TYPE %s %s', [Name, &Type.ToString.ToLower]))
    ];

  FLabelledMetrics := TDictionary<TLabels, ICollectorChild>.Create;
end;

destructor TCollector<TChild>.Destroy;
begin
  FUnlabelled := nil;
  FLabelledMetrics.Clear;
  FLabelledMetrics.Free;
  inherited;
end;

procedure TCollector<TChild>.EnsureUnlabelledMetricCreatedIfNoLabels;
begin
  // We want metrics to exist even with 0 values if they are supposed to be used without labels.
  // Labelled metrics are created when label values are assigned. However, as unlabelled metrics are lazy-created
  // (they might are optional if labels are used) we might lose them for cases where they really are desired.
  // If there are no label names then clearly this metric is supposed to be used unlabelled, so create it.
  // Otherwise, we allow unlabelled metrics to be used if the user explicitly does it but omit them by default.
  if (not assigned(FUnlabelled)) and (Length(LabelNames) = 0) then
    GetOrAddLabelled(TLabels.Empty);
end;

function TCollector<TChild>.GetAllLabels: TArray<TLabels>;
begin
  TMonitor.Enter(FLabelledMetrics);
  try
    result := FLabelledMetrics.Keys.ToArray;
  finally
    TMonitor.Exit(FLabelledMetrics);
  end;
end;

function TCollector<TChild>.GetAllLabelValues: TArray<TArray<string>>;
begin
  var LResult: TArray<TArray<string>>;
  for var Labels: TLabels in FLabelledMetrics.Keys do begin
    if Labels.Count = 0 then continue; //We do not return the "unlabelled" label set.

    LResult := LResult+[Labels.Values]; //yield
  end;

  result := LResult;
end;

function TCollector<TChild>.GetOrAddLabelled(Key: TLabels): ICollectorChild;
begin
  // Don't allocate lambda for GetOrAdd in the common case that the labeled metrics exist.
  var Metric: ICollectorChild := nil;
  TMonitor.Enter(FLabelledMetrics);
  try
    if not FLabelledMetrics.TryGetValue(Key, Metric) then begin
      Metric := NewChild(Key, Key.Concat(FStaticLabels), not FSuppressInitialValue);
      FLabelledMetrics.Add(Key, Metric);
    end;
  finally
    TMonitor.Exit(FLabelledMetrics);
  end;

  result := Metric;
end;

function TCollector<TChild>.GetUnlabelled: ICollectorChild;
begin
  if not assigned(FUnlabelled) then
    FUnlabelled := FUnlabelledLazy();

  result := FUnlabelled;
end;

function TCollector<TChild>.Labels(LabelValues: TArray<string>): ICollectorChild;
begin
  var Key := TLabels.New(LabelNames, LabelValues);
  result := GetOrAddLabelled(Key);
end;

procedure TCollector<TChild>.RemoveLabelled(LabelValues: TArray<string>);
begin
  var Key := TLabels.New(LabelNames, LabelValues);
  TMonitor.Enter(FLabelledMetrics);
  try
    if FLabelledMetrics.ContainsKey(Key) then
      FLabelledMetrics.Remove(Key);
  finally
    TMonitor.Exit(FLabelledMetrics);
  end;
end;

function TCollector<TChild>.WithLabels(LabelValues: TArray<string>): ICollectorChild;
begin
  result := Labels(LabelValues);
end;

procedure TCollector<TChild>.RemoveLabelled(Labels: TLabels);
begin
  TMonitor.Enter(FLabelledMetrics);
  try
    if FLabelledMetrics.ContainsKey(Labels) then
      FLabelledMetrics.Remove(Labels);
  finally
    TMonitor.Exit(FLabelledMetrics);
  end;
end;

{$ENDREGION}

{$REGION 'TChildBase'}

function TChildBase.CollectAndSerializeAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  if FPublish then begin
    result := CollectAndSerializeImplAsync(Serializer);
  end else begin
    result := TTask.Run(procedure begin end);
    TTask.WaitForAny(result);
  end;
end;

constructor TChildBase.Create(Parent: ICollector; Labels,
  FlattenedLabels: TLabels; Publish: boolean);
begin
  inherited Create;
  FParent           := Parent;
  FLabels           := Labels;
  FFlattenedLabels  := FlattenedLabels;
  FPublish          := Publish;
end;

function TChildBase.CreateIdentifier(Postfix: string;
  ExtraLabels: TArray<TStringPair>): TArray<byte>;
begin
  var FullName := ifthen(Postfix.IsEmpty, FParent.Name, FParent.Name+'_'+Postfix);

  var Labels := FlattenedLabels;
  if Length(ExtraLabels) > 0 then
    Labels := FlattenedLabels.Concat(ExtraLabels);

  if Labels.Count <> 0 then
    result := TPrometheusConstants.ExportEncoding.GetBytes(format('%s{%s}', [FullName, Labels.Serialize]))
  else
    result := TPrometheusConstants.ExportEncoding.GetBytes(FullName);
end;

destructor TChildBase.Destroy;
begin
  FParent := nil;
  inherited;
end;

procedure TChildBase.Publish;
begin
  FPublish := true;
end;

procedure TChildBase.Remove;
begin
  TCollector(FParent).RemoveLabelled(Labels);
end;

procedure TChildBase.Unpublish;
begin
  FPublish := false;
end;

{$ENDREGION}



{$REGION 'TCollectorRegistry.TCollectorInitializer<TCollectorType, TConfigurationType>'}

function TCollectorRegistry.TCollectorInitializer<TCollectorType, TConfigurationType>.CreateInstance: TCollectorType;
begin
  result := FCreateInstance(FName, FHelp, FConfiguration);
end;

constructor TCollectorRegistry.TCollectorInitializer<TCollectorType, TConfigurationType>.New(
  Name, Help: string; Configuration: TConfigurationType;
  CreateInstance: TFunc<string, string, TConfigurationType, TCollectorType>);
begin
  FCreateInstance := CreateInstance;
  FName           := Name;
  FHelp           := Help;
  FConfiguration  := Configuration;
end;

{$ENDREGION}

{$REGION 'TCollectorRegistry'}

procedure TCollectorRegistry.AddBeforeCollectorCallback(Callback: TProc);
begin
  if not assigned(Callback) then
    raise EArgumentNilException.Create('Callback');

  TMonitor.Enter(FBeforeCollectCallbacks);
  try
    FBeforeCollectCallbacks.Add(Callback);
  finally
    TMonitor.Exit(FBeforeCollectCallbacks);
  end;
end;

procedure TCollectorRegistry.AddBeforeCollectorCallback(Callback: TFunc<ITask>);
begin
  if not assigned(Callback) then
    raise EArgumentNilException.Create('Callback');

  TMonitor.Enter(FBeforeCollectAsyncCallbacks);
  try
    FBeforeCollectAsyncCallbacks.Add(Callback);
  finally
    TMonitor.Exit(FBeforeCollectAsyncCallbacks);
  end;
end;

function TCollectorRegistry.CollectAndExportAsTextAsync(Dest: TStream): ITask;
var
  Serializer: IMetricsSerializer;
begin
  if not assigned(Dest) then
    raise EArgumentNilException.Create('Dest');

  Serializer := TTextSerializer.Create(Dest);
  result := CollectAndSerializeAsync(Serializer);
end;

function TCollectorRegistry.CollectAndSerializeAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := TTask.Run(
    procedure begin
      TMonitor.Enter(FFirstCollectLock);
      try
        if not FHasPerformedFirstCollect then begin
          FHasPerformedFirstCollect := true;
          if assigned(FBeforeFirstCollectCallback) then
            FBeforeFirstCollectCallback();
            FBeforeFirstCollectCallback := nil;
        end;
      finally
        TMonitor.Exit(FFirstCollectLock);
      end;

      TMonitor.Enter(FBeforeCollectCallbacks);
      try
        for var Callback: TProc in FBeforeCollectCallbacks do
          if assigned(Callback) then Callback();
      finally
        TMonitor.Exit(FBeforeCollectCallbacks);
      end;

      var ACalls: TArray<ITask>;
      TMonitor.Enter(FBeforeCollectAsyncCallbacks);
      try
        for var AsyncCallback: TFunc<ITask> in FBeforeCollectAsyncCallbacks do begin
          if not assigned(AsyncCallback) then continue;
          ACalls := ACalls+[AsyncCallback()];
        end;
      finally
        TMonitor.Exit(FBeforeCollectAsyncCallbacks);
      end;

      TTask.WaitForAll(ACalls);

      for var Collector: ICollector in FCollectors.Values do
        TTask.WaitForAny(TCollector(Collector).CollectAndSerializeAsync(Serializer));
    end
  );
end;

constructor TCollectorRegistry.Create;
begin
  inherited Create;
  FFirstCollectLock := TObject.Create;
  FStaticLabelsLock := TObject.Create;
  FCollectors       := TDictionary<string, ICollector>.Create;
  FBeforeCollectCallbacks       := TList<TProc>.Create;
  FBeforeCollectAsyncCallbacks  := TList<TFunc<ITask>>.Create;
end;

destructor TCollectorRegistry.Destroy;
begin
  FBeforeCollectCallbacks.Free;
  FBeforeCollectAsyncCallbacks.Free;
  FCollectors.Free;
  FFirstCollectLock.Free;
  FStaticLabelsLock.Free;
  inherited;
end;

function TCollectorRegistry.GetOrAdd<TCollectorType, TConfigurationType>(
  Initializer: TCollectorInitializer<TCollectorType, TConfigurationType>): TCollectorType;
begin
  var CollectorToUse: ICollector := nil;
  TMonitor.Enter(FCollectors);
  try
    if not FCollectors.TryGetValue(Initializer.Name, CollectorToUse) then begin
      CollectorToUse := Initializer.CreateInstance;
      FCollectors.Add(Initializer.Name, CollectorToUse);
    end;
  finally
    TMonitor.Exit(FCollectors);
  end;

  if not (CollectorToUse is TCollectorType) then
    raise EInvalidOpException.Create('Collector of a different type with the same name is already registered.');

  var isEqCount :=  Length(Initializer.Configuration.LabelNames) = Length(CollectorToUse.LabelNames);
  var isEqSeq   := Initializer.Configuration.LabelNames = CollectorToUse.LabelNames;
  if (not isEqCount) or (not isEqSeq) then
    raise EInvalidOpException.Create('Collector matches a previous registration but has a different set of label names.');

  result := TCollectorType(CollectorToUse);
end;

function TCollectorRegistry.GetStaticLabels: TArray<TPair<string, string>>;
begin
  result := FStaticLabels;
end;

procedure TCollectorRegistry.SetBeforeFirstCollectCallback(Action: TProc);
begin
  TMonitor.Enter(FFirstCollectLock);
  try
    // Avoid keeping a reference to a callback we won't ever use.
    if FHasPerformedFirstCollect then exit;

    FBeforeFirstCollectCallback := Action;
  finally
    TMonitor.Exit(FFirstCollectLock);
  end;
end;

procedure TCollectorRegistry.SetStaticLabels(
  Labels: TDictionary<string, string>);
begin
  if not assigned(Labels) then
    raise EArgumentNilException.Create('Labels');

  // Read lock is taken when creating metrics, so we know that no metrics can be created while we hold this lock.
  TMonitor.Enter(FStaticLabelsLock);
  try
    if Length(FStaticLabels) <> 0 then
      raise EInvalidOpException.Create('Static labels have already been defined - you can only do it once per registry.');

    if FCollectors.Count <> 0 then
      raise EInvalidOpException.Create('Metrics have already been added to the registry - cannot define static labels anymore.');

    // Keep the lock for the duration of this method to make sure no publishing happens while we are setting labels.
    TMonitor.Enter(FFirstCollectLock);
    try
      if FHasPerformedFirstCollect then
        raise EInvalidOpException.Create('The metrics registry has already been published - cannot define static labels anymore.');

      for var Pair: TPair<string, string> in Labels do
        TCollector.ValidateLabelName(Pair.Key);

      FStaticLabels := Labels.ToArray;
    finally
      TMonitor.Exit(FFirstCollectLock);
    end;
  finally
    TMonitor.Exit(FStaticLabelsLock);
  end;
end;

function TCollectorRegistry.WhileReadingStaticLabels<TReturn>(
  Action: TFunc<TLabels, TReturn>): TReturn;
begin
  TMonitor.Enter(FStaticLabelsLock);
  try
    var Names: TArray<string>;
    var Values: TArray<string>;
    for var Pair: TPair<string, string> in FStaticLabels do begin
      Names   := Names  + [Pair.Key];
      Values  := Values + [Pair.Value];
    end;

    var Labels := TLabels.New(Names, Values);
    result := Action(Labels);
  finally
    TMonitor.Exit(FStaticLabelsLock);
  end;
end;

{$ENDREGION}

{$REGION 'TMetricFactory'}

constructor TMetricFactory.Create(Registry: ICollectorRegistry);
begin
  inherited Create;

  if not assigned(Registry) then
    raise EArgumentNilException.Create('Registry');

  FRegistry := Registry;
end;

function TMetricFactory.CreateCounter(Name, Help: string;
  LabelNames: TArray<string>): ICounter;
begin
  var Config := TCounterConfiguration.Create;
  Config.LabelNames := LabelNames;
  result := CreateCounter(Name, Help, Config);
end;

function TMetricFactory.CreateCounter(Name, Help: string;
  Configuration: ICounterConfiguration): ICounter;
begin
  result := TCollectorRegistry(FRegistry).GetOrAdd<TCounter, ICounterConfiguration>(
    TCollectorRegistry.TCollectorInitializer<TCounter, ICounterConfiguration>.New(
      Name, Help,
      TIf.IfThen<ICounterConfiguration>(assigned(Configuration), Configuration, TCounterConfiguration.Default),

      function(n, h: string; config: ICounterConfiguration): TCounter
      begin
        result := TCounter.Create(n, h, Config.LabelNames, CreateStaticLabels(Config), Config.SuppressInitialValue);
      end
    )
  );
end;

function TMetricFactory.CreateGauge(Name, Help: string;
  Configuration: IGaugeConfiguration): IGauge;
begin
  result := TCollectorRegistry(FRegistry).GetOrAdd<TGauge, IGaugeConfiguration>(
    TCollectorRegistry.TCollectorInitializer<TGauge, IGaugeConfiguration>.New(
      Name, Help,
      TIf.IfThen<IGaugeConfiguration>(assigned(Configuration), Configuration, TGaugeConfiguration.Default),

      function(n, h: string; config: IGaugeConfiguration): TGauge
      begin
        result := TGauge.Create(n, h, Config.LabelNames, CreateStaticLabels(Config), Config.SuppressInitialValue);
      end
    )
  );
end;

function TMetricFactory.CreateGauge(Name, Help: string;
  LabelNames: TArray<string>): IGauge;
begin
  var Config := TGaugeConfiguration.Create;
  Config.LabelNames := LabelNames;
  result := CreateGauge(Name, Help, Config);
end;

function TMetricFactory.CreateHistogram(Name, Help: string;
  Configuration: IHistogramConfiguration): IHistogram;
begin
  result := TCollectorRegistry(FRegistry).GetOrAdd<THistogram, IHistogramConfiguration>(
    TCollectorRegistry.TCollectorInitializer<THistogram, IHistogramConfiguration>.New(
      Name, Help,
      TIf.IfThen<IHistogramConfiguration>(assigned(Configuration), Configuration, THistogramConfiguration.Default),

      function(n, h: string; config: IHistogramConfiguration): THistogram
      begin
        result := THistogram.Create(n, h, Config.LabelNames, CreateStaticLabels(Config), Config.SuppressInitialValue, Config.Buckets);
      end
    )
  );
end;

function TMetricFactory.CreateHistogram(Name, Help: string;
  LabelNames: TArray<string>): IHistogram;
begin
  var Config := THistogramConfiguration.Create;
  Config.LabelNames := LabelNames;
  result := CreateHistogram(Name, Help, Config);
end;

function TMetricFactory.CreateStaticLabels(
  MetricConfiguration: IMetricConfiguration): TLabels;
begin
  result := TCollectorRegistry(FRegistry).WhileReadingStaticLabels<TLabels>(
    function(RegistryLabels: TLabels): TLabels
    begin
      if MetricConfiguration.StaticLabels = nil then
        exit(RegistryLabels);

      var MetricLabels := TLabels.New(MetricConfiguration.StaticLabels.Keys.ToArray,
                                      MetricConfiguration.StaticLabels.Values.ToArray);

      result := MetricLabels.Concat(RegistryLabels);
    end
  );
end;

function TMetricFactory.CreateSummary(Name, Help: string;
  Configuration: ISummaryConfiguration): ISummary;
begin
  result := TCollectorRegistry(FRegistry).GetOrAdd<TSummary, ISummaryConfiguration>(
    TCollectorRegistry.TCollectorInitializer<TSummary, ISummaryConfiguration>.New(
      Name, Help,
      TIf.IfThen<ISummaryConfiguration>(assigned(Configuration), Configuration, TSummaryConfiguration.Default),

      function(n, h: string; config: ISummaryConfiguration): TSummary
      begin
        result := TSummary.Create(n, h, Config.LabelNames, CreateStaticLabels(Config),
                                  Config.MaxAge, Config.AgeBuckets, Config.BufferSize, Config.SuppressInitialValue, Config.Objectives);
      end
    )
  );
end;

function TMetricFactory.CreateSummary(Name, Help: string;
  LabelNames: TArray<string>): ISummary;
begin
  var Config := TSummaryConfiguration.Create;
  Config.LabelNames := LabelNames;
  result := CreateSummary(Name, Help, Config);
end;

destructor TMetricFactory.Destroy;
begin
  FRegistry := nil;
  inherited;
end;

{$ENDREGION}

{Configurations}

{$REGION 'TMetricConfiguration'}

function TMetricConfiguration.GetLabelNames: TArray<string>;
begin
  result := FLabelNames;
end;

function TMetricConfiguration.GetStaticLabels: TDictionary<string, string>;
begin
  Result := FStaticLabels;
end;

function TMetricConfiguration.GetSuppressInitialValue: boolean;
begin
  result := FSuppressInitialValue;
end;

procedure TMetricConfiguration.SetLabelNames(Value: TArray<string>);
begin
  FLabelNames := Value;
end;

procedure TMetricConfiguration.SetStaticLabels(
  Value: TDictionary<string, string>);
begin
  FStaticLabels := Value;
end;

procedure TMetricConfiguration.SetSuppressInitialValue(Value: boolean);
begin
  FSuppressInitialValue := Value;
end;

{$ENDREGION}

{$REGION 'TCounterConfiguration'}

class function TCounterConfiguration.Default: ICounterConfiguration;
begin
  result := TCounterConfiguration.Create;
end;

{$ENDREGION}

{$REGION 'TGaugeConfiguration'}

class function TGaugeConfiguration.Default: IGaugeConfiguration;
begin
  result := TGaugeConfiguration.Create;
end;

{$ENDREGION}

{$REGION 'TSummaryConfiguration'}

constructor TSummaryConfiguration.Create;
begin
  inherited;
end;

class function TSummaryConfiguration.Default: ISummaryConfiguration;
begin
  result := TSummaryConfiguration.Create;
end;

destructor TSummaryConfiguration.Destroy;
begin

  inherited;
end;

function TSummaryConfiguration.GetAgeBuckets: integer;
begin
  result := FAgeBuckets;
end;

function TSummaryConfiguration.GetBufferSize: integer;
begin
  result := FBufferSize;
end;

function TSummaryConfiguration.GetMaxAge: TTimeSpan;
begin
  result := FMaxAge;
end;

function TSummaryConfiguration.GetObjectives: TList<TQuantileEpsilonPair>;
begin
  result := FObjectives;
end;

procedure TSummaryConfiguration.SetAgeBuckets(Value: integer);
begin
  FAgeBuckets := Value;
end;

procedure TSummaryConfiguration.SetBufferSize(Value: integer);
begin
  FBufferSize := Value;
end;

procedure TSummaryConfiguration.SetMaxAge(Value: TTimeSpan);
begin
  FMaxAge := Value;
end;

procedure TSummaryConfiguration.SetObjectives(
  Value: TList<TQuantileEpsilonPair>);
begin
  FObjectives := Value;
end;

{$ENDREGION}

{$REGION 'THistogramConfiguration'}

class function THistogramConfiguration.Default: IHistogramConfiguration;
begin
  result := THistogramConfiguration.Create;
end;

function THistogramConfiguration.GetBuckets: TArray<double>;
begin
  result := FBuckets;
end;

procedure THistogramConfiguration.SetBuckets(Value: TArray<double>);
begin
  FBuckets := Value;
end;

{$ENDREGION}


{Metric classes}

{$REGION 'TMetrics'}

class constructor TMetrics.Create;
var
  LDefaultRegistry: ICollectorRegistry;
begin
  LDefaultRegistry := TCollectorRegistry.Create;

  TCollectorRegistry(LDefaultRegistry).SetBeforeFirstCollectCallback(
    procedure begin
      // We include some metrics by default, just to give some output when a user first uses the library.
      // These are not designed to be super meaningful/useful metrics.
      //DotNetStats.Register(DefaultRegistry);
    end
  );

  FDefaultFactory := TMetricFactory.Create(LDefaultRegistry);
end;

class destructor TMetrics.Destroy;
begin
  FDefaultFactory   := nil;
end;

class function TMetrics.GetDefaultRegistry: ICollectorRegistry;
begin
  result := TMetricFactory(TMetrics.FDefaultFactory).FRegistry;
end;

class function TMetrics.CreateCounter(Name, Help: string;
  LabelNames: TArray<string>): ICounter;
begin
  result := TMetricFactory(FDefaultFactory).CreateCounter(Name, Help, LabelNames);
end;

class function TMetrics.CreateCounter(Name, Help: string;
  Configuration: ICounterConfiguration): ICounter;
begin
  result := FDefaultFactory.CreateCounter(Name, Help, Configuration);
end;

class function TMetrics.CreateGauge(Name, Help: string;
  Configuration: IGaugeConfiguration): IGauge;
begin
  result := FDefaultFactory.CreateGauge(Name, Help, Configuration);
end;

class function TMetrics.CreateGauge(Name, Help: string;
  LabelNames: TArray<string>): IGauge;
begin
  result := TMetricFactory(FDefaultFactory).CreateGauge(Name, Help, LabelNames);
end;

class function TMetrics.CreateHistogram(Name, Help: string;
  Configuration: IHistogramConfiguration): IHistogram;
begin
  result := FDefaultFactory.CreateHistogram(Help, Name, Configuration);
end;

class function TMetrics.CreateHistogram(Name, Help: string;
  LabelNames: TArray<string>): IHistogram;
begin
  result := TMetricFactory(FDefaultFactory).CreateHistogram(Name, Help, LabelNames);
end;

class function TMetrics.CreateSummary(Name, Help: string;
  LabelNames: TArray<string>): ISummary;
begin
  result := TMetricFactory(FDefaultFactory).CreateSummary(Name, Help, LabelNames);
end;

class function TMetrics.CreateSummary(Name, Help: string;
  Configuration: ISummaryConfiguration): ISummary;
begin
  result := FDefaultFactory.CreateSummary(Name, Help, Configuration);
end;

class function TMetrics.NewCustomRegistry: ICollectorRegistry;
begin
  result := TCollectorRegistry.Create;
end;

class function TMetrics.NewSerializer(
  const StreamFactory: TFunc<TStream>): IMetricsSerializer;
begin
  result := TTextSerializer.Create(StreamFactory);
end;

class procedure TMetrics.SuppressDefaultMetrics;
begin
  // Only has effect if called before the registry is collected from.
  TCollectorRegistry(DefaultRegistry).SetBeforeFirstCollectCallback(
    procedure begin

    end
  );
end;

class function TMetrics.WithCustomRegistry(
  Registry: ICollectorRegistry): IMetricFactory;
begin
  result := TMetricFactory.Create(TCollectorRegistry(Registry));
end;

{$ENDREGION}


{$REGION 'TCounter'}

constructor TCounter.Create(Name, Help: string; LabelNames: TArray<string>;
  StaticLabels: TLabels; SuppressInitialValue: boolean);
begin
  inherited Create(Name, Help, LabelNames, StaticLabels, SuppressInitialValue);
end;

function TCounter.GetType: TMetricType;
begin
  result := TMetricType.Counter;
end;

function TCounter.GetValue: double;
begin
  result := TCounterChild(Unlabelled).Value;
end;

procedure TCounter.Inc(Increment: double);
begin
  TCounterChild(Unlabelled).Inc(Increment);
end;

procedure TCounter.IncTo(TargetValue: double);
begin
  TCounterChild(Unlabelled).IncTo(TargetValue);
end;

function TCounter.NewChild(Labels, FlattenedLabels: TLabels;
  Publish: boolean): ICollectorChild;
begin
  result := TCounterChild.Create(self, Labels, FlattenedLabels, Publish);
end;

procedure TCounter.Publish;
begin
  TCounterChild(Unlabelled).Publish;
end;

procedure TCounter.Unpublish;
begin
  TCounterChild(Unlabelled).Unpublish;
end;

{$ENDREGION}

{$REGION 'TCounterChild'}

function TCounterChild.CollectAndSerializeImplAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := Serializer.WriteMetricAsync(FIdentifier, Value);
end;

constructor TCounterChild.Create(Parent: TCollector; Labels,
  FlattenedLabels: TLabels; Publish: boolean);
begin
  inherited Create(Parent, Labels, FlattenedLabels, Publish);
  FIdentifier := CreateIdentifier;
end;

function TCounterChild.GetValue: double;
begin
  result := FValue.Value;
end;

procedure TCounterChild.Inc(Increment: double);
begin
  if Increment < 0.0 then
    raise EArgumentOutOfRangeException.Create('Counter "Increment" value cannot decrease.');

  FValue.Add(Increment);
  Publish;
end;

procedure TCounterChild.IncTo(TargetValue: double);
begin
  FValue.IncrementTo(TargetValue);
  Publish;
end;

{$ENDREGION}


{$REGION 'TGauge'}

constructor TGauge.Create(Name, Help: string; LabelNames: TArray<string>;
  StaticLabels: TLabels; SuppressInitialValue: boolean);
begin
  inherited Create(Name, Help, LabelNames, StaticLabels, SuppressInitialValue);
end;

procedure TGauge.Dec(Decrement: double);
begin
  TGaugeChild(Unlabelled).Dec(Decrement);
end;

procedure TGauge.DecTo(TargetValue: double);
begin
  TGaugeChild(Unlabelled).DecTo(TargetValue);
end;

function TGauge.GetType: TMetricType;
begin
  result := TMetricType.Gauge;
end;

function TGauge.GetValue: double;
begin
  result := TGaugeChild(Unlabelled).Value;
end;

procedure TGauge.Inc(Increment: double);
begin
  TGaugeChild(Unlabelled).Inc(Increment);
end;

procedure TGauge.IncTo(TargetValue: double);
begin
  TGaugeChild(Unlabelled).IncTo(TargetValue);
end;

function TGauge.NewChild(Labels, FlattenedLabels: TLabels;
  Publish: boolean): ICollectorChild;
begin
  result := TGaugeChild.Create(self, Labels, FlattenedLabels, Publish);
end;

procedure TGauge.&Set(Val: double);
begin
  TGaugeChild(Unlabelled).&Set(Val);
end;

{$ENDREGION}

{$REGION 'TGaugeChild'}

function TGaugeChild.CollectAndSerializeImplAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := Serializer.WriteMetricAsync(FIdentifier, Value);
end;

constructor TGaugeChild.Create(Parent: TCollector; Labels,
  FlattenedLabels: TLabels; Publish: boolean);
begin
  inherited Create(Parent, Labels, FlattenedLabels, Publish);

  FIdentifier := CreateIdentifier();
end;

procedure TGaugeChild.Dec(Decrement: double);
begin
  Inc(-Decrement);
end;

procedure TGaugeChild.DecTo(TargetValue: double);
begin
  FValue.DecrementTo(TargetValue);
  Publish;
end;

function TGaugeChild.GetValue: double;
begin
  result := FValue.Value;
end;

procedure TGaugeChild.Inc(Increment: double);
begin
  FValue.Add(Increment);
  Publish;
end;

procedure TGaugeChild.IncTo(TargetValue: double);
begin
  FValue.IncrementTo(TargetValue);
  Publish;
end;

procedure TGaugeChild.&Set(Val: double);
begin
  FValue.Value := Val;
  Publish;
end;

{$ENDREGION}


{$REGION 'TSummaryChild.TSampleBuffer'}

procedure TSummaryChild.TSampleBuffer.Append(Value: double);
begin
  if Position >= Capacity then
    raise EInvalidOpException.Create('Buffer is full');

  inc(FPosition);
  FBuffer[FPosition] := Value;
end;

function TSummaryChild.TSampleBuffer.Capacity: integer;
begin
  result := Length(FBuffer);
end;

constructor TSummaryChild.TSampleBuffer.Create(Capacity: integer);
begin
  if Capacity <= 0 then
    raise EArgumentOutOfRangeException.Create('Capacity. Must be > 0');

  SetLength(FBuffer, Capacity);
  FPosition := 0;
end;

function TSummaryChild.TSampleBuffer.GetValue(Idx: integer): double;
begin
  if Idx > Position then
    raise EArgumentOutOfRangeException.Create('Index is greater than position');

  result := FBuffer[Idx];
end;

function TSummaryChild.TSampleBuffer.IsEmpty: boolean;
begin
  result := Position = 0;
end;

function TSummaryChild.TSampleBuffer.IsFull: boolean;
begin
  result := Position = Capacity;
end;

procedure TSummaryChild.TSampleBuffer.Reset;
begin
  FPosition := 0;
end;

{$ENDREGION}

{$REGION 'TSummaryChild.TSampleStream'}

procedure TSummaryChild.TSampleStream.Compress;
begin
  if FSamples.Count < 2 then exit;

  var x   := FSamples[FSamples.Count-1];
  var xi  := FSamples.Count - 1;
  var r   := N - 1 - x.Width;

  for var I := FSamples.Count-2 downto 0 do begin
    var c := FSamples[I];
    if (c.Width + x.Width + x.Delta) <= FInvariant(self, r) then begin
      x.Width := x.Width + c.Width;
      FSamples[xi] := x;
      FSamples.Delete(I);
      dec(xi);
    end else begin
      x  := c;
      xi := I;
    end;

    r := r - c.Width;
  end;
end;

function TSummaryChild.TSampleStream.Count: integer;
begin
  result := Trunc(N);
end;

constructor TSummaryChild.TSampleStream.Create(Invariant: TInvariant);
begin
  FInvariant := Invariant;
end;

procedure TSummaryChild.TSampleStream.Merge(Samples: TList<TSample>);
begin
  // TODO(beorn7): This tries to merge not only individual samples, but
  // whole summaries. The paper doesn't mention merging summaries at
  // all. Unittests show that the merging is inaccurate. Find out how to
  // do merges properly.

  var r: double := 0;
  var I         := 0;
  for var Sample in Samples do begin
    var IsFound := false;
    while I < FSamples.Count do begin
      var c := FSamples[I];
      IsFound := c.Value > Sample.Value;
      if IsFound then begin
        FSamples.Insert(I, TSample.New(Sample.Value, Sample.Width, Max(Sample.Delta, Floor(FInvariant(self, r))-1)));
        inc(I);
        break;
      end;
      r := r + c.Width;
      inc(I);
    end;

    if not IsFound then begin
      FSamples.Add(TSample.New(Sample.Value, Sample.Width, 0));
      inc(I);
    end;

    N := N + Sample.Width;
    R := R + Sample.Width;
  end;

  Compress;
end;

function TSummaryChild.TSampleStream.Query(q: double): double;
begin
  var t := Ceil(q * N);
  t := t + Ceil(FInvariant(self, t) / 2);
  var p := FSamples[0];
  var r: double := 0;

  for var I := 1 to FSamples.Count-1 do begin
    var c := FSamples[I];
    r := r + p.Width;

    if (r + c.Width + c.Delta) > t then exit(p.Value);
    p := c;
  end;

  result := p.Value;
end;

procedure TSummaryChild.TSampleStream.Reset;
begin
  FSamples.Clear;
  N := 0;
end;

function TSummaryChild.TSampleStream.SampleCount: integer;
begin
  result := FSamples.Count;
end;

{$ENDREGION}

{$REGION 'TSummaryChild.TSample'}

constructor TSummaryChild.TSample.New(AValue, AWidth, ADelta: double);
begin
  Value := AValue;
  Width := AWidth;
  Delta := ADelta;
end;

{$ENDREGION}

{$REGION 'TSummaryChild.TQuantileStream'}

function TSummaryChild.TQuantileStream.Count: integer;
begin
  result := FSamples.Count + FSampleStream.Count;
end;

constructor TSummaryChild.TQuantileStream.Create(SampleStream: TSampleStream;
  Samples: TList<TSample>; Sorted: boolean);
begin
  FSampleStream := SampleStream;
  FSamples      := Samples;
  FSorted       := Sorted;
end;

procedure TSummaryChild.TQuantileStream.Flush;
begin
  MaybeSort;
  FSampleStream.Merge(FSamples);
  FSamples.Clear;
end;

function TSummaryChild.TQuantileStream.Flushed: boolean;
begin
  result := FSampleStream.SampleCount > 0;
end;

procedure TSummaryChild.TQuantileStream.Insert(Value: double);
begin
  Insert(TSample.New(Value, 1, 0));
end;

procedure TSummaryChild.TQuantileStream.Insert(Sample: TSample);
begin
  FSamples.Add(Sample);
  FSorted := false;
  if FSamples.Count = FSamples.Capacity then
    Flush;
end;

procedure TSummaryChild.TQuantileStream.MaybeSort;
begin
  var Comparer := TComparer<TSample>.Construct(SampleComparison);
  if not FSorted then begin
    FSorted := true;
    FSamples.Sort(Comparer);
  end;
end;

class function TSummaryChild.TQuantileStream.NewHighBiased(
  Epsilon: double): TQuantileStream;
var
  Invariant: TInvariant;
begin
  Invariant :=
    (function(Stream: TSampleStream; R: double): double begin
      result := 2 * epsilon * (Stream.N - r);
     end);

  result := NewStream(Invariant);
end;

class function TSummaryChild.TQuantileStream.NewLowBiased(
  Epsilon: double): TQuantileStream;
var
  Invariant: TInvariant;
begin
  Invariant :=
    (function(Stream: TSampleStream; R: double): double begin
      result := 2 * epsilon * r;
     end);

  result := NewStream(Invariant);
end;

class function TSummaryChild.TQuantileStream.NewStream(
  Invariant: TInvariant): TQuantileStream;
var
  List: TList<TSample>;
begin
  List := TList<TSample>.Create;
  List.Capacity := 500;
  result := TQuantileStream.Create(TSampleStream.Create(Invariant), List, true);
end;

class function TSummaryChild.TQuantileStream.NewTargeted(
  Targets: TList<TQuantileEpsilonPair>): TQuantileStream;
var
  Invariant: TInvariant;
begin
  Invariant :=
    (function(Stream: TSampleStream; R: double): double begin
      var m := double.MaxValue;
      for var Target in Targets do begin
        var f: double;
        if (Target.Quantile * Stream.N) <= R
          then f := (2 * Target.Epsilon * r) / Target.Quantile
          else f := (2 * Target.Epsilon * (Stream.N - r)) / (1 - Target.Quantile);

        if f < m then
          m := f;
      end;

      result := m;
     end);

  result := NewStream(Invariant);
end;

function TSummaryChild.TQuantileStream.Query(q: double): double;
begin
  if not Flushed then begin
    // Fast path when there hasn't been enough data for a flush;
    // this also yields better accuracy for small sets of data.
    var L := FSamples.Count;
    if L = 0 then exit(0);

    var I := Trunc(L * q);
    if I > 0 then Dec(I);

    MaybeSort;
    exit(FSamples[I].Value);
  end;

  Flush;
  result := FSampleStream.Query(q);
end;

procedure TSummaryChild.TQuantileStream.Reset;
begin
  FSampleStream.Reset;
  FSamples.Clear;
end;

class function TSummaryChild.TQuantileStream.SampleComparison(const Lhs, Rhs: TSample): integer;
begin
  if Lhs.Value < Rhs.Value then exit(-1);
  if Lhs.Value > Rhs.Value then exit(1);
  result := 0;
end;

function TSummaryChild.TQuantileStream.SamplesCount: integer;
begin
  result := FSamples.Count;
end;

{$ENDREGION}

{$REGION 'TSummaryChild' }

function TSummaryChild.CollectAndSerializeImplAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := TTask.Run(
    procedure begin
      // We output sum.
      // We output count.
      // We output quantiles.

      var LNow          := TDateTime.UtcNow;
      var Count: double;
      var Sum: double;
      var Values        := TList<TQuantileEpsilonPair>.Create;

      TMonitor.Enter(FBufLock);
      try
        TMonitor.Enter(FLock);
        try
          SwapBufs(LNow);
          FlushColdBuf;

          Count := FCount;
          Sum   := FSum;

          for var Quantile: double in FSortedObjectives do begin
            var Value := ifthen(FHeadStream.Count = 0, double.NaN, FHeadStream.Query(Quantile));
            Values.Add(TQuantileEpsilonPair.New(Quantile, Value));
          end;
        finally
          TMonitor.Exit(FLock);
        end;
      finally
        TMonitor.Exit(FBufLock);
      end;

      TTask.WaitForAny(Serializer.WriteMetricAsync(FSumIdentifier, sum));
      TTask.WaitForAny(Serializer.WriteMetricAsync(FCountIdentifier, count));

      for var I := 0 to Values.Count-1 do
        TTask.WaitForAny(Serializer.WriteMetricAsync(FQuantileIdentifiers[I], Values[I].Epsilon));
    end
  );
end;

constructor TSummaryChild.Create(Parent: TCollector; Labels,
  FlattenedLabels: TLabels; Publish: boolean);
begin
  inherited Create(Parent, Labels, FlattenedLabels, Publish);

  FObjectives := TSummary(Parent).FObjectives;
  FMaxAge     := TSummary(Parent).FMaxAge;
  FAgeBuckets := TSummary(Parent).FAgeBuckets;
  FBufCap     := TSummary(Parent).FBufCap;

  SetLength(FSortedObjectives, FObjectives.Count);
  FHotBuf   := TSampleBuffer.Create(FBufCap);
  FColdBuf  := TSampleBuffer.Create(FBufCap);
  FStreamDuration     := TTimeSpan.Create(FMaxAge.Ticks div FAgeBuckets);
  FHeadStreamExpTime  := TDateTime.UtcNow.Add(FStreamDuration);
  FHotBufExpTime      := FHeadStreamExpTime;

  SetLength(FStreams, FAgeBuckets);
  for var I := 0 to FAgeBuckets-1 do
    FStreams[I] := TQuantileStream.NewTargeted(FObjectives);

  FHeadStream := FStreams[0];

  for var I := 0 to FObjectives.Count-1 do
    FSortedObjectives[I] := FObjectives[I].Quantile;

  TArray.Sort<double>(FSortedObjectives);

  FSumIdentifier    := CreateIdentifier('sum', []);
  FCountIdentifier  := CreateIdentifier('count', []);

  SetLength(FQuantileIdentifiers, FObjectives.Count);
  for var I := 0 to FObjectives.Count-1 do begin
    var Value: string := ifthen(double.IsPositiveInfinity(FObjectives[I].Quantile),
                        '+Inf',
                        FObjectives[I].Quantile.ToString);
    FQuantileIdentifiers[I] := CreateIdentifier('', [TStringPair.Create('quantile', Value)]);
  end;
end;

procedure TSummaryChild.Flush(ANow: TDateTime);
begin
  TMonitor.Enter(FLock);
  try
    SwapBufs(ANow);
    // Go version flushes on a separate goroutine, but doing this on another
    // thread actually makes the benchmark tests slower in .net
    FlushColdBuf;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TSummaryChild.FlushColdBuf;
begin
  for var bufIdx := 0 to FColdBuf.Position-1 do begin
    var Value := FColdBuf[bufIdx];

    for var streamIdx := 0 to Length(FStreams) - 1 do
      FStreams[streamIdx].Insert(Value);

    Inc(FCount);
    FSum := FSum + Value;
  end;

  FColdBuf.Reset;
  MaybeRotateStreams;
end;

procedure TSummaryChild.MaybeRotateStreams;
begin
  while not FHotBufExpTime.Equals(FHeadStreamExpTime) do begin
    FHeadStream.Reset;
    Inc(FHeadStreamIdx);

    if FHeadStreamIdx >= Length(FStreams) then
      FHeadStreamIdx := 0;

    FHeadStream := FStreams[FHeadStreamIdx];
    FHeadStreamExpTime := FHeadStreamExpTime.AddYears(FStreamDuration.Milliseconds);
  end;
end;

procedure TSummaryChild.Observe(Value: double);
begin
  Observe(Value, TDateTime.UtcNow);
end;

procedure TSummaryChild.Observe(Value: double; ANow: TDateTime);
begin
  if double.IsNan(Value) then exit;

  TMonitor.Enter(FBufLock);
  try
    if ANow > FHotBufExpTime then
      Flush(ANow);

    FHotBuf.Append(Value);

    if FHotBuf.IsFull then
      Flush(ANow);
  finally
    TMonitor.Exit(FBufLock);
  end;

  Publish;
end;

procedure TSummaryChild.SwapBufs(ANow: TDateTime);
begin
  if not FColdBuf.IsEmpty then
    raise EInvalidOpException.Create('coldBuf is not empty');

  var temp := FHotBuf;
  FHotBuf  := FColdBuf;
  FColdBuf := temp;

  // hotBuf is now empty and gets new expiration set.
  while ANow > FHotBufExpTime do
    FHotBufExpTime := FHotBufExpTime.AddMilliseconds(FStreamDuration.Milliseconds);
end;

{$ENDREGION}

{$REGION 'TSummary'}

constructor TSummary.Create(Name, Help: string; LabelNames: TArray<string>;
  StaticLabels: TLabels; MaxAge: TTimeSpan; AgeBuckets, BufCap: integer;
  SuppressInitialValue: boolean; Objectives: TList<TQuantileEpsilonPair>);
begin
  inherited Create(Name, Help, LabelNames, StaticLabels, SuppressInitialValue);

  if not assigned(Objectives)
    then FObjectives := TList<TQuantileEpsilonPair>.Create
    else FObjectives := Objectives;

  FMaxAge     := MaxAge;
  FAgeBuckets := AgeBuckets;
  FBufCap     := BufCap;

  if FMaxAge < TTimeSpan.Zero then
    raise EArgumentException.Create('Illegal max age '+FMaxAge);

  if FAgeBuckets = 0 then
    FAgeBuckets := DefAgeBuckets;
  if FBufCap = 0 then
    FBufCap := DefBufCap;

  var List: TList<string> := TList<string>.Create;
  try
    List.AddRange(labelNames);
    if List.Contains(QuantileLabel) then
      raise EArgumentException.Create(QuantileLabel+'  is a reserved label name');
  finally
    List.Free;
  end;
end;

function TSummary.GetType: TMetricType;
begin
  result := TMetricType.Summary;
end;

function TSummary.NewChild(Labels, FlattenedLabels: TLabels;
  Publish: boolean): ICollectorChild;
begin
  result := TSummaryChild.Create(self, Labels, FlattenedLabels, Publish);
end;

procedure TSummary.Observe(Val: double);
begin
  TSummaryChild(Unlabelled).Observe(Val);
end;

{$ENDREGION}


{Serializer}

{$REGION 'TTextSerializer'}
constructor TTextSerializer.Create(Dest: TStream);
begin
  inherited Create;
  SetLength(FStringBytesBuffer, 32);
 // FillChar(FStringBytesBuffer, Length(FStringBytesBuffer), #0);

  FStreamLazy    := nil;
  FGetStreamLazy := (function(): TStream
                     begin
                      result := Dest;
                     end);
end;

constructor TTextSerializer.Create(const StreamFactory: TFunc<TStream>);
begin
  inherited Create;

  FStreamLazy    := nil;
  FGetStreamLazy := (function: TStream
                     begin
                      result := StreamFactory();
                     end);
end;

function TTextSerializer.FStream: TStream;
begin
  if not assigned(FStreamLazy) then
    FStreamLazy := FGetStreamLazy();

  result := FStreamLazy;
end;

function TTextSerializer.WriteFamilyDeclarationAsync(
  HeaderLines: TArray<TArray<byte>>): ITask;
begin
  result := TTask.Run(
    procedure begin
      for var Line: TArray<Byte> in HeaderLines do begin
        FStream.Write(Line, Length(Line));
        FStream.Write(NewLine, Length(NewLine));
      end;
    end
  );
end;

function TTextSerializer.WriteMetricAsync(Identifier: TArray<byte>;
  value: double): ITask;
begin
  result := TTask.Run(
    procedure
    begin
      FStream.Write(Identifier, Length(Identifier));
      FStream.Write(Space, Length(Space));
      var ValueAsString := Value.ToString;
      var numBytes := TPrometheusConstants.ExportEncoding
            .GetBytes(ValueAsString, 1, ValueAsString.Length, FStringBytesBuffer, 0);

      FStream.Write(FStringBytesBuffer, numBytes);
      FStream.Write(NewLine, Length(NewLine));
    end
  );
end;


{$ENDREGION}


{Other implements}

{$REGION 'TMetricTypeHelper'}

function TMetricTypeHelper.ToString: string;
begin
  result := TRttiEnumerationType.GetName<TMetricType>(self);
end;

{$ENDREGION}

{$REGION 'TPrometheusConstants'}

class constructor TPrometheusConstants.Create;
begin
  FEncoding := TEncoding.UTF8;
end;

{$ENDREGION}

{$REGION 'TThreadSafeDouble'}

procedure TThreadSafeDouble.Add(AValue: double);
begin
  while True do begin
    var InitialValue: int64   := FValue;
    var ComputedValue: double := TBitConverter.Int64BitsToDouble(InitialValue)+AValue;

    if (InitialValue = TInterlocked.CompareExchange(FValue, TBitConverter.DoubleToInt64Bits(ComputedValue), InitialValue)) then
      exit;
  end;
end;

procedure TThreadSafeDouble.DecrementTo(AValue: double);
begin
  while true do begin
    var InitialRaw: int64     := FValue;
    var InitialValue: double  := TBitConverter.Int64BitsToDouble(InitialRaw);

    if InitialValue <= AValue then exit; //Already greater.

    if (InitialRaw = TInterlocked.CompareExchange(FValue, TBitConverter.DoubleToInt64Bits(AValue), InitialRaw)) then
      exit;
  end;
end;

function TThreadSafeDouble.GetValue: double;
begin
  result := TBitConverter.Int64BitsToDouble(TInterlocked.Read(FValue));
end;

procedure TThreadSafeDouble.IncrementTo(AValue: double);
begin
  while true do begin
    var InitialRaw: int64     := FValue;
    var InitialValue: double  := TBitConverter.Int64BitsToDouble(InitialRaw);

    if InitialValue >= AValue then exit; //Already greater.

    if (InitialRaw = TInterlocked.CompareExchange(FValue, TBitConverter.DoubleToInt64Bits(AValue), InitialRaw))then
      exit;
  end;
end;

constructor TThreadSafeDouble.New(AValue: double);
begin
  FValue := TBitConverter.DoubleToInt64Bits(AValue);
end;

procedure TThreadSafeDouble.SetValue(AValue: double);
begin
  TInterlocked.Exchange(FValue, TBitConverter.DoubleToInt64Bits(AValue));
end;

{$ENDREGION}

{$REGION 'TThreadSafeInt64'}

procedure TThreadSafeInt64.Add(Increment: Int64);
begin
  TInterlocked.Add(FValue, Increment);
end;

function TThreadSafeInt64.GetValue: Int64;
begin
  result := TInterlocked.Read(FValue);
end;

constructor TThreadSafeInt64.New(AValue: Int64);
begin
  FValue := AValue;
end;

procedure TThreadSafeInt64.SetValue(AValue: Int64);
begin
  TInterlocked.Exchange(FValue, AValue);
end;

{$ENDREGION}


{$REGION 'TLabels'}

{$OVERFLOWCHECKS OFF}
class function TLabels.CalculateHashCode(Values: TArray<string>): integer;
begin
  var HashCode: integer := 0;
  for var Item: string in Values do
    HashCode := HashCode or (Item.GetHashCode * 397);

  result := HashCode;
end;
{$OVERFLOWCHECKS ON}

function TLabels.Concat(More: TLabels): TLabels;
begin
  var AllNames  := TArray.Concat<string>([Names, More.Names]);
  var AllValues := TArray.Concat<string>([Values,More.Values]);

  if IsMultipleCopiesName(AllNames) then
    raise EInvalidOpException.Create('The metric instance received multiple copies of the same label.');

  result := TLabels.New(AllNames, AllValues);
end;

function TLabels.Concat(More: TArray<TStringPair>): TLabels;
var
  LNames, LValues: TArray<string>;
begin
  for var Item: TStringPair in More do begin
    LNames  := LNames  + [Item.Key];
    LValues := LValues + [Item.Value];
  end;

  result := Concat(TLabels.New(LNames, LValues));
end;

class constructor TLabels.Create;
begin
  FEmpty.FValues := [];
  FEmpty.FNames  := [];
end;

class function TLabels.EscapeLabelValue(Value: string): string;
begin
  result := Value
              .Replace(#13#10, '\n')
              .Replace(#13,    '\n')
              .Replace(#10,    '\n')
              .Replace('\',    '\\')
              .Replace('"',    '\"');
end;

function TLabels.GetCount: integer;
begin
  result := Length(FNames);
end;

class function TLabels.IsMultipleCopiesName(Names: TArray<string>): boolean;
begin
  var List := TStringList.Create(TDuplicates.dupIgnore, false, true);
  try
    List.AddStrings(Names);
    result := List.Count <> Length(Names);
  finally
    List.Free;
  end;
end;

constructor TLabels.New(Names, Values: TArray<string>);
begin
//  if Length(Names) = 0 then
//    raise EArgumentNilException.Create('Names');
//  if Length(Values) = 0 then
//    raise EArgumentNilException.Create('Values');
  if Length(Names) <> Length(Values) then
    raise EArgumentException.Create('The list of label values must have the same number of elements as the list of label names.');
  if IsMultipleCopiesName(Names) then
    raise EArgumentException.Create('The metric instance received multiple copies of the same label.');

//  for var lv: string in Values do begin
//    if lv.IsEmpty then
//      raise EArgumentNilException.Create('A label value cannot be null.');
//  end;

  FValues := Values;
  FNames  := Names;

  // Calculating the hash code is fast but we don't need to re-calculate it for each comparison.
  // Labels are fixed - calculate it once up-front and remember the value.
  FHashCode := CalculateHashCode(Values);
end;

function TLabels.Serialize: string;
var
  Labels: TArray<string>;
begin
  // Result is cached in child collector - no need to worry about efficiency here.

  for var I: integer := 0 to Length(Names)-1 do
    Labels := Labels+[format('%s="%s"', [Names[I], EscapeLabelValue(Values[I])])];

  result := string.Join(',', Labels);
end;

{$ENDREGION}

{$REGION 'TQuantileEpsilonPair'}

constructor TQuantileEpsilonPair.New(Quantile, Epsilon: double);
begin
  FQuantile := Quantile;
  FEpsilon  := Epsilon;
end;

{$ENDREGION}


{$REGION 'TIf'}

class function TIf.IfThen<T>(Expression: boolean; IsTrue, IsFalse: T): T;
begin
  if Expression
    then result := IsTrue
    else result := IsFalse;
end;

{$ENDREGION}

{ THistogram }

constructor THistogram.Create(Name, Help: string; LabelNames: TArray<string>;
  StaticLabels: TLabels; SuppressInitialValue: boolean; Buckets: TArray<double> = []);
begin
  inherited Create(Name, Help, LabelNames, StaticLabels, SuppressInitialValue);

  var List := TList<string>.Create;
  try
    List.AddRange(LabelNames);
    if List.Contains('le') then
      raise EArgumentException.Create('"le" is a reserved label name');
  finally
    List.Free;
  end;

  if Length(Buckets) = 0
    then FBuckets := DefaultBuckets
    else FBuckets := Buckets;

  if Length(FBuckets) = 0 then
    raise EArgumentException.Create('Histogram must have at least one bucket');

  if not double.IsPositiveInfinity(FBuckets[Length(FBuckets)-1]) then begin
    var LArr: TArray<double> := [Double.PositiveInfinity];
    FBuckets := TArray.Concat<double>([FBuckets, LArr]);
  end;

  for var I := 1 to Length(FBuckets)-1 do begin
    if FBuckets[I] <= FBuckets[I-1] then
      raise EArgumentException.Create('Bucket values must be increasing');
  end;
end;

class function THistogram.ExponetialBuckets(Start, Factor: double;
  Count: integer): TArray<double>;
begin
  if Count <= 0   then raise EArgumentException.Create('ExponentialBuckets needs a positive Count');
  if Start <= 0   then raise EArgumentException.Create('ExponentialBuckets needs a positive Start');
  if Factor <= 1  then raise EArgumentException.Create('ExponentialBuckets needs a Factor greater than 1');

  var Buckets: TArray<double>;
  SetLength(Buckets, Count);

  for var I := 0 to Length(Buckets)-1 do begin
    Buckets[I] := Start;
    Start := Start * Factor;
  end;

  result := Buckets;
end;

function THistogram.GetCount: Int64;
begin
  result := THistogramChild(Unlabelled).Count;
end;

function THistogram.GetSum: double;
begin
  result := THistogramChild(Unlabelled).Sum;
end;

function THistogram.GetType: TMetricType;
begin
  result := TMetricType.Histogram;
end;

class function THistogram.LinearBuckets(Start, Width: double;
  Count: integer): TArray<double>;
begin
  if Count <= 0 then raise EArgumentException.Create('LinearBuckets needs a positive Count');

  var Buckets: TArray<double>;
  SetLength(Buckets, Count);

  for var I := 0 to Length(Buckets)-1 do begin
    Buckets[I] := Start;
    Start := Start + width;
  end;

  result := Buckets;
end;

function THistogram.NewChild(Labels, FlattenedLabels: TLabels;
  Publish: boolean): ICollectorChild;
begin
  result := THistogramChild.Create(self, labels, FlattenedLabels, Publish);
end;

procedure THistogram.Observe(Val: double);
begin
  THistogramChild(Unlabelled).Observe(Val);
end;

procedure THistogram.Observe(Val: double; Count: Int64);
begin
  THistogramChild(Unlabelled).Observe(Val, Count);
end;

{ TDebugInterfacedObject }

function TDebugInterfacedObject.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  result := inherited QueryInterface(IID, Obj);
  TDebug.WriteLine(format('QueryInterface [%s]', [ClassName]));
end;

function TDebugInterfacedObject._AddRef: Integer;
begin
  result := inherited;
  TDebug.WriteLine(format('_AddRef (%d) [%s]', [FRefCount, ClassName]));
end;

function TDebugInterfacedObject._Release: Integer;
begin
  result := inherited;
  TDebug.WriteLine(format('_Release (%d) [%s]', [FRefCount, ClassName]));
end;


{ THistogramChild }

function THistogramChild.CollectAndSerializeImplAsync(
  Serializer: IMetricsSerializer): ITask;
begin
  result := TTask.Run(
    procedure begin
      // We output sum.
      // We output count.
      // We output each bucket in order of increasing upper bound.

      TTask.WaitForAny(Serializer.WriteMetricAsync(FSumIdentifier, FSum.Value));

      var SumCount: double := 0.0;
      for var Val in FBucketCounts do
        SumCount := SumCount + Val.Value;

      TTask.WaitForAny(Serializer.WriteMetricAsync(FCountIdentifier, SumCount));

      var CumulativeCount: int64 := 0;
      for var I := 0 to Length(FBucketCounts)-1 do begin
        CumulativeCount := CumulativeCount + FBucketCounts[I].Value;
        TTask.WaitForAny(Serializer.WriteMetricAsync(FBucketIdentifiers[I], CumulativeCount));
      end;
    end
  );
end;

constructor THistogramChild.Create(Parent: TCollector; Labels,
  FlattenedLabels: TLabels; Publish: boolean);
begin
  inherited Create(Parent, Labels, FlattenedLabels, Publish);

  FUpperBounds    := THistogram(Parent).FBuckets;
  SetLength(FBucketCounts, Length(FUpperBounds));

  FSumIdentifier    := CreateIdentifier('sum');
  FCountIdentifier  := CreateIdentifier('count');

  SetLength(FBucketIdentifiers, Length(FUpperBounds));
  for var I := 0 to Length(FUpperBounds)-1 do begin
    var Value := ifthen(double.IsPositiveInfinity(FUpperBounds[I]), '+Inf', FUpperBounds[I].ToString);
    FBucketIdentifiers[I] := CreateIdentifier('bucket', [TStringPair.Create('le', Value)]);
  end;

end;

function THistogramChild.GetCount: int64;
begin
  var LCount: int64 := 0;
  for var Val in FBucketCounts do
    LCount := LCount + Val.Value;

  result := LCount;
end;

function THistogramChild.GetSum: double;
begin
  result := FSum.Value;
end;

procedure THistogramChild.Observe(Value: double);
begin
  Observe(Value, 1);
end;

procedure THistogramChild.Observe(Value: double; Count: Int64);
begin
  if double.IsNan(Value) then exit;

  for var I := 0 to Length(FUpperBounds)-1 do begin
    if Value <= FUpperBounds[I] then begin
      FBucketCounts[I].Add(Count);
      break;
    end;
  end;

  FSum.Add(Value * Count);
  Publish;
end;

{ TCounterExtensions }

procedure TCounterExtensions.CountExceptions(Wrapped: TProc;
  ExceptionFilter: TFunc<Exception, boolean>);
begin
  if not assigned(self) then
    raise EArgumentException.Create('self');

  if not assigned(Wrapped) then
    raise EArgumentException.Create('Wrapped');

  try
    Wrapped();
  except
    on E: Exception do begin
      if (not assigned(ExceptionFilter)) or (ExceptionFilter(E)) then begin
        self.Inc;
        raise;
      end;
    end;
  end;
end;

function TCounterExtensions.CountExceptions<TResult>(
  Wrapped: TFunc<TResult>; ExceptionFilter: TFunc<Exception, boolean>): TResult;
begin
  if not assigned(self) then
    raise EArgumentException.Create('self');

  if not assigned(Wrapped) then
    raise EArgumentException.Create('Wrapped');

  try
    result := Wrapped();
  except
    on E: Exception do begin
      if (not assigned(ExceptionFilter)) or (ExceptionFilter(E)) then begin
        self.Inc;
        raise;
      end;
    end;
  end;
end;

function TCounterExtensions.CountExceptionsAsync(Wrapped: TFunc<ITask>;
  ExceptionFilter: TFunc<Exception, boolean>): ITask;
begin
  result := TTask.Run(
    procedure begin
      if not assigned(self) then
        raise EArgumentException.Create('self');

      if not assigned(Wrapped) then
        raise EArgumentException.Create('Wrapped');

      try
        TTask.WaitForAny(Wrapped());
      except
        on E: Exception do begin
          if (not assigned(ExceptionFilter)) or (ExceptionFilter(E)) then begin
            self.Inc;
            raise;
          end;
        end;
      end;
    end
  );
end;

function TCounterExtensions.CountExceptionsAsync<TResult>(
  Wrapped: TFunc<IFuture<TResult>>;
  ExceptionFilter: TFunc<Exception, boolean>): IFuture<TResult>;
begin
  result := TTask.Future<TResult>(
    function: TResult
    begin
      if not assigned(self) then
        raise EArgumentException.Create('self');

      if not assigned(Wrapped) then
        raise EArgumentException.Create('Wrapped');

      try
        result := Wrapped().Value;
      except
        on E: Exception do begin
          if (not assigned(ExceptionFilter)) or (ExceptionFilter(E)) then begin
            self.Inc;
            raise;
          end;
        end;
      end;
    end
  ).Start;
end;

end.
