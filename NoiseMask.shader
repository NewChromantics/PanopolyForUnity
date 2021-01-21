Shader "Panopoly/NoiseMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange]Steps("Steps",Range(1,10) ) = 4
        [IntRange]MaxSampleDiffR_8("MaxSampleDiffR_8",Range(0,50))=10
        [IntRange]MaxSampleDiffG_8("MaxSampleDiffG_8",Range(0,50))=10
        [IntRange]MaxSampleDiffB_8("MaxSampleDiffB_8",Range(0,50))=10
        [Toggle]Debug_Loners("Debug_Loners",float)=0
        SampleWalkWeight("SampleWalkWeight",Range(0,1)) = 0.5
        [IntRange]LonerMaxWidth("LonerMaxWidth",Range(0,20))=1
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
            float4 _MainTex_TexelSize;

            float Steps;
            float SampleWalkWeight;
            float MaxSampleDiffR_8;
            float MaxSampleDiffG_8;
            float MaxSampleDiffB_8;
#define MaxSampleDiff   ( float3(MaxSampleDiffR_8,MaxSampleDiffG_8,MaxSampleDiffB_8) / float3(255.0,255.0,255.0) )

            float Debug_Loners;
    #define DEBUG_LONERS    (Debug_Loners>0.5)

            int LonerMaxWidth;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float2 GetSampleUv(float2 uv,float PixelOffsetX,float PixelOffsetY)
            {
                uv -= fmod( uv, _MainTex_TexelSize );
                //  sample from center of texel
                uv += _MainTex_TexelSize.xy / 2;
                uv += _MainTex_TexelSize.xy * float2(PixelOffsetX,PixelOffsetY);
                return uv;
            }

            float4 GetSample(float2 uv,float PixelOffsetX,float PixelOffsetY)
            {
                uv = GetSampleUv(uv,PixelOffsetX,PixelOffsetY);
                float4 Sample = tex2D( _MainTex, uv );
                return Sample;
            }

            int GetMatchesHorz(float2 uv,float Step,out float4 NewSample,out float4 EdgeSample)
            {
                float4 Sample0 = GetSample(uv,0,0);
                NewSample = Sample0;
#define SampleSteps 10
               // [unroll(20)]
                for ( int s=1;  s<=SampleSteps;    s++ )
                {
                    float4 Sample4 = GetSample(uv,s*Step,0);
                    float4 Diff4 = abs(Sample4-Sample0);
                    //float Diff = Diff4[Channel];
                    //float Diff = max(Diff4.x,max(Diff4.y,Diff4.z));
                    float3 Diff = Diff4;
                    EdgeSample = Sample4;
                    if ( Diff.x > MaxSampleDiff.x || Diff.y > MaxSampleDiff.y || Diff.z > MaxSampleDiff.z )
                    {
                        NewSample = Sample0;
                        return s-1;
                    }
                    //  rewrite sample to let walk continue
                    Sample0 = lerp(Sample0,Sample4,SampleWalkWeight);
                }
                
                NewSample = Sample0;
                return SampleSteps;
            }

            //  gr: possible improvements
            //  - scan other directions
            //  - detect if I'm not a loner, but surrounded by them (maybe not neccessary if reader scans)
            bool IsLoner(float2 uv)
            {
                float4 LeftColour,LastLeftColour;
                float4 RightColour,LastRightColour;
                float StepSize = 2;
                int Lefts = GetMatchesHorz(uv,-StepSize,LastLeftColour,LeftColour);
                int Rights = GetMatchesHorz(uv,StepSize,LastRightColour,RightColour);

                if ( Lefts+Rights <= LonerMaxWidth )
                {
                    return true;
                }
                return false;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                   float4 BaseColour = GetSample(i.uv,0,0);
                    bool Loner = IsLoner(i.uv);
                    float4 OutColour = BaseColour;

                    if ( Loner && DEBUG_LONERS )
                        OutColour = float4(0,0,1,1);

                    return float4(OutColour.xyz, Loner ? 0 : 1 );
            }
            ENDCG
        }
    }
}
