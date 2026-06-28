#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/grain.glsl"
#include "includes/colorSpaces.glsl"

//-----------------------------------------------------------------------------

uniform	float	decCrosstalk     = 0.25;
uniform	float	decSubcarrier    = 0.25;
uniform	vec2	decPALDelayLine  = vec2 ( 1.0, 1.0 );

vec3 decGetCrosstalk ( vec3 signal, vec2 uv, sampler2D tex )
{
	float	chroma_phase = iTime * crtRefreshRate * 0.5 * PI;
	float	mod_phase = chroma_phase + ( uv.x + uv.y * -0.5 ) * ( 0.5 * PI ) * textureSize ( tex, 0 ).y * 2.0;
	float	subCarrier = decSubcarrier * signal.y;
	float	i_mod = cos ( mod_phase );
	float	q_mod = sin ( mod_phase );

	// crosstalk
	signal.x *= decCrosstalk * subCarrier * q_mod + 1.0;
	signal.y *= subCarrier * i_mod + 1.0;
	signal.z *= subCarrier * q_mod + 1.0;

	return signal;
}
//-----------------------------------------------------------------------------

#include "includes/getSignal.glsl"

//
// PAL decoder
// Signal chain -> delay-line cancellation -> receiver/display stage
//
void main ()
{
	float	dy = 1.0 / textureSize ( iChannel0, 0 ).y;

	// Two complete, independent signal lines
	vec3	here = getSignal ( fragCoord );
	vec3	prev = getSignal ( fragCoord - vec2 ( 0.0, dy ) );

	// PAL delay-line: average chroma carriers to cancel the alternating-phase
	// error. Full average = clean; none = Hanover bars. Misaligned lines
	// (from differing interference jitter) cancel imperfectly, as on real hardware.
	vec3	yuv = here;
	vec2	avg = ( here.gb + prev.gb ) * 0.5;
	yuv.gb = mix ( here.gb, avg, decPALDelayLine );

	// --- receiver / display stage (after the signal) ---

	// Apply brightness, contrast, and saturation
	yuv = encApplyBriConSat ( yuv );

	// Convert YUV to RGB
	fragColor = vec4 ( yuv2rgb ( yuv ), 0.0 );
}
//-----------------------------------------------------------------------------
