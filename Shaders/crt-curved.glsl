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

uniform float	crtVignette = 0.15;

float vignette ( vec2 uv )
{
	// Zoom in a tiny bit to hide hard-edges
	uv -= 0.5;
	uv *= 0.995;
	uv += 0.5;

	float	bias = 1.0 + dot ( uv - 0.5, vec2 ( 0.65, 0.40 ) * crtVignette );

	uv *= 1.0 - uv;

	return 1.0 - clamp ( pow ( uv.x * uv.y * 512.0, crtVignette * bias * 0.5 ), 0.0, 1.0 );
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
uniform float	camZoom = 1.0;
uniform int		crtWebcamFormat = 0;

uniform vec3	yuvCol0;
uniform vec3	yuvCol1;
uniform vec3	yuvCol2;
uniform vec3	yuvBias;

//-----------------------------------------------------------------------------

/*vec2 getCurveWithBloom ( vec2 uv, float level )
{
	const vec2	bloomFactor = vec2 ( 0.03, 0.03 / 1.4 );

	// Get interpolated current level
	float	frameCurrent = texelFetch ( iChannel1, ivec2 ( 0 ), 0 ).r;
	vec2	bloomedCoord = ( uv - 0.5 ) * ( 1.0 - ( frameCurrent * bloomFactor * crtBloomExpansion ) ) + 0.5;

	vec2	cRaw = ( uv - 0.5) * 2.0;
	vec2	cBloom = ( bloomedCoord - 0.5 ) * 2.0;

	vec2	distortionStrength = abs ( cRaw.yx ) / vec2 ( 5.0, 4.0 );
	vec2	distortionFactor = 1.0 + distortionStrength * distortionStrength;

	cBloom *= distortionFactor;

	vec2	finalWarpedUV = cBloom / 2.0 + 0.5;

	return mix ( bloomedCoord, finalWarpedUV, level );
}
*/
//-----------------------------------------------------------------------------

vec3 gausBlurWebcam ( sampler2D textY, sampler2D textUV, vec2 uv, float radius )
{
	float	lod = log2 ( max ( 1.0, radius * 5.0 ) );

	vec2	currentTexSize = textureSize ( textY, int ( lod ) );
	vec2	texelSize = 1.0 / vec2 ( currentTexSize );
	float	fractionalRadius = fract ( lod ) + 1.0;
	vec2	scale = texelSize * fractionalRadius;

	vec3	accumYUV = vec3 ( 0.0 );
	float	accumWeight = 0.0;

	const float samples = 8.0;
	for ( float i = -samples; i <= samples; i++ )
	{
		float weight = exp ( -0.5 * ( i * i ) / ( samples * samples ) );
		vec2  offset = vec2 ( i / samples ) * scale;

		// --- HORIZONTAL PASS ---
		vec2  uvH = uv + vec2 ( offset.x, 0.0 );
		float yH  = textureLod ( textY,  uvH, lod ).r;
		vec2  uv2H = textureLod ( textUV, uvH, max(0.0, lod - 1.0) ).rg;

		// --- VERTICAL PASS ---
		vec2  uvV = uv + vec2 ( 0.0, offset.y );
		float yV  = textureLod ( textY,  uvV, lod ).r;
		vec2  uv2V = textureLod ( textUV, uvV, max(0.0, lod - 1.0) ).rg;

		// Accumulate raw YUV channels directly [1]
		accumYUV += vec3(yH, uv2H) * weight;
		accumYUV += vec3(yV, uv2V) * weight;

		accumWeight += weight * 2.0; // Two samples per step
	}

	return accumYUV / accumWeight;
}
//-----------------------------------------------------------------------------

uniform float	crtAmbient = 0.5;

vec3 ambient ( vec3 col )
{
	vec3	ambientCol = mix ( vec3 ( 1.0, 0.890, 1.118 ), vec3 ( 1.0, 0.787, 1.376 ), crtAmbient );
	return max ( col, crtAmbient * 0.02 * ambientCol );
}
//-----------------------------------------------------------------------------

void main ()
{
	// Get CRT curvature
	vec2	cuv = curve ( fragCoord, crtCurve );
	vec3	col = texture ( iChannel0, cuv ).rgb;

	// Add vignette
	col = mix ( col, ambient ( vec3 ( 0.0 ) ), vignette ( cuv ) );

	// Phosphor has its own color
	col = ambient ( col );

	// Reflection in glass
	const vec3	glassTint = vec3 ( 0.8, 0.9, 1.0 );

	vec3	rfl = vec3 ( 0.0 );

	if ( crtSource )
	{
		// Glass distortion
		vec2	camCoord = glassDistortion ( vec2 ( 1.0 ) - fragCoord, crtDistortion, crtRflCorrection );

		// Zoom shrinks the sample window around center, the distortion shape
		// stays that of the full glass
		camCoord = ( camCoord - 0.5 ) / camZoom + 0.5;
//		vec3	yuv = gausBlurWebcam ( iChannel2, iChannel3, camCoord, 2.0 );

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

	vec3	rflLin = srgbToLinear ( rfl );
	vec3	blend  = ( rflLin * rflLin * rflLin ) * 0.125 * crtReflection * glassTint;

	vec3	outLin = screen ( col, blend );

	col = linearToSrgb ( outLin );
//	col = rfl;

	// Mask out corners, no CRT has 90 degree angles
	float	mask = roundedMask ( cuv * iResolution.xy, iResolution.xy, iResolution.x * 0.03 );

	// Apply mask
	col = mix ( backCol, col, mask );

	fragColor = vec4 ( col, 1.0 );
}
//-----------------------------------------------------------------------------
