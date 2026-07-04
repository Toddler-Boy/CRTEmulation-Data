//-----------------------------------------------------------------------------

vec3 getSignal ( vec2 fragPos, float angle, float rollOffset )
{
	// --- single quality slider -> staggered per-effect amounts ---
	float	n = decNoise * decNoise;

	const float	NOISE_RES_X = 1280.0;
	const float NOISE_RES_Y = 272.0;
	const float BLACK_LEVEL = 0.05;

	// Interference: this line's own horizontal jitter
	vec2	uv = decCreateInterference ( fragPos, n );

	// roll applies ONLY to the picture content lookup
	float	barH = 0.05;
	float	rolling = smoothstep ( 0.0, 0.05, rollOffset ) * smoothstep ( 1.0, 0.95, rollOffset );
	float	effBarH = barH * rolling;
	float	y = fract ( uv.y + rollOffset );
	vec2	rolledUV = uv;
	rolledUV.y = ( y - effBarH ) / ( 1.0 - effBarH );

	// Bandwidth limit (luma full, chroma reduced)
	vec3	sig = vec3 ( 0.0 );
	if ( uv.x >= 0.0 && uv.x <= 1.0 && rolledUV.y >= 0.0 && rolledUV.y <= 1.0 )
		sig = decGetBlurredSignal ( rolledUV, iChannel0 );

	// Phase shift chroma
	vec2	sc = vec2 ( cos ( angle ), sin ( angle ) );
	sig.yz = mat2 ( sc, -sc.y, sc.x ) * sig.yz;

	// Signal pedestal: lift black off zero so noise has symmetric headroom
	sig.x = sig.x * ( 1.0 - BLACK_LEVEL ) + BLACK_LEVEL;

	// --- Transmission noise: fine grain + impulsive spikes -------------------
	// One combined system driven by decNoise. Grain gives constant texture;
	// spikes punch through the rails so snow stays visible in black AND white.

	float	noiseAmt = n;

	// (a) Fine grain — line-coherent, additive
	vec2	noiseCoord = vec2 ( fragPos.x * NOISE_RES_X, floor ( fragPos.y * NOISE_RES_Y ) );
	vec3	noise = grnHash3 (  uint ( noiseCoord.x ) + uint ( NOISE_RES_X ) * uint ( noiseCoord.y )
							  + uint ( NOISE_RES_X ) * uint ( NOISE_RES_Y ) * uint ( iTime * crtRefreshRate ) );
	sig += ( noise - 0.5 ) * noiseAmt * 2.5;

	// (b) Impulsive spikes — per-pixel, per-frame, full-amplitude.
	// These REPLACE luma rather than add, so they survive at the rails:
	// a white spike shows on black, a black spike shows on white.
	float	spikeHash = grnHash3 ( uint ( fragPos.x * NOISE_RES_X ) * 7u + 3u
								 + uint ( NOISE_RES_X ) * uint ( fragPos.y * NOISE_RES_Y ) * 13u
								 + uint ( NOISE_RES_X ) * uint ( NOISE_RES_Y )
								 * uint ( iTime * crtRefreshRate ) * 17u ).x;

	float	spikeRate = smoothstep ( 0.1, 1.0, noiseAmt ) * 0.15;
	if ( spikeHash > 1.0 - spikeRate )
	{
		float	pol = step ( 0.5, fract ( spikeHash * 91.7 ) );   // 0 = black, 1 = white
		sig.x = pol;                                              // hard replace -> punches rails

		// faint chroma fringe on some spikes (not all, not full-amplitude)
		float	cHash = fract ( spikeHash * 47.3 );
		sig.yz += vec2 ( cHash, fract ( cHash * 7.0 ) ) - 0.5;   // small colored fringe
	}

	// Chroma dropout: color dies before luma as signal weakens.
	// Global desaturation + blotchy per-region loss.
	float	chromaLoss = smoothstep ( 0.1, 0.7, noiseAmt );
	if ( chromaLoss > 0.0 )
	{
		vec2	bc = vec2 ( fragPos.x * 8.0, fragPos.y * 6.0 );
		vec2	bf = smoothstep ( 0.0, 1.0, fract ( bc ) );
		vec2	bi = floor ( bc );

		uint	bx = uint ( bi.x );
		uint	by = uint ( bi.y );
		uint	time_offset = 4096u * uint ( floor ( iTime * crtRefreshRate * 0.3 ) );

		float	h00 = grnHash3 (   bx			+ 64u * by			+ time_offset ).x;
		float	h10 = grnHash3 ( ( bx + 1u )	+ 64u * by			+ time_offset ).x;
		float	h01 = grnHash3 ( bx				+ 64u * ( by + 1u ) + time_offset ).x;
		float	h11 = grnHash3 ( (bx + 1u )		+ 64u * ( by + 1u ) + time_offset ).x;

		float	blotch = mix ( mix ( h00, h10, bf.x ), mix ( h01, h11, bf.x ), bf.y );
		float	keep = ( 1.0 - chromaLoss ) * mix ( 1.0, blotch, chromaLoss );

		sig.yz *= keep;
	}

	// Receiver Y/C separation failure acts on the already-noisy signal
	sig = decGetCrosstalk ( sig, rolledUV, iChannel0 );

	return sig;
}
//-----------------------------------------------------------------------------
