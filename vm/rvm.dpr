program rvm;

uses
  Classes,
  Dialogs,
  SysUtils,
  vm in 'vm.pas';

{$R *.res}

var
  Data, OpPtr, ResPtr, OpEnd, ResEnd: PByte;
  Size: Cardinal;
  FIn: TFileStream;

begin
  FIn := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyNone);
  GetMem(Data, FIn.Size-4);
  Size := FIn.Size-4;
  FIn.Read(Data^, FIn.Size-4);
  FIn.Read(ResPtr, 4);
  FIn.Free;

  InitOpTable;

  // Increase ResPtr to Data start offset
  Inc(ResPtr, Cardinal(Data));
  ResEnd := Data;
  Inc(ResEnd, Size);
  
  OpPtr := Data;
  OpEnd := ResPtr;

  ImportResources(ResPtr, ResEnd);

  InitVM(Data, OpEnd);

  Execute(OpPtr);
  FreeMem(Data);
end.
