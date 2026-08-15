#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/grain.glsl"
#include "includes/colorSpaces.glsl"

//-----------------------------------------------------------------------------

uniform	float	decCrosstalk		= 0.25;
uniform	float	decCrossColor		= 1.0;	// 0 = clean (comb), 1 = heavy rainbowing (cheap notch)
uniform float	decDrift			= 1.0;
uniform float	decNoise			= 0.1;	// 0 = perfect, 1 = total breakup

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
	float	i_mod = cos ( mod_phase );
	float	q_mod = sin ( mod_phase );

	// dot crawl: residual modulated chroma leaks into luma (additive)
	float	modChroma = signal.y * i_mod + signal.z * q_mod;   // I·cos + Q·sin
	signal.x += decCrosstalk * modChroma * 0.25;

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

float getAnalogDefects ( int texH )
{
	// Apply hue offset with "live" jitter and drift

	// Tint drift: very slow thermal wander (minutes)
	float	slowDrift = sin ( iTime * 0.04 ) * decDrift * 10.0;

	// Tiny fast component from signal instability
	float	srcLine  = floor ( fragCoord.y * texH );
	float	microJitter = ( decRandom_v2_f ( vec2 ( 0.0, srcLine ), iTime ) - 0.5 ) * decDrift * 10.0;

	return radians ( slowDrift + microJitter );
}
//-----------------------------------------------------------------------------

#include "includes/verticalRoll.glsl"
#include "includes/getSignal.glsl"

void main ()
{
	int		texH = textureSize ( iChannel0, 0 ).y;

	// Get Y-offset for roll emulation
	float	rollOffset = vRollOffset ();

	// Get phase-defect inherent to analog signals
	float	angle = getAnalogDefects ( texH );

	// Complete signal for this line
	vec3	yiq = getSignal ( fragCoord, angle, rollOffset );

	// Apply brightness, contrast, and saturation
	yiq = encApplyBriConSat ( yiq );

	// Convert YIQ to RGB
	fragColor = vec4 ( encApplyTint ( yiq2rgb ( yiq ) ), 0.0 );
}
//-----------------------------------------------------------------------------
