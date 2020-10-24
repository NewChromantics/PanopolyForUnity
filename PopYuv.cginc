struct YuvColourParams
{
	float LumaMin;
	float LumaMax;
	float ChromaVRed;
	float ChromaUGreen;
	float ChromaVGreen;
	float ChromaUBlue;
};

//	here are some default values
//	gr: check if this is NTSC, do proper YUV matricies!
YuvColourParams GetDefaultYuvColourParams()
{
	YuvColourParams Params;
	Params.LumaMin = 16.0/255.0;
	Params.LumaMax = 253.0/255.0;
	Params.ChromaVRed = 1.5958;
	Params.ChromaUGreen = -0.81290;
	Params.ChromaVGreen = -0.81290;
	Params.ChromaUBlue = 2.017;
	return Params;
}

float3 LumaChromaUV_To_Rgb(float Luma,float ChromaU,float ChromaV,YuvColourParams Params)
{

		//	0..1 to -0.5..0.5
	float2 ChromaUV = float2(ChromaU,ChromaV);
	ChromaUV -= 0.5;

	//	set luma range
	Luma = lerp(Params.LumaMin, Params.LumaMax, Luma);
	float3 Rgb;
	Rgb.x = Luma + (Params.ChromaVRed * ChromaUV.y);
	Rgb.y = Luma + (Params.ChromaUGreen * ChromaUV.x) + (Params.ChromaVGreen * ChromaUV.y);
	Rgb.z = Luma + (Params.ChromaUBlue * ChromaUV.x);
	
	
	return Rgb;
}

float3 Yuv_8_8_8_To_Rgb(float2 uv,sampler2D LumaPlane,sampler2D ChromaUPlane,sampler2D ChromaVPlane,YuvColourParams Params)
{
	float Luma = tex2D( LumaPlane, uv ).x;
	float ChromaU = tex2D( ChromaUPlane, uv ).x;
	float ChromaV = tex2D( ChromaVPlane, uv ).x;
	
	return LumaChromaUV_To_Rgb(Luma,ChromaU,ChromaV,Params);
}

//	this is expecting 2nd plane to be 2 components.
//	need a seperate function for 1-component interleaved
float3 Yuv_8_88_To_Rgb(float2 uv,sampler2D LumaPlane,sampler2D ChromaUVPlane,YuvColourParams Params)
{
	float Luma = tex2D( LumaPlane, uv ).x;
	float2 ChromaUV = tex2D( ChromaUVPlane, uv ).xy;
	
	return LumaChromaUV_To_Rgb(Luma,ChromaUV.x,ChromaUV.y,Params);
}
