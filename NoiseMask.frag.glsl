
sampler2D _MainTex;
varying vec4 _MainTex_ST;
varying vec4 _MainTex_TexelSize;

varying float Steps;
varying float SampleWalkWeight;
varying float MaxSampleDiffR_8;
varying float MaxSampleDiffG_8;
varying float MaxSampleDiffB_8;
#define MaxSampleDiff   ( float3(MaxSampleDiffR_8,MaxSampleDiffG_8,MaxSampleDiffB_8) / float3(255.0,255.0,255.0) )

varying float Debug_Loners;
    #define DEBUG_LONERS    (Debug_Loners>0.5)

varying int LonerMaxWidth;
varying float WalkStepSize;


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

int GetMatchesHorz(vec2 uv,float Step,out vec4 NewSample,out vec4 EdgeSample)
{
    vec4 Sample0 = GetSample(uv,0,0);
    NewSample = Sample0;
#define SampleSteps 5
    [unroll(SampleSteps)]
    for ( int s=1;  s<=SampleSteps;    s++ )
    {
        float4 Sample4 = GetSample(uv,s*Step,0);
        float4 Diff4 = abs(Sample4-Sample0);
        //float Diff = Diff4[Channel];
        //float Diff = max(Diff4.x,max(Diff4.y,Diff4.z));
        float3 Diff = Diff4;
        EdgeSample = Sample4;
        //if ( Diff.x > MaxSampleDiff.x || Diff.y > MaxSampleDiff.y || Diff.z > MaxSampleDiff.z )
        if ( Diff.x > MaxSampleDiff.x )
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
bool IsLoner(vec2 uv)
{
    vec4 LeftColour,LastLeftColour;
    vec4 RightColour,LastRightColour;
    float StepSize = WalkStepSize;
    int Lefts = GetMatchesHorz(uv,-StepSize,LastLeftColour,LeftColour);
    int Rights = GetMatchesHorz(uv,StepSize,LastRightColour,RightColour);

    if ( Lefts+Rights <= LonerMaxWidth )
    {
        return true;
    }
    return false;
}

float4 NoiseMask(vec2 uv)
{
    vec4 BaseColour = GetSample(uv,0,0);
    bool Loner = IsLoner(uv);
    vec4 OutColour = BaseColour;

    if ( Loner && DEBUG_LONERS )
        OutColour = vec4(0,0,1,1);

    return vec4(OutColour.xyz, Loner ? 0 : 1 );
}

#if !defined(GLSL_NO_MAIN)
void main()
{
    gl_FragColor = NoiseMask(uv);
}
#endif
