program rvm;

uses
  Classes,
  Dialogs,
  SysUtils,
  Forms;

{$R *.res}

type
  TPointerArray = array of Pointer;
  PForm = ^TForm;

var
  FirstForm: Boolean;
  Ops, OpPtr, OpEnd: PByte;
  VarCount, Size: Cardinal;
  FIn: TFileStream;
  Vars: Pointer;
  app: TApplication;

procedure ProcessOpCode;
var idx: Cardinal;
begin
  case OpPtr^ of
    $01: // window create, @id
    begin
      Inc(OpPtr);
      idx := Cardinal(OpPtr^);
      Inc(OpPtr, Sizeof(Cardinal));
      New(PForm(TPointerArray(Vars)[idx]));
      if FirstForm then
        app.CreateForm(TForm, PForm(TPointerArray(Vars)[idx])^)
      else begin
        PForm(TPointerArray(Vars)[idx])^ := TForm.Create(nil);
        PForm(TPointerArray(Vars)[idx])^.Show;
      end;
      FirstForm := false;
    end;
    else begin
      MessageDlg(Format('ERROR: Invalid opcode (0x%x)', [OpPtr^]), mtError, [mbOK], 0);
      Halt;
    end;
  end;
end;

begin
  FirstForm := True;
  FIn := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyNone);
  GetMem(Ops, FIn.Size-4);
  Size := FIn.Size-4;
  FIn.Read(Ops^, FIn.Size-Sizeof(Cardinal));
  FIn.Read(VarCount, Sizeof(Cardinal));
  FIn.Free;

  GetMem(Vars, Sizeof(Pointer)*VarCount);

  OpPtr := Ops;
  OpEnd := Pointer(Cardinal(Ops) + Size);

  app := Application;
  app.Initialize;
  while (Cardinal(OpPtr) < Cardinal(OpEnd)) do begin
    ProcessOpCode;
  end;
  app.Run;
  app := nil;

  FreeMem(Ops);
  //FreeMem(Vars);
end.
