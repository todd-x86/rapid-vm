unit Structs;

interface

type
  TProcPtr = class(TObject)
    ProcAddr: Pointer;
    ParamCount: Byte;  // NOTE: Check DLL invoke param limits in Windows API
  end;

implementation

end.
