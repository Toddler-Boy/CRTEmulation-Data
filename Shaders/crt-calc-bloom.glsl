uniform float	deltaTime = 0.0;

//-----------------------------------------------------------------------------

void main ()
{
	ivec2	baseSize = textureSize ( iChannel1, 0 );
	int		maxDimension = max ( baseSize.x, baseSize.y );
	int		lastLod = int ( floor ( log2 ( float ( maxDimension ) ) ) );
	vec3	avgColor = texelFetch ( iChannel1, ivec2 ( 0 ), lastLod ).rgb;
	avgColor = pow ( avgColor, vec3 ( 2.2 ) );

	float	targetCurrent = dot ( avgColor, vec3 ( 0.50, 0.31, 0.19 ) );

	const float	settleTime = 0.1;

	float	alpha = 1.0 - exp ( -5.0 * deltaTime / settleTime );
	float	prevCurrent = texelFetch ( iChannel0, ivec2 ( 0 ), 0 ).r;
	float	newCurrent = mix ( prevCurrent, targetCurrent, alpha );

	fragColor = vec4 ( newCurrent );
}
//-----------------------------------------------------------------------------
