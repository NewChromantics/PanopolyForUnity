Shader "Panopoly/YuvRangesToPosition"
{
	Properties
	{
		[MainTexture]LumaPlane("LumaPlane", 2D) = "white" {}
		Plane2("Plane2", 2D) = "white" {}
		Plane3("Plane3", 2D) = "white" {}
		[IntRange]PlaneCount("PlaneCount",Range(0,3)) = 3

		DecodedLumaMin("DecodedLumaMin",Range(0,255) ) = 0
		DecodedLumaMax("DecodedLumaMax",Range(0,255) ) = 255

		[Header(Encoding Params from PopCap)]Encoded_DepthMinMetres("Encoded_DepthMinMetres",Range(0,30)) = 0
		Encoded_DepthMaxMetres("Encoded_DepthMaxMetres",Range(0,30)) = 5
		[IntRange]Encoded_ChromaRangeCount("Encoded_ChromaRangeCount",Range(1,128)) = 1
		[Toggle]Encoded_LumaPingPong("Encoded_LumaPingPong",Range(0,1)) = 1
		[Toggle]EnableDepthNoiseReduction("EnableDepthNoiseReduction",Range(0,1))=1
		MaxEdgeDepth("MaxEdgeDepth",Range(0.0001,0.2))=0.02	//	see MaxWeldDistance
		ScoreEdgeDepth("ScoreEdgeDepth",Range(0,0.2))=0.02
		MaxChromaDiff("MaxChromaDiff",Range(0,0.3)) = 0.1
		MaxLumaDiff("MaxLumaDiff",Range(0,0.3)) = 0.1
		[Toggle]Debug_Depth("Debug_Depth",Range(0,1)) = 0
		[Toggle]FlipSample("FlipSample",Range(0,1)) = 0
		[Toggle]FlipOutput("FlipOutput",Range(0,1)) = 0
		[Header(Temporary until invalid depth is standardised)]ValidMinMetres("ValidMinMetres",Range(0,1)) = 0
		[Toggle]Debug_IgnoreMinor("Debug_IgnoreMinor",Range(0,1)) = 0
		[Toggle]Debug_IgnoreMajor("Debug_IgnoreMajor",Range(0,1)) = 0
		[Toggle]Debug_MinorAsValid("Debug_MinorAsValid",Range(0,1))=0
		[Toggle]Debug_MajorAsValid("Debug_MajorAsValid",Range(0,1))=0
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
				float _Angle;
				sampler2D LumaPlane;
				float4 LumaPlane_TexelSize;
				float4 LumaPlane_ST;
				sampler2D Plane2;
				float4 Plane2_TexelSize;
				sampler2D Plane3;
				int PlaneCount;
				#define ChromaUPlane	Plane2
				#define ChromaVPlane	Plane3
				#define ChromaUVPlane	Plane2
				#define ChromaUPlane_TexelSize	Plane2_TexelSize
				
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
				
				float Debug_Depth;
				#define DEBUG_DEPTH	(Debug_Depth>0.5)

				float Debug_MinorAsValid;
				#define DEBUG_MINOR_AS_VALID	(Debug_MinorAsValid>0.5f)

				float Debug_MajorAsValid;
				#define DEBUG_MAJOR_AS_VALID	(Debug_MajorAsValid>0.5f)

				float ValidMinMetres;
				float MaxEdgeDepth;
				float MaxChromaDiff;
				float MaxLumaDiff;
				float ScoreEdgeDepth;
				float EnableDepthNoiseReduction;
	#define ENABLE_DEPTH_NOISE_REDUCTION	(EnableDepthNoiseReduction>0.5f)

				float Debug_IgnoreMinor;
				float Debug_IgnoreMajor;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);

	                o.uv = v.uv;

					if ( FLIP_SAMPLE )
						o.uv.y = 1.0 - o.uv.y;
					
					//o.uv = TRANSFORM_TEX(v.uv, LumaPlane);
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

				float2 GetLumaUvStep(float xMult=1,float yMult=1)
				{
					return LumaPlane_TexelSize * float2(xMult,yMult);
				}
				
				float2 GetChromaUvStep(float xMult=1,float yMult=1)
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

				float GetNeighbourDepth(float2 Sampleuv,float2 OffsetPixels,PopYuvEncodingParams EncodeParams,PopYuvDecodingParams DecodeParams)
				{
					//	remember to sample from middle of texel
					//	gr: sampleuv will be wrong (not exact to texel) if output resolution doesnt match
					//		may we can fix this in vert shader 
					float2 SampleLumauv = GetLumaUvAligned(Sampleuv) + GetLumaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetLumaUvStep(0.5,0.5);
					float2 SampleChromauv = GetChromaUvAligned(Sampleuv) + GetChromaUvStep( OffsetPixels.x, OffsetPixels.y ) + GetChromaUvStep(0.5,0.5);
					float Luma = GetLuma( SampleLumauv );
					float2 ChromaUV = GetChromaUv( SampleChromauv );
					float Depth = GetCameraDepth( Luma, ChromaUV.x, ChromaUV.y, EncodeParams, DecodeParams );
					return Depth;
				}

				void GetResolvedDepth(out float Depth,out float Score,float2 Sampleuv,PopYuvEncodingParams EncodeParams)
				{
					PopYuvDecodingParams DecodeParams;
					DecodeParams.Debug_IgnoreMinor = Debug_IgnoreMinor > 0.5f;
					DecodeParams.Debug_IgnoreMajor = Debug_IgnoreMajor > 0.5f;
					DecodeParams.DecodedLumaMin = DecodedLumaMin;
					DecodeParams.DecodedLumaMax = DecodedLumaMax;

					Depth = GetNeighbourDepth(Sampleuv,float2(0,0),EncodeParams,DecodeParams);
					if ( !ENABLE_DEPTH_NOISE_REDUCTION )
					{
						Score = 1;
						return;
					}

					//	gr: sample half way (on texel edge) to get binlear gradients, then can sample 2x? (plus up and down?)
					float Left1 = GetNeighbourDepth(Sampleuv,float2(-1,0),EncodeParams,DecodeParams);
					float Left2 = GetNeighbourDepth(Sampleuv,float2(-2,0),EncodeParams,DecodeParams);
					float Right1 = GetNeighbourDepth(Sampleuv,float2(1,0),EncodeParams,DecodeParams);
					float Right2 = GetNeighbourDepth(Sampleuv,float2(1,1),EncodeParams,DecodeParams);

					//	figure out if our value is way off (chroma plane or luma value dont align)
					float Diff_L1 = abs(Depth-Left1);
					float Diff_L2 = abs(Depth-Left2);
					float Diff_R1 = abs(Depth-Right1);
					float Diff_R2 = abs(Depth-Right2);


					float FarDist = max(Diff_L1,max(Diff_L2,max(Diff_R1,Diff_R2)));
					float NearDist = min(Diff_L1,min(Diff_L2,min(Diff_R1,Diff_R2)));

					//	if near enough to a neighbour, just score
					if ( NearDist <= MaxEdgeDepth )
					{
						Score = 1;//1 - (NearDist / ScoreEdgeDepth);
					}
					else // if best score is low, then snap to a neighbours depth
					{
						float BestDepth = Left1;
						BestDepth = lerp( BestDepth, Left1, abs(Left1-Depth) < abs(BestDepth-Depth) );
						BestDepth = lerp( BestDepth, Left2, abs(Left2-Depth) < abs(BestDepth-Depth) );
						BestDepth = lerp( BestDepth, Right1, abs(Right1-Depth) < abs(BestDepth-Depth) );
						BestDepth = lerp( BestDepth, Right2, abs(Right2-Depth) < abs(BestDepth-Depth) );
						Depth = BestDepth;
						Score = 1 - (NearDist / ScoreEdgeDepth);
					}

					//	typically zero (sometimes ~4 post vidoe decoding) means invalid
					//	Popcap should standardise this to far-away  
					if ( Depth < ValidMinMetres )
						Score = 0;
				}

				
				fixed4 frag(v2f i) : SV_Target
				{					
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


					if ( DEBUG_MINOR_AS_VALID )
					{
						float2 Sampleuv = i.uv;
						float Luma = GetLuma(Sampleuv);
						return float4(OutputPosition, Luma);
					}

					if ( DEBUG_MAJOR_AS_VALID )
					{
						float2 Sampleuv = i.uv;
						float2 ChromaUV = GetChromaUv(Sampleuv);
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
