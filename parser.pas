unit parser;

interface

uses Classes, SysUtils;

type
  TToken = (tkWindow, tkCreate, tkComma, tkID, tkInteger, tkEOL, tkUnknown);

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
  if kw = 'window' then Result := tkWindow
  else if kw = 'create' then Result := tkCreate
  else Result := tkUnknown;
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
