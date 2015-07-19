program compiler;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  parser in 'parser.pas';

var
  FAsmFile: TextFile;
  FOut: TFileStream;
  Line: String;
  FParser: TParser;
  Idents: TStringList;
  LineNum: Integer;

procedure AsmByte(const B: Byte);
begin
  FOut.Write(B, Sizeof(Byte));
end;

procedure AsmLongWord(const L: LongWord);
begin
  FOut.Write(L, Sizeof(LongWord));
end;

function LocateId (const Id: String): LongWord;
var tmpId: String;
    tmpLoc: Integer;
begin
  tmpId := Lowercase(Copy(Id, 2, Length(Id)-1));
  tmpLoc := Idents.IndexOf(tmpId);
  if tmpLoc >= 0 then Result := tmpLoc
  else Result := Idents.Add(tmpId);
end;

procedure Error (const Msg: String);
begin
  Writeln(Format('ERROR: Line %d - %s', [LineNum, Msg]));
  Halt;
end;

procedure CheckEOL;
begin
  if FParser.Next <> tkEOL then Error('End-of-line expected');
end;

{ Compilation }

procedure OpWindow;
var id: String;
begin
  case FParser.Next of
    tkCreate:
    begin
      if FParser.Next <> tkComma then Error('Comma expected');
      if FParser.Next <> tkID then Error('Identifier expected');
      id := FParser.Keyword;
      CheckEOL;

      // Emits 0x01 + @IdentSymbolicIndex
      AsmByte($01);
      AsmLongWord(LocateId(id));
    end;
    else begin
      Error('Unknown "window"-type opcode');
    end;
  end;
end;

procedure CompileLine;
begin
  case FParser.Next of
    tkWindow:
    begin
      OpWindow;
    end;
    tkEOL:
    begin
      // Skip
    end;
    else Error('Invalid opcode');
  end;
end;

{
  ID Translation
  ==============
  (1) If the ID exists, return its numerical value
  (2) Otherwise, generate the next successive numerical value and store it
      w/ the corresponding ID
}

{
  Bytecode translation
  ====================
  window create, @frm       | 01 NN NN NN NN
}

begin
  // Usage: compiler[.exe] <input> <output>
  AssignFile(FAsmFile, ParamStr(1));
  FOut := TFileStream.Create(ParamStr(2), fmCreate or fmOpenWrite);
  Reset(FAsmFile);
  Idents := TStringList.Create;

  FParser := TParser.Create;
  LineNum := 0;
  while not Eof(FAsmFile) do begin
    Readln(FAsmFile, Line);
    Inc(LineNum);
    FParser.SetLine(Line);
    CompileLine;
  end;

  // Write # of identifiers (VM metadata)
  AsmLongWord(Idents.Count);
  
  CloseFile(FAsmFile);
  FParser.Free;
  Idents.Free;
  FOut.Free;
end.
