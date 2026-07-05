#include "includes/colorSpaces.glsl"

uniform float	crtHalation = 1.0;

//-----------------------------------------------------------------------------

vec3 sampleMipJittered ( vec2 uv, float lod )
{
	vec2	texel = exp2 ( lod ) / vec2 ( textureSize ( iChannel0, 0 ) );

	vec3	s;
	s  = textureLod ( iChannel0, uv + texel * vec2 ( -0.4, -0.4 ), lod ).rgb;
	s += textureLod ( iChannel0, uv + texel * vec2 (  0.4, -0.4 ), lod ).rgb;
	s += textureLod ( iChannel0, uv + texel * vec2 ( -0.4,  0.4 ), lod ).rgb;
	s += textureLod ( iChannel0, uv + texel * vec2 (  0.4,  0.4 ), lod ).rgb;

	return s * 0.25;
}
//-----------------------------------------------------------------------------

vec3 halation ( vec3 col, vec2 uv )
{
	// wide diffuse halo: weights sum to 1.0, biased toward widest mip
	vec3	halCol;
	halCol  = sampleMipJittered ( uv, 4.0 ) * 0.2;
	halCol += sampleMipJittered ( uv, 3.0 ) * 0.3;
	halCol += sampleMipJittered ( uv, 2.0 ) * 0.5;

	// scatter mixes neighboring phosphors -> slight desaturation
	float	luma = getLinearLuma ( halCol );
	halCol = mix ( halCol, vec3 ( luma ), 0.1 );

	// energy-conserving blend
	float	k = crtHalation * crtHalation * 0.4;
	return col * ( 1.0 - k ) + halCol * k;
}
//-----------------------------------------------------------------------------

void main ()
{
	vec3	col = texture ( iChannel0, fragCoord ).rgb;

	col = halation ( col, fragCoord );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
