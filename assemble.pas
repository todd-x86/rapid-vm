unit assemble;

{
  Assembly unit
}

interface

uses DateUtils, Classes, SysUtils, Contnrs, parser;

type
  TLabelOffset = class(TObject)
  public
    Name: String;
    Ident, Offset: Cardinal;
    constructor Create(const Name: String; const Offset: Cardinal);
  end;

procedure Finalize;
procedure Init;
procedure SetOutputFile (const Fn: String);
procedure Error (const Msg: String);
procedure AsmByte(const B: Byte);
procedure AsmCardinal(const C: Cardinal);
procedure AsmIdent(const Id: String);
procedure AsmInt(const I: Integer);
procedure AsmString(const S: String);
procedure ParseTypeString;
function LocateId (const Id: String): Cardinal;
function StrConst (const S: String): Cardinal;
procedure CheckEOL;
procedure CompileLine(const S: String);
procedure WriteMetadata;
procedure AsmIntFromKeyword(const S: String);
procedure PrintStats;
procedure AsmStringRes(const S: String);
procedure AsmLabelRes(const Lbl: TLabelOffset);

implementation

const
  ERROR_IDENT = 'Identifier expected';
  ERROR_COMMA = 'Comma expected';
  ERROR_STR_IDENT = 'String or identifier expected';

var
  AsmOffset: Cardinal;
  LineNum: Integer;
  FOut: TFileStream;
  StrTable, Idents: TStringList;
  FParser: TParser;
  Labels: TObjectList;
  StartTime, EndTime: TDateTime;

constructor TLabelOffset.Create(const Name: String; const Offset: Cardinal);
begin
  inherited Create;
  Self.Name := Name;
  Self.Offset := Offset;
end;

{ Internal }

procedure Init;
begin
  StartTime := Now;
  Idents := TStringList.Create;
  StrTable := TStringList.Create;
  FParser := TParser.Create;
  Labels := TObjectList.Create(True);
  LineNum := 1;
  AsmOffset := 0;
end;

procedure WriteMetadata;
var tmpLoc, ResOffset, j: Integer;
begin
  ResOffset := AsmOffset;

  // Precompute label identifiers in table
  // TODO: Remove this and just make second pass
  j := 0;
  while j < Labels.Count do begin
    tmpLoc := Idents.IndexOf((Labels[j] as TLabelOffset).Name);
    if tmpLoc < 0 then begin
      // If the label is never identified, remove it from output
      Labels.Delete(j);
    end else begin
      (Labels[j] as TLabelOffset).Ident := tmpLoc;
      Inc(j);
    end;
  end;

  // -- RESOURCES BEGIN --
  // Write # of identifiers (VM metadata)
  AsmCardinal(Idents.Count);
  // Write all strings
  for j := 0 to StrTable.Count-1 do begin
    AsmStringRes(StrTable[j]);
  end;
  // Write label translation table
  for j := 0 to Labels.Count-1 do begin
    AsmLabelRes(Labels[j] as TLabelOffset);
  end;
  // -- RESOURCES END --

  // NOTE: IMPORTANT
  // Write ending marker for splitting opcode and resource sections
  AsmCardinal(ResOffset);
end;

procedure PrintStats;
begin
  EndTime := Now;
  Writeln('Successfully compiled');
  Writeln(Format('Input: %d lines', [LineNum-1]));
  Writeln(Format('Output: %d bytes', [AsmOffset]));
  Writeln(Format('Time: %d.%d seconds', [Trunc(SecondSpan(StartTime, EndTime)), Trunc(MilliSecondSpan(StartTime, EndTime))]));
  Writeln;
  Writeln('[Resources]');
  Writeln(Format('Labels: %d', [Labels.Count]));
  Writeln(Format('Strings: %d', [StrTable.Count]));
end;

procedure Finalize;
begin
  FParser.Free;
  Idents.Free;
  StrTable.Free;
  Labels.Free;
  FOut.Free;
end;

procedure SetOutputFile (const Fn: String);
begin
  FOut := TFileStream.Create(Fn, fmCreate or fmOpenWrite)
end;

procedure Error (const Msg: String);
begin
  Writeln(Format('ERROR: Line %d:%d - %s', [LineNum, FParser.Offset+1, Msg]));
  Halt;
end;

{ Assembly byte emission - compiler-level }

procedure AsmByte(const B: Byte);
begin
  Inc(AsmOffset, FOut.Write(B, Sizeof(Byte)));
end;

procedure AsmCardinal(const C: Cardinal);
begin
  Inc(AsmOffset, FOut.Write(C, Sizeof(Cardinal)));
end;

{ Assembly byte emission - type-identified }

