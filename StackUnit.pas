unit StackUnit;

interface

uses Classes, SysUtils, Dialogs;

type
  TStackObj = packed record
    case ObjType: Byte of
      0: (IntVal: Integer);
      1: (FloatVal: Single);
  end;

  PStackObj = ^TStackObj;

  TStack = class(TObject)
  protected
    FCapacity: Cardinal;
    FStackPtr: array of TStackObj;
    FTop: PStackObj;

    procedure TopUp;
    procedure TopDown;
    procedure Resize;
  public
    constructor Create;
    destructor Destroy; override;

    function PeekType: Byte;
    function PopInt: Integer;
    function PopFloat: Single;
    procedure PushFloat (f: Single);
    procedure PushInt (i: Integer);
  end;

implementation

constructor TStack.Create;
begin
  inherited Create;
  FCapacity := 64;
  Resize;
  FTop := Addr(FStackPtr[0]);
end;

destructor TStack.Destroy;
begin
  inherited Destroy;
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

procedure TStack.TopUp;
var diff: Cardinal;
begin
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

end.
