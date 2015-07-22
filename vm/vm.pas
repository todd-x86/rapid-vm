unit vm;

interface

uses Classes, SysUtils, Dialogs, StdCtrls, Forms, Contnrs;

type
  TPointerArray = array of Pointer;
  TOpCodeProc = procedure(var Ptr: PByte);
  TStackFrame = class(TObject)
    Return: PByte;
    constructor Create(const Return: PByte);
  end;
  TCallback = class(TObject)
    Offset: Cardinal;
    constructor Create(const Offset: Cardinal);
    procedure OnEvent(Sender: TObject);
  end;

  { Var Types }
  // Used for identifying types
  // NOTE: ALL TYPES MUST BEGIN WITH 1-BYTE TYPE IDENTIFIER
  TVarType = packed record
    TypeId: Byte;
  end;
  PVarType = ^TVarType;

  TVarLabel = packed record
    TypeId: Byte;
    Offset: Cardinal;
  end;
  PVarLabel = ^TVarLabel;
  TVarWindow = packed record
    TypeId: Byte;
    Form: TForm;
  end;
  PVarWindow = ^TVarWindow;
  TVarInteger = packed record
    TypeId: Byte;
    Value: Integer;
  end;
  PVarInteger = ^TVarInteger;
  TVarString = packed record
    TypeId: Byte;
    StringIndex: Cardinal;
  end;
  PVarString = ^TVarString;
  TVarButton = packed record
    TypeId: Byte;
    Button: TButton;
  end;
  PVarButton = ^TVarButton;

procedure InitVM (const StartPtr, EndPtr: PByte);
procedure InitOpTable;
procedure Error(const Msg: String);
procedure AssignLabel(const VarPtr: Pointer; const Offset: Cardinal);
function AllocVar(const Index, Mem: Integer): Pointer;
function ReadString(var Ptr: PByte): String;
function ReadByte(var Ptr: PByte): Byte;
function ReadCardinal(var Ptr: PByte): Cardinal;
function ReadInteger(var Ptr: PByte): Integer;
procedure ImportResources(const StartPtr, EndPtr: PByte);
procedure FreeVar(const Index: Integer);
procedure ProcessOpCode(var Ptr: PByte);
function ReadTypeIdent(var Ptr: PByte): Cardinal;
function ReadStrIdent(var Ptr: PByte): String;
function ReadIntIdent(var Ptr: PByte): Integer;
function StringVar(const Index: Cardinal): String;
function IntVar(const Index: Cardinal): Integer;
function GetCallback(const LabelId: Cardinal): TNotifyEvent;
procedure Execute(const Ptr: PByte);
procedure ExecuteUntilReturn(const Ptr: PByte);

{ VM Byte-code operations - for OpTable use }
procedure Op_WindowCreate(var Ptr: PByte);
procedure Op_WindowSetTitle(var Ptr: PByte);
procedure Op_IntCreate(var Ptr: PByte);
procedure Op_IntAdd(var Ptr: PByte);
procedure Op_IntSet(var Ptr: PByte);
procedure Op_ButtonCreate(var Ptr: PByte);
procedure Op_ButtonSetParent(var Ptr: PByte);
procedure Op_ButtonSetText(var Ptr: PByte);
procedure Op_ButtonSetOnClick(var Ptr: PByte);
procedure Op_StringCreate(var Ptr: PByte);
procedure Op_StringConcat(var Ptr: PByte);
procedure Op_ConvertIntStr(var Ptr: PByte);
procedure Op_AppRun(var Ptr: PByte);
procedure Op_Return(var Ptr: PByte);

implementation

var
  StrTable: TStringList;
  VarTable: TPointerArray;
  StrVars: TStringList;
  OpTable: array[$00..$0D] of TOpCodeProc;
  app: TApplication;
  FirstForm: Boolean;
  FuncStack: TObjectList;
  EventHandlers: TObjectList;
  // TODO: set VM_Start and VM_End
  VM_Start, VM_End, VM_Op: PByte;

