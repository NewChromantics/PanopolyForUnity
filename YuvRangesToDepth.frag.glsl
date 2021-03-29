precision highp float;

//	from quad shader (webgl)
varying vec2 uv;

//	unity->glsl conversion
#define lerp mix
#define tex2D texture2D
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define trunc	floor
#define fmod(x,y)	(x - y * trunc(x / y))

//	gr: this is now specifically "what is the output from poph264"
//uniform bool VideoYuvIsFlipped;
const bool VideoYuvIsFlipped = true;

//#include "YuvToDepth.cginc"
//	shader version of C version https://github.com/SoylentGraham/PopDepthToYuv
struct PopYuvEncodingParams
{
	int ChromaRangeCount;
	float DepthMinMetres;
	float DepthMaxMetres;
	bool PingPongLuma;
};

struct PopYuvDecodingParams
{
	bool Debug_IgnoreMinor;
	bool Debug_IgnoreMajor;
	float DecodedLumaMin;	//	byte
	float DecodedLumaMax;	//	byte
};



//	C struct
#define uint8_t int
#define uint16_t int
#define uint32_t int
#define int32_t int
struct EncodeParams_t
{
	uint16_t DepthMin;// = 0;
	uint16_t DepthMax;// = 0xffff;
	uint16_t ChromaRangeCount;// = 1;
	uint16_t PingPongLuma;// = 0;
};

int Floor(float v)
{
	//	gr: I have a feeling there's a shader bug here, maybe it was only in webgl
	return int(floor(v));
}

float Lerp(float Min, float Max, float Time)
{
	return mix(Min, Max, Time);
}

