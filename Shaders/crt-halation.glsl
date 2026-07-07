#include "includes/colorSpaces.glsl"
#include "includes/getMipMapColor.glsl"

uniform float	crtHalation = 1.0;

//-----------------------------------------------------------------------------

vec3 halation ( sampler2D tex, vec3 col, vec2 uv )
{
	// wide diffuse halo: weights sum to 1.0, biased toward widest mip
	vec3	halCol;
	float	lod = lodForRadius ( tex, 0.06 );
	halCol  = getMipMapColorJittered ( tex, uv, lod ) * 0.2;
	halCol += getMipMapColorJittered ( tex, uv, lod - 1.0 ) * 0.3;
	halCol += getMipMapColorJittered ( tex, uv, lod - 2.0 ) * 0.5;

	// scatter mixes neighboring phosphors -> slight desaturation
	float	luma = getLinearLuma ( halCol );
	halCol = mix ( halCol, vec3 ( luma ), 0.1 );

	float	kHal = crtHalation * crtHalation * 0.15;

	return mix ( col, halCol, kHal );
}
//-----------------------------------------------------------------------------

void main ()
{
	vec3	col = texture ( iChannel0, fragCoord ).rgb;

	col = halation ( iChannel0, col, fragCoord );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
