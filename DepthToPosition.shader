Shader "Panopoly/DepthToPosition"
{
	Properties
	{
		[MainTexture]_MainTex("Texture", 2D) = "white" {}
		[Header(Encoding Params from PopCap)]Encoded_DepthMinMetres("Encoded_DepthMinMetres",Range(0,30)) = 0
		Encoded_DepthMaxMetres("Encoded_DepthMaxMetres",Range(0,30)) = 5
		[IntRange]Encoded_ChromaRangeCount("Encoded_ChromaRangeCount",Range(1,128)) = 1
		[Toggle]Encoded_LumaPingPong("Encoded_LumaPingPong",Range(0,1)) = 1
		[Toggle]EnableDepthNoiseReduction("EnableDepthNoiseReduction",Range(0,1))=1
		[IntRange]NeighbourSamplePixelStep("NeighbourSamplePixelStep",Range(1,10)) = 4
		MaxEdgeDepth("MaxEdgeDepth",Range(0.0001,1.0))=0.02	//	see MaxWeldDistance
		MaxCorrectedEdgeDepth("MaxCorrectedEdgeDepth",Range(0.0001,1.0))=0.02	//	see MaxWeldDistance
		MaxChromaDiff("MaxChromaDiff",Range(0,0.3)) = 0.1
		MaxLumaDiff("MaxLumaDiff",Range(0,0.3)) = 0.1
		[Toggle]Debug_Alpha("Debug_Alpha",Range(0,1))=0
		[Toggle]Debug_Depth("Debug_Depth",Range(0,1)) = 0
		[Toggle]FlipSample("FlipSample",Range(0,1)) = 0
		[Toggle]FlipOutput("FlipOutput",Range(0,1)) = 0
		[Header(Temporary until invalid depth is standardised)]ValidMinMetres("ValidMinMetres",Range(0,1)) = 0
		Debug_DepthMinMetres("Debug_DepthMinMetres",Range(0,5)) = 0
		Debug_DepthMaxMetres("Debug_DepthMaxMetres",Range(0,5)) = 5
		//CameraToLocalTransform("CameraToLocalTransform", Matrix) = (1,0,0,0,	0,1,0,0,	0,0,1,0,	0,0,0,1	) 
		CameraToLocalViewportMin("CameraToLocalViewportMin",VECTOR) = (0,0,0)
		CameraToLocalViewportMax("CameraToLocalViewportMax",VECTOR) = (640,480,1000)
		[Toggle]ApplyLocalToWorld("ApplyLocalToWorld",Range(0,1))=0
	}
	
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "YuvToDepth.cginc"
				#include "UnityCG.cginc"

				struct appdata
				{
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
				};

				struct v2f
				{
					float2 uv : TEXCOORD0;
					float4 vertex : SV_POSITION;
				};

				float FlipSample;
#define FLIP_SAMPLE	(FlipSample>0.5f)
				float FlipOutput;
#define FLIP_OUTPUT	(FlipOutput>0.5f)

				sampler2D _MainTex;
				float4 _MainTex_TexelSize;
			#define YuvPlanes	_MainTex
			#define YuvPlanes_TexelSize	_MainTex_TexelSize
				
				int Encoded_ChromaRangeCount;
				float Encoded_DepthMinMetres;
				float Encoded_DepthMaxMetres;
				bool Encoded_LumaPingPong;

				float DecodedLumaMin;
				float DecodedLumaMax;


				//	this.FrameMeta.CameraToLocalViewportMinMax = [0,0,0,wh[0],wh[1],1000];
				float3 CameraToLocalViewportMin;
				float3 CameraToLocalViewportMax;
				float4x4 CameraToLocalTransform;

				float4x4 LocalToWorldTransform;
				float ApplyLocalToWorld;
				#define APPLY_LOCAL_TO_WORLD	(ApplyLocalToWorld>0.5)

				float Debug_Alpha;
				#define DEBUG_ALPHA	(Debug_Alpha>0.5)

				float Debug_Yuv;
				#define DEBUG_YUV	(Debug_Yuv>0.5)

				float Debug_Depth;
				#define DEBUG_DEPTH	(Debug_Depth>0.5)

				float Debug_MinorAsValid;
				#define DEBUG_MINOR_AS_VALID	(Debug_MinorAsValid>0.5)

				float Debug_MajorAsValid;
				#define DEBUG_MAJOR_AS_VALID	(Debug_MajorAsValid>0.5)

				float Debug_DepthAsValid;
				#define DEBUG_DEPTH_AS_VALID	(Debug_DepthAsValid>0.5)

				float Debug_PlaceInvalidDepth;
			#define DEBUG_PLACE_INVALID_DEPTH	(Debug_PlaceInvalidDepth>0.5)

				float Debug_DepthMinMetres;
				float Debug_DepthMaxMetres;

				float ValidMinMetres;
				float MaxEdgeDepth;
				float MaxCorrectedEdgeDepth;
				float MaxChromaDiff;
				float MaxLumaDiff;
				float EnableDepthNoiseReduction;
	#define ENABLE_DEPTH_NOISE_REDUCTION	(EnableDepthNoiseReduction>0.5f)
				float NeighbourSamplePixelStep;

				float Debug_IgnoreMinor;
				float Debug_IgnoreMajor;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);

	                o.uv = v.uv;

					if ( FLIP_SAMPLE )
						o.uv.y = 1.0 - o.uv.y;
					
					return o;
				}

				float3 NormalToRedGreen(float Normal)
				{
					if (Normal < 0.0)
					{
						return float3(0, 1, 1);
					}
					if (Normal < 0.5)
					{
						Normal = Normal / 0.5;
						return float3(1, Normal, 0);
					}
					else if (Normal <= 1)
					{
						Normal = (Normal - 0.5) / 0.5;
						return float3(1 - Normal, 1, 0);
					}

					//	>1
					return float3(0, 0, 1);
				}
	
				float GetLuma(float2 uv)
				{
					return tex2D(YuvPlanes, uv).x;
				}			

				float2 GetChroma(float2 uv)
				{
					return tex2D(YuvPlanes, uv).yz;
				}

				float2 GetAlpha(float2 uv)
				{
					return tex2D(YuvPlanes, uv).w;
				}

