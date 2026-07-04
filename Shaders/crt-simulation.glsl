#include "includes/mathDefines.glsl"
#include "includes/overscan.glsl"
#include "includes/common.glsl"
#include "includes/colorSpaces.glsl"

uniform float	crtBleed;
uniform vec2	crtRedOffset = vec2 ( 0.0, 0.0 );
uniform vec2	crtGreenOffset = vec2 ( 0.0, 0.0 );
uniform vec2	crtBlueOffset = vec2 ( 0.0, 0.0 );
uniform float	crtHoffset;
uniform float	crtGlow;
uniform float	crtAmbient = 0.5;
uniform float	crtConvergence = 1.0;

//-----------------------------------------------------------------------------

vec3 bleed ( vec2 uv )
{
	// H-wave
	float	x = sin ( 0.1 * iTime + uv.y * 13.0 ) * sin ( 0.23 * iTime + uv.y * 19.0 ) * sin ( 0.3 + 0.11 * iTime + uv.y * 23.0 ) * 0.0012;
	float	o = sin ( fragCoord.y / 2.0 ) / 500.0;
	vec2	xOff = vec2 ( ( x + o * 0.5 ) * crtHoffset, 0.0 );
	vec2	str = vec2 ( -0.005, 0.005 );

	// Radial Misconvergence
	vec2	coord = uv * 2.0 - 1.0;
	float	radius2 = dot ( coord, coord );
	float	k = 0.005 * ( crtConvergence * crtConvergence );
	vec2	r_distortion = coord * radius2 * k;
	vec2	b_distortion = coord * radius2 * -k;

	// Separation
	vec3	col = vec3	(	texture ( iChannel0, uv + crtRedOffset * crtBleed * str + xOff + r_distortion ).r,
							texture ( iChannel0, uv + crtGreenOffset * crtBleed * str + xOff ).g,
							texture ( iChannel0, uv + crtBlueOffset * crtBleed * str + xOff + b_distortion ).b );

	return col;
}
//-----------------------------------------------------------------------------

vec3 ambient ( vec3 col )
{
	vec3	ambientCol = mix ( vec3 ( 1.0, 0.95, 1.05 ), vec3 ( 1.0, 0.9, 1.15 ), crtAmbient );
	return max ( col, crtAmbient * 0.16 * ambientCol );
}
//-----------------------------------------------------------------------------

vec3 halation ( vec3 col, vec2 uv )
{
	if ( crtGlow < 0.01 )
		return col;

	float	glowSq = crtGlow * crtGlow;
	vec3	blCol;

	blCol  = textureLod ( iChannel0, uv, 2.5 ).rgb * 0.6;
	blCol += textureLod ( iChannel0, uv, 1.5 ).rgb * 0.3;
	blCol += textureLod ( iChannel0, uv, 0.5 ).rgb * 0.15;

	blCol = blCol * blCol * blCol;

	return col * ( 1.0 - glowSq * 0.1 ) + blCol * glowSq;
}
//-----------------------------------------------------------------------------

uniform float	crtScanlines = 0.5;

vec3 scanlines ( vec3 col, float y )
{
	float	luma = dot ( col, vec3 ( 0.299, 0.587, 0.114 ) );
	float	dark = abs ( sin ( PI * y ) );
	float	line = mix ( dark, 0.85, luma * luma );

	return	col * mix ( 1.0, line, crtScanlines );
}
//-----------------------------------------------------------------------------

uniform float	crtMask = 0.5;
uniform float	crtMaskScale = 0.75;
uniform vec3	crtMaskTint = vec3 ( 20.0 );

vec3 shadowMask ( vec3 col, vec2 uv )
{
	vec3	mask = texture ( iChannel1, uv * textureSize ( iChannel1, 0 ) * crtMaskScale ).rgb;
	mask = srgbToLinear ( mask );
	mask *= crtMaskTint;

	mask = mix ( vec3 ( 1.0 ), mask, crtMask );

	return mask * col;
}
//-----------------------------------------------------------------------------

uniform float	u_deltaTime = 0.016;
uniform	vec3	u_decayFactor = vec3 ( 18.0, 10.0, 20.0 );
uniform float	u_phosphorFlicker = 0.0;

vec3 phosphorDecay ( vec3 col )
{
	col *= abs ( sin ( iTime * crtRefreshRate * PI + fragCoord.y * PI ) * u_phosphorFlicker + ( 1.0 - u_phosphorFlicker ) );

	vec3	prev = texture ( iChannel2, fragCoord ).rgb * u_decayFactor;

	return max ( col, prev );
}
//-----------------------------------------------------------------------------

uniform float	crtBloomExpansion = 1.0;

vec2 bloomExpansion ( vec2 uv )
{
	const vec2	bloomFactor = vec2 ( 0.03, 0.03 / 1.4 );

	// Get interpolated current level
	float	frameCurrent = texelFetch ( iChannel3, ivec2 ( 0 ), 0 ).r;
	vec2	bloomedCoord = ( uv - 0.5 ) * ( 1.0 - ( frameCurrent * bloomFactor * crtBloomExpansion ) ) + 0.5;

	return bloomedCoord;
}
//-----------------------------------------------------------------------------

void main ()
{
	vec3	col;
	vec2	uv = overscan ( fragCoord );

	uv = bloomExpansion ( uv );

	// CRT-style post FX
	col = bleed ( uv );
	col = srgbToLinear ( col );
	col = scanlines ( col, uv.y * textureSize ( iChannel0, 0 ).y );
	col = shadowMask ( col, fragCoord );
	col = halation ( col, uv );
	col = linearToSrgb ( col );
	col = ambient ( col );
	col = phosphorDecay ( col );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
