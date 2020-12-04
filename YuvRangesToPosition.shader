Shader "Panopoly/YuvRangesToPosition"
{
	Properties
	{
		_Angle ("Angle", Range(-5.0,  5.0)) = 0.0

		[MainTexture]LumaPlane("LumaPlane", 2D) = "white" {}
		Plane2("Plane2", 2D) = "white" {}
		Plane3("Plane3", 2D) = "white" {}
		[IntRange]PlaneCount("PlaneCount",Range(0,3)) = 3

		[Header(Encoding Params from PopCap)]Encoded_DepthMinMetres("Encoded_DepthMinMetres",Range(0,30)) = 0
		Encoded_DepthMaxMetres("Encoded_DepthMaxMetres",Range(0,30)) = 5
		[IntRange]Encoded_ChromaRangeCount("Encoded_ChromaRangeCount",Range(1,128)) = 1
		[Toggle]Encoded_LumaPingPong("Encoded_LumaPingPong",Range(0,1)) = 1
		[Toggle]Debug_Depth("Debug_Depth",Range(0,1)) = 0
		[Header(Temporary until invalid depth is standardised)]ValidMinMetres("ValidMinMetres",Range(0,1)) = 0
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


				float _Angle;
				sampler2D LumaPlane;
				float4 LumaPlane_ST;
				sampler2D Plane2;
				sampler2D Plane3;
				int PlaneCount;
				#define ChromaUPlane	Plane2
				#define ChromaVPlane	Plane3
				#define ChromaUVPlane	Plane2

				int Encoded_ChromaRangeCount;
				float Encoded_DepthMinMetres;
				float Encoded_DepthMaxMetres;
				bool Encoded_LumaPingPong;


				//	this.FrameMeta.CameraToLocalViewportMinMax = [0,0,0,wh[0],wh[1],1000];
				float3 CameraToLocalViewportMin;
				float3 CameraToLocalViewportMax;
				float4x4 CameraToLocalTransform;

				float4x4 LocalToWorldTransform;
				float ApplyLocalToWorld;
				#define APPLY_LOCAL_TO_WORLD	(ApplyLocalToWorld>0.5)
				
				float Debug_Depth;
				#define DEBUG_DEPTH	(Debug_Depth>0.5)

			

				float ValidMinMetres;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);

					// Pivot
	                float2 pivot = float2(0.5, 0.5);
	                // Rotation Matrix
	                float cosAngle = cos(_Angle);
	                float sinAngle = sin(_Angle);
	                float2x2 rot = float2x2(cosAngle, -sinAngle, sinAngle, cosAngle);
	 
	                // Rotation consedering pivot
	                float2 uv = TRANSFORM_TEX(v.uv, LumaPlane) - pivot;
	                o.uv = mul(rot, uv);
	                o.uv += pivot;
					
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
				
				fixed4 frag(v2f i) : SV_Target
				{
					PopYuvEncodingParams Params;
					Params.ChromaRangeCount = Encoded_ChromaRangeCount;
					Params.DepthMinMetres = Encoded_DepthMinMetres;
					Params.DepthMaxMetres = Encoded_DepthMaxMetres;
					Params.PingPongLuma = Encoded_LumaPingPong;

					float Luma = GetLuma(i.uv);
					float2 ChromaUV = GetChromaUv(i.uv);
					bool Valid = true;
					float CameraDepth = GetCameraDepth(Luma, ChromaUV.x, ChromaUV.y, Params, Valid, ValidMinMetres);
					
					//	this output should be in camera-local space
					//	need a proper inverse projection matrix here to go from pixel/uv to projected out from camera
					//float x = lerp(-1,1,i.uv.x); 
					//float y = lerp(-1,1,i.uv.y);
					float x = lerp(0,1,i.uv.x); 
					float y = lerp(0,1,i.uv.y);
					float z = CameraDepth;
					
					//	now convert camera(image) space depth by the inverse of projection to get local-space

					float4 CameraPosition = float4(x,y,z,1.0);

					CameraPosition.xyz = lerp( CameraToLocalViewportMin, CameraToLocalViewportMax, CameraPosition.xyz );
	
					//	conversion
					//	https://developer.apple.com/documentation/arkit/arcamera/2875730-intrinsics?language=objc
					//mat4 CameraToLocal = ApplyCameraToLocalTransformInverse ? CameraToLocalTransformInverse : CameraToLocalTransform;
					//	gr: note: using camera depth, not CameraPosition.z
					float Depth = CameraDepth;
					float fx = CameraToLocalTransform[0].x;
					float fy = CameraToLocalTransform[1].y;
					float cx = CameraToLocalTransform[0].z;
					float cy = CameraToLocalTransform[1].z;
					float4 LocalPosition4;

					//	is this just the inverse of a/the projection matrix?
					float4x4 CameraToLocal;
					CameraToLocal[0] = float4(1.0/fx,	0,	0,0);
					CameraToLocal[1] = float4(0,		1.0/fy,0,0);
					CameraToLocal[2] = float4(0,		0,	1,0);
					CameraToLocal[3] = float4(0,		0,	0,1);

					LocalPosition4.x = (CameraPosition.x - cx);
					LocalPosition4.y = (CameraPosition.y - cy);
					LocalPosition4.z = 1;
					LocalPosition4.w = 1/Depth;	//	scale all by depth

					LocalPosition4 = mul(CameraToLocal,LocalPosition4);
					float3 LocalPosition = LocalPosition4.xyz / LocalPosition4.www;


					float4 WorldPosition4 = mul(LocalToWorldTransform,float4(LocalPosition,1));
					float3 WorldPosition = WorldPosition4.xyz / WorldPosition4.www;
				
					//	should we convert to world-pos here (with camera localtoworld) web version currently does not
					//	because webgl cant always do float textures so is quantized 8bit
					//	in native, we could
					float3 OutputPosition = APPLY_LOCAL_TO_WORLD ? WorldPosition : LocalPosition;

					if ( DEBUG_DEPTH )
					{
						float3 Rgb = NormalToRedGreen(CameraDepth);
						return float4(Rgb, 1.0);
					}
					
					float Alpha = Valid ? 1.0 : 0.0;
					return float4(OutputPosition, Alpha);
				}
				ENDCG
			}
		}
}
