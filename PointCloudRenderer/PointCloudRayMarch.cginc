#if !defined(CLOUD_POSITIONS_DEFINED)
sampler2D CloudPositions;
sampler2D CloudColours;
float4 CloudPositions_TexelSize;
float4 CloudColours_TexelSize;
#define CLOUD_POSITIONS_DEFINED
#endif


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


float3 NormalToRedGreen(float Normal)
{
	if (Normal < 0.0)
	{
		return float3(1, 0, 1);
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

float3 Range3(float3 Min,float3 Max,float3 Value)
{
	float x = Range(Min.x,Max.x,Value.x);
	float y = Range(Min.y,Max.y,Value.y);
	float z = Range(Min.z,Max.z,Value.z);
	return float3(x,y,z);
}

//	w = obviously in/valid
float4 GetCameraNearestCloudPosition(float3 RayPosWorld,out float3 Colour)
{
	//	draw sphere at 0,0,0 in cameralocal space
	float4 CameraCenterWorld = mul(WorldToLocalTransform,float4(0,0,0,1));
	float3 CameraCenter = CameraCenterWorld.xyz / CameraCenterWorld.www;

#if defined(ENABLE_CAMERA_DEBUG)
	if (DEBUG_CAMERA_CENTER)
	{
		float4 CameraCenterSphere = float4(CameraCenter,SphereRad);
		GetDistance_TestSphere(CameraCenterSphere,RayPosWorld,Distance,Colour);
		if ( Distance <= 0)
			return float4(RayPosWorld,1);
	}
#endif

	//	world -> cloud space
	float4 RayPosCloud4 = mul(WorldToLocalTransform,float4(RayPosWorld,1));
	RayPosCloud4.xyz /= RayPosCloud4.www;

	//	cloud space -> camera space (2d)
	float4 RayPosCamera4 = mul(LocalToCameraTransform,float4(RayPosCloud4.xyz,1));
	float3 RayPosCamera3 = RayPosCamera4.xyz / RayPosCamera4.www;

	//	camera image space to uv
	//	gr: by checking distance against a Z, we can see this needs to be /z
	float2 RayPosCamera2 = RayPosCamera3.xy / RayPosCamera3.zz;
	float2 RayPosUv = Range2( CameraToLocalViewportMin, CameraToLocalViewportMax, RayPosCamera2 );

	//	out of view frustum (either uv should be out)
	//	or behind camera
	float Valid = 1.0;
	if ( !IsInside01(RayPosUv.x) || !IsInside01(RayPosUv.y) || RayPosCamera3.z < 0 )
	{
		//Colour = float4(1,0,1,1);
		//return float4(0,0,0,0);
		Valid = 0;
		RayPosUv = clamp(RayPosUv, 0, 1);
	}

	//	gr: not sure why I need to flip, I think normally we render bottom to top, but here we're in camera space...
	if ( FLIP_POSITION_SAMPLE )
		RayPosUv.y = 1.0 - RayPosUv.y;

	//	get world depth/pos (does this need transform?)

	//	gr: do multiple samples to find nearest
	float4 RayHitCloudPos = float4(0,0,0,0);
	float2 RayHitUv = RayPosUv;

#if defined(CLOUD_SAMPLE_FUNCTION)
	CLOUD_SAMPLE_FUNCTION( RayPosWorld, RayPosUv, RayHitCloudPos, RayHitUv );
#else

#if !defined(CLOUD_RAYMARCH_SAMPLE_RADIUS)
	#define SampleRadius	0
#else
	#define SampleRadius CLOUD_RAYMARCH_SAMPLE_RADIUS
#endif
	{
		float RayHitCloudDistance=999;

		for ( int y=-SampleRadius;	y<=SampleRadius;	y++ )
		{
			for ( int x=-SampleRadius;	x<=SampleRadius;	x++ )
			{
				float2 uvoff = float2(x,y) * CloudPositions_TexelSize.xy;
				float4 HitPosition = tex2D(CloudPositions,RayPosUv+uvoff);
				float HitDistance = lerp( 999.0f, distance(RayPosWorld,HitPosition), HitPosition.w);

				float UseResult = ( HitDistance < RayHitCloudDistance ) ? 1 : 0;
				RayHitCloudPos = lerp( RayHitCloudPos, HitPosition, UseResult);
				RayHitCloudDistance = lerp( RayHitCloudDistance, HitDistance, UseResult);
				RayHitUv = lerp( RayHitUv, RayPosUv+uvoff, UseResult);
			}
		}
	}
#endif
	//RayHitCloudPos = tex2D(CloudPositions,RayHitUv);


	float2 RayColourUv = RayHitUv;
	if ( FLIP_COLOUR_SAMPLE )
		RayColourUv.y = 1.0 - RayColourUv.y;

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
/*
	if ( DEBUG_CAMERA_TEST_PLANE )
	{
		Distance = 0;
		Distance = abs(RayPosCamera3.z - CameraTestZ);
	}
*/
#endif
	return float4(RayHitCloudPos.xyz,Valid);
}
