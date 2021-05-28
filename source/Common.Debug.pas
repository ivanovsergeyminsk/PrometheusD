unit Common.Debug;

interface

type
  TDebug = class
    class procedure WriteLine(const Msg: string); static;
  end;

implementation

uses
  Common.DateTime.Helper,
  System.SysUtils,
  Winapi.Windows;

{$REGION 'TDebug'}

class procedure TDebug.WriteLine(const Msg: string);
{$IFDEF DEBUG}
var
  LMsg: string;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  LMsg := format('[<%s> %s] ', [Now.ToString('hh:mm:ss:zzz'), Msg]);
  OutputDebugString(PChar(LMsg));
  {$ENDIF}
end;

{$ENDREGION}

end.
