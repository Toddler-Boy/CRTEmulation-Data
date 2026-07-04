#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/grain.glsl"
#include "includes/colorSpaces.glsl"

//-----------------------------------------------------------------------------

uniform	float	decCrosstalk		= 0.25;
uniform	float	decPALDelayLine		= 1.0;
uniform float	decDrift			= 0.0;
uniform float	decNoise			= 0.1;	// 0 = perfect, 1 = total breakup

vec3 decGetCrosstalk ( vec3 signal, vec2 uv, sampler2D tex )
{
	float	texH = textureSize ( tex, 0 ).y;

	float	drift = ( decRandom_v2_f ( vec2 ( 0.0 ), iTime * 0.1 ) - 0.5 );
	float	chroma_phase = iTime * crtRefreshRate * 0.5 * PI + drift;
	float	mod_phase = chroma_phase + ( uv.x + uv.y * -0.5 ) * ( 0.5 * PI ) * texH * 2.0;
	float	i_mod = cos ( mod_phase );
	float	q_mod = sin ( mod_phase );

	// PAL: V (signal.z) phase alternates every line -> dot crawl partially
	// self-cancels between line pairs (finer/weaker than NTSC)
	float	palSign = ( mod ( floor ( uv.y * texH ), 2.0 ) < 1.0 ) ? 1.0 : -1.0;

	// dot crawl: residual modulated chroma leaks into luma (additive)
	float	modChroma = signal.y * i_mod + palSign * signal.z * q_mod;
	signal.x += decCrosstalk * 0.25 * modChroma;

	return signal;
}
//-----------------------------------------------------------------------------

#include "includes/verticalRoll.glsl"
#include "includes/getSignal.glsl"

float getAnalogDefects ( int texH )
{
	// Apply phase offset with "live" jitter and drift
	float	srcLine  = floor ( fragCoord.y * texH );
	float	lineSign = ( mod ( srcLine, 2.0 ) < 1.0 ) ? 1.0 : -1.0;

	float	drift  = sin ( iTime * 1.5 + srcLine * 0.3 ) * decDrift * 6.0;
	float	jitter = ( decRandom_v2_f ( vec2 ( 0.0, srcLine ), iTime ) - 0.5 ) * decDrift * 8.0;

	return lineSign * radians ( 22.5 + drift + jitter );
}
//-----------------------------------------------------------------------------

//
// PAL decoder
// Signal chain -> delay-line cancellation -> receiver/display stage
//
void main ()
{
	int		texH = textureSize ( iChannel0, 0 ).y;

	// Get Y-offset for roll emulation
	float	rollOffset = vRollOffset ();

	// Get phase-defect inherent to analog signals
	float	angle = getAnalogDefects ( texH );

	// Two complete, independent signal lines
	vec3	here = getSignal ( fragCoord, angle, rollOffset );
	vec3	prev = getSignal ( fragCoord - vec2 ( 0.0, 1.0 / texH ), -angle, rollOffset );

	// PAL delay-line: average adjacent lines' rotated chroma. The +/-22.5°
	// rotations cancel back to true hue. Full average = clean; none = Hanover
	// bars. Differing interference jitter makes lines cancel imperfectly.
	vec3	yuv = here;
	vec2	avg = ( here.gb + prev.gb ) * 0.5;
	yuv.gb = mix ( here.gb, avg, decPALDelayLine );

	// Apply brightness, contrast, and saturation
	yuv = encApplyBriConSat ( yuv );

	// Convert YUV to RGB
	fragColor = vec4 ( yuv2rgb ( yuv ), 0.0 );
}
//-----------------------------------------------------------------------------
