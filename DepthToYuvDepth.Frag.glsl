precision highp float;

//	from quad shader (webgl)
varying vec2 uv;


uniform float Encoded_ChromaRangeCount;
uniform float Encoded_DepthMinMetres;
uniform float Encoded_DepthMaxMetres;
uniform float Encoded_LumaPingPong;
uniform float DepthInput_ToMetres;

uniform sampler2D DepthTexture;
uniform vec2 DepthTextureSize;
#define DepthTexture_TexelSize	vec2(1.0/DepthTextureSize.x,1.0/DepthTextureSize.y)
uniform float FlipDepthTexture;


float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}

float Range01(float Min,float Max,float Value)
{
	Value = Range( Min, Max, Value );
	return clamp( Value, 0.0, 1.0 );
}

vec3 DepthToYuv(float Depth)
{
	//	quick 1 chroma implementation
	float Lumaf = Range01( Encoded_DepthMinMetres, Encoded_DepthMaxMetres, Depth );
	
	vec2 Chromauv = vec2(1,1);
	return vec3( Lumaf, Chromauv );
}

float GetDepthSample(vec2 uv)
{
	//	convert input to depth
	float Depth = texture2D( DepthTexture, uv ).x;
	Depth *= DepthInput_ToMetres;
	return Depth;
}


#if !defined(NO_MAIN)
void main()
{
	vec2 DepthSampleUv = uv;
	DepthSampleUv.y = (FlipDepthTexture>0.5) ? 1.0-DepthSampleUv.y : DepthSampleUv.y;
	float Depth = GetDepthSample(DepthSampleUv);
	vec3 YuvDepth = DepthToYuv(Depth);
	/*
	if ( uv.x > 0.5 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= DepthInput_ToMetres;
		YuvDepth.x /= Encoded_DepthMaxMetres;
	}*/
	/*
	if ( uv.x < 0.2 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.0005;
	}
	else if ( uv.x < 0.4 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.001;
	}
	else if ( uv.x < 0.6 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.01;
	}
	else if ( uv.x < 0.8 )
	{
		YuvDepth.x = texture2D( DepthTexture, uv ).x;
		YuvDepth.x *= 0.02;
	}
*/
/*
	if ( uv.y < 0.05 )
	{
		YuvDepth.x = uv.x;
	}
	*/
	//	work out yuv_8_88 output
	gl_FragColor.xyz = YuvDepth.xxx;
	gl_FragColor.w = 1.0;
}
#endif

