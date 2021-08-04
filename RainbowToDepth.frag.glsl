precision highp float;

//	from quad shader (webgl)
varying vec2 uv;

//	unity->glsl conversion
#define lerp mix
#define tex2D texture2D
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define trunc	floor
#define fmod(x,y)	(x - y * trunc(x / y))

//	gr: this is now specifically "what is the output from poph264"
uniform float VideoYuvIsFlipped;
#define VIDEOYUV_IS_FLIPPED	(VideoYuvIsFlipped>0.5)

uniform sampler2D RainbowDepth;
uniform vec2 RainbowDepthSize;

uniform float Encoded_DepthMinMetres;
uniform float Encoded_DepthMaxMetres;

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

void RainbowToNormalAndScore(out float Normal,out float Score,vec3 Rainbow)
{
	//	probbaly a smart way to do this
	//	one component is always 1.0 and one is always 0.0
	float r = Rainbow.x;
	float g = Rainbow.y;
	float b = Rainbow.z;

	bool rzero = (r<=1.0/255.0);
	bool gzero = (g<=1.0/255.0);
	bool bzero = (b<=1.0/255.0);
	if ( rzero && gzero && bzero )
	{
		Score = 0.0;
		Normal = 0.0;
		return;
	}

	if ( bzero )
	{
		//	red to green
		Normal = Range(1.0,0.0,r) + Range(0.0,1.0,g);
		Normal /= 2.0;
		Normal = Range( 0.0, 0.5, Normal );
		Score = 1.0;
	}
	else if ( rzero )
	{
		//	green to blue
		Normal = Range(1.0,0.0,g) + Range(0.0,1.0,b);
		Normal /= 2.0;
		Normal = Range( 0.0, 0.5, Normal );
		Score = 1.0;
	}
	else if ( gzero )
	{
		//	blue to red
		Normal = Range(1.0,0.0,b) + Range(0.0,1.0,r);
		Normal /= 2.0;
		Normal = Range( 0.0, 0.5, Normal );
		Score = 1.0;
	}
	else
	{
		Normal = 1.0;
		Score = 0.5;
	}
}

void main()
{
	vec2 SampleUv = uv;
	if ( VIDEOYUV_IS_FLIPPED )
		SampleUv.y = 1.0 - SampleUv.y;
		
	vec3 Rgb = tex2D( RainbowDepth, SampleUv ).xyz;
	float Depth;
	float Score;
	RainbowToNormalAndScore( Depth, Score, Rgb );
	Depth = mix( Encoded_DepthMinMetres, Encoded_DepthMaxMetres, Depth );
	gl_FragColor = vec4( Depth, Depth, Depth, Score );
}
