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



#define SAMPLE_TYPE_MIDDLE	1.0
#define SAMPLE_TYPE_RIGHT	1.9
#define SAMPLE_TYPE_LEFT	0.7
#define SAMPLE_TYPE_LONER	0.0

//	another sample type!
#define OUTPUT_SCORE_UNWELDABLE	0.2


//	gr: in the old code, some points were rejected AFTER being 
//		invalidated by depth->pos, so check that
//uniform float ClipNearMetres;
bool IsInputSampleGood(vec4 Sample)
{
	//	gr: why does this make a difference, why isn't the jump
	//		when walking catch a very big/very small value here?
/*
	//	this clip value is in metres, and is post-projection, so the value is wrong here
	//	but we're baking good-to-weld here (erk)
	float ClipNearMetres = 0.05;
	if ( Sample.x < ClipNearMetres )
		return false;
/*	if ( Sample.x > 0.50 )
		return false;
	*/return Sample.w > SAMPLE_TYPE_LONER;
}

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

//	check for floating point error
bool FloatMatch(float a,float b)
{
	float diff = abs(a-b);
	return ( diff <= 0.1 );
}

vec4 GetFilledSample(vec2 uv)
{
	return GetSample(uv,vec2(0,0));
}

uniform bool WeldSampleNegX;
//	maybe our sample IS flipped compared to the old texel sample when rendering triangles
uniform bool WeldSampleNegY;

void IsWeldable(vec2 uv,out vec4 OriginSample,out bool Weldable)
{
	OriginSample = GetSample(uv,vec2(0,0));
	vec4 FilledSample = OriginSample;
	
	//	now work out if we're weldable
	//	todo: ensure these are the same samples as the weld code (ie. check flip, or eradicate flipping by now!)
	vec2 RightUv = GetSampleUv(uv,vec2( WeldSampleNegX ? -1:1,0));
	vec2 TopUv = GetSampleUv(uv,vec2(0, WeldSampleNegY ? -1:1));
	vec2 OppUv = GetSampleUv(uv,vec2( WeldSampleNegX ? -1:1,WeldSampleNegY ? -1:1));
	//vec2 RightUv = uv + vec2(InputTexture_TexelSize.x,0);
	//vec2 TopUv = uv + vec2(0,InputTexture_TexelSize.y);
	//vec2 OppUv = uv + vec2(InputTexture_TexelSize.x,InputTexture_TexelSize.y);
	
	//	gr: we can assume the sample will be filled, but we need to know if it's going in the right direction
	//	gr: we need segmentation info here, is the noise-sample score left or right, and does that match our sample
	vec4 RightSample = GetFilledSample(RightUv);
	vec4 TopSample = GetFilledSample(TopUv);
	vec4 OppSample = GetFilledSample(OppUv);

	//	if we are a left-leaning sample we are right-edge
	//	we cannot weld with a right-leaning sample (that is a left edge)
	//	it will only ever be this rejecting combination? (left-middle or middle-right is fine)
	bool Right_ContradictingEdge_LR = FloatMatch(FilledSample.w,SAMPLE_TYPE_LEFT) && FloatMatch(RightSample.w,SAMPLE_TYPE_RIGHT);
	bool Top_ContradictingEdge_LR = FloatMatch(FilledSample.w,SAMPLE_TYPE_LEFT) && FloatMatch(TopSample.w,SAMPLE_TYPE_RIGHT);
	bool Opp_ContradictingEdge_LR = FloatMatch(FilledSample.w,SAMPLE_TYPE_LEFT) && FloatMatch(OppSample.w,SAMPLE_TYPE_RIGHT);
	//	just dont weld different colours and try and work out why vertexes arent matching our samples
	/*
	bool Right_ContradictingEdge_LR = !FloatMatch(FilledSample.w,RightSample.w);
	bool Top_ContradictingEdge_LR = !FloatMatch(FilledSample.w,TopSample.w);
	bool Opp_ContradictingEdge_LR = !FloatMatch(FilledSample.w,OppSample.w);
	*/
	bool Right_ContradictingEdge_RL = FloatMatch(FilledSample.w,SAMPLE_TYPE_RIGHT) && FloatMatch(RightSample.w,SAMPLE_TYPE_LEFT);
	bool Top_ContradictingEdge_RL = FloatMatch(FilledSample.w,SAMPLE_TYPE_RIGHT) && FloatMatch(TopSample.w,SAMPLE_TYPE_LEFT);
	bool Opp_ContradictingEdge_RL = FloatMatch(FilledSample.w,SAMPLE_TYPE_RIGHT) && FloatMatch(OppSample.w,SAMPLE_TYPE_LEFT);
	//bool Right_ContradictingEdge = (FilledSample.w != RightSample.w );
	//bool Top_ContradictingEdge = (FilledSample.w != TopSample.w );
	//bool Opp_ContradictingEdge = (FilledSample.w != OppSample.w );
	
	bool Weldable_LR = (!Right_ContradictingEdge_LR) && (!Top_ContradictingEdge_LR) && (!Opp_ContradictingEdge_LR);
	bool Weldable_RL = (!Right_ContradictingEdge_RL) && (!Top_ContradictingEdge_RL) && (!Opp_ContradictingEdge_RL);
	Weldable = Weldable_LR ;//&& Weldable_RL;

Weldable=true;

	Weldable = Weldable && IsInputSampleGood(RightSample);
	Weldable = Weldable && IsInputSampleGood(TopSample);
	Weldable = Weldable && IsInputSampleGood(OppSample);
	Weldable = Weldable && IsInputSampleGood(OriginSample);

	float WorstNeighbourScore = min( OriginSample.w, min( RightSample.w, min( TopSample.w, OppSample.w ) ) );
	if ( WorstNeighbourScore <= 0.0 )
		Weldable = false;
		
	//FilledSample.w = Weldable ? FilledSample.w : OUTPUT_SCORE_UNWELDABLE;
}


vec4 WeldableFilterFrag(vec2 uv)
{
	vec4 Sample;
	bool Weldable;
	IsWeldable( uv, Sample, Weldable );

	Sample.w = Weldable ? Sample.w : min( Sample.w, OUTPUT_SCORE_UNWELDABLE );

	return Sample;
}

#if !defined(NO_MAIN)
void main()
{
	//	gr: our blitter is obviously wrong, adding 1-more, it flips
	vec2 Sampleuv = vec2( uv.x, 1.0 - uv.y );
	gl_FragColor = WeldableFilterFrag(Sampleuv);
}
#endif
