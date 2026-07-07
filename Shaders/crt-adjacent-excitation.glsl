#include "includes/colorSpaces.glsl"
#include "includes/getMipMapColor.glsl"

uniform float	crtAdjacent = 0.5;

//-----------------------------------------------------------------------------

vec3 adjacentExcitation ( sampler2D tex, vec3 col, vec2 uv )
{
	// tight radius, slightly oversaturated (beam spillover excites same-color phosphors)
	vec3	adjCol = getMipMapColorJittered ( tex, uv, lodForRadius ( tex, 0.0074 ) );
	float	adjLuma = getLinearLuma ( adjCol );
	adjCol = max ( mix ( vec3 ( adjLuma ), adjCol, 1.15 ), 0.0 );

	float	kAdj = crtAdjacent * 0.5;

	return col * ( 1.0 - kAdj * 0.5 ) + adjCol * kAdj;
}
//-----------------------------------------------------------------------------

void main ()
{
	vec3	col = texture ( iChannel0, fragCoord ).rgb;

	col = adjacentExcitation ( iChannel0, col, fragCoord );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
