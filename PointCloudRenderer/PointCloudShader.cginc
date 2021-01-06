/*
float3 GetTrianglePosition(float TriangleIndex, out float2 ColourUv, out bool Valid)
{
	float MapWidth = 640;// CloudPositions_texelSize.z;
	float u = fmod(TriangleIndex, MapWidth) / MapWidth;
	float v = floor(TriangleIndex / MapWidth) / MapWidth;

	ColourUv = float2(u, 1.0 - v);
	float4 PositionUv = float4(u, v, 0, 0);
	float4 PositionSample = tex2Dlod(CloudPositions, PositionUv);
	Valid = PositionSample.w > 0.5;
	return PositionSample.xyz;
}
*/



//	dont weld to edge
float GetEdgeScore(Texture2D<float4> Positions,SamplerState PositionsSampler,float2 PositionMapUv,float2 VertexUv,float MaxWeldDistance)
{
	float2 PositionsTexelSize = float2(1.0,1.0) / float2(640.0, 480.0);

	float2 LeftUv = PositionMapUv;
	float2 RightUv = PositionMapUv + float2(PositionsTexelSize.x,0);
	float2 UpUv = PositionMapUv + float2(0,PositionsTexelSize.y);
	float2 OppUv = PositionMapUv + PositionsTexelSize;	//	opposite

	float SampleMip = 0;
	float4 LeftSample = Positions.SampleLevel( PositionsSampler, LeftUv, SampleMip );	
	float4 RightSample = Positions.SampleLevel( PositionsSampler, RightUv, SampleMip );	
	float4 UpSample = Positions.SampleLevel( PositionsSampler, UpUv, SampleMip );	
	float4 OppSample = Positions.SampleLevel( PositionsSampler, OppUv, SampleMip );	

	float RightDistance = distance(LeftSample.xyz,RightSample.xyz);
	float UpDistance = distance(LeftSample.xyz,UpSample.xyz);
	float OppDistance = distance(LeftSample.xyz,OppSample.xyz);

	float BigDistance = RightDistance;
	BigDistance = max( BigDistance, UpDistance);
	BigDistance = max( BigDistance, OppDistance);

	

	float Distance = BigDistance;
	return Distance / MaxWeldDistance;
}

//	gr: shadergraph fails looking for
//		Vertex_uv_TriangleIndex_To_CloudUvs
//	because of missing reference to 
//		Vertex_uv_TriangleIndex_To_CloudUvs_float 
#define Vertex_uv_TriangleIndex_To_CloudUvs	Vertex_uv_TriangleIndex_To_CloudUvs_float
void Vertex_uv_TriangleIndex_To_CloudUvs_float(Texture2D<float4> Positions,SamplerState PositionsSampler,float2 VertexUv,float2 PointMapUv,float PointSize,float MaxWeldDistance,bool WeldToNeighbour,out float3 Position,out float2 ColourUv,out float PositionScore,out float EdgeScore)
{
	float u = PointMapUv.x;
	float v = PointMapUv.y;
	ColourUv = float2(u, 1.0 - v);	
	
	//	uv needs to be varying across the point PointSize
	//	so, PointSize*Texelsize
	float2 ColourTexelSize = float2(1.0,1.0) / float2(640.0, 480.0);
	//ColourUv += VertexUv * float2(PointSize, PointSize)*ColourTexelSize;

	//	sample from middle of texels to avoid odd samples (or bilinear accidents)
	//	gr: get proper size! 
	float4 PositionUv = float4(u, v, 0, 0);
	float2 PositionsTexelSize = float2(1.0,1.0) / float2(640.0, 480.0);
	PositionUv.xy += PositionsTexelSize * 0.5f;

	EdgeScore = 1 - GetEdgeScore(Positions, PositionsSampler, PositionUv, VertexUv, MaxWeldDistance );
	bool IsEdge = EdgeScore <= 0.0;

	//	if welding, move our vertex to the next position
	if ( WeldToNeighbour )
	{
		//	degenerate if edge
		PositionUv.xy += PositionsTexelSize * VertexUv * (IsEdge?0:1);	
	}

	//float4 PositionSample = tex2Dlod(Positions, PositionUv);
	float4 PositionSample = Positions.SampleLevel( PositionsSampler, PositionUv.xy, PositionUv.z);
	PositionScore = PositionSample.w;


	float3 CameraPosition = PositionSample.xyz;

	//	local space offset of the triangle
	float3 VertexPosition = float3(VertexUv, 0) * ((WeldToNeighbour&&!IsEdge) ? 0 : PointSize);
	CameraPosition += VertexPosition;
	
	//return CameraPosition.xyz;
	Position = CameraPosition.xyz;
}


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

float MaxSdfDistance;
float RenderSdfMinScore;
#define MAX_SDF_DISTANCE MaxSdfDistance

void Vertex_uv_TriangleIndex_To_CloudUvs_Sdf(Texture2D<float4> Positions,SamplerState PositionsSampler,float2 VertexUv,float2 PointMapUv,float PointSize,out float3 Position,out float3 Colour,out float Valid)
{
	float u = PointMapUv.x;
	float v = PointMapUv.y;
	//ColourUv = float2(u, 1.0 - v);	
	
	//	uv needs to be varying across the point PointSize
	//	so, PointSize*Texelsize
	float2 ColourTexelSize = float2(1.0,1.0) / float2(640.0, 480.0);
	//ColourUv += VertexUv * float2(PointSize, PointSize)*ColourTexelSize;

	float4 PositionUv = float4(u, v, 0, 0);
	//float4 PositionSample = tex2Dlod(Positions, PositionUv);
	float4 PositionSample = Positions.SampleLevel( PositionsSampler, PositionUv.xy, PositionUv.z);	

	//Valid = PositionSample.w;
	float Score = 1.0 - min(1.0,PositionSample.w/MAX_SDF_DISTANCE);
	Colour = NormalToRedGreen(Score);

	float3 CameraPosition = PositionSample.xyz;
	Valid = Score >= RenderSdfMinScore;

	//	local space offset of the triangle
	float3 VertexPosition = float3(VertexUv, 0) * PointSize;
	CameraPosition += VertexPosition;
	
	//return CameraPosition.xyz;
	Position = CameraPosition.xyz;
}