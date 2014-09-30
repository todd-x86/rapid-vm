program runtime;

uses
  Forms,
  Dialogs,
  SysUtils,
  Math,
  StackUnit in 'StackUnit.pas',
  ResEditor in 'ResEditor.pas',
  FMath in 'FMath.pas';

{$R *.res}

var
  stack: TStack;
  rc: TResourceEditor;
  text, endptr: PByte;

begin
  // Init
  stack := TStack.Create;

  // Load bytecode resource (i.e. "CODE" resource 101)
  rc := TResourceEditor.Create(ParamStr(0));
  text := rc.Load('CODE', 101);
  if (text = nil) then begin
    ShowMessage('Runtime does not contain runnable code');
    Exit;
  end;
  endptr := PByte(Cardinal(text) + rc.Size('CODE', 101));

  // Bytecode interpreter
  // NOTE: Bytecode reader conditional needs to be optimized into jump table
  while Cardinal(text) < Cardinal(endptr) do begin
    if text^ = $00 then begin
      // add
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(stack.PopInt + stack.PopInt);
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(stack.PopFloat + stack.PopFloat);
      end;
    end else if text^ = $01 then begin
      // sub
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(-stack.PopInt + stack.PopInt);
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(-stack.PopFloat + stack.PopFloat);
      end;
    end else if text^ = $02 then begin
      // mul
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(stack.PopInt * stack.PopInt);
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(stack.PopFloat * stack.PopFloat);
      end;
    end else if text^ = $03 then begin
      // div
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(stack.PopInt div stack.PopInt);
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(stack.PopFloat / stack.PopFloat);
      end;
    end else if text^ = $04 then begin
      // mod
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(stack.PopInt mod stack.PopInt);
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(fMod(stack.PopFloat, stack.PopFloat));
      end;
    end else if text^ = $05 then begin
      // pow
      Inc(text);
      if stack.PeekType = 0 then begin
        stack.PushInt(Trunc(Power(stack.PopInt, stack.PopInt)));
      end else if stack.PeekType = 1 then begin
        stack.PushFloat(Power(stack.PopFloat, stack.PopFloat));
      end;
    end else if text^ = $06 then begin
      // push [int]
      Inc(text);
      stack.PushInt(Integer(text^));
      Inc(text, sizeof(Integer));
    end else if text^ = $07 then begin
      // push [float]
      Inc(text);
      stack.PushFloat(PSingle(text)^);
      Inc(text, sizeof(Single));
    end;
  end;
  ShowMessage(IntToStr(stack.PopInt));
end.
