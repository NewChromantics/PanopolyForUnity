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
typedef int uint8_t;
typedef int uint16_t;
typedef int uint32_t;
typedef int int32_t;
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
	return (int)floor(v);
}
float Lerp(float Min, float Max, float Time)
{
	return lerp(Min, Max, Time);
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

void GetChromaRangeIndex(out int Index,out float IndexNormalised,out float NextIndexNormalised,uint8_t ChromaU, uint8_t ChromaV, EncodeParams_t Params)
{
	//	work out from 0 to max this uv points at
	int Width = GetUvRangeWidthHeight(Params.ChromaRangeCount);
	int Height = Width;
	int RangeMax = (Width*Height) - 1;

	//	gr: emulate shader 
	float ChromaUv_x = ChromaU / 255.f;
	float ChromaUv_y = ChromaV / 255.f;

	//	in the encoder, u=x%width and /width, so scales back up to -1  
	float xf = ChromaUv_x * float(Width - 1);
	float yf = ChromaUv_y * float(Height - 1);
	//	we need the nearest, so we floor but go up a texel
	int x = Floor(xf + 0.5);
	int y = Floor(yf + 0.5);

	//	gr: this should be nearest, not floor so add half
	//ChromaUv = floor(ChromaUv + float2(0.5, 0.5) );
	Index = x + (y*Width);

	bool PingPong = (Index & 1) && Params.PingPongLuma;

	IndexNormalised = (Index+0) / float(RangeMax);
	NextIndexNormalised = (Index+1) / float(RangeMax);
}

uint16_t YuvToDepth(uint8_t Luma, uint8_t ChromaU, uint8_t ChromaV, EncodeParams_t Params)
{
	int Index;
	float IndexNormalised;
	float NextNormalised;
	GetChromaRangeIndex( Index, IndexNormalised, NextNormalised, ChromaU, ChromaV, Params );
/*
	//	work out from 0 to max this uv points at
	int Width = GetUvRangeWidthHeight(Params.ChromaRangeCount);
	int Height = Width;
	int RangeMax = (Width*Height) - 1;

	//	gr: emulate shader 
	float ChromaUv_x = ChromaU / 255.f;
	float ChromaUv_y = ChromaV / 255.f;

	//	in the encoder, u=x%width and /width, so scales back up to -1 
	float xf = ChromaUv_x * float(Width - 1);
	float yf = ChromaUv_y * float(Height - 1);
	//	we need the nearest, so we floor but go up a texel
	int x = Floor(xf + 0.5);
	int y = Floor(yf + 0.5);

	//	gr: this should be nearest, not floor so add half
	//ChromaUv = floor(ChromaUv + float2(0.5, 0.5) );
	int Index = x + (y*Width);


	float Indexf = Index / float(RangeMax);
	float Nextf = (Index + 1) / float(RangeMax);
	//return float2(Indexf, Nextf);
*/
	bool PingPong = (Index & 1) && Params.PingPongLuma;

	//	put into depth space
	float Indexf = Lerp(Params.DepthMin, Params.DepthMax, IndexNormalised);
	float Nextf = Lerp(Params.DepthMin, Params.DepthMax, NextNormalised);
	float Lumaf = Luma / 255.0f;
	Lumaf = PingPong ? (1.0-Lumaf) : Lumaf;
	float Depth = Lerp(Indexf, Nextf, Lumaf);
	uint16_t Depth16 = Depth;

	return Depth16;
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

//	convert YUV sampled values into local/camera depth
//	multiply this, plus camera uv (so u,v,z,1) with a projection matrix to get world space position
float GetCameraDepth(float Luma, float ChromaU, float ChromaV, PopYuvEncodingParams EncodingParams,PopYuvDecodingParams DecodingParams)
{
	if ( DecodingParams.Debug_IgnoreMinor )
		Luma = 0;

	if ( DecodingParams.Debug_IgnoreMajor )
	{
		ChromaU = 0;
		ChromaV = 0;
	}

	EncodeParams_t Params;
	Params.DepthMin = EncodingParams.DepthMinMetres * 1000;
	Params.DepthMax = EncodingParams.DepthMaxMetres * 1000;
	Params.ChromaRangeCount = EncodingParams.ChromaRangeCount;
	Params.PingPongLuma = EncodingParams.PingPongLuma;
	//	0..1 to 0..255 with adjustments for h264 range
	int Luma8 = Range( DecodingParams.DecodedLumaMin, DecodingParams.DecodedLumaMax, Luma*255 ) * 255;	
	int ChromaU8 = ChromaU * 255;
	int ChromaV8 = ChromaV * 255;
	uint16_t DepthMm = YuvToDepth(Luma8, ChromaU8, ChromaV8, Params);
	float Depthm = DepthMm / 1000.0;

	return DepthMm / 1000.0;
}

