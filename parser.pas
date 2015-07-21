unit parser;

interface

uses Classes, SysUtils;

type
  TToken = (tkWindowCreate, tkWindowSetTitle,
            tkIntCreate, tkIntAdd, tkIntSet,
            tkBtnCreate, tkBtnSetParent, tkBtnSetText, tkBtnSetOnClick,
            tkStrCreate, tkStrConcat,
            tkConvertIntStr,
            tkAppRun,
            tkInteger, tkString,
            tkReturn,
            tkComma, tkColon, tkID, tkKeyword,
            tkEOL, tkUnknown);

  TParser = class(TObject)
  private
    FLine: String;
    FPos, FLast: Integer;
    function ParseAlpha: TToken;
    function ParseNumeric: TToken;
    function ParseSymbol: TToken;
    procedure Whitespace;
    procedure ReadAlpha;
    procedure ReadInteger;
  public
    property Offset: Integer read FLast;
    property Current: Integer read FPos;

    constructor Create;
    procedure SetLine (const Line: String);
    function Next: TToken;
    function Peek: TToken;
    function Keyword: String;
    procedure Reset;
  end;

implementation

constructor TParser.Create;
begin
  FLine := '';
  FPos := 1;
  FLast := 1;
end;

procedure TParser.SetLine (const Line: String);
begin
  FLine := Line;
  Reset;
end;

function TParser.Next: TToken;
begin
  Whitespace;
  FLast := FPos;
  if FPos > Length(FLine) then
    Result := tkEOL
  else if FLine[FPos] in ['A'..'Z','a'..'z','_'] then
    Result := ParseAlpha
  else if FLine[FPos] in ['0'..'9'] then
    Result := ParseNumeric
  else
    Result := ParseSymbol;
end;

function TParser.Peek: TToken;
var TmpPos, TmpLast: Integer;
begin
  TmpPos := FPos;
  TmpLast := FLast;
  Result := Next;
  FPos := TmpPos;
  FLast := TmpLast;
end;

function TParser.Keyword: String;
begin
  Result := Copy(FLine, FLast, FPos-FLast);
end;

procedure TParser.Reset;
begin
  FPos := 1;
  FLast := 1;
end;

function TParser.ParseAlpha: TToken;
var kw: String;
begin
  ReadAlpha;
  kw := Lowercase(Keyword);
  { Window }
  if kw = 'window_create' then Result := tkWindowCreate
  else if kw = 'window_set_title' then Result := tkWindowSetTitle
  { Int }
  else if kw = 'int_create' then Result := tkIntCreate
  else if kw = 'int_add' then Result := tkIntAdd
  else if kw = 'int_set' then Result := tkIntSet
  { Button }
  else if kw = 'button_create' then Result := tkBtnCreate
  else if kw = 'button_set_parent' then Result := tkBtnSetParent
  else if kw = 'button_set_text' then Result := tkBtnSetText
  else if kw = 'button_set_onclick' then Result := tkBtnSetOnClick
  { String }
  else if kw = 'string_create' then Result := tkStrCreate
  else if kw = 'string_concat' then Result := tkStrConcat
  { Convert }
  else if kw = 'convert_int_string' then Result := tkConvertIntStr
  { App }
  else if kw = 'app_run' then Result := tkAppRun
  else if kw = 'return' then Result := tkReturn
  else Result := tkKeyword;
end;

function TParser.ParseNumeric: TToken;
begin
  ReadInteger;
  Result := tkInteger;
end;

function TParser.ParseSymbol: TToken;
begin
  case FLine[FPos] of
    '@':
    begin
      Inc(FPos);
      ReadAlpha;
      Result := tkID;
    end;
    ',':
    begin
      Inc(FPos);
      Result := tkComma;
    end;
    ';':
    begin
      Inc(FPos);
      Result := tkEOL;
    end;                                        
    ':':
    begin
      Inc(FPos);
      Result := tkColon;
    end;
    '"':
    begin
      Inc(FPos);
      while (FPos <= Length(FLine)) and (FLine[FPos] <> '"') do begin
        if (FLine[FPos] = '\') then Inc(FPos);
        Inc(FPos);
      end;
      Inc(FPos);
      Result := tkString;
    end;
    else begin
      Inc(FPos);
      Result := tkUnknown;
    end;
  end;
end;

procedure TParser.ReadInteger;
begin
  while (FPos <= Length(FLine)) and (FLine[FPos] in ['0'..'9']) do
    Inc(FPos);
end;

procedure TParser.ReadAlpha;
begin
  while (FPos <= Length(FLine)) and (FLine[FPos] in ['A'..'Z','a'..'z','_','0'..'9']) do
    Inc(FPos);
end;

procedure TParser.Whitespace;
begin
  while (FPos <= Length(FLine)) and (FLine[FPos] in [#13,#10,#9,' ']) do
    Inc(FPos);
end;

end.
