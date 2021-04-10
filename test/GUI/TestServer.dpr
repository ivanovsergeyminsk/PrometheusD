program TestServer;

uses
  System.StartUpCopy,
  FMX.Forms,
  View.Main in 'View.Main.pas' {FormMain},
  Prometheus.DelphiStats in '..\..\source\Prometheus.DelphiStats.pas',
  Prometheus.Metrics in '..\..\source\Prometheus.Metrics.pas',
  Prometheus.Servers in '..\..\source\Prometheus.Servers.pas',
  Common.BitConverter in '..\..\source\Common.BitConverter.pas',
  Common.DateTime.Helper in '..\..\source\Common.DateTime.Helper.pas',
  Common.Debug in '..\..\source\Common.Debug.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
