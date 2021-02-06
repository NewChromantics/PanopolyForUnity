#include "YuvToDepth.cginc"

uniform sampler2D LumaPlane;
uniform vec4 LumaPlane_TexelSize;
uniform sampler2D Plane2;
uniform vec4 Plane2_TexelSize;
uniform sampler2D Plane3;
uniform int PlaneCount;

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
//#define FLIP_SAMPLE	(FlipSample>0.5f)

uniform int Encoded_ChromaRangeCount;
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
	return LumaPlane_TexelSize * vec2(xMult,yMult);
}
				
vec2 GetChromaUvStep(float xMult,float yMult)
{
	return ChromaUPlane_TexelSize * vec2(xMult,yMult);
}

vec2 GetLumaUvAligned(vec2 uv)
{
	vec2 Overflow = fmod(uv,LumaPlane_TexelSize);
	return uv - Overflow;
}

vec2 GetChromaUvAligned(vec2 uv)
{
	vec2 Overflow = fmod(uv,ChromaUPlane_TexelSize);
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
	float Depth = GetCameraDepth( Luma, ChromaUV.x, ChromaUV.y, EncodeParams, DecodeParams );

	//	specifically catch 0 pixels. Need a better system here
	float Valid = Depth >= ValidMinMetres; 
	return vec2( Depth, Valid );
}

void GetDepth(out float Depth,out float Score,vec2 Sampleuv,PopYuvEncodingParams EncodeParams)
{
	PopYuvDecodingParams DecodeParams;
	DecodeParams.Debug_IgnoreMinor = Debug_IgnoreMinor > 0.5f;
	DecodeParams.Debug_IgnoreMajor = Debug_IgnoreMajor > 0.5f;
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
	else if (Normal <= 1)
	{
		Normal = (Normal - 0.5) / 0.5;
		return vec3(1 - Normal, 1, 0);
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
	float CameraDepth;
	float DepthScore;
	GetDepth(CameraDepth,DepthScore,uv,EncodeParams);

	//	return normalised depth
	CameraDepth = Range( EncodeParams.DepthMinMetres, EncodeParams.DepthMaxMetres, CameraDepth );
					

	if ( DEBUG_DEPTH_AS_VALID )
	{
		return vec4(CameraDepth,CameraDepth,CameraDepth,CameraDepth);
	}

	if ( DEBUG_MINOR_AS_VALID )
	{
		vec2 Sampleuv = uv;
		float Luma = GetLuma(Sampleuv);
		return vec4(CameraDepth,CameraDepth,CameraDepth, Luma);
	}

	if ( DEBUG_MAJOR_AS_VALID )
	{
		vec2 Sampleuv = uv;
		vec2 ChromaUV = GetChromaUv(Sampleuv);
		EncodeParams_t Params;
		Params.DepthMin = EncodeParams.DepthMinMetres * 1000;
		Params.DepthMax = EncodeParams.DepthMaxMetres * 1000;
		Params.ChromaRangeCount = EncodeParams.ChromaRangeCount;
		Params.PingPongLuma = EncodeParams.PingPongLuma;
	
		int Index;
		float Indexf;
		float Nextf;
		GetChromaRangeIndex(Index,Indexf,Nextf,ChromaUV.x*255,ChromaUV.y*255,Params);

		//	stripe this output
		if ( Index & 1 )
			Indexf += 0.5;

		return vec4(CameraDepth,CameraDepth,CameraDepth, Indexf);
	}

	if ( DEBUG_DEPTH )
	{
		vec3 Rgb = NormalToRedGreen(CameraDepth);
		return vec4(Rgb, DepthScore);
	}
					
	return vec4(CameraDepth,CameraDepth,CameraDepth, DepthScore);
}

#if !defined(NO_MAIN)
void main()
{
	gl_FragColor = vec4(1,0,0,1);
}
#endif