procedure AsmIdent(const Id: String);
begin
  AsmByte($00);
  AsmCardinal(LocateId(Id));
end;

procedure AsmInt(const I: Integer);
begin
  AsmByte($01);
  Inc(AsmOffset, FOut.Write(I, Sizeof(Integer)));
end;

procedure AsmIntFromKeyword(const S: String);
begin
  try
    AsmInt(StrToInt(S));
  except
    on E: Exception do begin
      Error(Format('"%s" is not a valid integer', [S]));
    end;
  end;
end;

procedure AsmString(const S: String);
var Index: Cardinal;
begin
  AsmByte($02);
  Index := StrConst(S);
  Inc(AsmOffset, FOut.Write(Index, Sizeof(Cardinal)));
end;

procedure AsmStringRes(const S: String);
begin
  AsmByte($00);
  AsmCardinal(Length(S));
  Inc(AsmOffset, FOut.Write(S[1], Length(S)));
end;

procedure AsmLabelRes(const Lbl: TLabelOffset);
begin
  AsmByte($01);
  AsmCardinal(Lbl.Ident);
  AsmCardinal(Lbl.Offset);
end;

{ Parsing }

procedure ParseTypeString;
var tk: TToken;
begin
  tk := FParser.Next;
  if tk = tkString then begin
    AsmString(FParser.Keyword);
  end else if tk = tkID then begin
    AsmIdent(FParser.Keyword);
  end else Error(ERROR_STR_IDENT);
end;

procedure ParseTypeInt;
var tk: TToken;
begin
  tk := FParser.Next;
  if tk = tkInteger then begin
    AsmIntFromKeyword(FParser.Keyword);
  end else if tk = tkID then begin
    AsmIdent(FParser.Keyword);
  end else Error(ERROR_STR_IDENT);
end;

procedure ParseTypeLabel;
begin
  Assert(FParser.Next = tkKeyword, ERROR_IDENT);
  Labels.Add(TLabelOffset.Create(Lowercase(FParser.Keyword), AsmOffset));
end;

{ Utilities }

function LocateId (const Id: String): Cardinal;
var tmpId: String;
    tmpLoc: Integer;
begin
  tmpId := Lowercase(Copy(Id, 2, Length(Id)-1));
  tmpLoc := Idents.IndexOf(tmpId);
  if tmpLoc >= 0 then Result := tmpLoc
  else Result := Idents.Add(tmpId);
end;

function StrConst (const S: String): Cardinal;
var tmpStr: String;
    j: Integer;
begin
  SetLength(tmpStr, Length(S)-2);
  tmpStr := '';
  j := 2;
  while j < Length(S) do begin
    if S[j] = '\' then Inc(j);
    tmpStr := tmpStr + S[j];
    Inc(j);
  end;
  Result := StrTable.Add(tmpStr);
end;

procedure CheckEOL;
begin
  if FParser.Next <> tkEOL then Error('End-of-line expected');
end;

{ Compilation }

procedure CompileLine(const S: String);
begin
  FParser.SetLine(S);
  case FParser.Next of
    tkWindowCreate:
    begin
      AsmByte($00);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkWindowSetTitle:
    begin
      AsmByte($01);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma);
      ParseTypeString;
    end;
    tkIntCreate:
    begin
      AsmByte($02);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkIntAdd:
    begin
      AsmByte($03);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeInt;
    end;
    tkIntSet:
    begin
      AsmByte($04);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeInt;
    end;
    tkBtnCreate:
    begin
      AsmByte($05);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkBtnSetParent:
    begin
      AsmByte($06);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkBtnSetText:
    begin
      AsmByte($07);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeString;
    end;
    tkBtnSetOnClick:
    begin
      AsmByte($08);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      // NOTE: Label is just an identifier to a block of code...
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkStrCreate:
    begin
      AsmByte($09);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeString;
    end;
    tkStrConcat:
    begin
      AsmByte($0A);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeString;
    end;
    tkConvertIntStr:
    begin
      AsmByte($0B);
      ParseTypeInt;
      Assert(FParser.Next = tkComma, ERROR_COMMA);
      ParseTypeString;
    end;
    tkAppRun:
    begin
      AsmByte($0C);
      Assert(FParser.Next = tkID, ERROR_IDENT);
      AsmIdent(FParser.Keyword);
    end;
    tkColon:  // Label
    begin
      ParseTypeLabel;
    end;
    tkReturn:
    begin
      AsmByte($0D);
    end;
    tkEOL:
    begin
      // Skip
    end;
    else Error('Invalid opcode');
  end;
  CheckEOL;
  Inc(LineNum);
end;

end.
