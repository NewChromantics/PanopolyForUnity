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

uniform vec4 DepthRect;
uniform float InputIsBgr;
#define INPUT_IS_BGR	(InputIsBgr>0.5)



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
		Normal = mix( 0.0, 0.333, Normal );
		Score = 1.0;
	}
	else if ( rzero )
	{
		//	green to blue
		Normal = Range(1.0,0.0,g) + Range(0.0,1.0,b);
		Normal /= 2.0;
		Normal = mix( 0.333, 0.666, Normal );
		Score = 1.0;
	}
	else if ( gzero )
	{
		//	blue to red
		Normal = Range(1.0,0.0,b) + Range(0.0,1.0,r);
		Normal /= 2.0;
		Normal = mix( 0.666, 1.0, Normal );
		Score = 1.0;
	}
	else
	{
		Normal = 1.0;
		Score = 0.5;
	}
}


vec3 GetDepthUv(vec2 Uv)
{
	float Depthu = Range( DepthRect.x, DepthRect.x+DepthRect.z, Uv.x );
	float Depthv = Range( DepthRect.y, DepthRect.y+DepthRect.w, Uv.y );
	
	bool Inside = ( Depthu >= 0.0 && Depthu <= 1.0 && Depthv >= 0.0 && Depthv <= 1.0 );
	return vec3( Depthu, Depthv, Inside?1.0:0.0 );
}


void main()
{
	vec2 SampleUv = uv;
	if ( VIDEOYUV_IS_FLIPPED )
		SampleUv.y = 1.0 - SampleUv.y;
	
	vec3 DepthUv = GetDepthUv( SampleUv );
	
	if ( DepthUv.z == 0.0 )
	{
		gl_FragColor = tex2D( RainbowDepth, SampleUv );
		if ( INPUT_IS_BGR )
			gl_FragColor.xyz = gl_FragColor.zyx;
		return;
	}
	
	vec3 Rgb = tex2D( RainbowDepth, SampleUv ).xyz;
	if ( INPUT_IS_BGR )
		Rgb.xyz = Rgb.zyx;
			
	float Depth;
	float Score;
	RainbowToNormalAndScore( Depth, Score, Rgb );
	Depth = mix( Encoded_DepthMinMetres, Encoded_DepthMaxMetres, Depth );
	gl_FragColor = vec4( Depth, Depth, Depth, Score );
}
