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

uniform float Steps;
uniform float SampleWalkWeight;
uniform float MaxSampleDiffR_8;
uniform float MaxSampleDiffG_8;
uniform float MaxSampleDiffB_8;
#define MaxSampleDiff	( vec3(MaxSampleDiffR_8,MaxSampleDiffG_8,MaxSampleDiffB_8) / vec3(255.0,255.0,255.0) )

uniform float Debug_Loners;
#define DEBUG_LONERS	(Debug_Loners>0.5)

uniform float LonerMaxWidth;
uniform float WalkStepSize;


float2 GetSampleUv(float2 uv,float PixelOffsetX,float PixelOffsetY)
{
	uv -= fmod( uv, InputTexture_TexelSize.xy );
	//  sample from center of texel
	uv += InputTexture_TexelSize.xy / 2.0;
	uv += InputTexture_TexelSize.xy * vec2(PixelOffsetX,PixelOffsetY);
	return uv;
}

float4 GetSample(float2 uv,float PixelOffsetX,float PixelOffsetY)
{
	uv = GetSampleUv(uv,PixelOffsetX,PixelOffsetY);
	float4 Sample = tex2D( InputTexture, uv );
	return Sample;
}

int GetMatchesHorz(vec2 uv,float Step,out vec4 NewSample,out vec4 EdgeSample)
{
	vec4 Sample0 = GetSample(uv,0.0,0.0);
	NewSample = Sample0;
	#define SampleSteps 5
	//[unroll(SampleSteps)]
	for ( int s=1;	s<=SampleSteps;	s++ )
	{
		float4 Sample4 = GetSample(uv,float(s)*Step,0.0);
		float4 Diff4 = abs(Sample4-Sample0);
		//float Diff = Diff4[Channel];
		//float Diff = max(Diff4.x,max(Diff4.y,Diff4.z));
		float3 Diff = Diff4.xyz;
		EdgeSample = Sample4;
		//if ( Diff.x > MaxSampleDiff.x || Diff.y > MaxSampleDiff.y || Diff.z > MaxSampleDiff.z )
		if ( Diff.x > MaxSampleDiff.x )
		{
			NewSample = Sample0;
			return s-1;
		}
		//	rewrite sample to let walk continue
		Sample0 = lerp(Sample0,Sample4,SampleWalkWeight);
	}
			
	NewSample = Sample0;
	return SampleSteps;
}

#define SAMPLE_TYPE_MIDDLE	1.0
#define SAMPLE_TYPE_RIGHT	1.9
#define SAMPLE_TYPE_LEFT	0.7
#define SAMPLE_TYPE_LONER	0.0

//	gr: possible improvements
//	- scan other directions
//	- detect if I'm not a loner, but surrounded by them (maybe not neccessary if reader scans)
float GetSampleType(vec2 uv)
{
	vec4 LeftColour,LastLeftColour;
	vec4 RightColour,LastRightColour;
	float StepSize = WalkStepSize;
	int Lefts = GetMatchesHorz(uv,-StepSize,LastLeftColour,LeftColour);
	int Rights = GetMatchesHorz(uv,StepSize,LastRightColour,RightColour);

	if ( Lefts+Rights <= int(LonerMaxWidth) )
		return SAMPLE_TYPE_LONER;

	if ( Lefts == Rights )
		return SAMPLE_TYPE_MIDDLE;
	
	//	closer to left than right
	if ( Lefts < Rights )
		return SAMPLE_TYPE_LEFT;
		
	return SAMPLE_TYPE_RIGHT;
}

float4 NoiseMask(vec2 uv)
{
	vec4 Sample = GetSample(uv,0.0,0.0);
	float SampleType = GetSampleType(uv);

	//	if depth has a score or anything other than 0/good, we're losing it here
	if ( Sample.w == 0.0 )
		SampleType = SAMPLE_TYPE_LONER;

	Sample.w = SampleType;

	return Sample;
}

#if !defined(GLSL_NO_MAIN)
void main()
{
	gl_FragColor = NoiseMask(uv);
}
#endif