float Lerp(int Min, int Max, float Time)
{
	return Lerp(float(Min), float(Max), Time);
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

vec3 Range3(vec3 Min,vec3 Max,vec3 Value)
{
	float x = Range(Min.x,Max.x,Value.x);
	float y = Range(Min.y,Max.y,Value.y);
	float z = Range(Min.z,Max.z,Value.z);
	return float3(x,y,z);
}


uint32_t GetUvRangeWidthHeight(int32_t UvRangeCount)
{
	//	get WxH for this size
	if (UvRangeCount < 2 * 2)
		return 1;
	if (UvRangeCount <= 2 * 2)	return 2;
	if (UvRangeCount <= 3 * 3)	return 3;
	if (UvRangeCount <= 4 * 4)	return 4;
	if (UvRangeCount <= 5 * 5)	return 5;
	if (UvRangeCount <= 6 * 6)	return 6;
	if (UvRangeCount <= 7 * 7)	return 7;
	if (UvRangeCount <= 8 * 8)	return 8;
	if (UvRangeCount <= 9 * 9)	return 9;
	//if (UvRangeCount <= 10 * 10)
	return 10;
}

bool BitwiseAndOne(int Value)
{
	//	return Value & 1;
	int WithoutBit1 = (Value / 2) * 2;
	return ( Value != WithoutBit1 );
}

/*	gr: unity version, but something wrong with depths in webgl
void GetChromaRangeIndex(out int Index,out float IndexNormalised,out float NextIndexNormalised,uint8_t ChromaU, uint8_t ChromaV, EncodeParams_t Params)
{
	//	work out from 0 to max this uv points at
	int Width = GetUvRangeWidthHeight(Params.ChromaRangeCount);
	int Height = Width;
	int RangeMax = (Width*Height) - 1;

	//	gr: emulate shader 
	float ChromaUv_x = float(ChromaU) / 255.0;
	float ChromaUv_y = float(ChromaU) / 255.0;

	//	in the encoder, u=x%width and /width, so scales back up to -1  
	float xf = ChromaUv_x * float(Width - 1);
	float yf = ChromaUv_y * float(Height - 1);
	//	we need the nearest, so we floor but go up a texel
	int x = Floor(xf + 0.5);
	int y = Floor(yf + 0.5);

	//	gr: this should be nearest, not floor so add half
	//ChromaUv = floor(ChromaUv + float2(0.5, 0.5) );
	Index = x + (y*Width);

	bool PingPong = BitwiseAndOne(Index) && (Params.PingPongLuma!=0);

	IndexNormalised = float(Index+0) / float(RangeMax);
	NextIndexNormalised = float(Index+1) / float(RangeMax);
}

uint16_t YuvToDepth(uint8_t Luma, uint8_t ChromaU, uint8_t ChromaV, EncodeParams_t Params)
{
	int Index;
	float IndexNormalised;
	float NextNormalised;
	GetChromaRangeIndex( Index, IndexNormalised, NextNormalised, ChromaU, ChromaV, Params );

	bool PingPong = BitwiseAndOne(Index) && (Params.PingPongLuma!=0);

	//	put into depth space
	float Indexf = Lerp( Params.DepthMin, Params.DepthMax, IndexNormalised);
	float Nextf = Lerp(Params.DepthMin, Params.DepthMax, NextNormalised);
	float Lumaf = float(Luma) / 255.0;
	Lumaf = PingPong ? (1.0-Lumaf) : Lumaf;
	float Depth = Lerp(Indexf, Nextf, Lumaf);
	uint16_t Depth16 = int(Depth);

	return Depth16;
}
*/

uint16_t YuvToDepth(float Lumaf, uint8_t ChromaU, uint8_t ChromaV, EncodeParams_t Params)
{
	//	work out from 0 to max this uv points at
	int Width = GetUvRangeWidthHeight(Params.ChromaRangeCount);
	int Height = Width;
	float Widthf = float(Width);
	float Heightf = float(Height);
	float RangeMax = max( 1.0, (Widthf*Heightf) - 1.0 );	//	range max ends up being 0 when 1 chroma range, so max()
	
	//	gr: emulate shader
	float ChromaUv_x = float(ChromaU) / 255.0;
	float ChromaUv_y = float(ChromaV) / 255.0;
	
	//	in the encoder, u=x%width and /width, so scales back up to -1
	float xf = ChromaUv_x * float(Widthf - 1.0);
	float yf = ChromaUv_y * float(Heightf - 1.0);
	//	we need the nearest, so we floor but go up a texel
	int x = Floor(xf + 0.5);
	int y = Floor(yf + 0.5);
	
	//	gr: this should be nearest, not floor so add half
	//ChromaUv = floor(ChromaUv + float2(0.5, 0.5) );
	int Index = x + (y*Width);
	
	float Indexf = float(Index) / RangeMax;
	float Nextf = float(Index + 1) / RangeMax;
	//return float2(Indexf, Nextf);
	
	//	put into depth space
	Indexf = Lerp(float(Params.DepthMin), float(Params.DepthMax), Indexf);
	Nextf = Lerp(float(Params.DepthMin), float(Params.DepthMax), Nextf);
	//float Lumaf = float(Luma) / 255.0;

	bool PingPong = BitwiseAndOne(Index) && (Params.PingPongLuma!=0);
	Lumaf = PingPong ? (1.0-Lumaf) : Lumaf;

	float Depth = Lerp(Indexf, Nextf, Lumaf);
	uint16_t Depth16 = int(Depth);
	
	return Depth16;
}


//	convert YUV sampled values into local/camera depth
//	multiply this, plus camera uv (so u,v,z,1) with a projection matrix to get world space position
float GetCameraDepth(float Luma, float ChromaU, float ChromaV, PopYuvEncodingParams EncodingParams,PopYuvDecodingParams DecodingParams)
{
	if ( DecodingParams.Debug_IgnoreMinor )
		Luma = 0.0;

	if ( DecodingParams.Debug_IgnoreMajor )
	{
		ChromaU = 0.0;
		ChromaV = 0.0;
	}

	EncodeParams_t Params;
	Params.DepthMin = int(EncodingParams.DepthMinMetres * 1000.0);
	Params.DepthMax = int(EncodingParams.DepthMaxMetres * 1000.0);
	Params.ChromaRangeCount = EncodingParams.ChromaRangeCount;
	Params.PingPongLuma = EncodingParams.PingPongLuma?1:0;
	//	0..1 to 0..255 with adjustments for h264 range
	//int Luma8 = int( Range( DecodingParams.DecodedLumaMin, DecodingParams.DecodedLumaMax, Luma*255.0 ) * 255.0 );	
	//int Luma8 = int(Luma * 255.0);
	float Lumaf = Luma;
	int ChromaU8 = int(ChromaU * 255.0);
	int ChromaV8 = int(ChromaV * 255.0);
	uint16_t DepthMm = YuvToDepth(Lumaf, ChromaU8, ChromaV8, Params);
	return float(DepthMm) / 1000.0;
}





//uniform int PlaneCount;
const int PlaneCount = 1;
uniform sampler2D LumaPlane;
uniform sampler2D Plane2;
uniform sampler2D Plane3;
uniform vec2 LumaPlaneSize;
uniform vec2 Plane2Size;
uniform vec2 Plane3Size;
#define LumaPlane_TexelSize	vec4( 1.0/LumaPlaneSize.x, 1.0/LumaPlaneSize.y, LumaPlaneSize.x, LumaPlaneSize.y )
#define Plane2_TexelSize	vec4( 1.0/Plane2Size.x, 1.0/Plane2Size.y, Plane2Size.xy )
#define Plane3_TexelSize	vec4( 1.0/Plane3Size.x, 1.0/Plane3Size.y, Plane3Size.xy )

#define ChromaUPlane	Plane2
#define ChromaVPlane	Plane3
#define ChromaUVPlane	Plane2
#define ChromaUPlane_TexelSize	Plane2_TexelSize


uniform float Debug_Depth;
#define DEBUG_DEPTH	(Debug_Depth>0.5)

uniform float Debug_MinorAsValid;
#define DEBUG_MINOR_AS_VALID	(Debug_MinorAsValid>0.5)

uniform float Debug_MajorAsValid;
#define DEBUG_MAJOR_AS_VALID	(Debug_MajorAsValid>0.5)

uniform float Debug_DepthAsValid;
#define DEBUG_DEPTH_AS_VALID	(Debug_DepthAsValid>0.5)

uniform float Debug_PlaceInvalidDepth;
#define DEBUG_PLACE_INVALID_DEPTH	(Debug_PlaceInvalidDepth>0.5)

uniform float Debug_DepthMinMetres;
uniform float Debug_DepthMaxMetres;

uniform float ValidMinMetres;
uniform float Debug_IgnoreMinor;
uniform float Debug_IgnoreMajor;

//	gr: flipsample should be done in vert shader for texture fetching improvement!
//uniform float FlipSample;
//#define FLIP_SAMPLE	(FlipSample>0.5)

//uniform int Encoded_ChromaRangeCount;
const int Encoded_ChromaRangeCount = 1;
uniform float Encoded_DepthMinMetres;
uniform float Encoded_DepthMaxMetres;
uniform bool Encoded_LumaPingPong;

uniform float DecodedLumaMin;
uniform float DecodedLumaMax;



float GetLuma(vec2 uv)
{
	return tex2D(LumaPlane, uv).x;
}			

vec2 GetChromaUv(vec2 uv)
{
	if ( PlaneCount <= 1 )
	{
		return vec2(0,0);
	}
	if ( PlaneCount == 2 )
	{
		return tex2D(ChromaUPlane, uv).xy;
	}
					
	float ChromaU = tex2D(ChromaUPlane, uv).x;
	float ChromaV = tex2D(ChromaVPlane, uv).x;
	return vec2(ChromaU,ChromaV);
}

vec2 GetLumaUvStep(float xMult,float yMult)
{
	return LumaPlane_TexelSize.xy * vec2(xMult,yMult);
}
				
vec2 GetChromaUvStep(float xMult,float yMult)
{
	return ChromaUPlane_TexelSize.xy * vec2(xMult,yMult);
}

vec2 GetLumaUvAligned(vec2 uv)
{
	vec2 Overflow = fmod(uv,LumaPlane_TexelSize.xy);
	return uv - Overflow;
}

vec2 GetChromaUvAligned(vec2 uv)
{
	vec2 Overflow = fmod(uv,ChromaUPlane_TexelSize.xy);
	return uv - Overflow;
}

//	return x=depth y=valid
vec2 GetNeighbourDepth(vec2 Sampleuv,vec2 OffsetPixels,PopYuvEncodingParams EncodeParams,PopYuvDecodingParams DecodeParams)
{
	//	remember to sample from middle of texel
	//	gr: sampleuv will be wrong (not exact to texel) if output resolution doesnt match
	//		may we can fix this in vert shader  
	vec2 SampleLumauv = GetLumaUvAligned(Sampleuv) + GetLumaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetLumaUvStep(0.5,0.5);
	vec2 SampleChromauv = GetChromaUvAligned(Sampleuv) + GetChromaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetChromaUvStep(0.5,0.5);
	float Luma = GetLuma( SampleLumauv );
	vec2 ChromaUV = GetChromaUv( SampleChromauv );
	//	result in metres
	float Depth = GetCameraDepth( Luma, ChromaUV.x, ChromaUV.y, EncodeParams, DecodeParams );

	//	specifically catch 0 pixels. Need a better system here
	float Valid = (Depth >= ValidMinMetres) ? 1.0 : 0.0; 
	return vec2( Depth, Valid );
}

//	returns depth in metres
void GetDepth(out float Depth,out float Score,vec2 Sampleuv,PopYuvEncodingParams EncodeParams)
{
	PopYuvDecodingParams DecodeParams;
	DecodeParams.Debug_IgnoreMinor = Debug_IgnoreMinor > 0.5;
	DecodeParams.Debug_IgnoreMajor = Debug_IgnoreMajor > 0.5;
	DecodeParams.DecodedLumaMin = DecodedLumaMin;
	DecodeParams.DecodedLumaMax = DecodedLumaMax;

	vec2 OriginDepthValid = GetNeighbourDepth(Sampleuv,vec2(0,0),EncodeParams,DecodeParams);
	Depth = OriginDepthValid.x;
	Score = OriginDepthValid.y;
					
	if ( DEBUG_PLACE_INVALID_DEPTH && OriginDepthValid.y < 1.0 )
	{
		Score = 0.5;
		Depth = Debug_DepthMinMetres;
		return;
	}
}


vec3 NormalToRedGreen(float Normal)
{
	if (Normal < 0.0)
	{
		return vec3(0, 1, 1);
	}
	if (Normal < 0.5)
	{
		Normal = Normal / 0.5;
		return vec3(1, Normal, 0);
	}
	else if (Normal <= 1.0)
	{
		Normal = (Normal - 0.5) / 0.5;
		return vec3(1.0 - Normal, 1.0, 0.0);
	}

	//	>1
	return vec3(0, 0, 1);
}

vec4 YuvRangesToDepth(vec2 uv)
{					
	PopYuvEncodingParams EncodeParams;
	EncodeParams.ChromaRangeCount = Encoded_ChromaRangeCount;
	EncodeParams.DepthMinMetres = Encoded_DepthMinMetres;
	EncodeParams.DepthMaxMetres = Encoded_DepthMaxMetres;
	EncodeParams.PingPongLuma = Encoded_LumaPingPong;

	//	this output should be in camera-local space (normalised)
	float CameraDepthMetres;
	float DepthScore;
	GetDepth(CameraDepthMetres,DepthScore,uv,EncodeParams);

	//	return normalised depth
	float CameraDepthNorm = Range( EncodeParams.DepthMinMetres, EncodeParams.DepthMaxMetres, CameraDepthMetres );
	//	gr: this makes it show up
	//float CameraDepthNorm = Range( EncodeParams.DepthMinMetres, 5.0, CameraDepth );

	if ( DEBUG_DEPTH_AS_VALID )
	{
		return vec4(CameraDepthNorm,CameraDepthNorm,CameraDepthNorm,CameraDepthMetres);
	}

	if ( DEBUG_MINOR_AS_VALID )
	{
		vec2 Sampleuv = uv;
		float Luma = GetLuma(Sampleuv);
		return vec4(CameraDepthNorm,CameraDepthNorm,CameraDepthNorm, Luma);
	}
/*	gr: GetChromaRangeIndex missing in glsl
	if ( DEBUG_MAJOR_AS_VALID )
	{
		vec2 Sampleuv = uv;
		vec2 ChromaUV = GetChromaUv(Sampleuv);
		EncodeParams_t Params;
		Params.DepthMin = EncodeParams.DepthMinMetres * 1000.0;
		Params.DepthMax = EncodeParams.DepthMaxMetres * 1000.0;
		Params.ChromaRangeCount = EncodeParams.ChromaRangeCount;
		Params.PingPongLuma = EncodeParams.PingPongLuma;
	
		int Index;
		float Indexf;
		float Nextf;
		GetChromaRangeIndex(Index,Indexf,Nextf,ChromaUV.x*255.0,ChromaUV.y*255.0,Params);

		//	stripe this output
		if ( BitwiseAndOne(Index) )
			Indexf += 0.5;

		return vec4(CameraDepth,CameraDepth,CameraDepth, Indexf);
	}
*/
	if ( DEBUG_DEPTH )
	{
		float CameraDepthDebugNorm = Range( Debug_DepthMinMetres, Debug_DepthMaxMetres, CameraDepthMetres );
		vec3 Rgb = NormalToRedGreen(CameraDepthDebugNorm);
		return vec4(Rgb, DepthScore);
	}
					
	return vec4(CameraDepthNorm,CameraDepthNorm,CameraDepthNorm, DepthScore);
}

#if !defined(NO_MAIN)
void main()
{
	vec2 SampleUv = uv;
	if ( VideoYuvIsFlipped )
		SampleUv.y = 1.0 - SampleUv.y;
	gl_FragColor = YuvRangesToDepth(SampleUv);
}
#endif
