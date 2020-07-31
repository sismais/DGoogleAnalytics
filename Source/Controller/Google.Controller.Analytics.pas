unit Google.Controller.Analytics;

interface

uses
  Google.Controller.Analytics.Interfaces,
  Google.Model.Analytics.Interfaces,
  System.DateUtils;

type
  TControllerGoogleAnalytics = Class(TInterfacedObject, iControllerGoogleAnalytics)
  private
    class var FInstance : TControllerGoogleAnalytics;

    FGooglePropertyID: String;
    FClienteID: String;
    FUserID: String;
    FSessionTimeOutMinutes : Integer;

    FSystemPlatform: String;
    FScreenResolution: String;

    FURL  : String;

    FAppInfo: iModelGoogleAppInfo;

    FSessionStartDateTime : TDateTime;

    function GuidCreate: string;
    function GetSystemPlatform: string;
    function GetScreenResolution: string;
    procedure ValidaDados;
    /// <summary> Checa se atingiu o "Tempo Limite da Sessão". Se sim, significa que a sssão foi encerrada de forma
    /// forçada pelo Google Analytics. Então, eu tenho que reenviar uma requisição de nova sessão
    /// </summary>
    procedure CheckSessionTimeOut;
  public
    constructor Create(AGooglePropertyID: String; AUserID: String = ''; ASessionTimeOutMinutes: Integer = 30);
    destructor Destroy; override;
    class function New(AGooglePropertyID: String; AUserID: String = ''; ASessionTimeOutMinutes: Integer = 30
      ): iControllerGoogleAnalytics;

    function GooglePropertyID: String; overload;
    function GooglePropertyID(Value: String): iControllerGoogleAnalytics; overload;
    function ClienteID: String; overload;
    function ClienteID(Value: String): iControllerGoogleAnalytics; overload;
    function UserID: String; overload;
    function UserID(Value: String): iControllerGoogleAnalytics; overload;

    /// <summary> Tempo Limite da Sessão (em minutos, tal como parametrizado no Google Analytics, padrão:
    /// 30 minutos </summary>
    function SessionTimeOutMinutes: Integer; overload;
    function SessionTimeOutMinutes(Value : Integer):  iControllerGoogleAnalytics; overload;

    function SystemPlatform: String;
    function ScreenResolution: String;

    function URL: String; overload;
    function URL(Value: String): iControllerGoogleAnalytics; overload;

    function AppInfo: iModelGoogleAppInfo;

    function Event(ACategory, AAction, ALabel: String; AValue: Integer = 0): iControllerGoogleAnalytics;
    function Exception(ADescription: String; AIsFatal: Boolean): iControllerGoogleAnalytics;
    function ScreenView(AScreenName: String): IControllerGoogleAnalytics;
    function PageView(ADocumentHostName, APage, ATitle: String): IControllerGoogleAnalytics;

    function StartSession: IControllerGoogleAnalytics;
    function EndSession: IControllerGoogleAnalytics;
  End;

implementation

uses
  Winapi.ActiveX,
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  System.Win.Registry,
  Vcl.Forms, Google.Model.Analytics.Factory, Google.Model.Analytics.Invoker;

{ TControllerGoogleAnalytics }

function TControllerGoogleAnalytics.AppInfo: iModelGoogleAppInfo;
begin
  Result  :=  FAppInfo;
end;

procedure TControllerGoogleAnalytics.CheckSessionTimeOut;
begin
  if MinutesBetween(Now, FSessionStartDateTime) >= FSessionTimeOutMinutes then
  begin
    Self.StartSession;
    FSessionStartDateTime := Now;
    Sleep(500); //Aguarda alguns instantes para garantir que o gogole recebeu e processou a requisição.
  end;
end;

function TControllerGoogleAnalytics.ClienteID(
  Value: String): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  FClienteID :=  Value;
end;

function TControllerGoogleAnalytics.ClienteID: String;
begin
  Result  :=  FClienteID;
end;

constructor TControllerGoogleAnalytics.Create(AGooglePropertyID: String; AUserID: String = '';
  ASessionTimeOutMinutes: Integer = 30);
begin
  FGooglePropertyID :=  AGooglePropertyID;
  FUserID :=  AUserID;

  FClienteID  :=  GuidCreate;

  FSessionTimeOutMinutes := ASessionTimeOutMinutes;
  FSessionStartDateTime := Now;

  FSystemPlatform  := GetSystemPlatform;
  FScreenResolution:=  GetScreenResolution;

  FURL    :=  'https://www.google-analytics.com/collect';

  FAppInfo  :=  TModelGoogleAnalyticsFactory.New.AppInfo;
