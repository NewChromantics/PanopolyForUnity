precision highp float;

//	from quad shader (webgl)
varying vec2 uv;

//	output yuv encoding settings
uniform float Encoded_DepthMinMetres;
uniform float Encoded_DepthMaxMetres;

//	input
uniform sampler2D DepthTexture;
uniform vec2 DepthTextureSize;
#define DepthTexture_TexelSize	vec2(1.0/DepthTextureSize.x,1.0/DepthTextureSize.y)
uniform float DepthInput_ToMetres;

uniform float FlipDepthTexture;


uniform float OutputYuvPlaneIndex;	//	-1 rgb, 0=luma 1=chromau 2=chromav
#define OUTPUT_RGBA		(OutputYuvPlaneIndex < 0.0)
#define OUTPUT_LUMA		(int(OutputYuvPlaneIndex) == 0)
#define OUTPUT_CHROMAU	(int(OutputYuvPlaneIndex) == 1)
#define OUTPUT_CHROMAV	(int(OutputYuvPlaneIndex) == 2)


const vec4 InvalidNearColour = vec4(0,0,0,0);
const vec4 InvalidFarColour = vec4(0,1,0,0);

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

float GetDepthSample(vec2 uv)
{
	#define TWO_CHANNEL_16BIT_RG
	#define TWO_CHANNEL_16BIT_RA

	#if defined(TWO_CHANNEL_16BIT_RG)
	//	dont seem to be getting any W value... test this more. also, the DepthInput_ToMetres might not match up
	//	gr: this just doesnt seem to be right, even on desktop. Do more r16 vs rg testing
	vec2 Depth2 = texture2D( DepthTexture, uv ).xy;
	float Depth = (Depth2.x * 255.0) + (Depth2.y * 65280.0);
	Depth /= 65535.0;
	//float Depth = Depth2.x;
	#else
	//	1 16bit/float channel (assume normalised and DepthInput_ToMetres compensates)
	float Depth = texture2D( DepthTexture, uv ).x;
	#endif
	Depth *= DepthInput_ToMetres;
	return Depth;
}

float4 NormalToRainbowAndScore(float Normal,vec4 OutOfRangeNearColour,vec4 OutOfRangeFarColour)
{
	if ( Normal < 0.0 )
		return OutOfRangeNearColour;
	if ( Normal > 1.0 )
		return OutOfRangeFarColour;
	
	float Score = 1.0;
	
	if ( Normal < 0.166 )
	{
		Normal = Range( 0.0, 0.166, Normal );
		return vec4( 1.0, Normal, 0.0, Score );	//	red -> yellow
	}
	else if ( Normal < 0.333 )
	{
		Normal = Range( 0.166, 0.333, Normal );
		return vec4( 1.0-Normal, 1.0, 0.0, Score );	//	yellow -> green
	}
	else if ( Normal < 0.500 )
	{
		Normal = Range( 0.333, 0.500, Normal );
		return vec4( 0.0, 1.0, Normal, Score );	//	green -> cyan
	}
	else if ( Normal < 0.666 )
	{
		Normal = Range( 0.500, 0.666, Normal );
		return vec4( 0.0, 1.0-Normal, 1.0, Score );	//	cyan -> blue
	}
	else if ( Normal < 0.833 )
	{
		Normal = Range( 0.666, 0.833, Normal );
		return vec4( Normal, 0.0, 1.0, Score );	//	blue -> purple
	}
	else //if ( Normal < 0.666 )
	{
		Normal = Range( 0.833, 1.0, Normal );
		return vec4( 1.0, 0.0, 1.0-Normal, Score );	//	purple -> red
	}
	
}


vec3 RgbToYuv(vec3 Rgb)
{
	//	calc YUV version
	//	https://github.com/libretro/glsl-shaders/blob/master/nnedi3/shaders/rgb-to-yuv.glsl
	//	todo: use proper input YUV params, and check theyre right!
	float r = Rgb.x;
	float g = Rgb.y;
	float b = Rgb.z;
	float y = r * 0.299 + g * 0.587 + b * 0.114;
	float u = r * -0.169 + g * -0.331 + b * 0.5 + 0.5;
	float v = r * 0.5 + g * -0.419 + b * -0.081 + 0.5;

	return vec3(y,u,v);
}

#if !defined(NO_MAIN)
void main()
{
/*
	{
		gl_FragColor = vec4(uv,1,1);
		gl_FragColor.xyz = NormalToRainbow( uv.x, InvalidColour );
		return;
	}
	*/
	//	we're expecting planes to go from 0 at the top, so this is to flip the output DATA
	vec2 OutputUv = vec2(uv.x,1.0-uv.y);
	//vec2 OutputUv = uv;
	vec2 DepthSampleUv = uv;
	DepthSampleUv.y = (FlipDepthTexture>0.5) ? 1.0-DepthSampleUv.y : DepthSampleUv.y;
	
	float Depth = GetDepthSample(DepthSampleUv);
	
	float DepthNorm = Range( Encoded_DepthMinMetres, Encoded_DepthMaxMetres, Depth );

	//	rgba
	gl_FragColor = NormalToRainbowAndScore(DepthNorm, InvalidNearColour, InvalidFarColour );

	//	yuv output
	vec3 Yuv = RgbToYuv(gl_FragColor.xyz);
	
	if ( OUTPUT_LUMA )
	{
		gl_FragColor.xyz = Yuv.xxx;
	}
	else if ( OUTPUT_CHROMAU )
	{
		gl_FragColor.xyz = Yuv.yyy;
	}
	else if ( OUTPUT_CHROMAV )
	{
		gl_FragColor.xyz = Yuv.zzz;
	}

	//gl_FragColor = vec4( DepthNorm, DepthNorm, DepthNorm, 1.0 );
}
#endif

