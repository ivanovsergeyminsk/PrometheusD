unit Prometheus.Server.Pusher;

interface

uses
    Prometheus.Metrics
  , Prometheus.Server
  , System.SysUtils
  , System.TimeSpan
  , System.Generics.Collections
  , System.Threading
  , System.Net.HttpClient
  , System.Net.URLClient
  ;

type
  TMetricPusher = class;

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

implementation

uses
    System.StrUtils
  , System.Classes
  , System.Diagnostics
  ;

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

end.
