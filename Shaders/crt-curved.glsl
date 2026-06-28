#include "includes/mathDefines.glsl"
#include "includes/common.glsl"
#include "includes/colorSpaces.glsl"

//-----------------------------------------------------------------------------

uniform float crtDistortion = 0.3;

//-----------------------------------------------------------------------------

vec2 glassDistortion ( vec2 uv, float k1, float xRatio )
{
	vec2	zoom = vec2 ( 1.0 / ( k1 + 1.0 ), 1.0 / ( k1 + 1.0 ) );

	// 0 to 1 -> -1 to +1
	vec2	cuv = ( uv * 2.0 - 1.0 ) * zoom;

	// Barrel distortion
	cuv *= 1.0 + k1 * ( cuv.x * cuv.x + cuv.y * cuv.y );

	// Add unevenness to glass surface
	cuv += sin ( cuv * PI * 2.5 + PI ) * vec2 ( 0.006, 0.012 ) * k1;// * sin ( iTime ) * 50.0;

	cuv.x *= xRatio;

	// -1 to + 1 -> 0 to 1
	cuv = cuv * 0.5 + 0.5;

	return cuv;
}
//-----------------------------------------------------------------------------

uniform float	crtVignette = 0.33;

float vignette ( vec2 uv )
{
	uv *= 1.0 - uv;
	return clamp ( pow ( uv.x * uv.y * 64.0, crtVignette * 0.25 ), 0.0, 1.0 );
}
//-----------------------------------------------------------------------------

vec3 screen ( vec3 base, vec3 blend )
{
	return 1.0 - ( 1.0 - base) * ( 1.0 - blend );
}
//-----------------------------------------------------------------------------

vec3 add ( vec3 base, vec3 blend )
{
	return base + blend;
}
//-----------------------------------------------------------------------------

uniform bool	crtSource = true;
uniform float	crtReflection = 0.25;
uniform float	crtRflCorrection = 1.0;

uniform vec3	backCol = vec3 ( 0.0, 0.0, 0.0 );

uniform	vec3	camBrightnessContrastSaturation = vec3 ( 1.0, 1.0, 1.0 );
uniform int		crtWebcamFormat = 0;

uniform vec3	yuvCol0;
uniform vec3	yuvCol1;
uniform vec3	yuvCol2;
uniform vec3	yuvBias;

void main ()
{
	vec2	cuv = curve ( fragCoord, crtCurve );
	vec3	col = texture ( iChannel0, cuv ).rgb;

	// Add vignette
	col *= vignette ( cuv );

	// Reflection in glass
	const vec3	glassTint = vec3 ( 0.8, 0.9, 1.0 );

	vec3	rfl = vec3 ( 0.0 );

	if ( crtSource )
	{
		// Glass distortion
		vec2	camCoord = glassDistortion ( vec2 ( 1.0 ) - fragCoord, crtDistortion, crtRflCorrection );

		// Webcam (NV12 only for now)
		vec3	yuv = vec3 ( texture ( iChannel2, camCoord ).r, texture ( iChannel3, camCoord ).rg );

		mat3	yuvMat = mat3 ( yuvCol0, yuvCol1, yuvCol2 );
		rfl = clamp ( yuvMat * yuv + yuvBias, 0.0, 1.0 );
	}
	else
	{
		// Glass reflection texture
		rfl = texture ( iChannel1, glassDistortion ( fragCoord, crtDistortion * 0.1, 1.0 ) ).rgb;
	}

	vec3	colLin = srgbToLinear ( col );
	vec3	rflLin = srgbToLinear ( rfl );

	vec3	blend  = ( rflLin * rflLin * rflLin ) * 0.25 * crtReflection * glassTint;

	vec3	outLin = screen ( colLin, blend );

	col = linearToSrgb ( outLin );
//	col = vec4 ( 0.0 );
//	col = rfl;

	// Mask out corners, no CRT has 90 degree angles
	float	mask = roundedMask ( cuv * iResolution.xy, iResolution.xy, iResolution.x * 0.03 );

	// Apply mask
	col = mix ( backCol, col, mask );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
