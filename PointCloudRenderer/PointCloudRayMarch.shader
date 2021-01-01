// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Panopoly/PointCloudRayMarch"
{
    Properties
    {
		CloudPositions("CloudPositions", 2D) = "white" {}
		CloudColours("CloudColours", 2D) = "white" {}
		PointSize("PointSize",Range(0.001,0.05)) = 0.01

		[Toggle]CloudPositionsAreSdf("CloudPositionsAreSdf",Range(0,1))=0
        WorldBoundsMin("WorldBoundsMin",Vector) = (0,0,0)
        WorldBoundsMax("WorldBoundsMax",Vector) = (1,1,1)


		[Toggle]EnableInsideDetection("EnableInsideDetection",Range(0,1))=1
		MaxHitDistance("MaxHitDistance",Range(0.001,0.2) ) = 0.001
		MarchNearDistance("MarchNearDistance",Range(-1,10) ) = 0
		//MarchFarDistance("MarchFarDistance",Range(-1,10) ) = 5
		MarchStepBackwards("MarchStepBackwards",Range(-0.4,0.4))=0
		NoDataStepDistance("NoDataStepDistance",Range(0,1)) = 0.1
		MaxMarchDistance("MaxMarchDistance",Range(0.001,1) ) = 1
		
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

		[Toggle]DebugHeat("DebugHeat", Range(0,1)) = 0
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
#define CLOUD_RAYMARCH_SAMPLE_RADIUS    0
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
				int BlockDepth : TEXCOORD4;
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
			//float MarchFarDistance;
			float MarchStepBackwards;
			float NoDataStepDistance;
			float MaxMarchDistance;

#define INVALID_NEW_DIST    99
#define SAMPLE_INVALID_DIST    INVALID_NEW_DIST

			float DebugHeat;
			#define DEBUG_STEP_HEAT	(DebugHeat>0.5f)



			float CloudPositionsAreSdf;
			#define CLOUD_POSITIONS_SDF	(CloudPositionsAreSdf>0.5f)




			//	SDF map
			#define MAP_TEXTURE_WIDTH    (CloudPositions_TexelSize.z)
            #define MAP_TEXTURE_HEIGHT   (CloudPositions_TexelSize.w)

			//  gr: make sure these are integers!
			#define CALC_BLOCKDEPTH int( floor( sqrt(MAP_TEXTURE_HEIGHT) ) )
            #define BLOCKWIDTH  (MAP_TEXTURE_WIDTH)
            #define BLOCKDEPTH  (g_BlockDepth) //  gr: ditch the extra param and calculate it as sqrt instead
            #define BLOCKHEIGHT (int(MAP_TEXTURE_HEIGHT / float(BLOCKDEPTH)))

			//	distance written in the sdf writer, so we can(?) assume there's this much gap to next
			float MaxSdfDistance;
			float3 WorldBoundsMin;
			float3 WorldBoundsMax;

			
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.WorldPosition = UnityObjectToWorldPos(v.vertex);
                o.LocalPosition = (v.vertex);
				o.WorldNormal = normalize(UnityObjectToWorldNormal(v.normal));
				o.BlockDepth = CALC_BLOCKDEPTH;
                return o;
            }


			float udBox(float3 p,float3 b)
			{
				return length(max(abs(p)-b,0.0));
			}

			float sdSphere( float3 p, float s )
			{
				  return length(p)-s;
			}

			float sdBox(float3 p,float3 b )
			{
				float3 q = abs(p) - b;
				return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
			}


			struct MarchMeta_t
			{
				int BlockDepth;
			};

			int3 PointCloudMapUvToXyz(float2 uv,int g_BlockDepth)
            {
                int x = uv.x * BLOCKWIDTH;
                int Row = uv.y * BLOCKHEIGHT * BLOCKDEPTH;
                int y = Row % BLOCKHEIGHT;
                int z = Row / BLOCKHEIGHT;
                return int3(x,y,z);
            }

			//	non-int so we can do subsampling
			float2 PointCloudMapXyzToUv(float3 xyz,int g_BlockDepth)
            {
				float u = xyz.x / float(BLOCKWIDTH);

				//	z needs to round to blocks
				float pz = floor( xyz.z ) / float(BLOCKDEPTH);

				//	how high is the texture
				float TextureSampleHeight = float(BLOCKHEIGHT * BLOCKDEPTH) / float(MAP_TEXTURE_HEIGHT);

				float py = xyz.y / float(BLOCKHEIGHT);
				//	y sample is within 1 height section	
				py = py / float(BLOCKDEPTH);

				float v = pz + py;

				//	normalise from 0..1 to 0..h, inside texture height (which is our sqrt rounding error/alignment like 8000/8100)
				v *= TextureSampleHeight;

				return float2(u,v);
            }

			struct uvpair_t
			{
				float2 a;
				float2 b;
				float Blend;
			};

			uvpair_t PointCloudMapXyzNormToUv(float3 xyz,int g_BlockDepth,out float3 InternalXyz)
            {
				float3 Blockwhd = float3(BLOCKWIDTH,BLOCKHEIGHT,BLOCKDEPTH);


				//	0..1 needs converting, because Y & Z don't neccessarly align to pixels
				float x = xyz.x * float(BLOCKWIDTH);
				//	z needs to be on the correct plane. maybe here we should blend between 2 planes
				float zf = xyz.z * float(BLOCKDEPTH);
				float za = floor(zf);
				float zb = za+1.0;
				float zLerp = Range( za, zb, zf );
				float y = xyz.y * float(BLOCKHEIGHT);

				float2 SampleUva = PointCloudMapXyzToUv( float3(x,y,za), g_BlockDepth );
				float2 SampleUvb = PointCloudMapXyzToUv( float3(x,y,zb), g_BlockDepth );
				
				//	convert to uv and back, as we know that uv->xyz is correct
				int3 InternalXyz_i = PointCloudMapUvToXyz(SampleUva, g_BlockDepth);
				InternalXyz = InternalXyz_i / Blockwhd;
				//InternalXyz = floor(xyz*Blockwhd)/Blockwhd;

				uvpair_t SamplePair;
				SamplePair.a = SampleUva;
				SamplePair.b = SampleUvb;
				SamplePair.Blend = zLerp;

				return SamplePair;
            }
			
			float GetDistance_SdfCloudLocal(float3 RayPosLocal,out float3 Colour,MarchMeta_t MarchMeta)
			{
				float3 InternalXyz;
				uvpair_t SampleUvs = PointCloudMapXyzNormToUv(RayPosLocal,MarchMeta.BlockDepth,InternalXyz);

				float4 Samplea = tex2D( CloudPositions, SampleUvs.a );
				float4 Sampleb = tex2D( CloudPositions, SampleUvs.b );

				float Blend = SampleUvs.Blend;
				int ValidBits = 0;
				if ( Samplea.w < SAMPLE_INVALID_DIST )
					ValidBits += 1;
				if ( Sampleb.w < SAMPLE_INVALID_DIST )
					ValidBits += 2;
				if ( ValidBits == 0 )
					return SAMPLE_INVALID_DIST;
				if ( ValidBits == 1 )
					Blend = 0;
				if ( ValidBits == 2 )
					Blend = 1;
				float4 Sample = lerp(Samplea,Sampleb,Blend);

				//	w is distance
				Colour = Sample.xyz;
				//Colour = Sample.www;
				//Colour = RayPosLocal;

				//Colour = InternalXyz;
				//Colour = NormalToRedGreen(SampleUv.y);
				//Colour = NormalToRedGreen(InternalXyz.yyy);
				int g_BlockDepth = MarchMeta.BlockDepth;
				float3 Blockwhd = float3(BLOCKWIDTH,BLOCKHEIGHT,BLOCKDEPTH);
				float3 WorkingInternalXyz = floor(RayPosLocal*Blockwhd)/Blockwhd;


				//return sdSphere(RayPosLocal-InternalXyz,SphereRad);
				//return distance(RayPosLocal,WorkingInternalXyz);

				return Sample.w;
			}

		

			float GetDistance_SdfCloud(float3 RayPosWorld,out float3 Colour,MarchMeta_t MarchMeta)
			{
				float3 BoxCenter = lerp(WorldBoundsMin,WorldBoundsMax,0.5f);
				float DistanceToBounds = sdBox( RayPosWorld-BoxCenter, (WorldBoundsMax-WorldBoundsMin)*0.5f );

				
				//	get local space xyz
				float3 Cloudxyz = Range3( WorldBoundsMin, WorldBoundsMax, RayPosWorld );
				Colour = Cloudxyz;
				//return sdSphere(RayPosWorld-BoxCenter,SphereRad);

				if ( !IsInside01(Cloudxyz.x) || !IsInside01(Cloudxyz.y) || !IsInside01(Cloudxyz.z) )
				{
					//	todo: if outside, return distance to bounds edge
					Colour = float3(0,0,1);
					//	gr: intead of stepping inside, it should read distance at the edge-sample
					//	gr: in case we're stepping backwards, need to make sure that step wont push us outside
					return DistanceToBounds+MarchStepBackwards+0.001;	//	step inside
				}

				//return DistanceToBounds;

				float LocalDistance = GetDistance_SdfCloudLocal(Cloudxyz,Colour,MarchMeta);
				return LocalDistance;
			}


			
			float GetDistance_TestSphere(float4 SphereWorld,float3 RayPosWorld,out float3 Colour)
			{
				//	test sphere in world space
				float3 RayPosLocal = RayPosWorld - SphereWorld.xyz;
				float Distance = sdSphere(RayPosLocal,SphereWorld.w);
	
				//	calc norm of the point we hit
				//	note: this is NOT the right normal. we should do 4x samples to get proper normal
				float3 Normal = normalize(RayPosLocal);
				Normal += 1;
				Normal /= 2;

				Colour = Normal;
				return Distance;
			}

			float3 GetCameraDirection()
			{
				float4 CameraCenterWorld = mul(WorldToLocalTransform,float4(0,0,0,1));
				float4 CameraForwardWorld = mul(WorldToLocalTransform,float4(0,0,1,1));
				float3 CameraCenter = CameraCenterWorld.xyz / CameraCenterWorld.www;
				float3 CameraForward = CameraForwardWorld.xyz / CameraForwardWorld.www;
				return normalize(CameraForward - CameraCenter);
			}


			float GetDistance_ToProjection(float3 RayPosWorld,out float3 Colour)
			{
				float4 NearCloudPosition = GetCameraNearestCloudPosition(RayPosWorld,Colour);

				//	gr: this happens when point is outside frustum, we should
				//		be able to work out the distance to the frustum...
				if ( NearCloudPosition.w < 0.5 )
				{
					//	hit invalid point
					Colour = float3(0,1,0);
					//return 0.2;
				}

				float3 Delta = NearCloudPosition.xyz - RayPosWorld;
				float Distance = length( Delta );

				float3 CameraDirection = GetCameraDirection();
				float DirectionDot = dot( normalize(Delta),CameraDirection);

				//	check if we go behind this point
				//	gr: should we be stepping backwards? maybe this is the solution to the old reverse-step
				if ( DirectionDot < 0 )
					Distance += MarchStepBackwards * DirectionDot;


				return Distance;
			}



			float GetDistance(float3 RayPosWorld,out float3 Colour,MarchMeta_t MarchMeta)
			{
				if ( CLOUD_POSITIONS_SDF )
				{
					Colour = float3(0,0,1);
					return GetDistance_SdfCloud(RayPosWorld,Colour,MarchMeta);
				}
				else
				{
					return GetDistance_ToProjection( RayPosWorld, Colour );
				}
/*
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
*/
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
				#define MARCH_STEPS 20	//	gr: temp for quick compiling

				//	ray needs to start at the camera if we're INSIDE the shape, otherwise frag pos is the backface
				//	gr: if we're inside, we could force the far distance to be the ray pos, then we won't draw
				//		past the geometry in world space	MarchFarDistance = 
				float3 RayEyeStart = Inside ? _WorldSpaceCameraPos : input.WorldPosition;
				float3 RayMarchDir = -RayDirection;//normalize(input.WorldPosition - RayEyeStart);

				float3 RayMarchStart = RayEyeStart + (RayMarchDir * MarchNearDistance);
				//float3 RayMarchEnd = RayEyeStart + (RayMarchDir * MarchFarDistance);

				float BestDistance = 999;
				float3 BestColour = float3(0,1,1);

				float StepHeat = 0;
				MarchMeta_t MarchMeta;
				MarchMeta.BlockDepth = input.BlockDepth;

				float RayDistance = 0;	//	this is ray time, but now in worldspace units
				//[unroll(MARCH_STEPS)]
				for ( int i=0;	i<MARCH_STEPS;	i++ )
				{
					float3 RayPosition = RayMarchStart + (RayMarchDir*RayDistance);

					float3 HitColour;
					float HitDistance = GetDistance(RayPosition,HitColour,MarchMeta);

					StepHeat += 1;

					//	very far, as in, bad/no data in the sdf, do a "standard step"
					//	gr: this is quite rare, seems to happen at certain angles...
					if ( HitDistance >= SAMPLE_INVALID_DIST )
					{
						//RayDistance += 0.1;
						RayDistance += NoDataStepDistance;// + MinHitDistance;
						//return float4(0,0,1,1);
						continue;
					}

					//	step ray forward
					//	allow smaller steps
					//	gr: for our heightmap stepping, if this is <step, we may want to step backwards
					RayDistance += min( MaxMarchDistance, HitDistance );
					if ( HitDistance > MinHitDistance )
						if ( HitDistance > MarchStepBackwards )
							RayDistance -= MarchStepBackwards;

					//	gr; move t along by distance, normally, but we need fixed step for this
					//	worse than current best
					if ( HitDistance > BestDistance )
						continue;

					BestDistance = HitDistance;
					BestColour = HitColour;

					//	gr: we're gettting z order issues, bail early if this is good enough
					if ( BestDistance <= MinHitDistance)
						if ( ENABLE_EARLY_Z_BREAK )
							break;
					
				}

				//	max distance can only be the (far-near) distance now
				//if ( BestDistance > MarchFarDistance )
				//	didn't get close enough to anything
				if ( BestDistance > MaxHitDistance )
				{
					//	debug misses
					//StepHeat += 10;
					discard;
				}

				//	get projection colour
				{
					float x;
					float3 RayPosition = RayMarchStart + (RayMarchDir*RayDistance);
					float3 ProjectedColour;
					float4 HitPosition = GetCameraNearestCloudPosition( RayPosition, ProjectedColour );
					if ( HitPosition.w > 0 )
						BestColour = ProjectedColour;
				}

				if ( DEBUG_STEP_HEAT )
				{
					//	make stepheat relative to total so these settings are step-agnostic
					StepHeat /= float(MARCH_STEPS);

					return float4(NormalToRedGreen(1-StepHeat),1);
				}
		
                return float4(BestColour,1.0);
                //return float4(i.WorldPosition,1.0);
            }
            ENDCG
        }
    }
}
