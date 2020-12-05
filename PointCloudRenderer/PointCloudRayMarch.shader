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

		SphereX("SphereX",Range(-2,2)) = 0
		SphereY("SphereY",Range(-2,2)) = 0
		SphereZ("SphereZ",Range(-2,2)) = 0
		SphereRad("SphereRad",Range(0,1)) = 0.1

		MaxHitDistance("MaxHitDistance",Range(0,0.2) ) = 0.001
		MaxMarchDistance("MaxMarchDistance",Range(0.001,10) ) = 5

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

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            //  https://github.com/SoylentGraham/PopUnityCommon/blob/master/PopCommon.cginc
            float3 UnityObjectToWorldPos(float3 LocalPos)
            {
	            return mul( unity_ObjectToWorld, float4( LocalPos, 1 ) ).xyz;
            }


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 WorldPosition : TEXCOORD1;
                float3 LocalPosition : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

			sampler2D CloudPositions;
			sampler2D CloudColours;
			float4 CloudPositions_texelSize;
			float4 CloudColours_texelSize;

			float SphereX;
			float SphereY;
			float SphereZ;
			float SphereRad;

			float MaxHitDistance;
			float MaxMarchDistance;

			//	this.FrameMeta.CameraToLocalViewportMinMax = [0,0,0,wh[0],wh[1],1000];
			float3 CameraToLocalViewportMin;
			float3 CameraToLocalViewportMax;
			float4x4 CameraToLocalTransform;
			float4x4 LocalToCameraTransform;
			float4x4 WorldToLocalTransform;

			float CameraTestZ;
			float DebugCameraColourUv;
			float DebugCameraColourDistanceToCamera;
			float DebugCameraColourPosition;
			float DebugCameraCenter;
			float DebugCameraTestPlane;
