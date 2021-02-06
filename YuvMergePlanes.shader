Shader "Panopoly/YuvMergePlanes"
{
	Properties
	{
		[MainTexture]LumaPlane("LumaPlane", 2D) = "white" {}
		Plane2("Plane2", 2D) = "white" {}
		Plane3("Plane3", 2D) = "white" {}
		[IntRange]PlaneCount("PlaneCount",Range(0,3)) = 3
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
				
				fixed4 frag(v2f i) : SV_Target
				{
					float2 Sampleuv = i.uv;
					float2 SampleLumauv = GetLumaUvAligned(Sampleuv) + GetLumaUvStep(0.5,0.5);
					float2 SampleChromauv = GetChromaUvAligned(Sampleuv) + GetChromaUvStep(0.5,0.5);
					float Luma = GetLuma( SampleLumauv );
					float2 ChromaUV = GetChromaUv( SampleChromauv );
//Luma = 0;
//ChromaUV.x = 0;
//ChromaUV.y = 0;
					return float4(Luma,ChromaUV.x,ChromaUV.y,1);
				}
				ENDCG
			}
		}
}
