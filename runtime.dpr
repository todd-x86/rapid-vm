program runtime;

uses
  Forms,
  Dialogs,
  SysUtils,
  Math,
  Windows,
  Classes,
  Contnrs,
  StackUnit in 'StackUnit.pas',
  ResEditor in 'ResEditor.pas',
  FMath in 'FMath.pas',
  Structs in 'Structs.pas';

{$R *.res}

procedure Kill (const Msg: String);
begin
  MessageDlg(Msg, mtError, [mbOK], 0);
  Halt;
end;

var
  stack: TStack;
  rc: TResourceEditor;
  text, startptr, endptr: PByte;
  stringptr: PByte;  // string table
  procptrs: TObjectList;   // external DLL proc table

  tmpProcPtr: TProcPtr;

begin
  // Init
  stack := TStack.Create;
  procptrs := TObjectList.Create(True);

  // Load bytecode resource (i.e. "CODE" resource 101)
  rc := TResourceEditor.Create(ParamStr(0));
  text := rc.Load('CODE', 101);
  if (text = nil) then begin
    ShowMessage('Runtime does not contain runnable code');
    Exit;
  end;

  // Load string table ('\0' separated)
  stringptr := rc.Load('CODE', 102);

  // TODO: Load proc table from resource

  startptr := text;
  endptr := PByte(Cardinal(text) + rc.Size('CODE', 101));

  // Bytecode interpreter
  // NOTE: Bytecode reader conditional needs to be optimized into jump table
  while Cardinal(text) < Cardinal(endptr) do begin
    case text^ of
      $00:
      begin
        // add
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(stack.PopInt + stack.PopInt);
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(stack.PopFloat + stack.PopFloat);
        end else if stack.PeekType = 3 then begin
          stack.PushAddr(stack.PopAddr + stack.PopAddr);
        end;
      end;
      $01:
      begin
        // sub
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(stack.PopInt - stack.PopInt);
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(stack.PopFloat - stack.PopFloat);
        end else if stack.PeekType = 3 then begin
          stack.PushAddr(stack.PopAddr - stack.PopAddr);
        end;
      end;
      $02:
      begin
        // mul
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(stack.PopInt * stack.PopInt);
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(stack.PopFloat * stack.PopFloat);
        end;
      end;
      $03:
      begin
        // div
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(stack.PopInt div stack.PopInt);
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(stack.PopFloat / stack.PopFloat);
        end;
      end;
      $04:
      begin
        // mod
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(stack.PopInt mod stack.PopInt);
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(fMod(stack.PopFloat, stack.PopFloat));
        end;
      end;
      $05:
      begin
        // pow
        Inc(text);
        if stack.PeekType = 0 then begin
          stack.PushInt(Trunc(Power(stack.PopInt, stack.PopInt)));
        end else if stack.PeekType = 1 then begin
          stack.PushFloat(Power(stack.PopFloat, stack.PopFloat));
        end;
      end;
      $06:
      begin
        // push [int]
        Inc(text);
        stack.PushInt(Integer(text^));
        Inc(text, sizeof(Integer));
      end;
      $07:
      begin
        // push [float]
        Inc(text);
        stack.PushFloat(PSingle(text)^);
        Inc(text, sizeof(Single));
      end;
      $08:
      begin
        // pop
        Inc(text);
        stack.Pop;
      end;
      $09:
      begin
        // and
        Inc(text);
        stack.PushInt(stack.PopInt and stack.PopInt);
      end;
      $0A:
      begin
        // or
        Inc(text);
        stack.PushInt(stack.PopInt or stack.PopInt);
      end;
      $0B:
      begin
        // xor
        Inc(text);
        stack.PushInt(stack.PopInt xor stack.PopInt);
      end;
      $0C:
      begin
        // not
        Inc(text);
        stack.PushInt(not stack.PopInt);
      end;
      $0D:
      begin
        // shl [byte]
        Inc(text);
        stack.PushInt(stack.PopInt shl text^);
        Inc(text);
      end;
      $0E:
      begin
        // shr [byte]
        Inc(text);
        stack.PushInt(stack.PopInt shr text^);
        Inc(text);
      end;
      $0F:
      begin
        // je addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt = 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat = 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $10:
      begin
        // jne addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt <> 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat <> 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $11:
      begin
        // jlt addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt < 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat < 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $12:
      begin
        // jle addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt <= 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat <= 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $13:
      begin
        // jgt addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt > 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat > 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $14:
      begin
        // jge addr [4 bytes]
        Inc(text);
        case stack.PeekType of
          0: // int
          begin
            if stack.PopInt >= 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          1: // float
          begin
            if stack.PopFloat >= 0 then
              text := PByte(Cardinal(startptr) + PCardinal(text)^)
            else
              Inc(text, Sizeof(Cardinal));
          end;
          else
            Kill('Unrecognized stack type');
        end;
      end;
      $15:
      begin
        // i2f
        Inc(text);
        stack.PushFloat(stack.PopInt);
      end;
      $16:
      begin
        // f2i
        Inc(text);
        stack.PushInt(Trunc(stack.PopFloat));
      end;
      $17:
      begin
        // push [str-addr] -- note absolute address in string table
        Inc(text);
        stack.PushStr(PChar(Cardinal(stringptr)+PCardinal(text)^));
        Inc(text, Sizeof(Cardinal));
      end;
      $18:
      begin
        // lib
        Inc(text);
        stack.PushAddr(LoadLibrary(stack.PopStr));
      end;
      $19:
      begin
        // unlib
        Inc(text);
        FreeLibrary(stack.PopAddr);
      end;
      $1A:
      begin
        // proc
        // STACK: [DLL handle][ProcName][ParamCount]
        // NOTE: Stack untouched
        Inc(text);
        stack.Freeze;
        // Add it to the proc pointer table and return the index
        // NOTE: This allows dynamic addresses to be stored locally
        tmpProcPtr := TProcPtr.Create;
        tmpProcPtr.ProcAddr := GetProcAddress(stack.PopAddr, stack.PopStr);
        tmpProcPtr.ParamCount := stack.PopInt;
        stack.PushAddr(Cardinal(procptrs.Add(tmpProcPtr)));

        stack.Unfreeze;
      end;
      $1B:
      begin
        // invoke - Proc handles only
        Inc(text);
        tmpProcPtr := procptrs[stack.PopInt] as TProcPtr;
        asm
          mov ecx, dword[tmpProcPtr.ParamCount]
        @_param_count_test:
          cmp ecx, 0
          jz @_invoke
          // TODO: call PopRaw and push to stack

          jmp @_param_count_test
        @_invoke:
          call [tmpProcPtr.ProcAddr]
          // TODO: mov eax onto stack

        end;
      end;
    end;
  end;
end.