#define DEBUG_COLOUR_UV		(DebugCameraColourUv>0.5f)
#define DEBUG_COLOUR_DISTANCE_TO_CAMERA	(DebugCameraColourDistanceToCamera>0.5f)
#define DEBUG_COLOUR_POSITION	(DebugCameraColourPosition>0.5f)
#define DEBUG_CAMERA_CENTER	(DebugCameraCenter>0.5f)
#define DEBUG_CAMERA_TEST_PLANE	(DebugCameraTestPlane>0.5f)
			float FlipColourSample;
			float FlipPositionSample;
			#define FLIP_COLOUR_SAMPLE		true	//(FlipColourSample>0.5f)
			#define FLIP_POSITION_SAMPLE	false	//(FlipPositionSample>0.5f)

			float DebugColourDistanceMin;
			float DebugColourDistanceMax;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.WorldPosition = UnityObjectToWorldPos(v.vertex);
                o.LocalPosition = (v.vertex);
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

			bool IsInside01(float v)
			{
				return (v>0.0) && (v<1.0);
			}

			float Range(float Min,float Max,float Value)
			{
				return (Value-Min) / (Max-Min);
			}

			float2 Range2(float2 Min,float2 Max,float2 Value)
			{
				float x = Range(Min.x,Max.x,Value.x);
				float y = Range(Min.y,Max.y,Value.y);
				return float2(x,y);
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
				//	draw sphere at 0,0,0 in cameralocal space
				float4 CameraCenterWorld = mul(WorldToLocalTransform,float4(0,0,0,1));
				float3 CameraCenter = CameraCenterWorld.xyz / CameraCenterWorld.www;
				Distance = 999;
				if (DEBUG_CAMERA_CENTER)
				{
					float4 CameraCenterSphere = float4(CameraCenter,SphereRad);
					GetDistance_TestSphere(CameraCenterSphere,RayPosWorld,Distance,Colour);
					if ( Distance <= 0)
						return true;
				}

				//	world -> cloud space
				float4 RayPosCloud4 = mul(WorldToLocalTransform,float4(RayPosWorld,1));
				RayPosCloud4.xyz /= RayPosCloud4.www;

				//	cloud space -> camera space (2d)
				float4 RayPosCamera4 = mul(LocalToCameraTransform,float4(RayPosCloud4.xyz,1));
				float3 RayPosCamera3 = RayPosCamera4.xyz / RayPosCamera4.www;

				//	behind camera
				if ( RayPosCamera3.z < 0 )
					return false;

				//	camera image space to uv
				//	gr: do I div or mult by z
				//	gr: by checking distance against a Z, we can see this needs to be /z
				float2 RayPosCamera2 = RayPosCamera3.xy / RayPosCamera3.zz;
				float2 RayPosUv = Range2( CameraToLocalViewportMin, CameraToLocalViewportMax, RayPosCamera2 );

				//	gr: not sure why I need to flip, I think normally we render bottom to top, but here we're in camera space...
				float2 RayColourUv = RayPosUv;
				if ( FLIP_COLOUR_SAMPLE )
					RayColourUv.y = 1.0 - RayColourUv.y;
				if ( FLIP_POSITION_SAMPLE )
					RayPosUv.y = 1.0 - RayPosUv.y;

				//	out of view frustum (either uv should be out)
				if ( !IsInside01(RayPosUv.x) || !IsInside01(RayPosUv.y) )
					return false;

				//	get world depth/pos (does this need transform?)
				float4 RayHitCloudPos = tex2D(CloudPositions,RayPosUv);
				Distance = distance( RayPosWorld, RayHitCloudPos.xyz );
				Colour = tex2D(CloudColours,RayColourUv);

				if ( DEBUG_COLOUR_UV )
				{
					Colour = float3(RayPosUv,0);
				}
				else if ( DEBUG_COLOUR_DISTANCE_TO_CAMERA )
				{
					float CameraDistance = distance( RayPosWorld, CameraCenter );
					CameraDistance = Range(DebugColourDistanceMin,DebugColourDistanceMax,CameraDistance);
					Colour = NormalToRedGreen(CameraDistance);
				}
				else if ( DEBUG_COLOUR_POSITION )
				{
					Colour = RayHitCloudPos.xyz;
				}
				
				if ( DEBUG_CAMERA_TEST_PLANE )
				{
					Distance = 0;
					Distance = abs(RayPosCamera3.z - CameraTestZ);
				}

				return true;
			}



			void GetDistance(float3 RayPosWorld,out float Distance,out float3 Colour)
			{
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
					//Distance = 999;
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
				//float3 RayDirection = normalize(ObjSpaceViewDir( float4(input.LocalPosition,1) ));
				//float3 RayPosition = input.LocalPosition;
				float3 RayDirection = input.WorldPosition - CameraPos4.xyz;
				float3 RayPosition = input.WorldPosition;
				//	we want ray AWAY from the camera
				RayDirection *= -1;



                
					
				//	start BEHIND for when we're INSIDE the bounds
				//	should auto determine this (ie, if we're looking at a backface)
				#if defined(TARGET_MOBILE)
					#define FORWARD_MARCHES		10
					#define BACKWARD_MARCHES	4
				#else
					#define FORWARD_MARCHES		200
					#define BACKWARD_MARCHES	10
				#endif


				#define MAX_HITDISTANCE	MaxHitDistance	//	gr: need to make this smarter 
				#define MAX_MARCH_DISTANCE MaxMarchDistance	//	need to find the far bounds or something
				float3 RayMarchStart = RayPosition;//_WorldSpaceCameraPos;
				float3 RayMarchDir = normalize(input.WorldPosition - _WorldSpaceCameraPos);
				float3 RayMarchEnd = RayMarchStart + ( RayMarchDir * MAX_MARCH_DISTANCE );

				float BestDistance = 99;
				float3 BestColour;

				[unroll(210)]
				for ( int i=-BACKWARD_MARCHES;	i<FORWARD_MARCHES;	i++ )
				{
					float t = i/(float)FORWARD_MARCHES;
					float3 RayPosition = lerp( RayMarchStart, RayMarchEnd, t );

					float HitDistance = 999;
					float3 HitColour;
					GetDistance(RayPosition,HitDistance,HitColour);

					//	gr; move t along by distance, normally, but we need fixed step for this
					//	worse than current best
					if ( HitDistance > BestDistance )
						continue;

					BestDistance = HitDistance;
					BestColour = HitColour;
				}

				if ( BestDistance > MAX_HITDISTANCE )
					discard;
		
                return float4(BestColour,1.0);
                //return float4(i.WorldPosition,1.0);
            }
            ENDCG
        }
    }
}
