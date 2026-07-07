//-----------------------------------------------------------------------------

float lodForRadius ( sampler2D tex, float frac )
{
	return log2 ( frac * float ( textureSize ( tex, 0 ).y ) );
}
//-----------------------------------------------------------------------------

vec4 getMipMapColor ( sampler2D tex, vec2 uv, float lod )
{
	float	bias = 0.5 / lod;
	vec2	offset = ( bias / textureSize ( tex, int ( lod ) ) );
	vec4	pix = textureLod ( tex, uv + offset, lod );

	return pix;
}
//-----------------------------------------------------------------------------

vec3 getMipMapColorJittered ( sampler2D tex, vec2 uv, float lod )
{
	vec2	texel = exp2 ( lod ) / vec2 ( textureSize ( tex, 0 ) );

	vec3	s;
	s  = textureLod ( tex, uv + texel * vec2 ( -0.4, -0.4 ), lod ).rgb;
	s += textureLod ( tex, uv + texel * vec2 (  0.4, -0.4 ), lod ).rgb;
	s += textureLod ( tex, uv + texel * vec2 ( -0.4,  0.4 ), lod ).rgb;
	s += textureLod ( tex, uv + texel * vec2 (  0.4,  0.4 ), lod ).rgb;

	return s * 0.25;
}
//-----------------------------------------------------------------------------