const
  // Language type identifiers (used in identifying types that vary)
  TID_VAR = $00;
  TID_INT = $01;
  TID_STRING = $02;

  // Resource identifiers (prefaced before each resource block)
  RES_STRING = $00;
  RES_LABEL = $01;

  // Internal type identifiers (for VM purposes)
  TYPE_LABEL = $00;
  TYPE_WINDOW = $01;
  TYPE_INT = $02;
  TYPE_STRING = $03;
  TYPE_BUTTON = $04;

  // Opcodes
  OP_WIN_CREATE = $00;
  OP_WIN_SETTITLE = $01;
  OP_INT_CREATE = $02;
  OP_INT_ADD = $03;
  OP_INT_SET = $04;
  OP_BTN_CREATE = $05;
  OP_BTN_SETPARENT = $06;
  OP_BTN_SETTEXT = $07;
  OP_BTN_SETONCLICK = $08;
  OP_STR_CREATE = $09;
  OP_STR_CONCAT = $0A;
  OP_CONV_INTSTR = $0B;
  OP_APP_RUN = $0C;
  OP_FLOW_RETURN = $0D;

constructor TStackFrame.Create(const Return: PByte);
begin
  Self.Return := Return;
end;

constructor TCallback.Create(const Offset: Cardinal);
begin
  Self.Offset := Offset;
end;

procedure TCallback.OnEvent(Sender: TObject);
var p: PByte;
begin
  FuncStack.Add(TStackFrame.Create(VM_Op));
  p := PByte(Cardinal(VM_Start) + Offset);
  ExecuteUntilReturn(p);
end;

procedure Execute(const Ptr: PByte);
begin
  VM_Op := Ptr;
  while (Cardinal(VM_Op) < Cardinal(VM_End)) do begin
    ProcessOpCode(VM_Op);
  end;
end;

procedure ExecuteUntilReturn(const Ptr: PByte);
begin
  VM_Op := Ptr;
  while (VM_Op^ <> OP_FLOW_RETURN) and (Cardinal(VM_Op) < Cardinal(VM_End)) do begin
    ProcessOpCode(VM_Op);
  end;
  // Manually skip return and call return protocol
  Inc(VM_Op, Sizeof(Byte));
  Op_Return(VM_Op);
end;

procedure InitOpTable;
begin
  OpTable[OP_WIN_CREATE] := Op_WindowCreate;
  OpTable[OP_WIN_SETTITLE] := Op_WindowSetTitle;
  OpTable[OP_INT_CREATE] := Op_IntCreate;
  OpTable[OP_INT_ADD] := Op_IntAdd;
  OpTable[OP_INT_SET] := Op_IntSet;
  OpTable[OP_BTN_CREATE] := Op_ButtonCreate;
  OpTable[OP_BTN_SETPARENT] := Op_ButtonSetParent;
  OpTable[OP_BTN_SETTEXT] := Op_ButtonSetText;
  OpTable[OP_BTN_SETONCLICK] := Op_ButtonSetOnClick;
  OpTable[OP_STR_CREATE] := Op_StringCreate;
  OpTable[OP_STR_CONCAT] := Op_StringConcat;
  OpTable[OP_CONV_INTSTR] := Op_ConvertIntStr;
  OpTable[OP_APP_RUN] := Op_AppRun;
  OpTable[OP_FLOW_RETURN] := Op_Return;
end;

procedure InitVM (const StartPtr, EndPtr: PByte);
begin
  VM_Start := StartPtr;
  VM_End := EndPtr;
  VM_Op := VM_Start;
end;

function GetCallback(const LabelId: Cardinal): TNotifyEvent;
var offset: Cardinal;
    c: TCallback;
begin
  offset := PVarLabel(VarTable[LabelId])^.Offset;
  c := TCallback.Create(offset);
  EventHandlers.Add(c);
  Result := c.OnEvent;
end;

procedure ProcessOpCode(var Ptr: PByte);
var op: Byte;
begin
  op := ReadByte(Ptr);
  if (op > High(OpTable)) then Error(Format('Invalid opcode [%x]', [op]));
  OpTable[op](Ptr);
end;

procedure Op_WindowCreate(var Ptr: PByte);
var Index: Cardinal;
    w: PVarWindow;
begin
  Index := ReadTypeIdent(Ptr);
  w := AllocVar(Index, Sizeof(TVarWindow));
  w^.TypeId := TYPE_WINDOW;
  if FirstForm then
    Application.CreateForm(TForm, w^.Form)
  else w^.Form := TForm.Create(nil);
  FirstForm := false;
end;

procedure Op_WindowSetTitle(var Ptr: PByte);
var Index: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  PVarWindow(VarTable[Index])^.Form.Caption := ReadStrIdent(Ptr);
end;

procedure Op_IntCreate(var Ptr: PByte);
var Index: Cardinal;
    i: PVarInteger;
