unit Prometheus.Servers;

interface
uses
  System.Threading,
  System.SysUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Generics.Collections,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,

  Prometheus.Metrics, System.TimeSpan
  ;

type
  ICancellationToken = interface;
  TMetricServer = class;
  TMetricPusher = class;


  /// <summary>
  /// A metric server exposes a Prometheus metric exporter endpoint in the background,
  /// operating independently and serving metrics until it is instructed to stop.
  /// </summary>
  IMetricServer = interface
    /// <summary>
    /// Starts serving metrics.
    ///
    /// Returns the same instance that was called (for fluent-API-style chaining).
    /// </summary>
    function Start: IMetricServer;
    /// <summary>
    /// Instructs the metric server to stop and returns a task you can await for it to stop.
    /// </summary>
    function StopAsync: ITask;
    /// <summary>
    /// Instructs the metric server to stop and waits for it to stop.
    /// </summary>
    procedure Stop;
  end;

  /// <summary>
  /// Base class for various metric server implementations that start an independent exporter in the background.
  /// The expoters may either be pull-based (exposing the Prometheus API) or push-based (actively pushing to PushGateway).
  /// </summary>
  TMetricHandler = class abstract(TInterfacedObject, IMetricServer)
  private
    // This is the task started for the purpose of exporting metrics.
    FTask: ITask;
    FCancel: ICancellationToken;
  protected
    // The registry that contains the collectors to export metrics from.
    // Subclasses are expected to use this variable to obtain the correct registry.
    FRegistry: ICollectorRegistry;

    constructor Create(Registry: ICollectorRegistry = nil);
    function StartServer(Cancel: ICancellationToken): ITask; virtual; abstract;
  public
    destructor Destroy; override;
    function Start: IMetricServer;
    function StopAsync: ITask;
    procedure Stop;
  end;

  /// <summary>
  /// Implementation of a Prometheus exporter that serves metrics using HttpListener.
  /// This is a stand-alone exporter for apps that do not already have an HTTP server included.
  /// </summary>
  TMetricServer = class(TMetricHandler)
  private
    FCancel: ICancellationToken;
    FRequestPredicate: TFunc<TIdHTTPRequestInfo, boolean>;
    FHttpListener: TIdHttpServer;
    procedure DoListen(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  protected
    function StartServer(Cancel: ICancellationToken): ITask; override;
  public
    constructor Create(Port: integer; Url: string = 'metrics/'; Registry: ICollectorRegistry = nil; IsUseHttps: boolean = false); overload;
    constructor Create(Hostname: string; Port: integer; Url: string = 'metrics/'; Registry: ICollectorRegistry = nil; IsUseHttps: boolean = false); overload;
    destructor Destroy; override;

    property RequestPredicate: TFunc<TIdHTTPRequestInfo, boolean> read FRequestPredicate write FRequestPredicate;
  end;

  TMetricPusherOptions = record
    class operator Initialize (out Dest: TMetricPusherOptions);
    class operator Finalize (var Dest: TMetricPusherOptions);
  public
    Endpoint: string;
    Job: string;
    Instance: string;
    IntervalMs: UInt64;
    AdditionalLabels: TArray<TPair<string, string>>;
    Registry: ICollectorRegistry;
    /// <summary>
    /// Callback for when a metric push fails.
    /// </summary>
    OnError: TProc<Exception>;
    /// <summary>
    /// If null, a singleton HttpClient will be used.
    /// </summary>
    HttpClientProvider: TFunc<THTTPClient>;
  end;

  TValueStopwatch = record
    class operator Initialize (out Dest: TValueStopwatch);
  strict private
    FTimestampToTicks: double;
    FStartTimestamp: Int64;
  public
    function IsActive: boolean;
    function GetElapsedTime: TTimespan;

    class function StartNew: TValueStopwatch; static;
  end;

  /// <summary>
  /// A metric server that regularly pushes metrics to a Prometheus PushGateway.
  /// </summary>
  TMetricPusher = class(TMetricHandler)
  strict private
    FContentTypeHeaderValue: TNetHeaders;
    FSingletonHttpClient: THTTPClient;
  strict private
    FPushInterval: TTimeSpan;
    FTargetUrl: string;
    FHttpClientProvider: TFunc<THttpClient>;
    FOnError: TProc<Exception>;

    procedure HandleFailedPush(Ex: Exception);
  protected
    function StartServer(Cancel: ICancellationToken): ITask; override;
  public
    constructor Create(Endpoint, Job: string; Instance: string = '';
      IntervalMs: UInt64 = 1000; AddtitionalLabels: TArray<TPair<string, string>> = [];
      Registry: ICollectorRegistry = nil); overload;
    constructor Create(Options: TMetricPusherOptions); overload;
  end;

  {$REGION 'CancellationToken'}

  ICancellationToken = interface
    procedure Reset;
    procedure Cancel;
    function IsCancellationRequested: boolean;
  end;

  TCancellationToken = class(TInterfacedObject, ICancellationToken)
  private
    FIsCancellationRequested: int64;
  public
    constructor Create;

    procedure Reset;
    procedure Cancel;
    function IsCancellationRequested: boolean;
  end;

  {$ENDREGION}

  EScrapeFailedException = class(Exception);
implementation
uses
  System.StrUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics
  ;

type TOpenMetrics = class(TMetrics);

{$REGION 'TCodes'}
type
  TCodes = record
    //1×× Informational
    const &Continue = 100;
    const SwitchingProtocols = 101;
    const Processing = 102;
    //2×× Success
    const OK = 200;
    const Created = 201;
    const Accepted = 202;
    const NonAuthoritativeInformation = 203;
    const NoContent = 204;
    const ResetContent = 205;
    const PartialContent = 206;
    const MultiStatus = 207;
    const AlreadyReported = 208;
    const IMUsed = 226;
    //3×× Redirection
    const MultipleChoices = 300;
    const MovedPermanently = 301;
    const Found = 302;
    const SeeOther = 303;
    const NotModified = 304;
    const UseProxy = 305;
    const TemporaryRedirect = 307;
    const PermanentRedirect = 308;
    //4×× Client Error
    const BadRequest = 400;
    const Unauthorized = 401;
    const PaymentRequired = 402;
    const Forbidden = 403;
    const NotFound = 404;
    const MethodNotAllowed = 405;
    const NotAcceptable = 406;
    const ProxyAuthenticationRequired = 407;
    const RequestTimeout = 408;
    const Conflict = 409;
    const Gone = 410;
    const LengthRequired = 411;
    const PreconditionFailed = 412;
    const PayloadTooLarge = 413;
    const RequestURITooLong = 414;
    const UnsupportedMediaType = 415;
    const RequestedRangeNotSatisfiable = 416;
    const ExpectationFailed = 417;
    const ImATeapot = 418;
    const MisdirectedRequest = 421;
    const UnprocessableEntity = 422;
    const Locked = 423;
    const FailedDependency = 424;
    const UpgradeRequired = 426;
    const PreconditionRequired = 428;
    const TooManyRequests = 429;
    const RequestHeaderFieldsTooLarge = 431;
    const ConnectionClosedWithoutResponse = 444;
    const UnavailableForLegalReasons = 451;
    const ClientClosedRequest = 499;
    //5×× Server Error
    const InternalServerError = 500;
    const NotImplemented = 501;
    const BadGateway = 502;
    const ServiceUnavailable = 503;
    const GatewayTimeout = 504;
    const HTTPVersionNotSupported = 505;
    const VariantAlsoNegotiates = 506;
    const InsufficientStorage = 507;
    const LoopDetected = 508;
    const NotExtended = 510;
    const NetworkAuthenticationRequired = 511;
    const NetworkConnectTimeoutError = 599;
  end;
{$ENDREGION}

{$REGION 'TMetricHandler'}

constructor TMetricHandler.Create(Registry: ICollectorRegistry);
begin
  inherited Create;
  if Assigned(Registry)
    then FRegistry := Registry
    else FRegistry := TMetrics.DefaultRegistry;

  FTask := nil;
  FCancel := TCancellationToken.Create;
end;

destructor TMetricHandler.Destroy;
begin
  Stop;
  FRegistry := nil;
  inherited;
end;

function TMetricHandler.Start: IMetricServer;
begin
  if assigned(FTask) then
    raise EInvalidOpException.Create('The metric server has already been started.');

  if not assigned(FCancel) then
    raise EInvalidOpException.Create('The metric server has already been started and stopped. Create a new server if you want to start it again.');

  FTask := StartServer(FCancel);
  result := self;
end;

procedure TMetricHandler.Stop;
begin
  TTask.WaitForAll(StopAsync);
end;

function TMetricHandler.StopAsync: ITask;
begin
  result := TTask.Run(
    procedure begin
      FCancel.Cancel;
      try
        try
          if not assigned(FTask) then exit; //Never started.

          TTask.WaitForAll(FTask);
        except
          // We'll eat this one, though, since it can easily get thrown by whatever checks the CancellationToken.
        end;
      finally
        FTask := nil;
      end;
    end
  );
end;

{$ENDREGION}

{$REGION 'TCancellationToken'}

procedure TCancellationToken.Cancel;
begin
  TInterlocked.Exchange(FIsCancellationRequested, 1);
end;

constructor TCancellationToken.Create;
begin
  FIsCancellationRequested := 0;
end;

function TCancellationToken.IsCancellationRequested: boolean;
var
  LValue: int64;
begin
  LValue := TInterlocked.Read(FIsCancellationRequested);
  result := LValue > 0;
end;

procedure TCancellationToken.Reset;
begin
  TInterlocked.Exchange(FIsCancellationRequested, 0);
end;

{$ENDREGION}

{$REGION 'TMetricServer'}

constructor TMetricServer.Create(Port: integer; Url: string;
  Registry: ICollectorRegistry; IsUseHttps: boolean);
begin
  Create('+', Port, Url, Registry, IsUseHttps);
end;

constructor TMetricServer.Create(Hostname: string; Port: integer; Url: string;
  Registry: ICollectorRegistry; IsUseHttps: boolean);
begin
  inherited Create(Registry);
  var s := ifthen(IsUseHttps, 's', '');

  FHttpListener := TIdHTTPServer.Create(nil);
  FHttpListener.ServerSoftware := 'Prometheus exporter';
  FHttpListener.KeepAlive      := true;
  FHttpListener.DefaultPort    := Port;
  FHttpListener.OnCommandGet   := DoListen;
  FRequestPredicate            := nil;
end;

destructor TMetricServer.Destroy;
begin
  FHttpListener.Free;
  inherited;
end;

procedure TMetricServer.DoListen(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  if (not assigned(FCancel)) or FCancel.IsCancellationRequested then exit;

  if Assigned(FRequestPredicate) and (not FRequestPredicate(ARequestInfo)) then begin
    // Request rejected by predicate.
    AResponseInfo.ResponseNo := TCodes.Forbidden;
    exit;
  end;

  try
    // We first touch the response.OutputStream only in the callback because touching
    // it means we can no longer send headers (the status code).
    var Serializer := TOpenMetrics.NewSerializer(
      function: TStream
      begin
        AResponseInfo.ContentType := TPrometheusConstants.ExporterContentType;
        AResponseInfo.ResponseNo  := TCodes.OK;
        result := TMemoryStream.Create;
        AResponseInfo.ContentStream := result;
      end
    );

    TTask.WaitForAny(FRegistry.CollectAndSerializeAsync(Serializer));
  except
    on E: EScrapeFailedException do begin
      // This can only happen before anything is written to the stream, so it
      // should still be safe to update the status code and report an error.
      AResponseInfo.ResponseNo := TCodes.ServiceUnavailable;
      if not string.IsNullOrWhiteSpace(E.Message) then begin
        var Writer := TStreamWriter(AResponseInfo.ContentStream);
        try
          Writer.Write(E.Message);
        finally
          Writer.Free;
        end;
      end;
    end;

    on E: Exception do begin
      if not FHttpListener.Active then exit;
      try
        AResponseInfo.ResponseNo := TCodes.InternalServerError;
      except
        // Might be too late in request processing to set response code, so just ignore.
      end;
    end;
  end;
end;

function TMetricServer.StartServer(Cancel: ICancellationToken): ITask;
begin
  FHttpListener.Active := true;
  result := TTask.Run(
    procedure begin
      FCancel := Cancel;
      try
//        try
          while not FCancel.IsCancellationRequested do begin
            sleep(100);
          end;
//        except
//          { TODO -cTLog : Log error }
//        end;
      finally
//        FHttpListener.Active := false;
        FCancel := nil;
      end;
    end
  );
end;

{$ENDREGION}

{$REGION 'TMetricPusher'}

constructor TMetricPusher.Create(Endpoint, Job, Instance: string;
  IntervalMs: UInt64; AddtitionalLabels: TArray<TPair<string, string>>;
  Registry: ICollectorRegistry);
var
  Options: TMetricPusherOptions;
begin
  Options.Endpoint          := Endpoint;
  Options.Job               := Job;
  Options.Instance          := Instance;
  Options.IntervalMs        := IntervalMs;
  Options.AdditionalLabels  := AddtitionalLabels;
  Options.Registry          := Registry;

  Create(Options);
end;

constructor TMetricPusher.Create(Options: TMetricPusherOptions);
begin
  if Options.Endpoint.IsEmpty then
    raise EArgumentNilException.Create('Options.Endpoint');
  if Options.Job.IsEmpty then
    raise EArgumentNilException.Create('Options.Job');
  if Options.IntervalMs <= 0 then
    raise EArgumentException.Create('Interval must be greater than zero Options.IntervalMs');

  FContentTypeHeaderValue := [TNameValuePair.Create('Content-Type', TPrometheusConstants.ExporterContentTypeMinimal)];

  if not (Options.HttpClientProvider = nil)
    then FHttpClientProvider := Options.HttpClientProvider
    else FHttpClientProvider := function: THTTPClient
                                begin
                                  result := FSingletonHttpClient;
                                end;

  var sb := TStringBuilder.Create(format('%s/job/%s', [ifthen(Options.Endpoint.IsEmpty, '', Options.Endpoint.TrimRight(['/'])), Options.Job]));
  try
    if not Options.Instance.IsEmpty then
      sb.AppendFormat('/instance/%s', [Options.Instance]);

    if length(Options.AdditionalLabels) > 0 then
      for var Pair: TPair<string, string> in Options.AdditionalLabels do begin
        if Pair.Key.IsEmpty or Pair.Value.IsEmpty then
          raise ENotSupportedException.Create(format('Invalid MetricPusher additional label: (%s):(%s)', [Pair.Key, Pair.Value]));

        sb.AppendFormat('/%s/%s', [Pair.Key, Pair.Value]);
      end;

    try
      FTargetUrl := TURI.Create(sb.ToString).ToString;
    except
      on E: Exception do
        raise EArgumentException.Create('Endpoint must be a valid url');
    end;
  finally
    sb.Free;
  end;

  FPushInterval := TTimeSpan.FromMilliseconds(Options.IntervalMs);
  FOnError      := Options.OnError;
end;

procedure TMetricPusher.HandleFailedPush(Ex: Exception);
begin
  if assigned(FOnError) then begin
    TTask.Run(procedure begin
      FOnError(Ex);
    end);
  end else begin
    //debug write
  end;
end;

function TMetricPusher.StartServer(Cancel: ICancellationToken): ITask;
begin
  // Kick off the actual processing to a new thread and return a Task for the processing thread.
  result := TTask.Run(procedure begin
    while true do begin
      // We schedule approximately at the configured interval. There may be some small accumulation for the
      // part of the loop we do not measure but it is close enough to be acceptable for all practical scenarios.
      var duration := TValueStopwatch.StartNew;

      try
        var HttpClient := FHttpClientProvider;

        var RequestStream   := TMemoryStream.Create;
        try
          TTask.WaitForAny(FRegistry.CollectAndExportAsTextAsync(RequestStream));

          var Response := HttpClient.Post(FTargetUrl, RequestStream, nil, FContentTypeHeaderValue);

          // If anything goes wrong, we want to get at least an entry in the trace log.
          if not Response.StatusCode = TCodes.OK then
            raise ENetHTTPRequestException.Create('HTTP response failed.');
        finally
          RequestStream.Free;
        end;

      except
        on E: EScrapeFailedException do begin
          // We do not consider failed scrapes a reportable error since the user code that raises the failure should be the one logging it.
          //trace
        end;
        on E: Exception do begin
          if not (E is EOperationCancelled) then
            HandleFailedPush(E);
        end;
      end;

      // We stop only after pushing metrics, to ensure that the latest state is flushed when told to stop.
      if Cancel.IsCancellationRequested then
        break;

      var SleepTime := FPushInterval - duration.GetElapsedTime;

      // Sleep until the interval elapses or the pusher is asked to shut down.
      if SleepTime > TTimeSpan.Zero then begin
        sleep(SleepTime.Milliseconds);
      end;

    end;
  end);
end;

{$ENDREGION}

{$REGION 'TMetricPusherOptions'}

class operator TMetricPusherOptions.Finalize(var Dest: TMetricPusherOptions);
begin
  Dest.Endpoint           := string.Empty;
  Dest.Job                := string.Empty;
  Dest.Instance           := string.Empty;
  Dest.IntervalMs         := 0;
  Dest.AdditionalLabels   := [];
  Dest.Registry           := nil;
  Dest.OnError            := nil;
  Dest.HttpClientProvider := nil;
end;

class operator TMetricPusherOptions.Initialize(out Dest: TMetricPusherOptions);
begin
  Dest.Endpoint           := string.Empty;
  Dest.Job                := string.Empty;
  Dest.Instance           := string.Empty;
  Dest.IntervalMs         := 1000;
  Dest.AdditionalLabels   := [];
  Dest.Registry           := nil;
  Dest.OnError            := nil;
  Dest.HttpClientProvider := nil;
end;

{$ENDREGION}

{$REGION 'TValueStopwatch'}

function TValueStopwatch.GetElapsedTime: TTimespan;
begin
  // Start timestamp can't be zero in an initialized ValueStopwatch. It would have to be literally the first thing executed when the machine boots to be 0.
  // So it being 0 is a clear indication of default(ValueStopwatch)
  if not IsActive then
    raise EInvalidOpException.Create('An uninitialized, or ''default'', ValueStopwatch cannot be used to get elapsed time.');


  var _end := TStopwatch.GetTimeStamp;
  var _TimestampDelta := _end - FStartTimestamp;
  var _ticks := trunc(FTimestampToTicks * _TimestampDelta);

  result := TTimeSpan.Create(_Ticks);
end;

class operator TValueStopwatch.Initialize(out Dest: TValueStopwatch);
begin
  Dest.FTimestampToTicks := TTimespan.TicksPerSecond / TStopwatch.Frequency;
  Dest.FStartTimestamp   := 0;
end;

function TValueStopwatch.IsActive: boolean;
begin
  result := FStartTimestamp <> 0;
end;

class function TValueStopwatch.StartNew: TValueStopwatch;
begin
  result.FStartTimestamp := TStopwatch.GetTimeStamp;
end;

{$ENDREGION}

end.
