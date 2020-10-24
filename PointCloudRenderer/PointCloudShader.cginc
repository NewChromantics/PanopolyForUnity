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

//	gr: shadergraph fails looking for
//		Vertex_uv_TriangleIndex_To_CloudUvs
//	because of missing reference to 
//		Vertex_uv_TriangleIndex_To_CloudUvs_float
#define Vertex_uv_TriangleIndex_To_CloudUvs	Vertex_uv_TriangleIndex_To_CloudUvs_float
void Vertex_uv_TriangleIndex_To_CloudUvs_float(Texture2D<float4> Positions,SamplerState PositionsSampler,float2 VertexUv,float2 PointMapUv,float PointSize,out float3 Position,out float2 ColourUv,out float Valid)
{
	float u = PointMapUv.x;
	float v = PointMapUv.y;
	ColourUv = float2(u, 1.0 - v);	
	
	//	uv needs to be varying across the point PointSize
	//	so, PointSize*Texelsize
	float2 ColourTexelSize = float2(1.0,1.0) / float2(640.0, 480.0);
	//ColourUv += VertexUv * float2(PointSize, PointSize)*ColourTexelSize;

	float4 PositionUv = float4(u, v, 0, 0);
	//float4 PositionSample = tex2Dlod(Positions, PositionUv);
	float4 PositionSample = Positions.SampleLevel( PositionsSampler, PositionUv.xy, PositionUv.z);	

	Valid = PositionSample.w;

	float3 CameraPosition = PositionSample.xyz;
	//Valid = PositionSample.w > 0.5;

	//	local space offset of the triangle
	float3 VertexPosition = float3(VertexUv, 0) * PointSize;
	CameraPosition += VertexPosition;
	
	//return CameraPosition.xyz;
	Position = CameraPosition.xyz;
}

