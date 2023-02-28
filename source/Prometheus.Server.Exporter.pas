unit Prometheus.Server.Exporter;

interface

uses
    Prometheus.Metrics
  , Prometheus.Server
  , System.SysUtils
  , System.Threading
  , IdHTTPServer
  , IdContext
  , IdCustomHTTPServer
  ;

type
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

implementation

uses
    System.StrUtils
  , System.Classes
  ;

type TOpenMetrics = class(TMetrics);

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

end.
