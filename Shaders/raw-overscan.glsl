#include "includes/overscan.glsl"

//-----------------------------------------------------------------------------

void main ()
{
	fragColor = texture ( iChannel0, overscan ( fragCoord ) );
}
//-----------------------------------------------------------------------------
