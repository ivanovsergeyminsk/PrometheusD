unit Prometheus.Server;

interface

uses
    Prometheus.Metrics
  , System.Threading
  , System.SysUtils
  ;

type
  ICancellationToken = interface;
  IMetricServer     = interface;

  EScrapeFailedException = class(Exception);

  /// <summary>
  /// A metric server exposes a Prometheus metric exporter endpoint in the background,
  /// operating independently and serving metrics until it is instructed to stop.
  /// </summary>
  IMetricServer = interface
  ['{EAA30FB0-7FB9-4907-A768-846E9C8F3488}']
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

  {$REGION 'TCodes'}
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

implementation

uses
    System.Classes
  , System.SyncObjs
  ;

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
      {$IFDEF DEBUG}
      TThread.Current.NameThreadForDebugging('TMetricHandler.StopAsync');
      {$ENDIF}
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
        {$IFDEF DEBUG}
        TThread.Current.NameThreadForDebugging('-');
        {$ENDIF}
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

end.
