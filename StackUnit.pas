unit StackUnit;

interface

uses Classes, SysUtils, Dialogs;

type
  TStackObj = packed record
    case ObjType: Byte of
      0: (IntVal: Integer);
      1: (FloatVal: Single);
      2: (StringVal: PChar);
      3: (AddrVal: Cardinal);
  end;

  PStackObj = ^TStackObj;

  TStack = class(TObject)
  protected
    FCapacity: Cardinal;
    FStackPtr: array of TStackObj;
    FTop: PStackObj;
    FFreeze: PStackObj;

    procedure TopUp;
    procedure TopDown;
    procedure Resize;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Freeze;
    procedure Unfreeze;
    procedure Pop;
    function PeekType: Byte;
    function PopInt: Integer;
    function PopFloat: Single;
    function PopStr: PChar;        
    function PopAddr: Cardinal;
    procedure PushFloat (f: Single);
    procedure PushInt (i: Integer);
    procedure PushStr (s: PChar);  
    procedure PushAddr (a: Cardinal);
  end;

implementation

constructor TStack.Create;
begin
  inherited Create;
  FCapacity := 64;
  FFreeze := nil;
  Resize;
  FTop := Addr(FStackPtr[0]);
end;

destructor TStack.Destroy;
begin
  inherited Destroy;
end;

procedure TStack.Pop;
begin
  TopDown;
end;

procedure TStack.Resize;
begin
  SetLength(FStackPtr, FCapacity);
end;

function TStack.PopInt: Integer;
begin
  TopDown;
  Assert(FTop^.ObjType = 0);
  Result := FTop^.IntVal;
end;

function TStack.PopFloat: Single;
begin
  TopDown;
  Assert(FTop^.ObjType = 1);
  Result := FTop^.FloatVal;
end;

function TStack.PopStr: PChar;
begin
  TopDown;
  Assert(FTop^.ObjType = 2);
  Result := FTop^.StringVal;
end;

function TStack.PopAddr: Cardinal;
begin
  TopDown;
  Assert(FTop^.ObjType = 3);
  Result := FTop^.AddrVal;
end;

procedure TStack.PushFloat (f: Single);
begin
  FTop^.ObjType := 1;
  FTop^.FloatVal := f;
  TopUp;
end;

procedure TStack.PushInt (i: Integer);
begin
  FTop^.ObjType := 0;
  FTop^.IntVal := i;
  TopUp;
end;

procedure TStack.PushStr (s: PChar);
begin
  FTop^.ObjType := 2;
  FTop^.StringVal := s;
  TopUp;
end;

procedure TStack.PushAddr (a: Cardinal);
begin
  FTop^.ObjType := 3;
  FTop^.AddrVal := a;
  TopUp;
end;

procedure TStack.TopUp;
var diff: Cardinal;
begin
  Inc(FFreeze, Sizeof(TStackObj));
  Inc(FTop, Sizeof(TStackObj));
  diff := Cardinal(Addr(FTop^)) - Cardinal(Addr(FStackPtr));
  if (diff div Sizeof(TStackObj)) >= FCapacity then begin
    FCapacity := Trunc(FCapacity * 1.5);
    Resize;
  end;
end;

function TStack.PeekType: Byte;
var ptr: PStackObj;
begin
  ptr := PStackObj(Cardinal(FTop)-Sizeof(TStackObj));
  Result := ptr^.ObjType;
end;

procedure TStack.TopDown;
begin
  Dec(FTop, Sizeof(TStackObj));
end;

procedure TStack.Freeze;
begin
  FFreeze := FTop;
end;

procedure TStack.Unfreeze;
begin
  Assert(FFreeze <> nil);
  FTop := FFreeze;
end;

end.