end;

destructor TControllerGoogleAnalytics.Destroy;
begin
  Sleep(500); //apenas para resolver o problema com a memoria ao fecha o sistema
  inherited;
end;

function TControllerGoogleAnalytics.EndSession: IControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .Session(Self)
        .Operation(osEnd)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.Event(ACategory, AAction, ALabel: String; AValue: Integer = 0): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  CheckSessionTimeOut;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .Event(Self)
        .Category(ACategory)
        .Action(AAction)
        .EventLabel(ALabel)
        .EventValue(AValue)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.Exception(ADescription: String; AIsFatal: Boolean): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  CheckSessionTimeOut;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .Exception(Self)
        .Description(ADescription)
        .isFatal(AIsFatal)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.GetScreenResolution: string;
begin
  Result  :=  Screen.Width.Tostring + 'x' + Screen.Height.ToString;
end;

function TControllerGoogleAnalytics.GetSystemPlatform: string;
var
  Reg: TRegistry;
begin
  Result  :=  '';

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows NT\CurrentVersion') then
    begin
      Result := Format('%s - %s', [Reg.ReadString('ProductName'),
                                    Reg.ReadString('BuildLabEx')]);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

function TControllerGoogleAnalytics.GooglePropertyID(
  Value: String): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  FGooglePropertyID :=  Value;
end;

function TControllerGoogleAnalytics.GuidCreate: string;
var
  ID: TGUID;
begin
  Result := '';
  if CoCreateGuid(ID) = S_OK then
    Result := GUIDToString(ID);
end;

function TControllerGoogleAnalytics.GooglePropertyID: String;
begin
  Result  :=  FGooglePropertyID;
end;

class function TControllerGoogleAnalytics.New(AGooglePropertyID: String; AUserID: String = '';
  ASessionTimeOutMinutes: Integer = 30): iControllerGoogleAnalytics;
begin
  if not Assigned(FInstance) then
    FInstance := Self.Create(AGooglePropertyID, AUserID, ASessionTimeOutMinutes)
  else
    FInstance
      .GooglePropertyID(AGooglePropertyID)
      .UserID(AUserID)
      .SessionTimeOutMinutes(ASessionTimeOutMinutes);

  Result := FInstance;
end;

function TControllerGoogleAnalytics.PageView(ADocumentHostName, APage, ATitle: String): IControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  CheckSessionTimeOut;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .PageView(Self)
        .DocumentHostName(ADocumentHostName)
        .Page(APage)
        .Title(ATitle)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.ScreenResolution: String;
begin
  Result  :=  FScreenResolution;
end;

function TControllerGoogleAnalytics.ScreenView(AScreenName: String): IControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  CheckSessionTimeOut;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .ScreeView(Self)
        .ScreenName(AScreenName)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.SessionTimeOutMinutes(Value: Integer): iControllerGoogleAnalytics;
begin
  Result := Self;
  FSessionTimeOutMinutes := Value;
end;

function TControllerGoogleAnalytics.SessionTimeOutMinutes: Integer;
begin
  Result := FSessionTimeOutMinutes;
end;

function TControllerGoogleAnalytics.StartSession: IControllerGoogleAnalytics;
begin
  Result  :=  Self;

  ValidaDados;

  TModelGoogleAnalyticsInvoker.New
    .Add(TModelGoogleAnalyticsFactory.New
      .Session(Self)
        .Operation(osStart)
      .Send)
    .Execute;
end;

function TControllerGoogleAnalytics.SystemPlatform: String;
begin
  Result  :=  FSystemPlatform;
end;

function TControllerGoogleAnalytics.URL(
  Value: String): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  FURL  :=  Value;
end;

function TControllerGoogleAnalytics.URL: String;
begin
  Result  :=  FURL;
end;

function TControllerGoogleAnalytics.UserID(
  Value: String): iControllerGoogleAnalytics;
begin
  Result  :=  Self;

  FUserID :=  Value;
end;

procedure TControllerGoogleAnalytics.ValidaDados;
begin
  if Trim(FGooglePropertyID) = '' then
    raise System.SysUtils.Exception.Create('Google Property ID "TID" não informado!');
end;

function TControllerGoogleAnalytics.UserID: String;
begin
  Result  :=  FUserID;
end;

end.