begin
  Index := ReadTypeIdent(Ptr);
  i := AllocVar(Index, Sizeof(TVarInteger));
  i^.TypeId := TYPE_INT;
  i^.Value := 0;
end;

procedure Op_IntAdd(var Ptr: PByte);
var Index: Cardinal;
    i: PVarInteger;
begin
  Index := ReadTypeIdent(Ptr);
  i := PVarInteger(VarTable[Index]);
  i^.Value := i^.Value + ReadIntIdent(Ptr);
end;

procedure Op_IntSet(var Ptr: PByte);
var Index: Cardinal;
    i: PVarInteger;
begin
  Index := ReadTypeIdent(Ptr);
  i := PVarInteger(VarTable[Index]);
  i^.Value := ReadIntIdent(Ptr);
end;

procedure Op_ButtonCreate(var Ptr: PByte);
var b: PVarButton;
    Index: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  b := AllocVar(Index, Sizeof(TVarButton));
  b^.TypeId := TYPE_BUTTON;
  b^.Button := TButton.Create(nil);
end;

procedure Op_ButtonSetParent(var Ptr: PByte);
var b: PVarButton;
    Index, ParentId: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  ParentId := ReadTypeIdent(Ptr);
  b := PVarButton(VarTable[Index]);
  b^.Button.Parent := PVarWindow(VarTable[ParentId])^.Form;
end;

procedure Op_ButtonSetText(var Ptr: PByte);
var b: PVarButton;
    Index: Cardinal;
    Text: String;
begin
  Index := ReadTypeIdent(Ptr);
  Text := ReadStrIdent(Ptr);
  b := PVarButton(VarTable[Index]);
  b^.Button.Caption := Text;
end;

procedure Op_ButtonSetOnClick(var Ptr: PByte);
var b: PVarButton;
    Index, ExecOffsetId: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  ExecOffsetId := ReadTypeIdent(Ptr);
  b := PVarButton(VarTable[Index]);
  b^.Button.OnClick := GetCallback(ExecOffsetId);
end;

procedure Op_StringCreate(var Ptr: PByte);
var s: PVarString;
    value: String;
    Index: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  s := AllocVar(Index, Sizeof(TVarString));
  value := ReadStrIdent(Ptr);
  s^.TypeId := TYPE_STRING;
  s^.StringIndex := StrVars.Add(value);
end;

procedure Op_StringConcat(var Ptr: PByte);
var s: PVarString;
    partB: String;
    Index: Cardinal;
begin
  Index := ReadTypeIdent(Ptr);
  s := PVarString(VarTable[Index]);
  partB := ReadStrIdent(Ptr);
  if s^.TypeId <> TYPE_STRING then
    Error('Cannot concat non-string type');
  StrVars[s^.StringIndex] := StrVars[s^.StringIndex] + partB;
end;

procedure Op_ConvertIntStr(var Ptr: PByte);
var v: Integer;
    idx: Cardinal;
    s: PVarString;
    outValue: String;
begin
  v := ReadIntIdent(Ptr);
  idx := ReadTypeIdent(Ptr);

  outValue := IntToStr(v);
  s := AllocVar(idx, Sizeof(TVarString));
  s^.TypeId := TYPE_STRING;
  s^.StringIndex := StrVars.Add(outValue);
end;

procedure Op_AppRun(var Ptr: PByte);
var Id: Cardinal;
begin
  Id := ReadTypeIdent(Ptr);
  // TODO: app.CreateForm from ID
  app.Run;
end;

procedure Op_Return(var Ptr: PByte);
begin
  if (FuncStack.Count < 1) then Error('Stack is empty');
  Ptr := (FuncStack.Last as TStackFrame).Return;
  FuncStack.Delete(FuncStack.Count-1);
end;

function ReadTypeIdent(var Ptr: PByte): Cardinal;
begin
  if ReadByte(Ptr) <> TID_VAR then Error('Langtype var was expected');
  Result := ReadCardinal(Ptr);
end;

function ReadStrIdent(var Ptr: PByte): String;
var bType: Byte;
begin
  bType := ReadByte(Ptr);
  if bType = TID_VAR then begin
    Result := StringVar(ReadCardinal(Ptr));
  end else if bType = TID_STRING then begin
    Result := StrTable[ReadCardinal(Ptr)];
  end else Error('Langtype string or identifier expected');
end;

