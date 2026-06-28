#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/colorGrade.glsl"
#include "includes/grain.glsl"

//-----------------------------------------------------------------------------

vec3 gausBlur ( vec2 uv, float radius )
{
	float	lod = log2 ( radius * 5.0 );
	vec2	scale = vec2 ( 4.0 / 1080.0, 4.0 / 813.0 ) * radius;
	vec3	col = vec3 ( 0.0 );
	float	accum = 0.0;

	const float samples = 8.0;
	for ( float i = -samples; i <= samples; i++ )
	{
		float	weight = exp ( -0.5 * ( i * i ) / ( samples * samples ) );
		vec2	offset = vec2 ( i / samples ) * scale;

		vec3	clipper  = textureLod ( iChannel0, uv + vec2 ( offset.x, 0.0 ), lod ).rgb;
				clipper += textureLod ( iChannel0, uv + vec2 ( 0.0, offset.y ), lod ).rgb;

		// Remove ambient color
		clipper = clamp ( clipper - 0.2, 0.0, 1.0 ) * 1.25;
		float	lum = dot ( clipper, vec3 ( 0.299, 0.587, 0.114 ) );
		float	targetLum = mix ( lum, 1.0 - lum, 0.15 );
		clipper *= targetLum / max ( lum, 0.01 );

		col += clipper * weight;
		accum += weight;
	}

	return col / accum;
}
//-----------------------------------------------------------------------------

uniform float rflFold = 3.0;   // overlap fold multiplier; tune per-overlay

vec2 foldOverlap ( vec2 uv )
{
	float dl = uv.x, dr = 1.0 - uv.x, dt = uv.y, db = 1.0 - uv.y;
	if ( dl > 0.0 && dr > 0.0 && dt > 0.0 && db > 0.0 )
	{
		float mx = min ( dl, dr );
		float my = min ( dt, db );
		if ( mx < my )
			uv.x = ( dl < dr ) ? -dl * rflFold
			                   :  1.0 + dr * rflFold;
		else
			uv.y = ( dt < db ) ? -dt * rflFold
			                   :  1.0 + db * rflFold;
	}
	return uv;
}
//-----------------------------------------------------------------------------

uniform float	rflLevel;

uniform vec2	rflZoom = vec2 ( 1.0 );
uniform vec2	rflShift = vec2 ( 0.0 );
uniform int		rflRadius = 2;

uniform float	ovlGrain = 0.2;

void main ()
{
	// iChannel0 = CRT texture as blur-source
	// iChannel1 = Bezel texture to blend into
	// iChannel2 = 3D LUT for color grading (day to dusk)
	// iChannel3 = 3D LUT for color grading (dusk to night)
	vec4	mask = texture ( iChannel1, fragCoord );

	if ( mask.a < ( 1.0 / 255.0 ) )
		discard;

	// Unmultiply alpha
	mask.rgb /= mask.a;

	// Color grade
	mask.rgb = colorGrade ( mask.rgb, iChannel2, iChannel3 );

	// Reflection
	vec2	uv = curve ( fragCoord, crtCurve );

	// Bezel
	uv -= 0.5;
	uv *= rflZoom;
	uv += rflShift;
	uv += 0.5;
	uv = foldOverlap ( uv );
	vec3	col = gausBlur ( uv, rflRadius ) * rflLevel;

	col += mask.rgb;
	col *= grnGrain ( uvec2 ( fragCoord * iResolution.xy ), ovlGrain );

	fragColor = vec4 ( col * mask.a, mask.a );
}
//-----------------------------------------------------------------------------
