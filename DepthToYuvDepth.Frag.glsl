precision highp float;

//	from quad shader (webgl)
varying vec2 uv;


uniform float Encoded_ChromaRangeCount;
uniform float Encoded_DepthMinMetres;
uniform float Encoded_DepthMaxMetres;
uniform float Encoded_LumaPingPong;
uniform float DepthInput_ToMetres;

uniform sampler2D DepthTexture;
uniform vec2 DepthTextureSize;
#define DepthTexture_TexelSize	vec2(1.0/DepthTextureSize.x,1.0/DepthTextureSize.y)
uniform float FlipDepthTexture;

uniform vec2 OutputImageSize;


float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

float Range01(float Min,float Max,float Value)
{
	Value = Range( Min, Max, Value );
	return clamp( Value, 0.0, 1.0 );
}

void GetPlaneVs_8_8_8(out float LumaBottom,out float ChromaUBottom)
{
	//	layout is w x h luma
	//			+ w/2 x h/2 chroma u
	//			+ w/2 x h/2 chroma v
	//	in BYTES, so a row is twice as long in chroma
	float LumaWeight = 1.0 * 1.0;
	float ChromaUWeight = 0.5 * 0.5;
	float ChromaVWeight = 0.5 * 0.5;
	float TotalWeight = LumaWeight + ChromaUWeight + ChromaVWeight;
	LumaWeight /= TotalWeight;
	ChromaUWeight /= TotalWeight;
	ChromaVWeight /= TotalWeight;
	LumaBottom = LumaWeight;
	ChromaUBottom = LumaBottom + ChromaUWeight;
}

bool BitwiseAndOne(int Value)
{
	//	return Value & 1;
	int WithoutBit1 = (Value / 2) * 2;
	return ( Value != WithoutBit1 );
}

//	for an output(uv), work out which plane we're writing out, 
//	and where on the original image we want to sample 
void GetOutputUv_8_8_8(vec2 OutputImageUv,vec2 OutputImageSize,out vec2 PlaneSampleUv,out int PlaneIndex)
{
	//	Luma
	//	ChromaU (half width & half height, so 1/4 height and two rows per row)
	//	ChromaV ^^same
	float LumaTop = 0.0;
	float ChromaUTop;
	float ChromaVTop;
	GetPlaneVs_8_8_8(ChromaUTop,ChromaVTop);
	float LumaBottom = ChromaUTop;
	float ChromaUBottom = ChromaVTop;
	float ChromaVBottom = 1.0;

	if ( OutputImageUv.y < LumaBottom )
	{
		PlaneSampleUv.x = OutputImageUv.x;
		PlaneSampleUv.y = Range( LumaTop, LumaBottom, OutputImageUv.y );
		PlaneIndex = 0;
		return;
	}
	
	//	get plane-space uv
	vec2 OutputPlaneUv;
	OutputPlaneUv.x = OutputImageUv.x;
	if ( OutputImageUv.y < ChromaVTop )
	{
		//	ChromaU
		PlaneIndex = 1;	
		OutputPlaneUv.y = Range( ChromaUTop, ChromaUBottom, OutputImageUv.y );
	}
	else
	{
		PlaneIndex = 2;
		OutputPlaneUv.y = Range( ChromaVTop, ChromaVBottom, OutputImageUv.y );
	}
	
	//	now the chroma planes are 1/4 size
	
	//	this is the plane's normal size
	float ChromaWidth = OutputImageSize.x / 2.0;
	float ChromaHeight = OutputImageSize.y / 2.0;
	
	//	but it's spread out to 2 rows per row
	//	as they're half the width, so rows appear side by side in the image
	//		000111
	//		222333
	//		444555
	//	so the pixels are twice wide and half height
	float OutputChromaWidth = ChromaWidth * 2.0;
	float OutputChromaHeight = ChromaHeight / 2.0;
	//	now we have output uv as pixels
	float Outputx = OutputPlaneUv.x * OutputChromaWidth;
	float Outputy = OutputPlaneUv.y * OutputChromaHeight;

	//	now move these pixels from DoubleWideHalfHeight back to normal plane size
	Outputy *= 2.0;
	//	move this pixel from right half onto it's odd row
	if ( Outputx >= ChromaWidth )
	{
		Outputy += 1.0;
		Outputx -= ChromaWidth;
	}
	
	//	back to uv in the proper size
	PlaneSampleUv.x = Outputx / ChromaWidth;
	PlaneSampleUv.y = Outputy / ChromaHeight;
}



vec3 DepthToYuv(float Depth)
{
	//	quick 1 chroma implementation
	float Lumaf = Range01( Encoded_DepthMinMetres, Encoded_DepthMaxMetres, Depth );
	
	vec2 Chromauv = vec2(1,1);
	return vec3( Lumaf, Chromauv );
}

float GetDepthSample(vec2 uv)
{
	//	convert input to depth
	float Depth = texture2D( DepthTexture, uv ).x;
	Depth *= DepthInput_ToMetres;
	return Depth;
}


#if !defined(NO_MAIN)
void main()
{
	//	we're expecting planes to go from 0 at the top, so this is to flip the output DATA
	vec2 OutputUv = vec2(uv.x,1.0-uv.y);
	vec2 DepthSampleUv;
	int DepthPlaneIndex;
	GetOutputUv_8_8_8( OutputUv, OutputImageSize, DepthSampleUv, DepthPlaneIndex );

	//DepthSampleUv.y = (FlipDepthTexture>0.5) ? 1.0-DepthSampleUv.y : DepthSampleUv.y;
	float Depth = GetDepthSample(DepthSampleUv);
	vec3 YuvDepth = DepthToYuv(Depth);
	/*
	if ( uv.x > 0.5 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= DepthInput_ToMetres;
		YuvDepth.x /= Encoded_DepthMaxMetres;
	}*/
	/*
	if ( uv.x < 0.2 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.0005;
	}
	else if ( uv.x < 0.4 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.001;
	}
	else if ( uv.x < 0.6 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.01;
	}
	else if ( uv.x < 0.8 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.02;
	}
*/
/*
	if ( uv.y < 0.05 )
	{
		YuvDepth.x = uv.x;
	}
	*/
	
	float Output = YuvDepth[DepthPlaneIndex];
	gl_FragColor = vec4( Output, Output, Output, 1.0 );
}
#endif

