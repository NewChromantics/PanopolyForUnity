Shader "Panopoly/AlphaFill"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle]ApplyFill("ApplyFill",float)=1
        [Toggle]Debug_Filled("Debug_Filled",float)=0
        [Toggle]Debug_Failed("Debug_Failed",float)=0
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

            float ApplyFill;
#define APPLY_FILL  (ApplyFill>0)
            float Debug_Filled;
            float Debug_Failed;
        #define DEBUG_FILLED    (Debug_Filled>0)
        #define DEBUG_FAILED    (Debug_Failed>0)
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
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
                float4 Sample4 = tex2D( _MainTex, uv );
                return Sample4;
            }

            int WalkToGoodSample(float2 uv,float2 Step,out float4 NewSample)
            {
#define SampleSteps 6
                for ( int s=1;  s<=SampleSteps;    s++ )
                {
                    float4 SampleX = GetSample(uv,s*Step.x,s*Step.y);

                    NewSample = SampleX;
                    if ( SampleX.w > 0 )
                        return s;
                }
                
                NewSample = float4(0,0,0,0);
                return SampleSteps;
            }


            float4 GetGoodNeighbour(float2 uv )
            {
//  gr: this might be better as a guassian sample map, but we explicitly do want to walk sideways as that's where we've cut stuff from
                #define DIR_COUNT  8
                float2 Directions[DIR_COUNT];
                Directions[0] = float2(-1,0);
                Directions[1] = float2(1,0);
                Directions[2] = float2(0,-1);
                Directions[3] = float2(0,1);
#if DIR_COUNT>4
                Directions[4] = float2(-1,-1);
                Directions[5] = float2(1,-1);
                Directions[6] = float2(1,1);
                Directions[7] = float2(-1,1);
#endif
                float StepSize = 2;
                float4 DirSamples[DIR_COUNT];
                int DirSteps[DIR_COUNT];
                for ( int d=0;  d<DIR_COUNT;    d++)
                {
                    DirSteps[d] = WalkToGoodSample( uv, Directions[d]*StepSize, DirSamples[d] );
				}

                float4 BestSample = DirSamples[0];
                int BestSteps = DirSteps[0];
                for ( int d=0;  d<DIR_COUNT;    d++ )
                {
                    bool Better = (BestSample.w < 1) || (DirSteps[d]<BestSteps);
                    Better = Better && (DirSamples[d].w > 0);
                    BestSample = lerp( BestSample, DirSamples[d], Better ? 1 : 0 );
                    BestSteps = lerp( BestSteps, DirSteps[d], Better ? 1 : 0 );
				}
                return BestSample;
			}

            fixed4 frag (v2f i) : SV_Target
            {
                float4 Input = GetSample(i.uv,0,0);

                //  just blit good samples
                if ( Input.w > 0 || !APPLY_FILL )
                    return Input;

                float4 NewSample = GetGoodNeighbour(i.uv);

                if ( DEBUG_FAILED && NewSample.w < 1 )
                    return NewSample * float4(1,0,0,0);

                if ( DEBUG_FILLED && NewSample.w > 0 )
                    return NewSample * float4(0,1,0,1);

                return NewSample;
            }
            ENDCG
        }
    }
}
