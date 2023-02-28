program TestServer;

uses
  System.StartUpCopy,
  FMX.Forms,
  View.Main in 'View.Main.pas' {FormMain},
  Prometheus.DelphiStats in '..\..\source\Prometheus.DelphiStats.pas',
  Prometheus.Metrics in '..\..\source\Prometheus.Metrics.pas',
  Prometheus.Server in '..\..\source\Prometheus.Server.pas',
  Prometheus.Server.Pusher in '..\..\source\Prometheus.Server.Pusher.pas',
  Prometheus.Server.Exporter in '..\..\source\Prometheus.Server.Exporter.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
