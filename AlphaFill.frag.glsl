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

uniform bool EnableAlphaFill;
#define APPLY_FILL	EnableAlphaFill

uniform float Debug_Filled;
#define DEBUG_FILLED	(Debug_Filled>0.5)

uniform float Debug_Failed;
#define DEBUG_FAILED	(Debug_Failed>0.5)


//	input score == noise output
#define SAMPLE_TYPE_MIDDLE	1.0
#define SAMPLE_TYPE_RIGHT	0.9
#define SAMPLE_TYPE_LEFT	0.8
#define SAMPLE_TYPE_LONER	0.0

#define OUTPUT_SCORE_WELDABLE	1.0
#define OUTPUT_SCORE_WELDABLE_CORRECTED	0.9
#define OUTPUT_SCORE_UNWELDABLE	0.5
#define OUTPUT_SCORE_CORRECTED	0.4
#define OUTPUT_SCORE_INVALID	0.0

vec2 GetSampleUv(vec2 uv,vec2 PixelOffset)
{
	// sample from center of texel
	uv -= fmod( uv, InputTexture_TexelSize.xy );
	uv += InputTexture_TexelSize.xy / 2.0;

	//	now jump to next texel
	uv += InputTexture_TexelSize.xy * PixelOffset;

	return uv;
}

vec4 GetSample(vec2 uv,vec2 PixelOffset)
{
	uv = GetSampleUv(uv,PixelOffset);
	vec4 Sample4 = tex2D( InputTexture, uv );
	return Sample4;
}

int WalkToGoodSample(vec2 uv,vec2 Step,out vec4 NewSample)
{
#define SampleSteps 6
	for ( int s=1;	s<=SampleSteps;	s++ )
	{
		float sf = float(s);
		vec4 SampleX = GetSample(uv, vec2(sf,sf) * Step );

		NewSample = SampleX;
		if ( SampleX.w > 0.0 )
			return s;
	}
				
	NewSample = vec4(0,0,0,0);
	return SampleSteps;
}

bool IsInputSampleBad(vec4 Sample)
{
	return Sample.w <= SAMPLE_TYPE_LONER;
}

bool IsInputSampleGood(vec4 Sample)
{
	return Sample.w > SAMPLE_TYPE_LONER;
}

bool IsOutputSampleBad(vec4 Sample)
{
	return Sample.w < OUTPUT_SCORE_CORRECTED;
}	

bool IsOutputSampleGood(vec4 Sample)
{
	return Sample.w >= OUTPUT_SCORE_CORRECTED;
}	

vec4 GetGoodNeighbour(vec2 uv)
{
	//	gr: should this not be left/right? we're using it to see if we're an edge vs weldable 
	#define SAMPLE_TYPE_NOTHORZ	SAMPLE_TYPE_MIDDLE
	
	//	gr: this might be better as a guassian sample map, but we explicitly do want to walk sideways as that's where we've cut stuff from
	#define DIR_COUNT  8
	vec4 Directions[DIR_COUNT];
	Directions[0] = vec4(-1,0,	0, SAMPLE_TYPE_LEFT );
	Directions[1] = vec4(1,0,	0, SAMPLE_TYPE_RIGHT );
	Directions[2] = vec4(0,-1,	0, SAMPLE_TYPE_NOTHORZ );	
	Directions[3] = vec4(0,1,	0, SAMPLE_TYPE_NOTHORZ );
	#if DIR_COUNT>4
	Directions[4] = vec4(-1,-1,	0, SAMPLE_TYPE_NOTHORZ );
	Directions[5] = vec4(1,-1,	0, SAMPLE_TYPE_NOTHORZ );
	Directions[6] = vec4(1,1,	0, SAMPLE_TYPE_NOTHORZ );
	Directions[7] = vec4(-1,1,	0, SAMPLE_TYPE_NOTHORZ );
	#endif
	float StepSize = 2.0;
	vec4 DirSamples[DIR_COUNT];
	int DirSteps[DIR_COUNT];
	for ( int d=0;  d<DIR_COUNT;    d++)
	{
		DirSteps[d] = WalkToGoodSample( uv, Directions[d].xy*StepSize, DirSamples[d] );
	}

	vec4 BestSample = DirSamples[0];
	int BestSteps = DirSteps[0];
	for ( int d=0;	d<DIR_COUNT;	d++ )
	{
		bool Better = IsInputSampleBad(BestSample) || (DirSteps[d]<BestSteps);
		Better = Better && IsInputSampleGood(DirSamples[d]);
		BestSample = lerp( BestSample, DirSamples[d], Better ? 1.0 : 0.0 );
		BestSteps = int(lerp( float(BestSteps), float(DirSteps[d]), Better ? 1.0 : 0.0 ));
	}
	return BestSample;
}