#define LumaPlane_TexelSize	(YuvPlanes_TexelSize)
#define ChromaUPlane_TexelSize	(YuvPlanes_TexelSize * float2(2,2))


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
					float2 SampleLumauv = GetLumaUvAligned(Sampleuv) + GetLumaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetLumaUvStep(0.5,0.5);
					float2 DepthValid = GetLuma( SampleLumauv );
					float Depth = lerp( EncodeParams.DepthMinMetres, EncodeParams.DepthMaxMetres, DepthValid.x );
					return float2( Depth, DepthValid.x );
				}

				void GetResolvedDepth(out float Depth,out float Score,float2 Sampleuv,PopYuvEncodingParams EncodeParams)
				{
					PopYuvDecodingParams DecodeParams;
					DecodeParams.Debug_IgnoreMinor = Debug_IgnoreMinor > 0.5f;
					DecodeParams.Debug_IgnoreMajor = Debug_IgnoreMajor > 0.5f;
					DecodeParams.DecodedLumaMin = DecodedLumaMin;
					DecodeParams.DecodedLumaMax = DecodedLumaMax;

					float2 OriginDepthValid = GetNeighbourDepth(Sampleuv,float2(0,0),EncodeParams,DecodeParams);
					Depth = OriginDepthValid.x;
					/*
					if ( DEBUG_PLACE_INVALID_DEPTH && OriginDepthValid.y < 1.0 )
					{
						Score = 0.5;
						Depth = Debug_DepthMinMetres;
						return;
					}
*/
					if ( !ENABLE_DEPTH_NOISE_REDUCTION )
					{
						Score = 1;
						return;
					}

					//	gr: our 1280x720 encoding seems to be 2x the size of 640x480
					//		and as chroma planes are half the size, we're seeing gaps (black pixels) of 4x4.
					//		maybe our chroma sample shouldn't be pixel left & right inside GetNeighbourDepth
					//		but we definitely need to sample a bit further than 1 pixel... in this case
					float SampleStep = NeighbourSamplePixelStep;
					#define NEIGHBOUR_COUNT	8
					float2 SampleOffsets[NEIGHBOUR_COUNT];
					//	gr: we want to sample left & rught, (and in all directions, but planning for future scanline)
					//	but also, lets match welding directions
					SampleOffsets[0] = float2(-1,0) * SampleStep;
					SampleOffsets[1] = float2(-1,-1) * SampleStep;
					SampleOffsets[2] = float2(0,-1) * SampleStep;
					SampleOffsets[3] = float2(1,-1) * SampleStep;
					SampleOffsets[4] = float2(1,0) * SampleStep;
					SampleOffsets[5] = float2(1,1) * SampleStep;
					SampleOffsets[6] = float2(0,1) * SampleStep;
					SampleOffsets[7] = float2(-1,1) * SampleStep;
#if NEIGHBOUR_COUNT > 8
					SampleOffsets[8] = float2(-2,0) * SampleStep;
					SampleOffsets[9] = float2(-2,-2) * SampleStep;
					SampleOffsets[10] = float2(0,-2) * SampleStep;
					SampleOffsets[11] = float2(2,-2) * SampleStep;
					SampleOffsets[12] = float2(2,0) * SampleStep;
					SampleOffsets[13] = float2(2,2) * SampleStep;
					SampleOffsets[14] = float2(0,2) * SampleStep;
					SampleOffsets[15] = float2(-2,2) * SampleStep;
#endif

					float2 SampleDepths[NEIGHBOUR_COUNT];
					float SampleDiffs[NEIGHBOUR_COUNT];
					float FarDist = 0;
					float NearDist = 9999;
					for ( int s=0;	s<NEIGHBOUR_COUNT;	s++ )
					{
						float2 SampleDepth = GetNeighbourDepth(Sampleuv,SampleOffsets[s],EncodeParams,DecodeParams);
						SampleDepths[s] = SampleDepth;
						//	gr: make the diff massive so it's not used 
						float SampleDiff = abs(Depth-SampleDepth.x) * lerp( 999, 1, SampleDepth.y );
						SampleDiffs[s] = SampleDiff;
						FarDist = max( FarDist, SampleDiff );
						NearDist = min( NearDist, SampleDiff );
					}

					//	origin sample is invalid, (ie black pixel, not noisy) we need to pick any good sample
					//	todo: this is where we would find a nearby pixel of the same COLOUR and pick that
					if ( OriginDepthValid.y < 1.0 )
					{
						float2 Result = OriginDepthValid;
						for ( int s=0;	s<NEIGHBOUR_COUNT;	s++ )
						{
							float2 SampleDepth = SampleDepths[s];
							Result = lerp( Result, SampleDepth, (SampleDepth.y > Result.y) ? 1 : 0 );
						}
						Depth = Result.x;
						Score = (Result.y > 0.0) ? 0.5 : -1;
						return;
					}
					else if ( NearDist <= MaxEdgeDepth )
					{
						//Score = Range( MaxEdgeDepth, 0.0, NearDist );
						//Score += 1.001;
						Score = 2;
					}
					else // if best score is low, then snap to a neighbours depth
					if ( NearDist <= MaxCorrectedEdgeDepth )
					{
						float BestDepth = SampleDepths[0].x;
						for ( int s=0;	s<NEIGHBOUR_COUNT;	s++ )
						{
							float2 SampleDepth = SampleDepths[s];
							BestDepth = lerp( BestDepth, SampleDepth, abs(SampleDepth-Depth) < abs(BestDepth-Depth) );
						}
						Depth = BestDepth;

						Score = Range( MaxEdgeDepth, MaxCorrectedEdgeDepth, NearDist );
						Score = 1.0;
					}
					else
					{
						Score = 0;
					}

					//	typically zero (sometimes ~4 post vidoe decoding) means invalid
					//	Popcap should standardise this to far-away  
					if ( Depth < ValidMinMetres )
						Score = -1.0;
				}

				
				fixed4 frag(v2f i) : SV_Target
				{
					if ( DEBUG_YUV )
					{
						float Luma = GetLuma(i.uv);
						float2 ChromaUv = GetChroma(i.uv);
						float Alpha = GetAlpha(i.uv);
						return float4(Luma,ChromaUv,Alpha);
					}

					if ( DEBUG_ALPHA )
					{
						float Alpha = GetAlpha(i.uv);
						return float4(Alpha,Alpha,Alpha,1);
					}

					PopYuvEncodingParams EncodeParams;
					EncodeParams.ChromaRangeCount = Encoded_ChromaRangeCount;
					EncodeParams.DepthMinMetres = Encoded_DepthMinMetres;
					EncodeParams.DepthMaxMetres = Encoded_DepthMaxMetres;
					EncodeParams.PingPongLuma = Encoded_LumaPingPong;

					//	this output should be in camera-local space 
					float CameraDepth;
					float DepthScore;
					GetResolvedDepth(CameraDepth,DepthScore,i.uv,EncodeParams);

					//	gr: projection matrix expects 0..1 
					float x = lerp(0,1,i.uv.x); 
					float y = FLIP_OUTPUT ? lerp(1,0,i.uv.y) : lerp(0,1,i.uv.y);
					float z = CameraDepth;
					
					//	now convert camera(image) space depth by the inverse of projection to get local-space

					float4 CameraPosition = float4(x,y,z,1.0);

					CameraPosition.xyz = lerp( CameraToLocalViewportMin, CameraToLocalViewportMax, CameraPosition.xyz );
	
					float4 CameraPosition4;
					CameraPosition4.x = CameraPosition.x;
					CameraPosition4.y = CameraPosition.y;
					CameraPosition4.z = 1;
					//	scale all by depth, this is undone by /w hence 1/z
					//	surely this can go in the matrix....
					CameraPosition4.w = 1/CameraDepth;

					float4 LocalPosition4 = mul(CameraToLocalTransform,CameraPosition4);
					float3 LocalPosition = LocalPosition4.xyz / LocalPosition4.www;


					float4 WorldPosition4 = mul(LocalToWorldTransform,float4(LocalPosition,1));
					float3 WorldPosition = WorldPosition4.xyz / WorldPosition4.www;
				
					//	should we convert to world-pos here (with camera localtoworld) web version currently does not
					//	because webgl cant always do float textures so is quantized 8bit
					//	in native, we could
					float3 OutputPosition = APPLY_LOCAL_TO_WORLD ? WorldPosition : LocalPosition;

					if ( DEBUG_DEPTH_AS_VALID )
					{
						float DepthNormalised = Range( Debug_DepthMinMetres, Debug_DepthMaxMetres, CameraDepth );
						return float4(OutputPosition, DepthNormalised );
					}

					if ( DEBUG_MINOR_AS_VALID )
					{
						float2 Sampleuv = i.uv;
						float Luma = GetLuma(Sampleuv);
						return float4(OutputPosition, Luma);
					}

					if ( DEBUG_MAJOR_AS_VALID )
					{
						float2 Sampleuv = i.uv;
						float2 Chroma = GetChroma(Sampleuv);
						EncodeParams_t Params;
						Params.DepthMin = EncodeParams.DepthMinMetres * 1000;
						Params.DepthMax = EncodeParams.DepthMaxMetres * 1000;
						Params.ChromaRangeCount = EncodeParams.ChromaRangeCount;
						Params.PingPongLuma = EncodeParams.PingPongLuma;
	
						int Index;
						float Indexf;
						float Nextf;
						GetChromaRangeIndex(Index,Indexf,Nextf,Chroma.x*255,Chroma.y*255,Params);

						//	stripe this output
						if ( Index & 1 )
							Indexf += 0.5;

						return float4(OutputPosition, Indexf);
					}

					if ( DEBUG_DEPTH )
					{
						float3 Rgb = NormalToRedGreen(CameraDepth);
						return float4(Rgb, DepthScore);
					}
					
					return float4(OutputPosition, DepthScore);
				}
				ENDCG
			}
		}
}
