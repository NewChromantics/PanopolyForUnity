using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class MakeDumbMesh : MonoBehaviour
{
	public Mesh mesh;

	[Range(2, 2048)]
	public int PointCountWidth = 640;
	[Range(2, 2048)]
	public int PointCountHeight = 480;
	public int PointCount { get { return PointCountWidth * PointCountHeight; } }
	public int VertexCount { get { return PointCount * 3; } }

	void GenerateMesh()
	{
		//	modify existing asset where possible
		mesh = MakeMesh(PointCountWidth, PointCountHeight, mesh);
		//	try and make the user save it as a file
#if UNITY_EDITOR
		mesh = AssetWriter.SaveAsset(mesh);
#endif
		var mf = GetComponent<MeshFilter>();
		if (mf != null)
		{
			mf.sharedMesh = mesh;
		}
	}

	void Update()
	{
		//	auto regen mesh
		if (mesh != null)
		{
			if (VertexCount != mesh.vertexCount)
			{
				Debug.Log("VertexCount " + VertexCount + " != mesh vertex count " + mesh.vertexCount + ", regenerating", this);
				GenerateMesh();
			}
		}
	}

	void OnEnable()
	{
		Update();

		if (mesh == null)
			GenerateMesh();
	}

	public static void AddTriangle(ref List<Vector3> Positions, ref List<Vector3> Uvs, ref List<int> Indexes, int x,int y, int Width, int Height)
	{
		//	xy = local triangle uv
		//	z = triangle index
		//	gr: if we have all triangles in the same place, this causes huge overdraw and cripples the GPU when it tries to render the raw mesh.
		//	gr: change this so it matches web layout (doesnt really matter, but might as well)
		var Index = x + (y * Width);
		var pos0 = new Vector3(0, 0, Index);
		var pos1 = new Vector3(1, 0, Index);
		var pos2 = new Vector3(0, 1, Index);
		//	these are point-uv's but would need adjusting in the shader to be less blocky, 
		//	but that would depend on point size so we dont do it here
		var u = x / (float)Width;
		var v = y / (float)Height;
		var uv0 = new Vector3(u, v, 0);
		var uv1 = new Vector3(u, v, 1);
		var uv2 = new Vector3(u, v, 2);

		var VertexIndex = Positions.Count;

		Positions.Add(pos0);
		Positions.Add(pos1);
		Positions.Add(pos2);
		Uvs.Add(uv0);
		Uvs.Add(uv1);
		Uvs.Add(uv2);

		Indexes.Add(VertexIndex + 0);
		Indexes.Add(VertexIndex + 1);
		Indexes.Add(VertexIndex + 2);
	}

	public static Mesh MakeMesh(int PointCountWidth, int PointCountHeight,Mesh ExistingMesh)
	{
		var Name = "Triangle Mesh " + PointCountWidth + "x" + PointCountHeight;
		Debug.Log("Generating new mesh " + Name);

		var Positions = new List<Vector3>();
		var Uvs = new List<Vector3>();
		var Indexes = new List<int>();

		for (int y = 0; y < PointCountHeight; y++)
		{
			for (int x = 0; x < PointCountWidth; x++)
			{
				AddTriangle(ref Positions, ref Uvs, ref Indexes, x, y, PointCountWidth, PointCountHeight);
			}
		}

		//	create new mesh if we need to
		if (ExistingMesh == null )
			ExistingMesh = new Mesh();
		var Mesh = ExistingMesh;
		Mesh.name = Name;

		Mesh.SetVertices(Positions);
		Mesh.SetUVs(0,Uvs);

		Mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
		Mesh.SetIndices(Indexes.ToArray(), MeshTopology.Triangles, 0, true );

		return Mesh;
	}
}