vec4 GetFilledSample(vec2 uv)
{
	vec4 Input = GetSample(uv,vec2(0.0,0.0) );
	if ( IsInputSampleGood(Input) )
	{
		//Input.w = OUTPUT_SCORE_WELDABLE;
		return Input;
	}
	
	if ( !APPLY_FILL )
	{
		//Input.w = OUTPUT_SCORE_INVALID;
		return Input;
	}		
	
	//	we are a hole, find good neighbour to fill with
	vec4 GoodSample = GetGoodNeighbour(uv);
	/*
	if ( IsInputSampleGood(GoodSample) )
		GoodSample.w = OUTPUT_SCORE_WELDABLE_CORRECTED;
	else
		GoodSample.w = OUTPUT_SCORE_INVALID;
	*/
	return GoodSample;
}


vec4 AlphaFillFrag(vec2 uv)
{
	vec4 FilledSample = GetFilledSample(uv);
	
	//	couldn't fill
	if ( IsInputSampleBad(FilledSample) )
	{
		return FilledSample;
	}

	//	now work out if we're weldable
	//	todo: ensure these are the same samples as the weld code (ie. check flip, or eradicate flipping by now!)
	vec2 RightUv = GetSampleUv(uv,vec2(1,0));
	vec2 TopUv = GetSampleUv(uv,vec2(0,1));
	vec2 OppUv = GetSampleUv(uv,vec2(1,1));
	
	//	gr: we can assume the sample will be filled, but we need to know if it's going in the right direction
	//	gr: we need segmentation info here, is the noise-sample score left or right, and does that match our sample
	vec4 RightSample = GetFilledSample(RightUv);
	vec4 TopSample = GetFilledSample(TopUv);
	vec4 OppSample = GetFilledSample(OppUv);

	//	if we are a left-leaning sample we are right-edge
	//	we cannot weld with a right-leaning sample (that is a left edge)
	//	it will only ever be this rejecting combination? (left-middle or middle-right is fine)
	bool Right_ContradictingEdge = (FilledSample.w == SAMPLE_TYPE_LEFT) && (RightSample.w == SAMPLE_TYPE_RIGHT);
	bool Top_ContradictingEdge = (FilledSample.w == SAMPLE_TYPE_LEFT) && (TopSample.w == SAMPLE_TYPE_RIGHT);
	bool Opp_ContradictingEdge = (FilledSample.w == SAMPLE_TYPE_LEFT) && (OppSample.w == SAMPLE_TYPE_RIGHT);
	
	bool Weldable = (!Right_ContradictingEdge) && (!Top_ContradictingEdge) && (!Opp_ContradictingEdge);

	Weldable = Weldable && IsInputSampleGood(RightSample);
	Weldable = Weldable && IsInputSampleGood(TopSample);
	Weldable = Weldable && IsInputSampleGood(OppSample);

	/*
	bool RightGood = IsOutputSampleGood(RightSample);
	bool TopGood = IsOutputSampleGood(TopSample);
	bool OppGood = IsOutputSampleGood(OppSample);
	bool Weldable = RightGood && TopGood && OppGood;
	*/
	FilledSample.w = Weldable ? FilledSample.w : OUTPUT_SCORE_UNWELDABLE;

	return FilledSample;
}



#if !defined(NO_MAIN)
void main()
{
	gl_FragColor = AlphaFillFrag(uv);
}
#endif
