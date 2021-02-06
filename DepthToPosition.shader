Shader "Panopoly/DepthToPosition"
{
	Properties
	{
		[MainTexture]_MainTex("Texture", 2D) = "white" {}
		[Header(Encoding Params from PopCap)]Encoded_DepthMinMetres("Encoded_DepthMinMetres",Range(0,30)) = 0
		Encoded_DepthMaxMetres("Encoded_DepthMaxMetres",Range(0,30)) = 5
		[IntRange]Encoded_ChromaRangeCount("Encoded_ChromaRangeCount",Range(1,128)) = 1
		[Toggle]Encoded_LumaPingPong("Encoded_LumaPingPong",Range(0,1)) = 1
		ClipFarMetres("ClipFarMetres",Range(0,10)) = 10
		ClipNearMetres("ClipNearMetres",Range(0,5)) = 0
		[Toggle]Debug_Valid("Debug_Valid",Range(0,1))=0
		[Toggle]Debug_InputDepth("Debug_InputDepth",Range(0,1))=0
		[Toggle]Debug_OutputDepth("Debug_OutputDepth",Range(0,1)) = 0
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

//	now done exclusively in yuv->depth
#define FLIP_SAMPLE	(false)
#define FLIP_OUTPUT	(false)

				sampler2D _MainTex;
				float4 _MainTex_TexelSize;
			#define DepthTexture	_MainTex
			#define DepthTexture_TexelSize	_MainTex_TexelSize
				
				int Encoded_ChromaRangeCount;
				float Encoded_DepthMinMetres;
				float Encoded_DepthMaxMetres;
				bool Encoded_LumaPingPong;

				//	any clipping we HAVE to do in this shader as its post-projection scaling 
				float ClipFarMetres;
				float ClipNearMetres;

				float DecodedLumaMin;
				float DecodedLumaMax;


				//	this.FrameMeta.CameraToLocalViewportMinMax = [0,0,0,wh[0],wh[1],1000];
				float3 CameraToLocalViewportMin;
				float3 CameraToLocalViewportMax;
				float4x4 CameraToLocalTransform;

				float4x4 LocalToWorldTransform;
				float ApplyLocalToWorld;
				#define APPLY_LOCAL_TO_WORLD	(ApplyLocalToWorld>0.5)

				float Debug_Valid;
				#define DEBUG_VALID	(Debug_Valid>0.5)

				float Debug_InputDepth;
				#define DEBUG_INPUT_DEPTH	(Debug_InputDepth>0.5)

				float Debug_OutputDepth;
				#define DEBUG_OUTPUT_DEPTH	(Debug_OutputDepth>0.5)

				float Debug_DepthAsValid;
				#define DEBUG_DEPTH_AS_VALID	(Debug_DepthAsValid>0.5)

				float Debug_PlaceInvalidDepth;
			#define DEBUG_PLACE_INVALID_DEPTH	(Debug_PlaceInvalidDepth>0.5)

				float Debug_DepthMinMetres;
				float Debug_DepthMaxMetres;

				float ValidMinMetres;
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
	
				float GetDepth(float2 uv)
				{
					return tex2D(DepthTexture, uv).x;
				}			

				float2 GetDepthAndValid(float2 uv)
				{
					return tex2D(DepthTexture, uv).xw;
				}

				float2 GetDepthUvStep(float xMult,float yMult)
				{
					return DepthTexture_TexelSize * float2(xMult,yMult);
				}
				
				float2 GetDepthUvAligned(float2 uv)
				{
					float2 Overflow = fmod(uv,DepthTexture_TexelSize);
					return uv - Overflow;
				}


				void GetResolvedDepth(out float Depth,out float Score,float2 Sampleuv,PopYuvEncodingParams EncodeParams)
				{
					float2 OffsetPixels = float2(0,0);
					float2 SampleLumauv = GetDepthUvAligned(Sampleuv) + GetDepthUvStep( OffsetPixels.x, OffsetPixels.y ) + GetDepthUvStep(0.5,0.5);
					float2 DepthValid = GetDepthAndValid( SampleLumauv );
					Depth = lerp( EncodeParams.DepthMinMetres, EncodeParams.DepthMaxMetres, DepthValid.x );
					Score = DepthValid.y;
				}

				
				fixed4 frag(v2f i) : SV_Target
				{
					if ( DEBUG_INPUT_DEPTH )
					{
						float2 DepthValid = GetDepthAndValid(i.uv);
						return float4(DepthValid.xxxy);
					}

					if ( DEBUG_VALID )
					{
						float Alpha = GetDepthAndValid(i.uv).y;
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

					if ( LocalPosition.z > ClipFarMetres )
						DepthScore = 0.0;
					if ( LocalPosition.z < ClipNearMetres )
						DepthScore = 0.0;

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

					if ( DEBUG_OUTPUT_DEPTH )
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
