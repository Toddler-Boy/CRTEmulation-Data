//-----------------------------------------------------------------------------

vec3 getSignal ( vec2 fragPos )
{
	const float	NOISE_RES_X = 1280.0;
	const float NOISE_RES_Y = 272.0;
	const float BLACK_LEVEL = 0.05;

	// Interference: this line's own horizontal jitter
	vec2	uv = decCreateInterference ( fragPos );

	// Bandwidth limit (luma full, chroma reduced)
	vec3	sig = decGetBlurredSignal ( uv, iChannel0 );

	// Signal pedestal: lift black off zero so noise has symmetric headroom
	sig.x = sig.x * ( 1.0 - BLACK_LEVEL ) + BLACK_LEVEL;

	// Noise enters during transmission, BEFORE the receiver separates Y/C.
	// Additive, zero-centered (so it perturbs small signed chroma too), luma
	// boosted to read at the same level as chroma. Fine along X, one row per line.
	vec2	noiseCoord = vec2 ( fragPos.x * NOISE_RES_X, floor ( fragPos.y * NOISE_RES_Y ) );
	vec3	noise = grnHash3 ( uint ( noiseCoord.x ) + uint ( NOISE_RES_X ) * uint ( noiseCoord.y )
	                          + uint ( NOISE_RES_X ) * uint ( NOISE_RES_Y ) * uint ( iTime * crtRefreshRate ) );
	noise -= 0.5;
	noise.x = clamp ( noise.x * 2.5, -0.5, 0.5 );
	sig += noise * ( decNoise * decNoise );

	// Receiver Y/C separation failure acts on the already-noisy signal
	sig = decGetCrosstalk ( sig, uv, iChannel0 );

	return sig;
}
//-----------------------------------------------------------------------------
