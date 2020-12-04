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
                float2 uv : TEXCOORD0;
                float3 WorldPosition : TEXCOORD1;
                float3 LocalPosition : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float SphereX;
			float SphereY;
			float SphereZ;
			float SphereRad;

			float MaxHitDistance;
			float MaxMarchDistance;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.WorldPosition = UnityObjectToWorldPos(v.vertex);
                o.LocalPosition = (v.vertex);
                //o.LocalPosition = o.WorldPosition;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }


			//	http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
			float sdSphere( float3 p, float s )
			{
				  return length(p)-s;
			}

			void GetDistance_TestSphere(float3 RayPosWorld,out float Distance,out float3 Colour)
			{
				//	test sphere in world space
				float4 Sphere = float4(SphereX,SphereY,SphereZ,SphereRad);
				float3 RayPosLocal = RayPosWorld - Sphere.xyz;
				Distance = sdSphere(RayPosLocal,Sphere.w);

				if ( Distance > Sphere.w )
					return;
					
				//	calc norm of the point we hit
				//	note: this is NOT the right normal. we should do 4x samples to get proper normal
				float3 Normal = normalize(RayPosLocal);
				Normal += 1;
				Normal /= 2;

				Colour = Normal;
			}

			void GetDistance(float3 RayPosWorld,out float Distance,out float3 Colour)
			{
				GetDistance_TestSphere(RayPosWorld,Distance,Colour);
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



                
					
				//	start BEHIND for when we're INSIDE the bounds (gr: this may only apply to the debug sphere)
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

				for ( int i=-BACKWARD_MARCHES;	i<FORWARD_MARCHES;	i++ )
				{
					float t = i/(float)FORWARD_MARCHES;
					float3 RayPosition = lerp( RayMarchStart, RayMarchEnd, t );

					float HitDistance;
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