function ReadIntIdent(var Ptr: PByte): Integer;
var bType: Byte;
begin
  bType := ReadByte(Ptr);
  if bType = TID_VAR then begin
    Result := IntVar(ReadCardinal(Ptr));
  end else if bType = TID_INT then begin
    Result := ReadInteger(Ptr);
  end else Error('Langtype integer or identifier expected');
end;

function StringVar(const Index: Cardinal): String;
begin
  if PVarString(VarTable[Index])^.TypeId <> TYPE_STRING then
    Error('Identifier does not match a string type');
  Result := StrVars[PVarString(VarTable[Index])^.StringIndex];
end;

function IntVar(const Index: Cardinal): Integer;
begin
  if PVarInteger(VarTable[Index])^.TypeId <> TYPE_INT then
    Error('Identifier does not match an integer type');
  Result := PVarInteger(VarTable[Index])^.Value;
end;

procedure Error(const Msg: String);
begin
  MessageDlg(Format('ERROR: %s', [Msg]), mtError, [mbOK], 0);
  Halt;
end;

procedure AssignLabel(const VarPtr: Pointer; const Offset: Cardinal);
begin
  PVarLabel(VarPtr)^.TypeId := TYPE_LABEL;
  PVarLabel(VarPtr)^.Offset := Offset;
end;

procedure FreeVar(const Index: Integer);
begin
  if VarTable[Index] = nil then Exit;
  case PVarType(VarTable[Index])^.TypeId of
    TYPE_LABEL, TYPE_INT:
    begin
      // Skip
    end;
    TYPE_STRING:
    begin
      // Free up memory to string mem manager
      StrVars[PVarString(VarTable[Index])^.StringIndex] := '';
    end;
    TYPE_WINDOW:
    begin
      PVarWindow(VarTable[Index])^.Form.Free;
    end;
    TYPE_BUTTON:
    begin
      PVarButton(VarTable[Index])^.Button.Free;
    end;
    else Error(Format('Invalid var type freed [%d]', [PVarType(VarTable[Index])^.TypeId]));
  end;
  FreeMem(VarTable[Index]);
  VarTable[Index] := nil;
end;

function AllocVar(const Index, Mem: Integer): Pointer;
begin
  if VarTable[Index] <> nil then FreeVar(Index);
  GetMem(VarTable[Index], Mem);
  Result := VarTable[Index];
end;

function ReadInteger(var Ptr: PByte): Integer;
begin
  Result := Integer(Ptr^);
  Inc(Ptr, Sizeof(Integer));
end;

function ReadCardinal(var Ptr: PByte): Cardinal;
begin
  Result := Cardinal(Ptr^);
  Inc(Ptr, Sizeof(Cardinal));
end;

function ReadByte(var Ptr: PByte): Byte;
begin
  Result := Ptr^;
  Inc(Ptr, Sizeof(Byte));
end;

function ReadString(var Ptr: PByte): String;
var len: Cardinal;
    j: Integer;
begin
  len := ReadCardinal(Ptr);
  SetLength(Result, len);
  j := 1;
  while j <= len do begin
    Result[j] := Chr(ReadByte(Ptr));
    Inc(j);
  end;
end;

procedure ImportResources(const StartPtr, EndPtr: PByte);
var p: PByte;
    c: Cardinal;
    j: Integer;
    resType: Byte;
begin
  app := Application;
  app.Initialize;
  FirstForm := true;

  StrVars := TStringList.Create;
  FuncStack := TObjectList.Create(True);
  EventHandlers := TObjectList.Create(True);

  p := StartPtr;

  // String table init
  StrTable := TStringList.Create;

  // 4-byte identifier table size
  c := ReadCardinal(p);
  GetMem(VarTable, Sizeof(Pointer)*c);
  // Initialize identifier table to null
  j := 0;
  while j < c do begin
    VarTable[j] := nil;
    Inc(j);
  end;

  // Read resources by type
  while (Cardinal(p) < Cardinal(EndPtr)) do begin
    resType := ReadByte(p);
    case resType of
      // String type (4-bytes length) + (data)
      RES_STRING:
      begin
        StrTable.Add(ReadString(p));
      end;
      // Label type (4-bytes index) + (4-bytes opcode offset)
      RES_LABEL:
      begin
        AssignLabel(AllocVar(ReadCardinal(p), sizeof(TVarLabel)), ReadCardinal(p));
      end;
      else begin
        Error(Format('Invalid resource type (%x)', [resType]));
      end;
    end;
  end;
end;

end.
