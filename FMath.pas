unit FMath;

interface

// Copied from: https://groups.google.com/forum/#!topic/comp.graphics.api.opengl/FFl3djAYERs
function fmod( ParaDividend : single; ParaDivisor : single ) : single;

implementation

// floating point mod
function fmod( ParaDividend : single; ParaDivisor : single ) : Single;
var
 vQuotient : integer;
begin
 vQuotient := trunc( ParaDividend / ParaDivisor );
 result := ParaDividend - (vQuotient * ParaDivisor);
end;

end.
