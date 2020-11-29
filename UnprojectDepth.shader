Shader "Panopoly/UnprojectDepth"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

			float cx;
			float cy;
			float fx;
			float fy;
			float k1;
			float k2;
			float k3;
			float k4;
			float k5;
			float k6;
			float codx;
			float cody;
			float p1;
			float p2;

			//	gr: this code is expecting uv in pixels, need the original pixel size (or at least, make cxy and fxy relative)
			//	from https://github.com/microsoft/Azure-Kinect-Sensor-SDK/blob/39319dcc1e64507b459bbb2594bfc54dfa50c0cc/src/transformation/intrinsic_transformation.c#L330
			float2 Unproject_Internal(float2 uv, float Depth)
			{
				//	gr: projectionm matrix should be something like
				//	fx	0	cx	0
				//	0	fy	cy	0
				//	0	0	near	0
				//	0	0	far	0

				// correction for radial distortion
				float xp_d = (uv[0] - cx) / fx - codx;
				float yp_d = (uv[1] - cy) / fy - cody;

				float rs = xp_d * xp_d + yp_d * yp_d;
				float rss = rs * rs;
				float rsc = rss * rs;
				float a = 1.f + k1 * rs + k2 * rss + k3 * rsc;
				float b = 1.f + k4 * rs + k5 * rss + k6 * rsc;
				float ai;
				if (a != 0.f)
				{
					ai = 1.f / a;
				}
				else
				{
					ai = 1.f;
				}
				float di = ai * b;

				float2 xy;
				xy[0] = xp_d * di;
				xy[1] = yp_d * di;

				// approximate correction for tangential params
				float two_xy = 2.f * xy[0] * xy[1];
				float xx = xy[0] * xy[0];
				float yy = xy[1] * xy[1];

				xy[0] -= (yy + 3.f * xx) * p2 + two_xy * p1;
				xy[1] -= (xx + 3.f * yy) * p1 + two_xy * p2;

				// add on center of distortion
				xy[0] += codx;
				xy[1] += cody;

				//	here in the code it does 20 passes of 
				//	transformation_project_internal to get some delta and adjust xy back to the lsense
				//	and try again

				return xy;
			}

			float3 Unproject_DepthToPos(float2 uv, float Depth)
			{
				float3 xyz;
				xyz.xy = Unproject_Internal(uv, Depth);
				xyz.x *= Depth;
				xyz.y *= Depth;
				xyz.z = Depth;
				return xyz;
			}


            fixed4 frag (v2f i) : SV_Target
            {
				float Depth = 0;
				//	get position in camera space
				float3 LocalPos = Unproject_DepthToPos(i.uv, Depth);
				return float4(LocalPos, 1);
            }
            ENDCG
        }
    }
}
