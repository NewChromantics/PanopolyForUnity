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

			sampler2D CloudPositions;
			sampler2D CloudColours;
			float4 CloudPositions_texelSize;
			float4 CloudColours_texelSize;

			float SphereX;
			float SphereY;
			float SphereZ;
			float SphereRad;

			float MaxHitDistance;
			float EnableInsideDetection;
			#define ENABLE_INSIDE_DETECTION	(EnableInsideDetection>0.5f)
			float MarchNearDistance;
			float MarchFarDistance;


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
				o.WorldNormal = normalize(UnityObjectToWorldNormal(v.normal));
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

#if defined(ENABLE_CAMERA_DEBUG)
				if (DEBUG_CAMERA_CENTER)
				{
					float4 CameraCenterSphere = float4(CameraCenter,SphereRad);
					GetDistance_TestSphere(CameraCenterSphere,RayPosWorld,Distance,Colour);
					if ( Distance <= 0)
						return true;
				}
#endif

				//	world -> cloud space
				float4 RayPosCloud4 = mul(WorldToLocalTransform,float4(RayPosWorld,1));
				RayPosCloud4.xyz /= RayPosCloud4.www;

				//	cloud space -> camera space (2d)
				float4 RayPosCamera4 = mul(LocalToCameraTransform,float4(RayPosCloud4.xyz,1));
				float3 RayPosCamera3 = RayPosCamera4.xyz / RayPosCamera4.www;

				//	camera image space to uv
				//	gr: do I div or mult by z
				//	gr: by checking distance against a Z, we can see this needs to be /z
				float2 RayPosCamera2 = RayPosCamera3.xy / RayPosCamera3.zz;
				float2 RayPosUv = Range2( CameraToLocalViewportMin, CameraToLocalViewportMax, RayPosCamera2 );

				//	out of view frustum (either uv should be out)
				//	or behind camera
				if ( !IsInside01(RayPosUv.x) || !IsInside01(RayPosUv.y) || RayPosCamera3.z < 0 )
					return false;

				//	gr: not sure why I need to flip, I think normally we render bottom to top, but here we're in camera space...
				float2 RayColourUv = RayPosUv;
				if ( FLIP_COLOUR_SAMPLE )
					RayColourUv.y = 1.0 - RayColourUv.y;
				if ( FLIP_POSITION_SAMPLE )
					RayPosUv.y = 1.0 - RayPosUv.y;

				//	get world depth/pos (does this need transform?)
				float4 RayHitCloudPos = tex2D(CloudPositions,RayPosUv);
				Distance = distance( RayPosWorld, RayHitCloudPos.xyz );
				Colour = tex2D(CloudColours,RayColourUv);

#if defined(ENABLE_CAMERA_DEBUG)
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
#endif
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
