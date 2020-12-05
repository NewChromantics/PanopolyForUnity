// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Panopoly/PointCloudRayMarch"
{
    Properties
    {
		CloudPositions("CloudPositions", 2D) = "white" {}
		CloudColours("CloudColours", 2D) = "white" {}
		PointSize("PointSize",Range(0.001,0.05)) = 0.01
		[Toggle]Billboard("Billboard", Range(0,1)) = 1
		[Toggle]DrawInvalidPositions("DrawInvalidPositions",Range(0,1)) = 0
		[Toggle]Debug_InvalidPositions("Debug_InvalidPositions",Range(0,1))= 0

		[Toggle]EnableInsideDetection("EnableInsideDetection",Range(0,1))=1
		MaxHitDistance("MaxHitDistance",Range(0.001,0.2) ) = 0.001
		MarchNearDistance("MarchNearDistance",Range(-1,10) ) = 0
		MarchFarDistance("MarchFarDistance",Range(-1,10) ) = 5

		SphereX("SphereX",Range(-2,2)) = 0
		SphereY("SphereY",Range(-2,2)) = 0
		SphereZ("SphereZ",Range(-2,2)) = 0
		SphereRad("SphereRad",Range(0,1)) = 0.1

		CameraTestZ("CameraTestZ",Range(0,10)) = 0.3
		[Toggle]DebugCameraColourUv("DebugCameraColourUv",Range(0,1)) = 0
		[Toggle]DebugCameraColourDistanceToCamera("DebugCameraColourDistanceToCamera",Range(0,1)) = 0
		[Toggle]DebugCameraColourPosition("DebugCameraColourPosition",Range(0,1)) = 0
		[Toggle]DebugCameraCenter("DebugCameraCenter",Range(0,1)) = 0
		[Toggle]DebugCameraTestPlane("DebugCameraTestPlane",Range(0,1)) = 0
		DebugColourDistanceMin("DebugColourDistanceMin",Range(0,10)) = 0
		DebugColourDistanceMax("DebugColourDistanceMax",Range(0,10)) = 5
		[Toggle]FlipColourSample("FlipColourSample",Range(0,1)) = 1
		[Toggle]FlipPositionSample("FlipPositionSample",Range(0,1)) = 1
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

			//#define ENABLE_CAMERA_DEBUG

            #include "UnityCG.cginc"
			#include "PointCloudRayMarch.cginc"

            //  https://github.com/SoylentGraham/PopUnityCommon/blob/master/PopCommon.cginc
            float3 UnityObjectToWorldPos(float3 LocalPos)
            {
	            return mul( unity_ObjectToWorld, float4( LocalPos, 1 ) ).xyz;
            }


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float3 WorldPosition : TEXCOORD1;
                float3 LocalPosition : TEXCOORD2;
                float4 vertex : SV_POSITION;
				half3 WorldNormal : TEXCOORD3;
            };

			float SphereX;
			float SphereY;
			float SphereZ;
			float SphereRad;

			float MaxHitDistance;
#define MinHitDistance	(MaxHitDistance*0.5f)
			float EnableInsideDetection;
			#define ENABLE_INSIDE_DETECTION	(EnableInsideDetection>0.5f)
#define ENABLE_EARLY_Z_BREAK	true
			float MarchNearDistance;
			float MarchFarDistance;

			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.WorldPosition = UnityObjectToWorldPos(v.vertex);
                o.LocalPosition = (v.vertex);
				o.WorldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                return o;
            }


			//	http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
			float sdSphere( float3 p, float s )
			{
				  return length(p)-s;
			}

			void GetDistance_TestSphere(float4 SphereWorld,float3 RayPosWorld,out float Distance,out float3 Colour)
			{
				//	test sphere in world space
				float3 RayPosLocal = RayPosWorld - SphereWorld.xyz;
				Distance = sdSphere(RayPosLocal,SphereWorld.w);

				if ( Distance > SphereWorld.w )
					return;
					
				//	calc norm of the point we hit
				//	note: this is NOT the right normal. we should do 4x samples to get proper normal
				float3 Normal = normalize(RayPosLocal);
				Normal += 1;
				Normal /= 2;

				Colour = Normal;
			}

			bool GetDistance_ToProjection(float3 RayPosWorld,out float Distance,out float3 Colour)
			{
				float4 NearCloudPosition = GetCameraNearestCloudPosition(RayPosWorld,Colour);
				if ( NearCloudPosition.w < 0.5 )
				{
					Distance = 999;
					return false;
				}

				Distance = distance( RayPosWorld, NearCloudPosition.xyz );
				return true;
			}



			void GetDistance(float3 RayPosWorld,out float Distance,out float3 Colour)
			{
				GetDistance_ToProjection( RayPosWorld, Distance, Colour );
				return;

				float4 DebugSphere = float4(SphereX,SphereY,SphereZ,SphereRad);
				float SphereDistance;
				float3 SphereColour;
				GetDistance_TestSphere(DebugSphere,RayPosWorld,SphereDistance,SphereColour);

				float CloudDistance;
				float3 CloudColor;
				if ( GetDistance_ToProjection( RayPosWorld, CloudDistance, CloudColor ) )
				{
					Distance = CloudDistance;
					Colour = CloudColor;
				}
				else
				{
					Distance = 999;
					//Distance = SphereDistance;
					//Colour = SphereColour;
				}

			}


            fixed4 frag (v2f input) : SV_Target
            {
                //  ressurrected from 2016
                //  https://github.com/NewChromantics/PopHolograham/blob/master/Assets/CubeVolume/RayVolume.shader
                //  get ray from camera to frag surface point (our only world reference) gives us a ray
                float4 CameraPos4 = float4( _WorldSpaceCameraPos, 1 );
				float3 CameraPosLocal = mul( unity_WorldToObject, CameraPos4 );
				float3 RayDirection = normalize(input.WorldPosition - CameraPos4.xyz);
				//	we want ray AWAY from the camera
				RayDirection *= -1;

				bool Inside = ENABLE_INSIDE_DETECTION && dot(input.WorldNormal,RayDirection) <= 0;

				//	hardcoded to unroll loop									
				#define MARCH_STEPS 100

				//	ray needs to start at the camera if we're INSIDE the shape, otherwise frag pos is the backface
				//	gr: if we're inside, we could force the far distance to be the ray pos, then we won't draw
				//		past the geometry in world space	MarchFarDistance = 
				float3 RayEyeStart = Inside ? _WorldSpaceCameraPos : input.WorldPosition;
				float3 RayMarchDir = -RayDirection;//normalize(input.WorldPosition - RayEyeStart);

				float3 RayMarchStart = RayEyeStart + (RayMarchDir * MarchNearDistance);
				float3 RayMarchEnd = RayEyeStart + (RayMarchDir * MarchFarDistance);

				float BestDistance = 99;
				float3 BestColour = float3(0,1,1);

				float RayStep = distance(RayMarchEnd,RayMarchStart) / float(MARCH_STEPS);
				float RayDistance = 0;	//	this is ray time, but now in worldspace units
				for ( int i=0;	i<MARCH_STEPS;	i++ )
				{
					float3 RayPosition = RayMarchStart + (RayMarchDir*RayDistance);

					float HitDistance = 999;
					float3 HitColour;
					GetDistance(RayPosition,HitDistance,HitColour);

					//	step ray forward
					//	allow smaller steps
					//	gr: for our heightmap stepping, if this is <step, we may want to step backwards
					RayDistance += min( HitDistance, RayStep );

					//	gr; move t along by distance, normally, but we need fixed step for this
					//	worse than current best
					if ( HitDistance > BestDistance )
						continue;

					//	gr: we're gettting z order issues, bail early if this is good enough
					if ( ENABLE_EARLY_Z_BREAK && BestDistance <= MinHitDistance )
						break;

					BestDistance = HitDistance;
					BestColour = HitColour;
				}

				//	max distance can only be the (far-near) distance now
				//if ( BestDistance > MarchFarDistance )
				//	didn't get close enough to anything
				if ( BestDistance > MaxHitDistance )
					discard;
		
                return float4(BestColour,1.0);
                //return float4(i.WorldPosition,1.0);
            }
            ENDCG
        }
    }
}
