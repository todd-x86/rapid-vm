unit ResEditor;

interface

uses Windows, SysUtils;

type
  TResourceEditor = class(TObject)
  protected
    FFile: TFileName;
  public
    constructor Create (const Filename: TFileName);
    destructor Destroy; override;
    function Update (Section: String; ResId: Integer; Buf: Pointer; Size: Cardinal): Boolean;
    function Load (Section: String; ResId: Integer): Pointer;
    function Size (Section: String; ResId: Integer): Cardinal;
  end;

implementation

constructor TResourceEditor.Create (const Filename: TFileName);
begin
  inherited Create;
  FFile := Filename;
end;

destructor TResourceEditor.Destroy;
begin
  inherited Destroy;
end;

function TResourceEditor.Update (Section: String; ResId: Integer; Buf: Pointer; Size: Cardinal): Boolean;
var h: HWND;
begin
  h := BeginUpdateResource(PAnsiChar(FFile), false);
  Result := UpdateResource(h, PAnsiChar(Section), MAKEINTRESOURCE(ResId), 0, Buf, Size);
  EndUpdateResource(h, false);
end;

function TResourceEditor.Load (Section: String; ResId: Integer): Pointer;
var mHnd, resHnd: HWND;
begin
  mHnd := GetModuleHandle(PAnsiChar(ParamStr(0)));
  resHnd := FindResource(mHnd, MAKEINTRESOURCE(ResId), PAnsiChar(Section));
  Result := Pointer(LoadResource(mHnd, resHnd));
end;

function TResourceEditor.Size (Section: String; ResId: Integer): Cardinal;
var mHnd, resHnd: HWND;
begin
  mHnd := GetModuleHandle(PAnsiChar(ParamStr(0)));
  resHnd := FindResource(mHnd, MAKEINTRESOURCE(ResId), PAnsiChar(Section));
  Result := SizeofResource(mHnd, resHnd);
end;

end.
