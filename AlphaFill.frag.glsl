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

uniform float EnableAlphaFill;
#define APPLY_FILL	(EnableAlphaFill>0.5)

uniform float Debug_Filled;
#define DEBUG_FILLED	(Debug_Filled>0.5)

uniform float Debug_Failed;
#define DEBUG_FAILED	(Debug_Failed>0.5)

vec2 GetSampleUv(vec2 uv,float PixelOffsetX,float PixelOffsetY)
{
	uv -= fmod( uv, InputTexture_TexelSize.xy );
	//  sample from center of texel
	uv += InputTexture_TexelSize.xy / 2.0;
	uv += InputTexture_TexelSize.xy * vec2(PixelOffsetX,PixelOffsetY);
	return uv;
}

vec4 GetSample(vec2 uv,float PixelOffsetX,float PixelOffsetY)
{
	uv = GetSampleUv(uv,PixelOffsetX,PixelOffsetY);
	vec4 Sample4 = tex2D( InputTexture, uv );
	return Sample4;
}

int WalkToGoodSample(vec2 uv,vec2 Step,out vec4 NewSample)
{
#define SampleSteps 6
	for ( int s=1;	s<=SampleSteps;	s++ )
	{
		vec4 SampleX = GetSample(uv,float(s)*Step.x,float(s)*Step.y);

		NewSample = SampleX;
		if ( SampleX.w > 0.0 )
			return s;
	}
				
	NewSample = vec4(0,0,0,0);
	return SampleSteps;
}


vec4 GetGoodNeighbour(vec2 uv)
{
	//	gr: this might be better as a guassian sample map, but we explicitly do want to walk sideways as that's where we've cut stuff from
	#define DIR_COUNT  8
	vec2 Directions[DIR_COUNT];
	Directions[0] = vec2(-1,0);
	Directions[1] = vec2(1,0);
	Directions[2] = vec2(0,-1);
	Directions[3] = vec2(0,1);
	#if DIR_COUNT>4
	Directions[4] = vec2(-1,-1);
	Directions[5] = vec2(1,-1);
	Directions[6] = vec2(1,1);
	Directions[7] = vec2(-1,1);
	#endif
	float StepSize = 2.0;
	vec4 DirSamples[DIR_COUNT];
	int DirSteps[DIR_COUNT];
	for ( int d=0;  d<DIR_COUNT;    d++)
	{
		DirSteps[d] = WalkToGoodSample( uv, Directions[d]*StepSize, DirSamples[d] );
	}

	vec4 BestSample = DirSamples[0];
	int BestSteps = DirSteps[0];
	for ( int d=0;  d<DIR_COUNT;    d++ )
	{
		bool Better = (BestSample.w < 1.0) || (DirSteps[d]<BestSteps);
		Better = Better && (DirSamples[d].w > 0.0);
		BestSample = lerp( BestSample, DirSamples[d], Better ? 1.0 : 0.0 );
		BestSteps = int(lerp( float(BestSteps), float(DirSteps[d]), Better ? 1.0 : 0.0 ));
	}
	return BestSample;
}

vec4 AlphaFillFrag(vec2 uv)
{
	vec4 Input = GetSample(uv,0.0,0.0);

	//  just blit good samples
	if ( Input.w > 0.0 || !APPLY_FILL )
		return Input;

	vec4 NewSample = GetGoodNeighbour(uv);

	if ( DEBUG_FAILED && NewSample.w < 1.0 )
		return NewSample * vec4(1,0,0,0);

	if ( DEBUG_FILLED && NewSample.w > 0.0 )
		return NewSample * vec4(0,1,0,1);

	return NewSample;
}

#if !defined(NO_MAIN)
void main()
{
	gl_FragColor = AlphaFillFrag(uv);
}
#endif
