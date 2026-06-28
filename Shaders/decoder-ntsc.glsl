#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/grain.glsl"
#include "includes/colorSpaces.glsl"

//-----------------------------------------------------------------------------

uniform	float	decCrosstalk   = 0.25;
uniform	float	decSubcarrier  = 0.25;
uniform	float	decCrossColor  = 0.33;	// 0 = clean (comb), 1 = heavy rainbowing (cheap notch)

#define	CC_TAPS		8					// taps across one subcarrier period

//
// NTSC cross-talk:
//   - dot crawl   : chroma leaks into luma; per-line half-cycle stagger + per-frame advance = diagonal upward crawl
//   - cross-color : luma energy at the subcarrier frequency is demodulated into false chroma (rainbowing)
// Both share ONE subcarrier oscillator, so the artifacts are physically coherent.
//
vec3 decGetCrosstalk ( vec3 signal, vec2 uv, sampler2D tex )
{
	float	texH = textureSize ( tex, 0 ).y;

	// dot-crawl phase (per-line sign -0.5 -> correct upward diagonal crawl)
	float	chroma_phase = iTime * crtRefreshRate * 0.5 * PI;
	float	mod_phase = chroma_phase + ( uv.x + uv.y * -0.5 ) * ( 0.5 * PI ) * texH * 2.0;
	float	subCarrier = decSubcarrier * signal.y;
	float	i_mod = cos ( mod_phase );
	float	q_mod = sin ( mod_phase );

	// dot crawl
	signal.x *= decCrosstalk * subCarrier * q_mod + 1.0;
	signal.y *= subCarrier * i_mod + 1.0;
	signal.z *= subCarrier * q_mod + 1.0;

	// cross-color: demodulate clean luma against the SAME subcarrier
	if ( decCrossColor > 0.0 )
	{
		// horizontal freq = (0.5*PI)*texH*2.0 = PI*texH radians per unit uv.x
		// => cycles per unit uv.x = texH*0.5 ; period = 1/(texH*0.5)
		float	period = 1.0 / ( texH * 0.5 );
		float	stepUV = period / float ( CC_TAPS );

		float	sumI = 0.0;
		float	sumQ = 0.0;

		for ( int t = 0; t < CC_TAPS; t++ )
		{
			float	o     = ( float ( t ) - float ( CC_TAPS ) * 0.5 + 0.5 ) * stepUV;
			float	luma  = texture ( tex, uv + vec2 ( o, 0.0 ) ).r;
			float	phase = mod_phase + o * ( PI * texH );

			sumI += luma * cos ( phase );
			sumQ += luma * sin ( phase );
		}

		sumI /= float ( CC_TAPS );
		sumQ /= float ( CC_TAPS );

		// factor 3.0 baked in: uniform 0..1 maps to clean..worst-case
		signal.y += sumI * decCrossColor * 3.0;
		signal.z += sumQ * decCrossColor * 3.0;
	}

	return signal;
}
//-----------------------------------------------------------------------------

#include "includes/getSignal.glsl"

void main ()
{
	// Complete signal for this line
	vec3	yiq = getSignal ( fragCoord );

	// --- receiver / display stage (after the signal) ---

	// Apply brightness, contrast, and saturation
	yiq = encApplyBriConSat ( yiq );

	// Convert YIQ to RGB
	fragColor = vec4 ( yiq2rgb ( yiq ), 0.0 );
}
//-----------------------------------------------------------------------------
