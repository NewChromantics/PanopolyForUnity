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
		[Toggle]ClipToQuad("ClipToQuad", Range(0,1)) = 1
		ClipQuadSize("ClipQuadSize",Range(0,1)) = 0.5
		[Toggle]WeldToNeighbour("WeldToNeighbour",Range(0,1))=1
		MaxWeldDistance("MaxWeldDistance",Range(0.0001,0.1))=0.02
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
                float2 SampleUv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 OverrideColour : TEXCOORD1;
                float2 TriangleUv : TEXCOORD2;
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

			float ClipToQuad;
			#define CLIP_TO_QUAD	(ClipToQuad>0.5f)
			float ClipQuadSize;
			//float4x4 CameraToWorld;

			float WeldToNeighbour;
			#define WELD_TO_NEIGHBOUR	(WeldToNeighbour>0.5f)
			float MaxWeldDistance;

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

            v2f vert (appdata v)
            {
				//	position in camera space
				float3 CameraPosition;
				float2 ColourUv;
				float Validf = 1;
				float2 VertexUv = v.TriangleUv_PointIndex.xy;
				float2 PointMapUv = v.PointMapUv_VertexIndex.xy;

				Vertex_uv_TriangleIndex_To_CloudUvs(CloudPositions, sampler_CloudPositions, VertexUv, PointMapUv, PointSize, MaxWeldDistance, WELD_TO_NEIGHBOUR, CameraPosition, ColourUv, Validf);
				//float3 CameraPosition = GetTrianglePosition(TriangleIndex, ColourUv, Valid);
				bool Valid = Validf > 0.5;

				//	gr: here, do billboarding, and repalce below with UnityWorldToClipPos
				v2f o;
				o.vertex = UnityObjectToClipPos(CameraPosition);
                o.SampleUv = ColourUv;
				o.TriangleUv = VertexUv;
				o.OverrideColour = float4(0, 0, 0, 0);
				
				if ( Validf < 1.0 && DEBUG_INVALIDPOSITIONS )
				{
					o.OverrideColour = float4(0, 1, 0, 1);
					o.OverrideColour.xyz = NormalToRedGreen(Validf);
				}

				if (!Valid && !DRAW_INVALIDPOSITIONS && !DEBUG_INVALIDPOSITIONS)
				{
					o.vertex = float4(0, 0, 0, 0);
				}
				
                return o;
            }

			float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 Colour = tex2D(CloudColours, i.SampleUv);
				Colour = lerp(Colour, i.OverrideColour, i.OverrideColour.w);

				if ( CLIP_TO_QUAD )
					if ( i.TriangleUv.x > ClipQuadSize || i.TriangleUv.y > ClipQuadSize )
						discard;

                return Colour;
            }
            ENDCG
        }
    }
}
