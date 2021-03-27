unit Prometheus.Servers;

interface
uses
  System.Threading,
  System.SysUtils,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,

  Prometheus.Metrics
  ;

type
  ICancellationToken = interface;

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
  System.SyncObjs
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
  TInterlocked.Read(LValue);
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
        result := AResponseInfo.ContentStream;
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
  result := TTask.Run(
    procedure begin
      FCancel := Cancel;
      try
        try
          FHttpListener.Active := true;
          while not FCancel.IsCancellationRequested do begin
            sleep(100);
          end;
        except
          { TODO -cTLog : Log error }
        end;
      finally
        FHttpListener.Active := false;
        FCancel := nil;
      end;
    end
  );
end;

{$ENDREGION}

end.
