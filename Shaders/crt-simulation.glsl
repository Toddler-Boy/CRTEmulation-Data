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
	return max ( col, crtAmbient * 0.015 * ambientCol );
}
//-----------------------------------------------------------------------------

uniform float	crtScanlines = 0.5;
uniform float	crtLinePixels = 5.0;	// Physical on-screen pixels per source line

// A small or distant screen blends the fine patterns away before the eye,
// and a small render target could only alias them, so they fade out early.
// featureScale: how much larger than the reference the pattern renders
float detailFade ( float featureScale )
{
	return smoothstep ( 2.0, 5.0, crtLinePixels * featureScale );
}

// y in source lines: the beam lights each line's center, the gap between
// lines is what reads as scanlines
vec3 scanlines ( vec3 col, float y )
{
	float	luma = getLinearLuma ( col );

	// Distance from the line's center, 0.5 = the boundary to the neighbor
	float	dist = abs ( fract ( y ) - 0.5 );

	// A brighter beam widens the lit core
	float	width = mix ( 0.2, 0.35, luma );

	float	line = 1.0 - smoothstep ( width - 0.25, width + 0.25, dist );

	// Normalize so the pattern's mean stays 1.0
	line /= 2.0 * width;

	return	col * mix ( 1.0, line, crtScanlines * detailFade ( 1.0 ) );
}
//-----------------------------------------------------------------------------

uniform float	crtMask = 0.5;

vec3 shadowMask ( vec3 col, vec2 uv )
{
	// 64px is the reference mask size, a larger bitmap renders proportionally
	// larger slots (the SX-64 look)
	const vec2	refSize = vec2 ( 64.0 * 64.0 * 0.75 );

	vec2	texSize = vec2 ( textureSize ( iChannel1, 0 ).xy );
	vec2	repeats = refSize / texSize;
	vec3	mask = texture ( iChannel1, uv * repeats ).rgb;
	mask = srgbToLinear ( mask );

	// per-channel mean of the tinted mask = top mip level
	vec3	avg = srgbToLinear ( textureLod ( iChannel1, vec2 ( 0.5 ), 16.0 ).rgb );

	// normalize so the blended mask averages to 1.0 per channel
	mask /= max ( avg, vec3 ( 0.001 ) );

	// A coarser mask stays resolvable on smaller screens
	mask = mix ( vec3 ( 1.0 ), mask, crtMask * detailFade ( texSize.x / 64.0 ) );

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

vec3 reduceBlue ( vec3 col )
{
	// Bloom expansion also reduces blue level
	col.b = col.b / ( 1.0 + crtBloomExpansion * 0.2 * col.b );

	return col;
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
	col = reduceBlue ( col );
	col = scanlines ( col, uv.y * textureSize ( iChannel0, 0 ).y );
	col = shadowMask ( col, fragCoord );
	col = phosphorDecay ( col );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
