precision highp float;

//	from quad shader (webgl)
varying vec2 uv;

//	unity->glsl conversion
#define lerp mix
#define tex2D texture2D
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float4x4 mat4
#define trunc	floor
#define fmod(x,y)	(x - y * trunc(x / y))
#define mul(Matrix,Vector)	(Matrix*Vector)

uniform sampler2D InputTexture;
uniform vec2 InputTextureSize;
#define InputTexture_TexelSize	vec4(1.0/InputTextureSize.x,1.0/InputTextureSize.y,InputTextureSize.x,InputTextureSize.y)


vec4 WeldableFilterFrag(vec2 uv)
{
	vec4 Sample4 = tex2D( InputTexture, uv );
	return Sample4;
}

#if !defined(NO_MAIN)
void main()
{
	gl_FragColor = WeldableFilterFrag(uv);
}
#endif
