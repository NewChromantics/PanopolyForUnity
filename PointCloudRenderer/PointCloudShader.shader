Shader "Panopoly/PointCloudShader"
{
    Properties
    {
		CloudPositions("CloudPositions", 2D) = "white" {}
		CloudColours("CloudColours", 2D) = "white" {}
		PointSize("PointSize",Range(0.001,0.05)) = 0.01
		[Toggle]Billboard("Billboard", Range(0,1)) = 1
		[Toggle]DrawInvalidPositions("DrawInvalidPositions",Range(0,1)) = 0
		[Toggle]Debug_InvalidPositions("Debug_InvalidPositions",Range(0,1))= 0

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
		Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			#include "UnityCG.cginc"
			#include "PointCloudShader.cginc"

            struct appdata
            {
				float3 TriangleUv_PointIndex : POSITION;
				float3 PointMapUv_VertexIndex : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 OverrideColour : TEXCOORD1;
            };

			//sampler2D CloudPositions;
			Texture2D<float4> CloudPositions;
			SamplerState sampler_CloudPositions;

			sampler2D CloudColours;
			float4 CloudPositions_texelSize;
			float4 CloudColours_texelSize;
			float Billboard;
			float PointSize;
#define ENABLE_BILLBOARD	(Billboard>0.5)
			float DrawInvalidPositions;
			float Debug_InvalidPositions;
#define DRAW_INVALIDPOSITIONS	(DrawInvalidPositions>0.5)
#define DEBUG_INVALIDPOSITIONS	(Debug_InvalidPositions>0.5)

			//float4x4 CameraToWorld;


            v2f vert (appdata v)
            {
				//	position in camera space
				float3 CameraPosition;
				float2 ColourUv;
				float Validf = 1;
				float2 VertexUv = v.TriangleUv_PointIndex.xy;
				float2 PointMapUv = v.PointMapUv_VertexIndex.xy;
				Vertex_uv_TriangleIndex_To_CloudUvs(CloudPositions, sampler_CloudPositions, VertexUv, PointMapUv, PointSize, CameraPosition, ColourUv, Validf);
				//float3 CameraPosition = GetTrianglePosition(TriangleIndex, ColourUv, Valid);
				bool Valid = Validf > 0.5;

				//	gr: here, do billboarding, and repalce below with UnityWorldToClipPos
				v2f o;
				o.vertex = UnityObjectToClipPos(CameraPosition);
                o.uv = ColourUv;
				o.OverrideColour = float4(0, 0, 0, 0);
				
				if (!Valid && DEBUG_INVALIDPOSITIONS)
				{
					o.OverrideColour = float4(0, 1, 0, 1);
				}
				else if (!Valid && !DRAW_INVALIDPOSITIONS)
				{
					o.vertex = float4(0, 0, 0, 0);
				}
				
                return o;
            }

			float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 Colour = tex2D(CloudColours, i.uv);
				Colour = lerp(Colour, i.OverrideColour, i.OverrideColour.w);
                return Colour;
            }
            ENDCG
        }
    }
}
