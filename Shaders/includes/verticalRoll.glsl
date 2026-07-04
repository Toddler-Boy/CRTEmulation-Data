//-----------------------------------------------------------------------------

float vRollOffset ()
{
	// V-sync roll offset (content only; passed into getSignal)
	float	n = decNoise * decNoise;
	float	amount = smoothstep ( 0.2, 1.0, n );
	if ( amount <= 0.0 )
		return 0.0;

	float	t = iTime;

	// Divide time into episodes (~1.5s each). Each episode independently
	// decides: stay locked, roll through, or roll-and-stall.
	float	ep      = floor ( t * 0.66 );      // episode index (~1.5s)
	float	epLocal = fract ( t * 0.66 );      // 0..1 within episode

	// per-episode random traits
	float	rType  = decRandom_v2_f ( vec2 ( 0.0, ep ), 1.0 );   // decides lock vs roll
	float	rSpeed = decRandom_v2_f ( vec2 ( 1.0, ep ), 1.0 );   // roll-through count
	float	rStall = decRandom_v2_f ( vec2 ( 2.0, ep ), 1.0 );   // stall point

	// is this episode a rolling one? higher amount -> more episodes roll
	float	rolls = step ( 1.0 - amount, rType );
	if ( rolls < 0.5 )
		return 0.0;                            // locked episode -> no roll

	// rolling episode: sweep through, with a stall partway
	float	cycles = 1.0 + floor ( rSpeed * 2.0 );          // 1..3 roll-throughs
	float	stallAt = 0.3 + rStall * 0.4;                   // stall somewhere mid-episode

	// ease: progress normally, but pause near stallAt (flatten the curve there)
	float	prog = epLocal;
	float	stallZone = smoothstep ( stallAt - 0.08, stallAt, prog )
	                  * ( 1.0 - smoothstep ( stallAt, stallAt + 0.12, prog ) );
	prog -= stallZone * 0.12;                               // flatten -> bar parks briefly

	float	erratic = fract ( prog * cycles );

	// at high amount, blend toward pure fast continuous roll (total sync loss)
	float	freeRun = fract ( t * 4.0 );                    // fast constant tumble
	float	chaos   = smoothstep ( 0.8, 1.0, amount );      // kicks in only near max

	return mix ( erratic, freeRun, chaos );
}
//-----------------------------------------------------------------------------
