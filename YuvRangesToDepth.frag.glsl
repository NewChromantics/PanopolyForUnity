
float GetLuma(float2 uv)
{
	return tex2D(LumaPlane, uv).x;
}			

float2 GetChromaUv(float2 uv)
{
	if ( PlaneCount == 2 )
	{
		return tex2D(ChromaUPlane, uv).xy;
	}
					
	float ChromaU = tex2D(ChromaUPlane, uv).x;
	float ChromaV = tex2D(ChromaVPlane, uv).x;
	return float2(ChromaU,ChromaV);
}

float2 GetLumaUvStep(float xMult,float yMult)
{
	return LumaPlane_TexelSize * float2(xMult,yMult);
}
				
float2 GetChromaUvStep(float xMult,float yMult)
{
	return ChromaUPlane_TexelSize * float2(xMult,yMult);
}

float2 GetLumaUvAligned(float2 uv)
{
	float2 Overflow = fmod(uv,LumaPlane_TexelSize);
	return uv - Overflow;
}

float2 GetChromaUvAligned(float2 uv)
{
	float2 Overflow = fmod(uv,ChromaUPlane_TexelSize);
	return uv - Overflow;
}

//	return x=depth y=valid
float2 GetNeighbourDepth(float2 Sampleuv,float2 OffsetPixels,PopYuvEncodingParams EncodeParams,PopYuvDecodingParams DecodeParams)
{
	//	remember to sample from middle of texel
	//	gr: sampleuv will be wrong (not exact to texel) if output resolution doesnt match
	//		may we can fix this in vert shader  
	float2 SampleLumauv = GetLumaUvAligned(Sampleuv) + GetLumaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetLumaUvStep(0.5,0.5);
	float2 SampleChromauv = GetChromaUvAligned(Sampleuv) + GetChromaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetChromaUvStep(0.5,0.5);
	float Luma = GetLuma( SampleLumauv );
	float2 ChromaUV = GetChromaUv( SampleChromauv );
	float Depth = GetCameraDepth( Luma, ChromaUV.x, ChromaUV.y, EncodeParams, DecodeParams );

	//	specifically catch 0 pixels. Need a better system here
	float Valid = Depth >= ValidMinMetres; 
	return float2( Depth, Valid );
}

void GetDepth(out float Depth,out float Score,float2 Sampleuv,PopYuvEncodingParams EncodeParams)
{
	PopYuvDecodingParams DecodeParams;
	DecodeParams.Debug_IgnoreMinor = Debug_IgnoreMinor > 0.5f;
	DecodeParams.Debug_IgnoreMajor = Debug_IgnoreMajor > 0.5f;
	DecodeParams.DecodedLumaMin = DecodedLumaMin;
	DecodeParams.DecodedLumaMax = DecodedLumaMax;

	float2 OriginDepthValid = GetNeighbourDepth(Sampleuv,float2(0,0),EncodeParams,DecodeParams);
	Depth = OriginDepthValid.x;
	Score = OriginDepthValid.y;
					
	if ( DEBUG_PLACE_INVALID_DEPTH && OriginDepthValid.y < 1.0 )
	{
		Score = 0.5;
		Depth = Debug_DepthMinMetres;
		return;
	}
}

#if !defined(NO_MAIN)
void main()
{
	gl_FragColor = vec4(1,0,0,1);
}
#endif
