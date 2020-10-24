Shader "Panopoly/YuvToRgb"
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
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "../PopUnity/PopYuv.cginc"

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


			sampler2D LumaPlane;
			float4 LumaPlane_ST;
			sampler2D Plane2;
			sampler2D Plane3;
			int PlaneCount;
			#define ChromaUPlane	Plane2
			#define ChromaVPlane	Plane3
			#define ChromaUVPlane	Plane2

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;//TRANSFORM_TEX(v.uv, LumaPlane);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				YuvColourParams YuvParams = GetDefaultYuvColourParams();
				float3 Rgb;
				
				if ( PlaneCount == 3 )
				{
					Rgb = Yuv_8_8_8_To_Rgb( i.uv, LumaPlane, ChromaUPlane, ChromaVPlane, YuvParams );
				}
				else if ( PlaneCount == 2 )
				{
					Rgb = Yuv_8_88_To_Rgb( i.uv, LumaPlane, ChromaUVPlane, YuvParams );
				}
				else
				{
					//	fallback
					Rgb = tex2D(LumaPlane,i.uv).xxx;
				}
				
				return float4(Rgb,1.0);
			}
		ENDCG
		}
	}
}
