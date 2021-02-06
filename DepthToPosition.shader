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


#define vec2 float2
#define vec3 float3
#define vec4 float4
#define InputTexture _MainTex
float4 _MainTex_TexelSize;
#define InputTextureSize	(_MainTex_TexelSize.zw)
#define NO_MAIN
				#include "DepthToPosition.Frag.glsl"

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);

					o.uv = v.uv;

					if ( FLIP_SAMPLE )
						o.uv.y = 1.0 - o.uv.y;
					
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{
					return DepthToPosition(i.uv);
				}
				ENDCG
			}
		}
}
