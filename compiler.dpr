program compiler;

{$APPTYPE CONSOLE}

uses
  assemble in 'assemble.pas';

var
  FAsmFile: TextFile;
  Line: String;

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
  SetOutputFile(ParamStr(2));
  Reset(FAsmFile);
  Init;

  while not Eof(FAsmFile) do begin
    Readln(FAsmFile, Line);
    CompileLine(Line);
  end;

  WriteMetadata;

  CloseFile(FAsmFile);
  PrintStats;
  Finalize;
end.
